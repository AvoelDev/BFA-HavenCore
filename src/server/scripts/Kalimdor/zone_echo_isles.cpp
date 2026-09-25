/*
 * 2026 BFA-HavenCore
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Echo Isles (6453), Darkspear troll start. Timings, positions, texts: retail 12.1.0 sniffs.
// Static data lives in the echo_isles migration (sql/updates/world); this file owns state and timers.

#include <algorithm>
#include <array>
#include <iterator>
#include <limits>
#include "ScriptMgr.h"
#include "CreatureAIImpl.h"
#include "CreatureTextMgr.h"
#include "DB2Structure.h"
#include "GameObject.h"
#include "Log.h"
#include "MotionMaster.h"
#include "MovementTypedefs.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "Random.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "Spell.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "SpellScript.h"
#include "TemporarySummon.h"
#include "WaypointManager.h"
#include "Vehicle.h"

/*######
## Darkspear Training Grounds
######*/

enum TrainingGroundsCreatures
{
    NPC_ZUNI_TRAINING_GROUNDS       = 37988,
    NPC_TIKI_TARGET                 = 38038,
    NPC_CAPTIVE_SPITESCALE_SCOUT    = 38142,
    NPC_DARKSPEAR_JAILOR            = 39062
};

// Shortest step the spline validator accepts (MoveSplineInitArgs).
float const MinSplineSegment = 0.1f;

// Replays a waypoint_data path as one spline; retail sends scene moves as multi-point splines.
// Slot 0 is overwritten with the mover's position; steps < MinSplineSegment are dropped (one zero-length step voids the spline).
// firstNode/lastNode: waypoint_data point range. velocity: overrides the creature's speed.
static bool MoveAlongRecordedPath(Creature* creature, uint32 pathId, uint32 pointId, bool walk,
    Optional<float> velocity = {}, uint32 firstNode = 0, uint32 lastNode = std::numeric_limits<uint32>::max())
{
    WaypointPath const* path = sWaypointMgr->GetPath(pathId);
    if (!path || path->empty())
        return false;

    std::vector<Position> points;
    points.reserve(path->size() + 1);
    points.push_back(creature->GetPosition());
    for (WaypointData const* node : *path)
    {
        if (node->id < firstNode || node->id > lastNode)
            continue;

        Position const next(node->x, node->y, node->z);
        if (points.back().GetExactDist(&next) >= MinSplineSegment)
            points.push_back(next);
    }

    if (points.size() < 2)
    {
        // Already there: report arrival anyway so callers keep one code path.
        if (CreatureAI* ai = creature->AI())
            ai->MovementInform(EFFECT_MOTION_TYPE, pointId);
        return true;
    }

    creature->GetMotionMaster()->MoveSmoothPath(pointId, points.data(), points.size(), walk, false, velocity);
    return true;
}

// Prepends the mover's position: MoveSplineInit overwrites slot 0, so the list's first point would be lost (cut corners).
static void MoveAlongPoints(Creature* creature, uint32 pointId, Position const* points, size_t count, bool walk,
    bool fly = false, Optional<float> velocity = {})
{
    std::vector<Position> path;
    path.reserve(count + 1);
    path.push_back(creature->GetPosition());
    for (size_t i = 0; i < count; ++i)
        if (path.back().GetExactDist(&points[i]) >= MinSplineSegment)
            path.push_back(points[i]);

    if (path.size() < 2)
    {
        if (CreatureAI* ai = creature->AI())
            ai->MovementInform(EFFECT_MOTION_TYPE, pointId);
        return;
    }

    creature->GetMotionMaster()->MoveSmoothPath(pointId, path.data(), path.size(), walk, fly, velocity);
}

// Position of one recorded node, for moves that are not a spline replay.
static Optional<Position> GetRecordedPathNode(uint32 pathId, uint32 node)
{
    if (WaypointPath const* path = sWaypointMgr->GetPath(pathId))
        for (WaypointData const* data : *path)
            if (data->id == node)
                return Position(data->x, data->y, data->z, data->orientation);

    return {};
}

// Facing stored on a recorded path's last node.
static float GetRecordedPathFacing(uint32 pathId, float fallback)
{
    WaypointPath const* path = sWaypointMgr->GetPath(pathId);
    return path && !path->empty() ? path->back()->orientation : fallback;
}

/*######
## EchoIslesPatrolAI - looped stops with an action at each (plain waypoint paths can't run one).
## Stop 0 = spawn; each stop has its own recorded path, last node = facing (0 = keep arrival facing).
######*/

struct PatrolStop
{
    uint32 PathTo;          // waypoint_data path walked to reach this stop
    Milliseconds MinPause;
    Milliseconds MaxPause;
};

enum EchoIslesPatrol
{
    POINT_PATROL_STOP               = 1,
    EVENT_PATROL_ARRIVE             = 1,
    EVENT_PATROL_DEPART             = 2
};

// Wait out the turn: channels that break on turning (Ardsami's "Read Scroll") fail otherwise. Retail: 0.2 s.
Milliseconds const PatrolActionDelay = 500ms;

struct EchoIslesPatrolAI : public ScriptedAI
{
    template<std::size_t N>
    EchoIslesPatrolAI(Creature* creature, PatrolStop const (&stops)[N]) : ScriptedAI(creature), _stops(stops), _stopCount(N), _stop(0) { }

    void Reset() override
    {
        events.Reset();
        _stop = 0;
        ArriveAtStop();
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type == EFFECT_MOTION_TYPE && pointId == POINT_PATROL_STOP)
            ArriveAtStop();
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        uint32 const eventId = events.ExecuteEvent();
        if (eventId == EVENT_PATROL_ARRIVE)
        {
            OnArrive(_stop);
            return;
        }
        if (eventId != EVENT_PATROL_DEPART)
            return;

        OnDepart(_stop);
        // Advance first: arrival can fire inside the move call.
        _stop = (_stop + 1) % _stopCount;
        MoveAlongRecordedPath(me, _stops[_stop].PathTo, POINT_PATROL_STOP, true);
    }

protected:
    virtual void OnArrive(std::size_t /*stop*/) { }
    virtual void OnDepart(std::size_t /*stop*/) { }

private:
    void ArriveAtStop()
    {
        PatrolStop const& stop = _stops[_stop];
        float const facing = _stop ? GetRecordedPathFacing(stop.PathTo, 0.0f) : me->GetHomePosition().GetOrientation();
        if (facing != 0.0f)
            me->SetFacingTo(facing);
        events.ScheduleEvent(EVENT_PATROL_ARRIVE, PatrolActionDelay);
        events.ScheduleEvent(EVENT_PATROL_DEPART, stop.MinPause + PatrolActionDelay, stop.MaxPause + PatrolActionDelay);
    }

    PatrolStop const* _stops;
    std::size_t _stopCount;
    std::size_t _stop;
};

/*######
## Intro Zuni (37988) - summoned on zone entry (91404). Quest accept -> Jin'thala casts 71035
## (rewards tracking quest 24644, applies aura 93342). First step breaks 93342 -> 71037 hits Zuni -> greet and run.
######*/

enum IntroZuni
{
    ZONE_ECHO_ISLES                     = 6453,
    QUEST_TROLL_INTRODUCTION_TRACKING   = 24644,

    SPELL_SUMMON_ZUNI_LVL_1             = 91404,
    SPELL_TROLL_INTRODUCTION_TRACKING   = 71035,
    SPELL_ZUNI_LVL_1_TRIGGER_AURA       = 93342,
    SPELL_ZUNI_LVL_1_TRIGGER            = 71037,

    SAY_JINTHALA_FIND_YOUR_TRAINER      = 0,
    SAY_ZUNI_CRACK_SKULLS               = 0,
    SAY_ZUNI_FIND_YOUR_TRAINER          = 1,

    PATH_ZUNI_TO_TRAINING_GROUNDS       = 3798800,
    POINT_ZUNI_TRAINING_GROUNDS         = 1,

    EVENT_ZUNI_GREET                    = 1,
    EVENT_ZUNI_RUN                      = 2,
    EVENT_ZUNI_TURN_AWAY                = 3,
    EVENT_ZUNI_DESPAWN                  = 4,
    EVENT_INTRO_ZUNI_CHECK_OWNER              = 5
};

// Retail spot beside Jin'thala.
Position const ZuniSummonPos = { -1173.4531f, -5266.401f, 0.94239277f, 0.941414594650268554f };
float const ZuniFinalFacing = 3.490658521652221679f;
float const IntroZuniLeashRange = 100.0f;

static bool IsOwnIntroZuni(Unit const* unit, ObjectGuid ownerGuid)
{
    if (!unit || unit->GetEntry() != NPC_ZUNI_TRAINING_GROUNDS || !unit->IsAlive())
        return false;
    TempSummon const* summon = unit->ToTempSummon();
    return summon && summon->GetSummonerGUID() == ownerGuid;
}

static bool HasIntroZuni(Player const* player)
{
    std::list<Creature*> zunis;
    player->GetCreatureListWithEntryInGrid(zunis, NPC_ZUNI_TRAINING_GROUNDS, IntroZuniLeashRange);
    for (Creature* zuni : zunis)
        if (IsOwnIntroZuni(zuni, player->GetGUID()))
            return true;
    return false;
}

struct npc_jinthala : public ScriptedAI
{
    npc_jinthala(Creature* creature) : ScriptedAI(creature) { }

    void sQuestAccept(Player* player, Quest const* /*quest*/) override
    {
        Talk(SAY_JINTHALA_FIND_YOUR_TRAINER, player);
        me->CastSpell(player, SPELL_TROLL_INTRODUCTION_TRACKING, true);
    }
};

struct npc_zuni_training_grounds : public ScriptedAI
{
    npc_zuni_training_grounds(Creature* creature) : ScriptedAI(creature), _started(false) { }

    void IsSummonedBy(Unit* summoner) override
    {
        // Retail: player-summoned only; anything else means bad spell data.
        if (!summoner->IsPlayer())
        {
            me->DespawnOrUnsummon();
            return;
        }

        _playerGuid = summoner->GetGUID();
        me->SetReactState(REACT_PASSIVE);
        events.ScheduleEvent(EVENT_INTRO_ZUNI_CHECK_OWNER, 5s);
    }

    void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_ZUNI_LVL_1_TRIGGER || _started || caster->GetGUID() != _playerGuid)
            return;

        _started = true;
        events.ScheduleEvent(EVENT_ZUNI_GREET, 1700ms);
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type != EFFECT_MOTION_TYPE || pointId != POINT_ZUNI_TRAINING_GROUNDS)
            return;

        if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid))
        {
            me->SetFacingToObject(player);
            Talk(SAY_ZUNI_FIND_YOUR_TRAINER, player);
        }

        events.ScheduleEvent(EVENT_ZUNI_TURN_AWAY, 6s);
        events.ScheduleEvent(EVENT_ZUNI_DESPAWN, 27s);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_ZUNI_GREET:
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid))
                    {
                        me->SetFacingToObject(player);
                        Talk(SAY_ZUNI_CRACK_SKULLS, player);
                    }
                    events.ScheduleEvent(EVENT_ZUNI_RUN, 4700ms);
                    break;
                case EVENT_ZUNI_RUN:
                    MoveAlongRecordedPath(me, PATH_ZUNI_TO_TRAINING_GROUNDS, POINT_ZUNI_TRAINING_GROUNDS, false);
                    break;
                case EVENT_ZUNI_TURN_AWAY:
                    me->SetFacingTo(ZuniFinalFacing);
                    break;
                case EVENT_ZUNI_DESPAWN:
                    me->DespawnOrUnsummon();
                    return;
                case EVENT_INTRO_ZUNI_CHECK_OWNER:
                {
                    Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid);
                    if (!player || !me->IsWithinDistInMap(player, IntroZuniLeashRange))
                    {
                        me->DespawnOrUnsummon();
                        return;
                    }
                    events.Repeat(5s);
                    break;
                }
                default:
                    break;
            }
        }
    }

private:
    ObjectGuid _playerGuid;
    bool _started;
};

// Fixed retail spot; the nearby-entry destination would put him inside Jin'thala.
class spell_echo_isles_summon_zuni_lvl_1 : public SpellScript
{
    PrepareSpellScript(spell_echo_isles_summon_zuni_lvl_1);

    void SetDestination(SpellDestination& destination)
    {
        destination.Relocate(ZuniSummonPos);
    }

    void Register() override
    {
        OnDestinationTargetSelect += SpellDestinationTargetSelectFn(spell_echo_isles_summon_zuni_lvl_1::SetDestination, EFFECT_0, TARGET_DEST_NEARBY_ENTRY);
    }
};

// 93342 -> 71037 on first step (retail: 2.4-7.9 s after accept). Also on expiry (20 s), or an idle player keeps Zuni forever.
class spell_echo_isles_zuni_lvl_1_trigger_aura : public AuraScript
{
    PrepareAuraScript(spell_echo_isles_zuni_lvl_1_trigger_aura);

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        AuraRemoveMode removeMode = GetTargetApplication()->GetRemoveMode();
        if (removeMode != AURA_REMOVE_BY_INTERRUPT && removeMode != AURA_REMOVE_BY_EXPIRE)
            return;

        GetTarget()->CastSpell(GetTarget(), SPELL_ZUNI_LVL_1_TRIGGER, true);
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(spell_echo_isles_zuni_lvl_1_trigger_aura::HandleRemove, EFFECT_0, SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Only the caster's own Zuni.
class spell_echo_isles_zuni_lvl_1_trigger : public SpellScript
{
    PrepareSpellScript(spell_echo_isles_zuni_lvl_1_trigger);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        ObjectGuid casterGuid = GetCaster()->GetGUID();
        targets.remove_if([casterGuid](WorldObject* target)
        {
            return !target->IsUnit() || !IsOwnIntroZuni(target->ToUnit(), casterGuid);
        });
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_echo_isles_zuni_lvl_1_trigger::FilterTargets, EFFECT_0, TARGET_UNIT_DEST_AREA_ENTRY);
    }
};

// Not spell_area: the aura would persist on the character and block re-summons after relog.
class player_echo_isles_intro_zuni : public PlayerScript
{
public:
    player_echo_isles_intro_zuni() : PlayerScript("player_echo_isles_intro_zuni") { }

    void OnLogin(Player* player, bool /*firstLogin*/) override
    {
        // Delay until fully in world; player-owned event dies with the player.
        player->m_Events.AddEventAtOffset([player]()
        {
            SummonIntroZuniIfNeeded(player);
        }, 1s);
    }

    void OnUpdateZone(Player* player, uint32 newZone, uint32 /*oldZone*/, uint32 /*newArea*/) override
    {
        if (newZone == ZONE_ECHO_ISLES)
            SummonIntroZuniIfNeeded(player);
    }

private:
    static void SummonIntroZuniIfNeeded(Player* player)
    {
        if (player->getRace() != RACE_TROLL || player->GetZoneId() != ZONE_ECHO_ISLES
            || player->GetQuestStatus(QUEST_TROLL_INTRODUCTION_TRACKING) == QUEST_STATUS_REWARDED
            || HasIntroZuni(player))
            return;

        player->CastSpell(player, SPELL_SUMMON_ZUNI_LVL_1, true);
    }
};

/*######
## Proving Pit - Jailor (39062) and Captive Spitescale Scout (38142)
## Gossip -> credit, Jailor walks to cage, scout walks in and fights. Cage state never changes on retail;
## the door is a one-shot anim kit. Retail's 227105 would *use* the cage in this core, so the kit is sent directly.
######*/

struct ProvingPit
{
    Position JailorAtCage;  // Jailor stop at the cage
    Position ScoutArena;    // scout wait spot in the pit
    uint32 JailorOutPath;   // path to cage
    uint32 JailorBackPath;  // path home
};

ProvingPit const ProvingPits[] =
{
    // North pit
    { { -1135.87f, -5416.76f, 13.27f }, { -1142.49f, -5415.59f, 10.60f }, 3906202, 3906203 },
    // South pit
    { { -1153.5295f, -5518.6094f, 12.005672f }, { -1149.03f, -5526.18f, 8.1045685f }, 3906200, 3906201 }
};

// Shared entries for both pits: pick by spawn point, not GUID.
static ProvingPit const& GetProvingPit(Creature const* creature)
{
    Position const& home = creature->GetHomePosition();
    ProvingPit const* nearest = &ProvingPits[0];
    for (ProvingPit const& pit : ProvingPits)
        if (home.GetExactDist2dSq(pit.JailorAtCage) < home.GetExactDist2dSq(nearest->JailorAtCage))
            nearest = &pit;
    return *nearest;
}

enum ProvingPitData
{
    GOSSIP_MENU_PROVING_PIT         = 10974,

    GO_DARKSPEAR_CAGE               = 201968,
    // SMSG_GAME_OBJECT_ACTIVATE_ANIM_KIT, Maintain false
    ANIM_KIT_DARKSPEAR_CAGE_OPEN    = 11172,

    SAY_JAILOR_GET_IN_THE_PIT       = 0,
    SAY_SCOUT_TAUNT                 = 0,

    // Scout's only retail spell
    SPELL_SPITESCALE_SCOUT_ATTACK   = 15089,

    ACTION_RELEASE_SCOUT            = 1,
    DATA_CHALLENGER                 = 1,

    POINT_JAILOR_CAGE               = 1,
    POINT_JAILOR_HOME               = 2,
    POINT_SCOUT_ARENA               = 1,

    EVENT_JAILOR_WALK_TO_CAGE       = 1,
    EVENT_JAILOR_RELEASE_SCOUT      = 2,
    EVENT_SCOUT_ATTACK              = 1,
    EVENT_SCOUT_CAST                = 2
};

float const ProvingPitSearchRange = 30.0f;
// Jailor stops 2-4 yd from the door.
float const DarkspearCageSearchRange = 10.0f;

struct npc_darkspear_jailor : public ScriptedAI
{
    npc_darkspear_jailor(Creature* creature) : ScriptedAI(creature), _presenting(false) { }

    void Reset() override
    {
        _presenting = false;
        events.Reset();
    }

    void sGossipSelect(Player* player, uint32 menuId, uint32 /*gossipListId*/) override
    {
        if (menuId != GOSSIP_MENU_PROVING_PIT)
            return;

        player->KilledMonsterCredit(NPC_DARKSPEAR_JAILOR);
        Talk(SAY_JAILOR_GET_IN_THE_PIT, player);

        // Retail: gossip stays open mid-fight; later challengers get credit and join.
        if (_presenting)
            return;

        _presenting = true;
        _challengerGuid = player->GetGUID();
        events.ScheduleEvent(EVENT_JAILOR_WALK_TO_CAGE, 1s);
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type != EFFECT_MOTION_TYPE)
            return;

        switch (pointId)
        {
            case POINT_JAILOR_CAGE:
                me->HandleEmoteCommand(EMOTE_ONESHOT_USE_STANDING);
                if (GameObject* cage = me->FindNearestGameObject(GO_DARKSPEAR_CAGE, DarkspearCageSearchRange))
                    cage->SetAnimKitId(ANIM_KIT_DARKSPEAR_CAGE_OPEN, true);
                events.ScheduleEvent(EVENT_JAILOR_RELEASE_SCOUT, 1600ms);
                break;
            case POINT_JAILOR_HOME:
                me->SetFacingTo(me->GetHomePosition().GetOrientation());
                _presenting = false;
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_JAILOR_WALK_TO_CAGE:
                    // Retail: runs out, walks back.
                    if (!MoveAlongRecordedPath(me, GetProvingPit(me).JailorOutPath, POINT_JAILOR_CAGE, false))
                        _presenting = false;
                    break;
                case EVENT_JAILOR_RELEASE_SCOUT:
                    if (Creature* scout = me->FindNearestCreature(NPC_CAPTIVE_SPITESCALE_SCOUT, ProvingPitSearchRange))
                    {
                        scout->AI()->SetGUID(_challengerGuid, DATA_CHALLENGER);
                        scout->AI()->DoAction(ACTION_RELEASE_SCOUT);
                    }
                    if (!MoveAlongRecordedPath(me, GetProvingPit(me).JailorBackPath, POINT_JAILOR_HOME, true))
                        _presenting = false;
                    break;
                default:
                    break;
            }
        }
    }

private:
    ObjectGuid _challengerGuid;
    bool _presenting;
};

struct npc_captive_spitescale_scout : public ScriptedAI
{
    npc_captive_spitescale_scout(Creature* creature) : ScriptedAI(creature), _released(false) { }

    void Reset() override
    {
        _released = false;
        _challengerGuid.Clear();
        events.Reset();

        // Hostile but PC-immune while caged: no aggro through the bars.
        me->AddUnitFlag(UNIT_FLAG_IMMUNE_TO_PC);
        me->SetEmoteState(EMOTE_ONESHOT_NONE);
    }

    void SetGUID(ObjectGuid guid, int32 id) override
    {
        if (id == DATA_CHALLENGER && !_released)
            _challengerGuid = guid;
    }

    void DoAction(int32 action) override
    {
        if (action != ACTION_RELEASE_SCOUT || _released || me->IsInCombat())
            return;

        _released = true;
        me->SetWalk(true);
        me->GetMotionMaster()->MovePoint(POINT_SCOUT_ARENA, GetProvingPit(me).ScoutArena);
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type != POINT_MOTION_TYPE || pointId != POINT_SCOUT_ARENA)
            return;

        me->RemoveUnitFlag(UNIT_FLAG_IMMUNE_TO_PC);
        me->SetEmoteState(EMOTE_STATE_READY_UNARMED);
        Talk(SAY_SCOUT_TAUNT);
        events.ScheduleEvent(EVENT_SCOUT_ATTACK, 1800ms);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        me->SetEmoteState(EMOTE_ONESHOT_NONE);
        events.ScheduleEvent(EVENT_SCOUT_CAST, 1s, 2500ms);
    }

    void JustDied(Unit* /*killer*/) override
    {
        // Retail: next scout ~6 s after the kill.
        me->DespawnOrUnsummon(5s, 1s);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_SCOUT_ATTACK:
                    if (Player* challenger = ObjectAccessor::GetPlayer(*me, _challengerGuid))
                        if (challenger->IsAlive() && me->IsWithinDistInMap(challenger, ProvingPitSearchRange))
                        {
                            AttackStart(challenger);
                            break;
                        }
                    EnterEvadeMode(EVADE_REASON_NO_HOSTILES);
                    break;
                case EVENT_SCOUT_CAST:
                    DoCastVictim(SPELL_SPITESCALE_SCOUT_ATTACK);
                    events.Repeat(20s);
                    break;
                default:
                    break;
            }
        }

        if (!UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }

private:
    ObjectGuid _challengerGuid;
    bool _released;
};

/*######
## player_echo_isles_trainer_praise - trainer line when the Tiki Target / Scout objective completes.
## Keyed on the objective creature so every class variant is covered without a quest list.
######*/

enum TrainerPraiseTexts
{
    SAY_TRAINER_NOT_BAD             = 0,
    SAY_TRAINER_WELL_DONE           = 1
};

float const TrainerPraiseRange = 50.0f;

class player_echo_isles_trainer_praise : public PlayerScript
{
public:
    player_echo_isles_trainer_praise() : PlayerScript("player_echo_isles_trainer_praise") { }

    void OnObjectiveValidate(Player* player, uint32 questId, uint32 objectiveId) override
    {
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        if (!quest)
            return;

        QuestObjectives const& objectives = quest->GetObjectives();
        auto objective = std::find_if(objectives.begin(), objectives.end(), [objectiveId](QuestObjective const& obj) { return obj.ID == objectiveId; });
        if (objective == objectives.end() || objective->Type != QUEST_OBJECTIVE_MONSTER)
            return;

        uint8 textGroup;
        switch (objective->ObjectID)
        {
            case NPC_TIKI_TARGET:
                textGroup = SAY_TRAINER_NOT_BAD;
                break;
            case NPC_CAPTIVE_SPITESCALE_SCOUT:
                textGroup = SAY_TRAINER_WELL_DONE;
                break;
            default:
                return;
        }

        QuestRelationReverseBounds enders = sObjectMgr->GetCreatureQuestInvolvedRelationReverseBounds(questId);
        for (auto itr = enders.first; itr != enders.second; ++itr)
        {
            if (!sCreatureTextMgr->TextExist(itr->second, textGroup))
                continue;

            if (Creature* trainer = player->FindNearestCreature(itr->second, TrainerPraiseRange))
            {
                sCreatureTextMgr->SendChat(trainer, textGroup, player);
                return;
            }
        }
    }
};


/*######
## npc_tiki_target - 38038
## Random visual (1 of 3) + Arcane Missiles Trainer aura; death visual on kill. Never fights or evades (would heal mid-quest).
######*/

// Retail NPC-vs-NPC fights never finish: Darkspear/naga floor 50%, Tiki Targets 85%.
int32 const NpcDamageFloorPct = 50;
int32 const TikiNpcDamageFloorPct = 85;

static void ApplyNpcDamageFloor(Creature* victim, Unit* attacker, uint32& damage, int32 floorPct = NpcDamageFloorPct)
{
    if (attacker && !attacker->IsControlledByPlayer() && victim->HealthBelowPctDamaged(floorPct, damage))
        damage = 0;
}

enum TikiTarget
{
    SPELL_TIKI_TARGET_VISUAL_1      = 71064,
    SPELL_TIKI_TARGET_VISUAL_2      = 71065,
    SPELL_TIKI_TARGET_VISUAL_3      = 71066,
    SPELL_TIKI_TARGET_STUN          = 7056,
    SPELL_ARCANE_MISSILES_TRAINER   = 83470,
    SPELL_TIKI_TARGET_DEATH         = 71240
};


struct npc_tiki_target : public ScriptedAI
{
    npc_tiki_target(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
        if (!me->HasAura(SPELL_TIKI_TARGET_STUN))
            DoCastSelf(SPELL_TIKI_TARGET_STUN, true);
        DoCastSelf(RAND(SPELL_TIKI_TARGET_VISUAL_1, SPELL_TIKI_TARGET_VISUAL_2, SPELL_TIKI_TARGET_VISUAL_3), true);
        DoCastSelf(SPELL_ARCANE_MISSILES_TRAINER, true);
    }

    void AttackStart(Unit* /*who*/) override { }

    void EnterEvadeMode(EvadeReason /*why*/) override { }

    // Retail: novices hit for real, but only a player breaks a dummy.
    void DamageTaken(Unit* attacker, uint32& damage) override
    {
        ApplyNpcDamageFloor(me, attacker, damage, TikiNpcDamageFloorPct);
    }

    void JustDied(Unit* /*killer*/) override
    {
        DoCastSelf(SPELL_TIKI_TARGET_DEATH, true);
    }

    void UpdateAI(uint32 /*diff*/) override { }
};

/*######
## npc_echo_isles_sparring - endless NPC fights: novices vs tiki targets, tribesmen/shamans vs naga.
## Stays at post, nearest foe from its list, retail ability; nobody chases. NPC damage floor on both sides.
######*/

enum EchoIslesSparring
{
    NPC_SPITESCALE_WAVETHRASHER     = 38300,
    NPC_SPITESCALE_SIREN            = 38301,
    NPC_DARKSPEAR_SHAMAN            = 38326,

    SPELL_SHAMAN_CHAIN_HEAL         = 72014,
    SPELL_PERMANENT_FEIGN_DEATH     = 29266,

    EVENT_SPARRING_FIND_FOE         = 1,
    EVENT_SPARRING_HEAL             = 2,
    EVENT_SPARRING_CAST             = 3,
    EVENT_SPARRING_MANA_CHECK       = 4
};

struct SparringRole
{
    uint32 Entry;
    uint32 SpellId;                 // 0 = melee only
    std::array<uint32, 2> Foes;
    float SearchRange;
    uint32 CastMinMs;                // 0 = normal attack/cast cadence
    uint32 CastMaxMs;
};

SparringRole const SparringRoles[] =
{
    { 38268, 25710, { NPC_TIKI_TARGET, 0 }, 20.0f, 8000, 12000 }, // Warrior - Heroic Strike
    { 38272, 60195, { NPC_TIKI_TARGET, 0 }, 20.0f, 6000,  9000 }, // Rogue   - Sinister Strike
    { 38278,  9734, { NPC_TIKI_TARGET, 0 }, 20.0f, 2800,  4100 }, // Priest  - Holy Smite
    { 38279, 20797, { NPC_TIKI_TARGET, 0 }, 20.0f, 2200,  4700 }, // Mage    - Fireball
    { 38280,  9739, { NPC_TIKI_TARGET, 0 }, 20.0f, 2200,  4700 }, // Druid   - Wrath
    { 38281, 20802, { NPC_TIKI_TARGET, 0 }, 20.0f, 2200,  4700 }, // Shaman  - Lightning Bolt
    { 38282,  6660, { NPC_TIKI_TARGET, 0 }, 20.0f, 2000,  3000 }, // Hunter  - Shoot
    { 42619, 20791, { NPC_TIKI_TARGET, 0 }, 20.0f, 2200,  4700 }, // Warlock - Shadow Bolt
    { 38324,     0, { NPC_SPITESCALE_WAVETHRASHER, NPC_SPITESCALE_SIREN }, 8.0f, 0, 0 },     // Darkspear Tribesman - melee
    { 38326, 73212, { NPC_SPITESCALE_WAVETHRASHER, NPC_SPITESCALE_SIREN }, 30.0f, 0, 0 }     // Darkspear Shaman    - Lightning Bolt
};

Milliseconds const SparringRetargetDelay = 2s;

// Retail rogue novice: 100 energy. The core only builds mana pools, so energy users spawn with MaxPower 0.
int32 const SparringEnergyPool = 100;
uint32 const NPC_ROGUE_NOVICE = 38272;
uint32 const NPC_WARRIOR_NOVICE = 38268;

// Retail naga "corpses" are live spawns under Permanent Feign Death; skip them.
static bool IsStagedCorpse(Unit const* unit)
{
    return unit->HasAura(SPELL_PERMANENT_FEIGN_DEATH);
}

// Retail: ~1 Chain Heal per 3 bolts.
Milliseconds const ShamanChainHealCooldown = 7s;
float const ShamanChainHealRange = 40.0f;
uint32 const ShamanChainHealMissingPct = 30;

struct npc_echo_isles_sparring : public ScriptedAI
{
    npc_echo_isles_sparring(Creature* creature) : ScriptedAI(creature), _role(nullptr), _spellInfo(nullptr), _manaResting(false)
    {
        for (SparringRole const& role : SparringRoles)
            if (role.Entry == me->GetEntry())
                _role = &role;

        if (_role && _role->SpellId)
            _spellInfo = sSpellMgr->GetSpellInfo(_role->SpellId);

        // Warrior/rogue swing between abilities; Sinister Strike isn't on-next-swing, so SpellInfo can't tell.
        _meleeRole = me->GetEntry() == NPC_WARRIOR_NOVICE || me->GetEntry() == NPC_ROGUE_NOVICE
            || !_spellInfo || _spellInfo->IsNextMeleeSwingSpell();
    }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
        _manaResting = false;
        if (me->GetPowerType() == POWER_MANA)
            me->AddUnitFlag2(UNIT_FLAG2_REGENERATE_POWER);
        InitEnergyPool();

        events.Reset();
        events.ScheduleEvent(EVENT_SPARRING_FIND_FOE, SparringRetargetDelay);
        if (me->GetEntry() == NPC_DARKSPEAR_SHAMAN)
            events.ScheduleEvent(EVENT_SPARRING_HEAL, ShamanChainHealCooldown);
    }

    void MoveInLineOfSight(Unit* /*who*/) override { }

    void AttackStart(Unit* /*who*/) override { }

    void DamageTaken(Unit* attacker, uint32& damage) override
    {
        ApplyNpcDamageFloor(me, attacker, damage);
    }

    // Foe gone: stay put, retarget.
    void EnterEvadeMode(EvadeReason /*why*/) override
    {
        me->CombatStop(true);
        _manaResting = false;
        if (me->GetPowerType() == POWER_MANA)
            me->AddUnitFlag2(UNIT_FLAG2_REGENERATE_POWER);
        events.RescheduleEvent(EVENT_SPARRING_FIND_FOE, SparringRetargetDelay);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_SPARRING_FIND_FOE:
                    StartOnNearestFoe();
                    break;
                case EVENT_SPARRING_HEAL:
                    if (!me->HasUnitState(UNIT_STATE_CASTING))
                        if (Unit* hurt = DoSelectLowestHpFriendly(ShamanChainHealRange, ShamanChainHealMissingPct))
                            DoCast(hurt, SPELL_SHAMAN_CHAIN_HEAL);
                    events.Repeat(ShamanChainHealCooldown);
                    break;
                case EVENT_SPARRING_CAST:
                    if (_role && _spellInfo && me->GetVictim() && !me->HasUnitState(UNIT_STATE_CASTING))
                    {
                        if (NeedsManaRest())
                        {
                            BeginManaRest();
                            break;
                        }

                        me->CastSpell(me->GetVictim(), _spellInfo, TRIGGERED_NONE);
                    }
                    if (_role && _role->CastMaxMs && !_manaResting)
                        events.ScheduleEvent(EVENT_SPARRING_CAST, Milliseconds(urand(_role->CastMinMs, _role->CastMaxMs)));
                    break;
                case EVENT_SPARRING_MANA_CHECK:
                    if (!_manaResting)
                        break;
                    if (me->GetPower(POWER_MANA) >= me->CountPctFromMaxPower(POWER_MANA, 90))
                    {
                        _manaResting = false;
                        me->RemoveUnitFlag2(UNIT_FLAG2_REGENERATE_POWER);
                        if (_role && _role->CastMaxMs)
                            events.ScheduleEvent(EVENT_SPARRING_CAST, Milliseconds(urand(_role->CastMinMs, _role->CastMaxMs)));
                    }
                    else
                        events.Repeat(1s);
                    break;
                default:
                    break;
            }
        }

        if (!_role)
            return;

        Unit* foe = me->GetVictim();
        if (!foe)
            return;

        if (!foe->IsAlive())
        {
            EnterEvadeMode(EVADE_REASON_NO_HOSTILES);
            return;
        }

        if (!_spellInfo)
        {
            DoMeleeAttackIfReady();
            return;
        }

        if (_role->CastMaxMs)
        {
            if (_meleeRole)
                DoMeleeAttackIfReady();
            return;
        }

        if (_spellInfo->IsNextMeleeSwingSpell())
        {
            if (!me->GetCurrentSpell(CURRENT_MELEE_SPELL))
                me->CastSpell(foe, _spellInfo, TRIGGERED_NONE);
            DoMeleeAttackIfReady();
            return;
        }

        if (_spellInfo->CalcCastTime() > 0)
        {
            if (!me->HasUnitState(UNIT_STATE_CASTING))
                me->CastSpell(foe, _spellInfo, TRIGGERED_NONE);
            return;
        }

        DoSpellAttackIfReady(_spellInfo->Id);
    }

private:
    void StartOnNearestFoe()
    {
        Creature* foe = nullptr;
        if (_role)
        {
            for (uint32 entry : _role->Foes)
            {
                if (!entry)
                    continue;

                std::list<Creature*> candidates;
                me->GetCreatureListWithEntryInGrid(candidates, entry, _role->SearchRange);
                for (Creature* candidate : candidates)
                    if (candidate->IsAlive() && !IsStagedCorpse(candidate) && (!foe || me->GetDistance(candidate) < me->GetDistance(foe)))
                        foe = candidate;
            }
        }

        if (!foe)
        {
            events.ScheduleEvent(EVENT_SPARRING_FIND_FOE, SparringRetargetDelay);
            return;
        }

        me->SetFacingToObject(foe);

        me->Attack(foe, _meleeRole);

        // Retail casters drain, pause, then recover: no passive regen while casting, only during mana rest.
        if (me->GetPowerType() == POWER_MANA)
            me->RemoveUnitFlag2(UNIT_FLAG2_REGENERATE_POWER);

        if (_role->CastMaxMs)
            events.RescheduleEvent(EVENT_SPARRING_CAST, Milliseconds(urand(500, _role->CastMaxMs)));
    }

    bool NeedsManaRest() const
    {
        if (!_spellInfo || me->GetPowerType() != POWER_MANA)
            return false;

        for (SpellPowerCost const& cost : _spellInfo->CalcPowerCost(me, _spellInfo->GetSchoolMask()))
            if (cost.Power == POWER_MANA)
                return cost.Amount > me->GetPower(POWER_MANA);

        return false;
    }

    void BeginManaRest()
    {
        _manaResting = true;
        me->AddUnitFlag2(UNIT_FLAG2_REGENERATE_POWER);
        events.CancelEvent(EVENT_SPARRING_CAST);
        events.ScheduleEvent(EVENT_SPARRING_MANA_CHECK, 1s);
    }

    // Rogue: retail 100 energy; creature_template unit_class owns the power type.
    // The core still spawns energy users with MaxPower 0, so only repair the pool here.
    void InitEnergyPool()
    {
        if (me->GetEntry() != NPC_ROGUE_NOVICE)
            return;

        me->SetMaxPower(POWER_ENERGY, SparringEnergyPool);
        me->SetFullPower(POWER_ENERGY);
        me->AddUnitFlag2(UNIT_FLAG2_REGENERATE_POWER);
    }

    SparringRole const* _role;
    SpellInfo const* _spellInfo;
    bool _manaResting;
    bool _meleeRole = false;
};

/*######
## npc_echo_isles_class_trainer - walks to the pit on "Proving Pit" accept, home after turn-in.
## Paths <entry>00 (to pit, last node = facing) / <entry>01 (home). Idle stance off while away.
######*/

enum ClassTrainer
{
    POINT_TRAINER_AT_PIT            = 1,
    POINT_TRAINER_HOME              = 2,

    EVENT_TRAINER_WALK_TO_PIT       = 1,
    EVENT_TRAINER_WALK_HOME         = 2
};

// Keyed on the scout objective: covers every class variant.
static bool IsProvingPitQuest(Quest const* quest)
{
    for (QuestObjective const& objective : quest->GetObjectives())
        if (objective.Type == QUEST_OBJECTIVE_MONSTER && objective.ObjectID == NPC_CAPTIVE_SPITESCALE_SCOUT)
            return true;
    return false;
}

struct npc_echo_isles_class_trainer : public ScriptedAI
{
    npc_echo_isles_class_trainer(Creature* creature) : ScriptedAI(creature), _atPit(false), _idleEmoteState(EMOTE_ONESHOT_NONE) { }

    void InitializeAI() override
    {
        if (CreatureAddon const* addon = me->GetCreatureAddon())
            _idleEmoteState = Emote(addon->emote);
        ScriptedAI::InitializeAI();
    }

    void sQuestAccept(Player* /*player*/, Quest const* quest) override
    {
        if (IsProvingPitQuest(quest) && !_atPit)
            events.RescheduleEvent(EVENT_TRAINER_WALK_TO_PIT, 2300ms);
    }

    void sQuestReward(Player* /*player*/, Quest const* quest, uint32 /*opt*/) override
    {
        if (IsProvingPitQuest(quest) && _atPit)
            events.RescheduleEvent(EVENT_TRAINER_WALK_HOME, 5700ms);
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type != EFFECT_MOTION_TYPE)
            return;

        switch (pointId)
        {
            case POINT_TRAINER_AT_PIT:
                me->SetFacingTo(GetRecordedPathFacing(me->GetEntry() * 100, me->GetOrientation()));
                break;
            case POINT_TRAINER_HOME:
                me->SetFacingTo(me->GetHomePosition().GetOrientation());
                me->SetEmoteState(_idleEmoteState);
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_TRAINER_WALK_TO_PIT:
                    _atPit = MoveAlongRecordedPath(me, me->GetEntry() * 100, POINT_TRAINER_AT_PIT, true);
                    if (_atPit)
                        me->SetEmoteState(EMOTE_ONESHOT_NONE);
                    break;
                case EVENT_TRAINER_WALK_HOME:
                    if (MoveAlongRecordedPath(me, me->GetEntry() * 100 + 1, POINT_TRAINER_HOME, true))
                        _atPit = false;
                    break;
                default:
                    break;
            }
        }
    }

private:
    bool _atPit;
    Emote _idleEmoteState;
};

/*######
## npc_tsu_the_wanderer - 63309, spars with Zabrax (63310): strike/parry swap every 2.4 s.
## Tsu drives both so emotes land together (sniff); spars alone while Zabrax is at the pit.
######*/

enum TsuTheWanderer
{
    NPC_ZABRAX                      = 63310,

    EVENT_TSU_SPAR                  = 1
};

Milliseconds const SparringBeat = 2400ms;
float const SparringPartnerRange = 10.0f;

struct npc_tsu_the_wanderer : public ScriptedAI
{
    npc_tsu_the_wanderer(Creature* creature) : ScriptedAI(creature), _tsuStrikes(true) { }

    void Reset() override
    {
        events.Reset();
        events.ScheduleEvent(EVENT_TSU_SPAR, SparringBeat);
    }

    void UpdateAI(uint32 diff) override
    {
        if (UpdateVictim())
        {
            DoMeleeAttackIfReady();
            return;
        }

        events.Update(diff);
        if (events.ExecuteEvent() != EVENT_TSU_SPAR)
            return;

        Emote const tsuEmote = _tsuStrikes ? EMOTE_ONESHOT_MONKOFFENSE_SPECIALUNARMED : EMOTE_ONESHOT_MONKOFFENSE_PARRYUNARMED;
        Emote const partnerEmote = _tsuStrikes ? EMOTE_ONESHOT_MONKOFFENSE_PARRYUNARMED : EMOTE_ONESHOT_MONKOFFENSE_SPECIALUNARMED;
        me->HandleEmoteCommand(tsuEmote);
        if (Creature* zabrax = me->FindNearestCreature(NPC_ZABRAX, SparringPartnerRange))
            if (zabrax->GetEmoteState() == EMOTE_STATE_MONKOFFENSE_READYUNARMED)
                zabrax->HandleEmoteCommand(partnerEmote);

        _tsuStrikes = !_tsuStrikes;
        events.Repeat(SparringBeat);
    }

private:
    bool _tsuStrikes;
};

/*######
## npc_voljin_darkspear_hold - 38966. "More Than Expected" -> Garrosh vision; "An Ancient Enemy" -> Thrall vision.
## One Vol'jin + bunny per scene on the same spot, split by quest invis (49414 before, 49415 after). Retail timings from turn-in.
######*/

enum VoljinVision
{
    QUEST_AN_ANCIENT_ENEMY          = 24814,

    NPC_VISION_OF_GARROSH           = 38938,
    NPC_VISION_OF_VOLJIN            = 38953,

    SPELL_RITES_OF_VISION           = 73169,
    SPELL_VISION_VISUAL             = 49414,

    SAY_VOLJIN_SHOW_YOU             = 0,
    SAY_VOLJIN_LED_THEM_HERE        = 1,
    SAY_VOLJIN_TEMPER               = 2,
    SAY_VOLJIN_OLDER_MINDS          = 3,
    SAY_VOLJIN_SEA_WITCH_DEAD       = 4,
    SAY_VOLJIN_NO_LOVE_FOR_GARROSH  = 5,
    SAY_VOLJIN_ONLY_ONE             = 6,
    SAY_VOLJIN_GLAD_YA_BE_WELL      = 7,
    SAY_VOLJIN_BEG_COUNCIL          = 8,
    SAY_VOLJIN_I_UNDERSTAND         = 9,
    SAY_VOLJIN_STRONG_AND_PROUD     = 10,
    SAY_VOLJIN_DARK_TIMES           = 11,
    SAY_VOLJIN_WORDS_BE_TRUE        = 12,
    SAY_VOLJIN_HOPIN                = 13,
    SAY_VOLJIN_GO_NOW               = 14,

    NPC_VISION_OF_THRALL            = 38939,
    NPC_VISION_BUNNY                = 38003,
    SPELL_VISION_SMOKE              = 73158,
    SPELL_THRALL_VISION_VISUAL      = 49415,

    SAY_THRALL_GOOD_TO_SEE_YOU      = 0,
    SAY_THRALL_WORLD_CALLS          = 1,
    SAY_THRALL_CHOSE_GARROSH        = 2,
    SAY_THRALL_SUPPOSED_WISDOM      = 3,
    SAY_THRALL_HERO_OF_OLD          = 4,
    SAY_THRALL_NOT_LIGHTLY          = 5,
    SAY_THRALL_TRUSTING_YOU         = 6,
    SAY_THRALL_THROMKA              = 7,

    SAY_GARROSH_DONT_TALK_BACK      = 0,
    SAY_GARROSH_LUCKY               = 1,
    SAY_GARROSH_THREATS_HOLLOW      = 2,
    SAY_GARROSH_SEALED_FATE         = 3,
    EMOTE_GARROSH_SPITS             = 4,

    SAY_VISION_VOLJIN_NO_QUESTION   = 0,
    SAY_VISION_VOLJIN_FATHER        = 1,
    SAY_VISION_VOLJIN_NO_WARCHIEF   = 2,
    SAY_VISION_VOLJIN_WATCH_WAIT    = 3,
    SAY_VISION_VOLJIN_END_RULE      = 4,
    SAY_VISION_VOLJIN_SHADOWS       = 5,
    SAY_VISION_VOLJIN_AND_YOURS     = 6,

    EVENT_VISION_CHANNEL            = 1,
    EVENT_VISION_SUMMON_GARROSH,
    EVENT_VISION_GARROSH_1,
    EVENT_VISION_SUMMON_VOLJIN,
    EVENT_VISION_VOLJIN_1,
    EVENT_VISION_VOLJIN_2,
    EVENT_VISION_GARROSH_2,
    EVENT_VISION_VOLJIN_3,
    EVENT_VISION_GARROSH_3,
    EVENT_VISION_VOLJIN_4,
    EVENT_VISION_VOLJIN_5,
    EVENT_VISION_VOLJIN_6,
    EVENT_VISION_GARROSH_4,
    EVENT_VISION_GARROSH_SPIT,
    EVENT_VISION_VOLJIN_7,
    EVENT_VISION_END,
    EVENT_VOLJIN_LED_THEM_HERE,
    EVENT_VOLJIN_TEMPER,
    EVENT_VOLJIN_OLDER_MINDS,

    EVENT_THRALL_NO_LOVE,
    EVENT_THRALL_ONLY_ONE,
    EVENT_THRALL_CHANNEL,
    EVENT_THRALL_SUMMON,
    EVENT_THRALL_1,
    EVENT_THRALL_VOLJIN_1,
    EVENT_THRALL_2,
    EVENT_THRALL_VOLJIN_2,
    EVENT_THRALL_3,
    EVENT_THRALL_4,
    EVENT_THRALL_5,
    EVENT_THRALL_6,
    EVENT_THRALL_7,
    EVENT_THRALL_VOLJIN_3,
    EVENT_THRALL_8,
    EVENT_THRALL_END,
    EVENT_THRALL_DARK_TIMES,
    EVENT_THRALL_WORDS_BE_TRUE,
    EVENT_THRALL_HOPIN,
    EVENT_THRALL_GO_NOW
};

Position const VisionOfGarroshPos = { -1321.6406f, -5610.2466f, 25.454046f, 2.460914134979248f };
Position const VisionOfVoljinPos  = { -1323.8646f, -5608.5625f, 25.45229f,  5.4803338050842285f };
Position const VisionOfThrallPos  = { -1323.3073f, -5609.903f,  25.305038f, 0.9300000071525574f };
// Bunny sits on the brazier.
float const VisionBunnySearchRange = 10.0f;
// Vol'jin faces the brazier during a vision.
float const VoljinFacingBrazier = 3.979350566864013671f;

struct npc_voljin_darkspear_hold : public ScriptedAI
{
    npc_voljin_darkspear_hold(Creature* creature) : ScriptedAI(creature), _inScene(false) { }

    // Visions are TEMPSUMMON_MANUAL_DESPAWN: if the scene is cut short they
    // would stay in the world forever and _inScene would block every later
    // turn-in. Death and respawn both abort the scene cleanly.
    void JustDied(Unit* /*killer*/) override
    {
        AbortScene();
    }

    void JustRespawned() override
    {
        AbortScene();
    }

    void sQuestReward(Player* player, Quest const* quest, uint32 /*opt*/) override
    {
        if (_inScene)
            return;

        _inScene = true;
        if (quest->GetQuestId() == QUEST_AN_ANCIENT_ENEMY)
        {
            StartThrallVision(player);
            return;
        }

        me->SetFacingTo(VoljinFacingBrazier);
        Talk(SAY_VOLJIN_SHOW_YOU, player);

        events.ScheduleEvent(EVENT_VISION_CHANNEL,       2620ms);
        events.ScheduleEvent(EVENT_VISION_SUMMON_GARROSH, 6610ms);
        events.ScheduleEvent(EVENT_VISION_GARROSH_1,     7500ms);
        events.ScheduleEvent(EVENT_VISION_SUMMON_VOLJIN, 13980ms);
        events.ScheduleEvent(EVENT_VISION_VOLJIN_1,      18470ms);
        events.ScheduleEvent(EVENT_VISION_VOLJIN_2,      29390ms);
        events.ScheduleEvent(EVENT_VISION_GARROSH_2,     35890ms);
        events.ScheduleEvent(EVENT_VISION_VOLJIN_3,      45960ms);
        events.ScheduleEvent(EVENT_VISION_GARROSH_3,     56940ms);
        events.ScheduleEvent(EVENT_VISION_VOLJIN_4,      72320ms);
        events.ScheduleEvent(EVENT_VISION_VOLJIN_5,      88510ms);
        events.ScheduleEvent(EVENT_VISION_VOLJIN_6,     102990ms);
        events.ScheduleEvent(EVENT_VISION_GARROSH_4,    120130ms);
        events.ScheduleEvent(EVENT_VISION_GARROSH_SPIT, 122670ms);
        events.ScheduleEvent(EVENT_VISION_VOLJIN_7,     124990ms);
        events.ScheduleEvent(EVENT_VISION_END,          133520ms);
        events.ScheduleEvent(EVENT_VOLJIN_LED_THEM_HERE, 135950ms);
        events.ScheduleEvent(EVENT_VOLJIN_TEMPER,       144470ms);
        events.ScheduleEvent(EVENT_VOLJIN_OLDER_MINDS,  159460ms);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_VISION_CHANNEL:
                    DoCastSelf(SPELL_RITES_OF_VISION, true);
                    break;
                case EVENT_VISION_SUMMON_GARROSH:
                    SummonVision(NPC_VISION_OF_GARROSH, VisionOfGarroshPos, _garroshGuid);
                    break;
                case EVENT_VISION_SUMMON_VOLJIN:
                    SummonVision(NPC_VISION_OF_VOLJIN, VisionOfVoljinPos, _visionVoljinGuid);
                    break;
                case EVENT_VISION_GARROSH_1: VisionTalk(_garroshGuid, SAY_GARROSH_DONT_TALK_BACK); break;
                case EVENT_VISION_GARROSH_2: VisionTalk(_garroshGuid, SAY_GARROSH_LUCKY); break;
                case EVENT_VISION_GARROSH_3: VisionTalk(_garroshGuid, SAY_GARROSH_THREATS_HOLLOW); break;
                case EVENT_VISION_GARROSH_4: VisionTalk(_garroshGuid, SAY_GARROSH_SEALED_FATE); break;
                case EVENT_VISION_GARROSH_SPIT: VisionTalk(_garroshGuid, EMOTE_GARROSH_SPITS); break;
                case EVENT_VISION_VOLJIN_1: VisionTalk(_visionVoljinGuid, SAY_VISION_VOLJIN_NO_QUESTION); break;
                case EVENT_VISION_VOLJIN_2: VisionTalk(_visionVoljinGuid, SAY_VISION_VOLJIN_FATHER); break;
                case EVENT_VISION_VOLJIN_3: VisionTalk(_visionVoljinGuid, SAY_VISION_VOLJIN_NO_WARCHIEF); break;
                case EVENT_VISION_VOLJIN_4: VisionTalk(_visionVoljinGuid, SAY_VISION_VOLJIN_WATCH_WAIT); break;
                case EVENT_VISION_VOLJIN_5: VisionTalk(_visionVoljinGuid, SAY_VISION_VOLJIN_END_RULE); break;
                case EVENT_VISION_VOLJIN_6: VisionTalk(_visionVoljinGuid, SAY_VISION_VOLJIN_SHADOWS); break;
                case EVENT_VISION_VOLJIN_7: VisionTalk(_visionVoljinGuid, SAY_VISION_VOLJIN_AND_YOURS); break;
                case EVENT_VISION_END:
                    me->RemoveAurasDueToSpell(SPELL_RITES_OF_VISION);
                    DespawnVision(_garroshGuid);
                    DespawnVision(_visionVoljinGuid);
                    break;
                case EVENT_VOLJIN_LED_THEM_HERE:
                    me->SetFacingTo(me->GetHomePosition().GetOrientation());
                    Talk(SAY_VOLJIN_LED_THEM_HERE);
                    break;
                case EVENT_VOLJIN_TEMPER:
                    Talk(SAY_VOLJIN_TEMPER);
                    break;
                case EVENT_VOLJIN_OLDER_MINDS:
                    Talk(SAY_VOLJIN_OLDER_MINDS);
                    _inScene = false;
                    break;
                case EVENT_THRALL_NO_LOVE:    Talk(SAY_VOLJIN_NO_LOVE_FOR_GARROSH); break;
                case EVENT_THRALL_ONLY_ONE:   Talk(SAY_VOLJIN_ONLY_ONE); break;
                case EVENT_THRALL_CHANNEL:
                    me->SetFacingTo(VoljinFacingBrazier);
                    DoCastSelf(SPELL_RITES_OF_VISION, true);
                    SetVisionSmoke(true);
                    break;
                case EVENT_THRALL_SUMMON:
                    if (TempSummon* vision = me->SummonCreature(NPC_VISION_OF_THRALL, VisionOfThrallPos, TEMPSUMMON_MANUAL_DESPAWN))
                    {
                        vision->CastSpell(vision, SPELL_THRALL_VISION_VISUAL, true);
                        _thrallGuid = vision->GetGUID();
                    }
                    break;
                case EVENT_THRALL_1:          VisionTalk(_thrallGuid, SAY_THRALL_GOOD_TO_SEE_YOU); break;
                case EVENT_THRALL_VOLJIN_1:   Talk(SAY_VOLJIN_GLAD_YA_BE_WELL); break;
                case EVENT_THRALL_2:          VisionTalk(_thrallGuid, SAY_THRALL_WORLD_CALLS); break;
                case EVENT_THRALL_VOLJIN_2:   Talk(SAY_VOLJIN_BEG_COUNCIL); break;
                case EVENT_THRALL_3:          VisionTalk(_thrallGuid, SAY_THRALL_CHOSE_GARROSH); break;
                case EVENT_THRALL_4:          VisionTalk(_thrallGuid, SAY_THRALL_SUPPOSED_WISDOM); break;
                case EVENT_THRALL_5:          VisionTalk(_thrallGuid, SAY_THRALL_HERO_OF_OLD); break;
                case EVENT_THRALL_6:          VisionTalk(_thrallGuid, SAY_THRALL_NOT_LIGHTLY); break;
                case EVENT_THRALL_7:          VisionTalk(_thrallGuid, SAY_THRALL_TRUSTING_YOU); break;
                case EVENT_THRALL_VOLJIN_3:   Talk(SAY_VOLJIN_I_UNDERSTAND); break;
                case EVENT_THRALL_8:          VisionTalk(_thrallGuid, SAY_THRALL_THROMKA); break;
                case EVENT_THRALL_END:
                    me->RemoveAurasDueToSpell(SPELL_RITES_OF_VISION);
                    SetVisionSmoke(false);
                    DespawnVision(_thrallGuid);
                    me->SetFacingTo(me->GetHomePosition().GetOrientation());
                    Talk(SAY_VOLJIN_STRONG_AND_PROUD);
                    break;
                case EVENT_THRALL_DARK_TIMES:     Talk(SAY_VOLJIN_DARK_TIMES); break;
                case EVENT_THRALL_WORDS_BE_TRUE:  Talk(SAY_VOLJIN_WORDS_BE_TRUE); break;
                case EVENT_THRALL_HOPIN:          Talk(SAY_VOLJIN_HOPIN); break;
                case EVENT_THRALL_GO_NOW:
                    Talk(SAY_VOLJIN_GO_NOW);
                    _inScene = false;
                    break;
                default:
                    break;
            }
        }
    }

private:
    void AbortScene()
    {
        if (!_inScene && !_garroshGuid && !_visionVoljinGuid && !_thrallGuid)
            return;

        TC_LOG_DEBUG("scripts", "Echo Isles: Vol'jin %s vision scene aborted, cleaning up.",
            me->GetGUID().ToString().c_str());

        events.Reset();
        me->RemoveAurasDueToSpell(SPELL_RITES_OF_VISION);
        SetVisionSmoke(false);
        DespawnVision(_garroshGuid);
        DespawnVision(_visionVoljinGuid);
        DespawnVision(_thrallGuid);
        _inScene = false;
    }

    void StartThrallVision(Player* player)
    {
        Talk(SAY_VOLJIN_SEA_WITCH_DEAD, player);
        events.ScheduleEvent(EVENT_THRALL_NO_LOVE,         8620ms);
        events.ScheduleEvent(EVENT_THRALL_ONLY_ONE,       17110ms);
        events.ScheduleEvent(EVENT_THRALL_CHANNEL,        21980ms);
        events.ScheduleEvent(EVENT_THRALL_SUMMON,         25630ms);
        events.ScheduleEvent(EVENT_THRALL_1,              26830ms);
        events.ScheduleEvent(EVENT_THRALL_VOLJIN_1,       30470ms);
        events.ScheduleEvent(EVENT_THRALL_2,              36540ms);
        events.ScheduleEvent(EVENT_THRALL_VOLJIN_2,       47460ms);
        events.ScheduleEvent(EVENT_THRALL_3,              64500ms);
        events.ScheduleEvent(EVENT_THRALL_4,              70570ms);
        events.ScheduleEvent(EVENT_THRALL_5,              82740ms);
        events.ScheduleEvent(EVENT_THRALL_6,              99840ms);
        events.ScheduleEvent(EVENT_THRALL_7,             116850ms);
        events.ScheduleEvent(EVENT_THRALL_VOLJIN_3,      125370ms);
        events.ScheduleEvent(EVENT_THRALL_8,             136320ms);
        events.ScheduleEvent(EVENT_THRALL_END,           142400ms);
        events.ScheduleEvent(EVENT_THRALL_DARK_TIMES,    151310ms);
        events.ScheduleEvent(EVENT_THRALL_WORDS_BE_TRUE, 159820ms);
        events.ScheduleEvent(EVENT_THRALL_HOPIN,         178000ms);
        events.ScheduleEvent(EVENT_THRALL_GO_NOW,        188930ms);
    }

    // Only this scene's bunny: both share the spot.
    void SetVisionSmoke(bool on)
    {
        std::list<Creature*> bunnies;
        me->GetCreatureListWithEntryInGrid(bunnies, NPC_VISION_BUNNY, VisionBunnySearchRange);
        for (Creature* bunny : bunnies)
        {
            if (!bunny->HasAura(SPELL_THRALL_VISION_VISUAL))
                continue;
            if (on)
                bunny->CastSpell(bunny, SPELL_VISION_SMOKE, true);
            else
                bunny->RemoveAurasDueToSpell(SPELL_VISION_SMOKE);
        }
    }

    void SummonVision(uint32 entry, Position const& pos, ObjectGuid& guid)
    {
        if (TempSummon* vision = me->SummonCreature(entry, pos, TEMPSUMMON_MANUAL_DESPAWN))
        {
            vision->CastSpell(vision, SPELL_VISION_VISUAL, true);
            guid = vision->GetGUID();
        }
    }

    void VisionTalk(ObjectGuid const& guid, uint8 group)
    {
        if (Creature* vision = ObjectAccessor::GetCreature(*me, guid))
            vision->AI()->Talk(group);
    }

    void DespawnVision(ObjectGuid& guid)
    {
        if (Creature* vision = ObjectAccessor::GetCreature(*me, guid))
            vision->DespawnOrUnsummon();
        guid.Clear();
    }

    ObjectGuid _garroshGuid;
    ObjectGuid _visionVoljinGuid;
    ObjectGuid _thrallGuid;
    bool _inScene;
};

/*######
## npc_ardsami - 90113. Cauldron (use-standing) <-> mailbox ("Read Scroll", endless channel, dropped on leave). Retail pauses.
######*/

enum Ardsami
{
    SPELL_READ_SCROLL               = 133464
};

PatrolStop const ArdsamiPatrol[] =
{
    { 9011301, 17s, 20s },      // cauldron
    { 9011300, 16s, 19s }       // mailbox
};

struct npc_ardsami : public EchoIslesPatrolAI
{
    npc_ardsami(Creature* creature) : EchoIslesPatrolAI(creature, ArdsamiPatrol) { }

    void OnArrive(std::size_t stop) override
    {
        if (stop)
            DoCastSelf(SPELL_READ_SCROLL);
        else
            me->SetEmoteState(EMOTE_STATE_USE_STANDING);
    }

    void OnDepart(std::size_t stop) override
    {
        if (stop)
            // Retail closes the endless channel with CHANNEL_UPDATE(0); cancel() also sends CAST_FAILED/INTERRUPTED.
            me->FinishSpell(CURRENT_CHANNELED_SPELL);
        else
            me->SetEmoteState(EMOTE_ONESHOT_NONE);
    }
};

/*######
## Quest 24622 "A Troll's Truest Companion" - personal Zuni (38930), driven by area triggers.
## 5677 summons (73302), 5777/5778 cue lines, "Saving the Young" accept sends him to the hatchlings.
######*/

enum RaptorPensZuni
{
    QUEST_A_TROLLS_TRUEST_COMPANION = 24622,
    QUEST_SAVING_THE_YOUNG          = 24623,

    NPC_ZUNI_RAPTOR_PENS            = 38930,

    AREATRIGGER_ZUNI_JOINS          = 5677,
    AREATRIGGER_ZUNI_TRAINING_TALK  = 5777,
    AREATRIGGER_ZUNI_RAPTOR_TALK    = 5778,

    SAY_ZUNI_WAIT_UP                = 0,
    SAY_ZUNI_FINISHED_TRAINING      = 1,
    SAY_ZUNI_BUSY_WORK              = 2,
    SAY_ZUNI_DONT_MAKE_ME_LOOK_BAD  = 3,

    // Player-cast on entering 5677
    SPELL_SUMMON_ZUNI_RAPTOR_PENS   = 73302,

    ACTION_ZUNI_FINISHED_TRAINING   = 1,
    ACTION_ZUNI_BUSY_WORK           = 2,
    ACTION_ZUNI_JOIN_RESCUE         = 3,

    POINT_ZUNI_RAPTOR_PENS          = 1,
    POINT_ZUNI_HATCHLING_GROUNDS    = 2,

    PATH_ZUNI_TO_RAPTOR_PENS        = 3893000,
    PATH_ZUNI_TO_HATCHLING_GROUNDS  = 3893001,
    PATH_ZUNI_BRIDGE_TO_RAPTOR_PENS = 3893002,

    EVENT_ZUNI_WAIT_UP              = 1,
    EVENT_ZUNI_LEAVE_FOR_RESCUE     = 2,
    EVENT_ZUNI_CHECK_OWNER          = 3
};

// Covers 5677 (bridge) to the pens.
float const ZuniSearchRange = 300.0f;

static Creature* FindPersonalZuni(WorldObject const* searcher, ObjectGuid ownerGuid)
{
    std::list<Creature*> zunis;
    searcher->GetCreatureListWithEntryInGrid(zunis, NPC_ZUNI_RAPTOR_PENS, ZuniSearchRange);
    for (Creature* zuni : zunis)
        if (TempSummon const* summon = zuni->ToTempSummon())
            if (summon->GetSummonerGUID() == ownerGuid)
                return zuni;
    return nullptr;
}

struct npc_zuni_raptor_pens : public ScriptedAI
{
    npc_zuni_raptor_pens(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(Unit* summoner) override
    {
        if (!summoner->IsPlayer())
        {
            me->DespawnOrUnsummon();
            return;
        }

        _playerGuid = summoner->GetGUID();
        me->SetReactState(REACT_PASSIVE);
        events.ScheduleEvent(EVENT_ZUNI_WAIT_UP, 1300ms);
        events.ScheduleEvent(EVENT_ZUNI_CHECK_OWNER, 5s);
    }

    void DoAction(int32 action) override
    {
        Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid);
        if (!player)
            return;

        switch (action)
        {
            case ACTION_ZUNI_FINISHED_TRAINING:
                Talk(SAY_ZUNI_FINISHED_TRAINING, player);
                break;
            case ACTION_ZUNI_BUSY_WORK:
                // Retail: line only; he is already on the pens spline.
                Talk(SAY_ZUNI_BUSY_WORK, player);
                break;
            case ACTION_ZUNI_JOIN_RESCUE:
                me->SetFacingToObject(player);
                Talk(SAY_ZUNI_DONT_MAKE_ME_LOOK_BAD, player);
                events.ScheduleEvent(EVENT_ZUNI_LEAVE_FOR_RESCUE, 7s);
                break;
            default:
                break;
        }
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type == EFFECT_MOTION_TYPE && pointId == POINT_ZUNI_HATCHLING_GROUNDS)
            me->DespawnOrUnsummon();
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_ZUNI_WAIT_UP:
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid))
                    {
                        Talk(SAY_ZUNI_WAIT_UP, player);
                        // Recorded bridge spline (3 captures agree); follow resets on the bridge navmesh.
                        if (!MoveAlongRecordedPath(me, PATH_ZUNI_BRIDGE_TO_RAPTOR_PENS, POINT_ZUNI_RAPTOR_PENS, false))
                            me->GetMotionMaster()->MoveFollow(player, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE);
                    }
                    break;
                case EVENT_ZUNI_LEAVE_FOR_RESCUE:
                    if (!MoveAlongRecordedPath(me, PATH_ZUNI_TO_HATCHLING_GROUNDS, POINT_ZUNI_HATCHLING_GROUNDS, false))
                        me->DespawnOrUnsummon();
                    break;
                case EVENT_ZUNI_CHECK_OWNER:
                {
                    // No zone check: the bridge is area 6453, parent zone Durotar.
                    Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid);
                    if (!player || !me->IsWithinDistInMap(player, ZuniSearchRange)
                        || player->GetQuestStatus(QUEST_A_TROLLS_TRUEST_COMPANION) == QUEST_STATUS_NONE)
                    {
                        me->DespawnOrUnsummon();
                        return;
                    }
                    events.Repeat(5s);
                    break;
                }
                default:
                    break;
            }
        }
    }

private:
    ObjectGuid _playerGuid;
};

class at_echo_isles_raptor_pens_zuni : public AreaTriggerScript
{
public:
    at_echo_isles_raptor_pens_zuni() : AreaTriggerScript("at_echo_isles_raptor_pens_zuni") { }

    // false: keep default handling (exploration, teleports).
    bool OnTrigger(Player* player, AreaTriggerEntry const* trigger, bool entered) override
    {
        // 24622 has no objectives: complete once taken.
        QuestStatus status = player->GetQuestStatus(QUEST_A_TROLLS_TRUEST_COMPANION);
        if (!entered || (status != QUEST_STATUS_INCOMPLETE && status != QUEST_STATUS_COMPLETE))
            return false;

        Creature* zuni = FindPersonalZuni(player, player->GetGUID());
        switch (trigger->ID)
        {
            case AREATRIGGER_ZUNI_JOINS:
                if (!zuni)
                    player->CastSpell(player, SPELL_SUMMON_ZUNI_RAPTOR_PENS, true);
                break;
            case AREATRIGGER_ZUNI_TRAINING_TALK:
                if (zuni)
                    zuni->AI()->DoAction(ACTION_ZUNI_FINISHED_TRAINING);
                break;
            case AREATRIGGER_ZUNI_RAPTOR_TALK:
                if (zuni)
                    zuni->AI()->DoAction(ACTION_ZUNI_BUSY_WORK);
                break;
            default:
                break;
        }
        return false;
    }
};

/*######
## Quest 24623 "Saving the Young" - Lost Bloodtalon Hatchling (39157)
## Whistle (item 52283, spell 70874): each hatchling hit gives credit and follows until despawn.
######*/

enum SavingTheYoung
{
    NPC_LOST_BLOODTALON_HATCHLING   = 39157,
    SPELL_BLOODTALON_WHISTLE        = 70874,

    EMOTE_HATCHLING_FOLLOW          = 0,
    EVENT_HATCHLING_DESPAWN         = 1
};

// Retail: despawn 64-84 s after the whistle.
Milliseconds const HatchlingDespawnMin = 64s;
Milliseconds const HatchlingDespawnMax = 84s;
// Retail: ~1 in 10 emotes (4 of 45 sniffed).
uint32 const HatchlingEmoteChance = 10;

struct npc_lost_bloodtalon_hatchling : public ScriptedAI
{
    npc_lost_bloodtalon_hatchling(Creature* creature) : ScriptedAI(creature), _rescued(false) { }

    void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
    {
        if (_rescued || spellInfo->Id != SPELL_BLOODTALON_WHISTLE)
            return;

        // Quest complete: remaining hits stay behind.
        Player* player = caster->ToPlayer();
        if (!player || player->GetQuestStatus(QUEST_SAVING_THE_YOUNG) != QUEST_STATUS_INCOMPLETE)
            return;

        _rescued = true;
        player->KilledMonsterCredit(NPC_LOST_BLOODTALON_HATCHLING, me->GetGUID());
        if (roll_chance_i(HatchlingEmoteChance))
            Talk(EMOTE_HATCHLING_FOLLOW, player);
        me->GetMotionMaster()->MoveFollow(player, PET_FOLLOW_DIST, frand(0.0f, 2.0f * float(M_PI)));
        events.ScheduleEvent(EVENT_HATCHLING_DESPAWN, HatchlingDespawnMin, HatchlingDespawnMax);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        if (events.ExecuteEvent() == EVENT_HATCHLING_DESPAWN)
            me->DespawnOrUnsummon();
    }

private:
    bool _rescued;
};

/*######
## npc_najtess - 39072, Zalazane's Fall. Wanders; every 15.8 s stops and channels Orb of Corruption at a hatchling
## (channel breaks on movement, so the wander stops first). Combat timings from her old SmartAI.
######*/

enum Najtess
{
    SPELL_ORB_OF_CORRUPTION         = 79782,
    SPELL_SHRINK                    = 73424,

    EVENT_NAJTESS_CORRUPT           = 1,
    EVENT_NAJTESS_CORRUPT_CAST      = 2,
    EVENT_NAJTESS_WANDER            = 3,
    EVENT_NAJTESS_ORB               = 4,
    EVENT_NAJTESS_SHRINK            = 5
};

Milliseconds const NajtessCorruptInterval = 15800ms;
Milliseconds const NajtessCorruptWindup = 2400ms;
Milliseconds const NajtessCorruptChannel = 7s;
float const NajtessWanderDistance = 5.0f;
// Orb of Corruption range
float const NajtessCorruptRange = 20.0f;

struct npc_najtess : public ScriptedAI
{
    npc_najtess(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        events.Reset();
        me->GetMotionMaster()->MoveRandom(NajtessWanderDistance);
        events.ScheduleEvent(EVENT_NAJTESS_CORRUPT, 5s, 8s);
    }

    void JustEngagedWith(Unit* who) override
    {
        // Hatchlings aren't real opponents: keep the idle sequence.
        if (who && !who->IsControlledByPlayer())
        {
            me->CombatStop(true);
            return;
        }

        events.Reset();
        _corruptionTarget.Clear();
        events.ScheduleEvent(EVENT_NAJTESS_SHRINK, 2s, 4s);
        events.ScheduleEvent(EVENT_NAJTESS_ORB, 5s, 8s);
    }

    void UpdateAI(uint32 diff) override
    {
        bool const inCombat = UpdateVictim();

        events.Update(diff);
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_NAJTESS_CORRUPT:
                    if (Creature* hatchling = me->FindNearestCreature(NPC_LOST_BLOODTALON_HATCHLING, NajtessCorruptRange))
                    {
                        me->GetMotionMaster()->Clear();
                        me->GetMotionMaster()->MoveIdle();
                        me->StopMoving();
                        me->SetFacingToObject(hatchling);
                        _corruptionTarget = hatchling->GetGUID();
                        events.ScheduleEvent(EVENT_NAJTESS_CORRUPT_CAST, NajtessCorruptWindup);
                    }
                    else
                        events.ScheduleEvent(EVENT_NAJTESS_CORRUPT, NajtessCorruptInterval);
                    break;
                case EVENT_NAJTESS_CORRUPT_CAST:
                    if (Creature* hatchling = ObjectAccessor::GetCreature(*me, _corruptionTarget))
                    {
                        me->SetFacingToObject(hatchling);
                        DoCast(hatchling, SPELL_ORB_OF_CORRUPTION);
                    }
                    _corruptionTarget.Clear();
                    events.ScheduleEvent(EVENT_NAJTESS_WANDER, NajtessCorruptChannel);
                    events.ScheduleEvent(EVENT_NAJTESS_CORRUPT, NajtessCorruptInterval);
                    break;
                case EVENT_NAJTESS_WANDER:
                    me->GetMotionMaster()->MoveRandom(NajtessWanderDistance);
                    break;
                case EVENT_NAJTESS_ORB:
                    DoCastVictim(SPELL_ORB_OF_CORRUPTION);
                    events.ScheduleEvent(EVENT_NAJTESS_ORB, 24s, 32s);
                    break;
                case EVENT_NAJTESS_SHRINK:
                    DoCastVictim(SPELL_SHRINK);
                    events.ScheduleEvent(EVENT_NAJTESS_SHRINK, 34s, 38s);
                    break;
                default:
                    break;
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        if (inCombat)
            DoMeleeAttackIfReady();
    }

private:
    ObjectGuid _corruptionTarget;
};

// Retail: no tick damage on hatchlings (would pull Naj'tess into combat). Players still take it.
class spell_echo_isles_orb_of_corruption : public AuraScript
{
    PrepareAuraScript(spell_echo_isles_orb_of_corruption);

    void HandlePeriodic(AuraEffect const* /*aurEff*/)
    {
        if (!GetTarget()->IsControlledByPlayer())
            PreventDefaultAction();
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_echo_isles_orb_of_corruption::HandlePeriodic, EFFECT_0, SPELL_AURA_PERIODIC_DAMAGE);
    }
};

/*######
## npc_kijara - 37969. Sends Zuni to the hatchlings; starts the "Young and Vicious" Swiftclaw chain.
######*/

enum Kijara
{
    QUEST_YOUNG_AND_VICIOUS             = 24626,

    // Player-cast on accept -> permanent 70902, ticks 70898 every 10 s from apply
    SPELL_FORCECAST_RAPTOR_SUMMON_AURA  = 70944,
    SPELL_SUMMON_NAMED_RAPTOR_AURA      = 70902
};

// Post -> two nests (kneel at each) -> post. Retail pauses.
PatrolStop const KijaraPatrol[] =
{
    { 3796902, 30s, 72s },      // post
    { 3796900, 2800ms, 2800ms },
    { 3796901, 3600ms, 3600ms }
};

struct npc_kijara : public EchoIslesPatrolAI
{
    npc_kijara(Creature* creature) : EchoIslesPatrolAI(creature, KijaraPatrol) { }

    void OnArrive(std::size_t stop) override
    {
        if (stop)
            me->HandleEmoteCommand(EMOTE_ONESHOT_KNEEL);
    }

    void sQuestAccept(Player* player, Quest const* quest) override
    {
        switch (quest->GetQuestId())
        {
            case QUEST_SAVING_THE_YOUNG:
                if (Creature* zuni = FindPersonalZuni(player, player->GetGUID()))
                    zuni->AI()->DoAction(ACTION_ZUNI_JOIN_RESCUE);
                break;
            case QUEST_YOUNG_AND_VICIOUS:
                player->CastSpell(player, SPELL_FORCECAST_RAPTOR_SUMMON_AURA, true);
                break;
            default:
                break;
        }
    }
};

/*######
## Quest 24626 "Young and Vicious" - 8.3.7 spell chain:
##  70902 ticks 70898 -> personal Swiftclaw (38002, vehicle 617) if none.
##  Rope 70927 (15 yd) -> rope bunny 37995; lasso credit 70943 (37989); ride 70925 (seat 1).
##  AT 5675: quest bunny 38003 casts 70941 (credit 38002) -> eject 50630.
######*/

enum YoungAndVicious
{
    NPC_SWIFTCLAW_WILD              = 37989,
    NPC_SWIFTCLAW_VEHICLE           = 38002,
    NPC_RAPTOR_ROPE_BUNNY           = 37995,
    NPC_ECHO_ISLES_QUEST_BUNNY      = 38003,

    SPELL_SUMMON_NAMED_RAPTOR       = 70898,
    SPELL_RAPTOR_ROPE               = 70927,
    SPELL_RAPTOR_LASSO_CREDIT       = 70943,
    SPELL_RIDE_NAMED_RAPTOR         = 70925,
    SPELL_RAPTOR_TURN_IN_CREDIT     = 70941,
    SPELL_EJECT_ALL_PASSENGERS      = 50630,
    SPELL_NAMED_RAPTOR_GUARDIAN     = 70899,

    AREATRIGGER_RAPTOR_PENS_RETURN  = 5675,

    // Retail escape circuit
    PATH_SWIFTCLAW_ESCAPE           = 3800200,

    SAY_SWIFTCLAW_WONT_STOP         = 0,

    EVENT_SWIFTCLAW_BOLT            = 1,
    EVENT_SWIFTCLAW_CHECK_OWNER     = 2,
    EVENT_SWIFTCLAW_DESPAWN         = 3,
    EVENT_SWIFTCLAW_TAKE_RIDER      = 4,

    EVENT_ROPE_BUNNY_DESPAWN        = 1
};

// Retail: ~14 yd/s loose (2x run), normal speed when ridden.
float const SwiftclawEscapeSpeedRate = 2.0f;
float const SwiftclawOwnerLeashRange = 150.0f;
// Retail: mills in the pen ~10 s after drop-off.
float const SwiftclawPenWanderDist   = 5.0f;
// 70941 range
float const RaptorPensBunnyRange     = 30.0f;

static bool IsOwnSwiftclaw(Unit const* unit, ObjectGuid ownerGuid)
{
    if (!unit || unit->GetEntry() != NPC_SWIFTCLAW_VEHICLE || !unit->IsAlive())
        return false;
    TempSummon const* summon = unit->ToTempSummon();
    return summon && summon->GetSummonerGUID() == ownerGuid;
}

static Creature* FindOwnSwiftclaw(Player const* player)
{
    std::list<Creature*> swiftclaws;
    player->GetCreatureListWithEntryInGrid(swiftclaws, NPC_SWIFTCLAW_VEHICLE, SwiftclawOwnerLeashRange);
    for (Creature* swiftclaw : swiftclaws)
        if (IsOwnSwiftclaw(swiftclaw, player->GetGUID()))
            return swiftclaw;
    return nullptr;
}

static void HideWildSwiftclawFor(Player* player)
{
    // Per-player hide only: the world Swiftclaw is shared.
    std::list<Creature*> wildSwiftclaws;
    player->GetCreatureListWithEntryInGrid(wildSwiftclaws, NPC_SWIFTCLAW_WILD, SwiftclawOwnerLeashRange);
    for (Creature* swiftclaw : wildSwiftclaws)
        swiftclaw->DestroyForPlayer(player);
}

struct npc_swiftclaw_vehicle : public ScriptedAI
{
    npc_swiftclaw_vehicle(Creature* creature) : ScriptedAI(creature), _returned(false) { }

    void InitializeAI() override
    {
        // Retail: steer only. Vehicle 617 data has no strafe/jump lock; set before the client sees it.
        me->AddExtraUnitMovementFlag(MOVEMENTFLAG2_NO_STRAFE | MOVEMENTFLAG2_NO_JUMPING);
        ScriptedAI::InitializeAI();
    }

    // Keep AI on while charmed: it handles boarding and the turn-in credit.
    void OnCharmed(bool /*apply*/) override { }

    void IsSummonedBy(Unit* summoner) override
    {
        _playerGuid = summoner->GetGUID();
        me->SetReactState(REACT_PASSIVE);
        events.ScheduleEvent(EVENT_SWIFTCLAW_BOLT, 1300ms);
        events.ScheduleEvent(EVENT_SWIFTCLAW_CHECK_OWNER, 5s);
    }

    void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
    {
        switch (spellInfo->Id)
        {
            case SPELL_RAPTOR_ROPE:
                // Rope hit resolves first; board next update.
                if (caster->GetGUID() == _playerGuid && me->GetVehicleKit() && !me->GetVehicleKit()->IsVehicleInUse())
                    events.ScheduleEvent(EVENT_SWIFTCLAW_TAKE_RIDER, 1ms);
                break;
            case SPELL_RAPTOR_TURN_IN_CREDIT:
                if (_returned)
                    break;
                _returned = true;
                DoCastSelf(SPELL_EJECT_ALL_PASSENGERS, true);
                me->GetMotionMaster()->MoveRandom(SwiftclawPenWanderDist);
                events.CancelEvent(EVENT_SWIFTCLAW_BOLT);
                events.ScheduleEvent(EVENT_SWIFTCLAW_DESPAWN, 10s);
                break;
            default:
                break;
        }
    }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        if (passenger->GetGUID() != _playerGuid)
            return;

        if (apply)
        {
            events.CancelEvent(EVENT_SWIFTCLAW_BOLT);
            me->GetMotionMaster()->Clear();
            me->SetSpeedRate(MOVE_RUN, 1.0f);
            // 70943 has 0 yd range and the seat offset never meets it: self-cast for the same credit.
            passenger->CastSpell(passenger, SPELL_RAPTOR_LASSO_CREDIT, true);
            Talk(SAY_SWIFTCLAW_WONT_STOP, passenger);
            return;
        }

        // Thrown off early: bolt again so it can be re-roped.
        if (!_returned)
            events.ScheduleEvent(EVENT_SWIFTCLAW_BOLT, 1s);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_SWIFTCLAW_BOLT:
                    DoCastSelf(SPELL_NAMED_RAPTOR_GUARDIAN, true);
                    me->SetSpeedRate(MOVE_RUN, SwiftclawEscapeSpeedRate);
                    me->SetWalk(false);
                    me->GetMotionMaster()->MovePath(PATH_SWIFTCLAW_ESCAPE, true);
                    break;
                case EVENT_SWIFTCLAW_TAKE_RIDER:
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid))
                        player->CastSpell(player, SPELL_RIDE_NAMED_RAPTOR, true);
                    break;
                case EVENT_SWIFTCLAW_CHECK_OWNER:
                {
                    Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid);
                    if (!player || !me->IsWithinDistInMap(player, SwiftclawOwnerLeashRange)
                        || player->GetQuestStatus(QUEST_YOUNG_AND_VICIOUS) != QUEST_STATUS_INCOMPLETE)
                    {
                        if (!_returned)
                        {
                            me->DespawnOrUnsummon();
                            return;
                        }
                    }
                    events.Repeat(5s);
                    break;
                }
                case EVENT_SWIFTCLAW_DESPAWN:
                    me->DespawnOrUnsummon();
                    break;
                default:
                    break;
            }
        }
    }

private:
    ObjectGuid _playerGuid;
    bool _returned;
};

// Retail visuals 70918/70919 and ride 70926 target the bunny's master; here it has none, so it only despawns.
struct npc_raptor_rope_bunny : public ScriptedAI
{
    npc_raptor_rope_bunny(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(Unit* /*summoner*/) override
    {
        events.ScheduleEvent(EVENT_ROPE_BUNNY_DESPAWN, 8300ms);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        if (events.ExecuteEvent() == EVENT_ROPE_BUNNY_DESPAWN)
            me->DespawnOrUnsummon();
    }
};

// 70898 ticks every 10 s: summon only when the player has no Swiftclaw.
class spell_echo_isles_summon_named_raptor : public SpellScript
{
    PrepareSpellScript(spell_echo_isles_summon_named_raptor);

    void HandleSummon(SpellEffIndex effIndex)
    {
        Player* player = GetCaster()->ToPlayer();
        if (!player || player->GetQuestStatus(QUEST_YOUNG_AND_VICIOUS) != QUEST_STATUS_INCOMPLETE || FindOwnSwiftclaw(player))
            PreventHitDefaultEffect(effIndex);
    }

    void Register() override
    {
        OnEffectHit += SpellEffectFn(spell_echo_isles_summon_named_raptor::HandleSummon, EFFECT_1, SPELL_EFFECT_SUMMON);
    }
};

// Own Swiftclaw only.
class spell_echo_isles_raptor_rope : public SpellScript
{
    PrepareSpellScript(spell_echo_isles_raptor_rope);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        ObjectGuid casterGuid = GetCaster()->GetGUID();
        targets.remove_if([casterGuid](WorldObject* target)
        {
            return !target->IsUnit() || !IsOwnSwiftclaw(target->ToUnit(), casterGuid);
        });
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_echo_isles_raptor_rope::FilterTargets, EFFECT_0, TARGET_UNIT_DEST_AREA_ENTRY);
    }
};

class spell_echo_isles_ride_named_raptor : public SpellScript
{
    PrepareSpellScript(spell_echo_isles_ride_named_raptor);

    void SelectOwnSwiftclaw(WorldObject*& target)
    {
        Player* player = GetCaster()->ToPlayer();
        target = player ? FindOwnSwiftclaw(player) : nullptr;
    }

    void Register() override
    {
        OnObjectTargetSelect += SpellObjectTargetSelectFn(spell_echo_isles_ride_named_raptor::SelectOwnSwiftclaw, EFFECT_0, TARGET_UNIT_NEARBY_ENTRY);
    }
};

class q_echo_isles_young_and_vicious : public QuestScript
{
public:
    q_echo_isles_young_and_vicious() : QuestScript("q_echo_isles_young_and_vicious") { }

    // 70902 is permanent: drop it once the quest leaves INCOMPLETE.
    void OnQuestStatusChange(Player* player, Quest const* /*quest*/, QuestStatus /*oldStatus*/, QuestStatus newStatus) override
    {
        if (newStatus == QUEST_STATUS_INCOMPLETE)
        {
            HideWildSwiftclawFor(player);
            return;
        }

        player->RemoveAurasDueToSpell(SPELL_SUMMON_NAMED_RAPTOR_AURA);
    }
};

class at_echo_isles_raptor_pens_return : public AreaTriggerScript
{
public:
    at_echo_isles_raptor_pens_return() : AreaTriggerScript("at_echo_isles_raptor_pens_return") { }

    bool OnTrigger(Player* player, AreaTriggerEntry const* /*trigger*/, bool entered) override
    {
        if (!entered || !IsOwnSwiftclaw(player->GetVehicleBase(), player->GetGUID()))
            return false;

        Creature* bunny = player->FindNearestCreature(NPC_ECHO_ISLES_QUEST_BUNNY, RaptorPensBunnyRange);
        if (!bunny)
            return false;

        bunny->CastSpell(player, SPELL_RAPTOR_TURN_IN_CREDIT, true);
        return false;
    }
};

/*######
## npc_bloodtalon_thrasher_ride - 38991, Jornun's ride (73209 -> 73208) to Sen'jin Village.
## Retail: 2 s wait, 3 runs + 2 jumps, drop rider 0.7 s after arrival, run off.
######*/

enum ThrasherRide
{
    PATH_THRASHER_TO_SPITESCALE_COVE    = 3899100,
    PATH_THRASHER_LEAVE                 = 3899101,

    POINT_THRASHER_LEG                  = 1,
    POINT_THRASHER_GONE                 = 2,

    EVENT_THRASHER_NEXT_LEG             = 1,
    EVENT_THRASHER_DROP_RIDER           = 2
};

// Leg of path 3899100 (point range); a jump leg is one landing point.
// Full spline points (two captures agree): end points only cut through slopes.
struct ThrasherRideLeg
{
    uint32 FirstNode;
    uint32 LastNode;
    bool Jump;
};

std::array<ThrasherRideLeg, 5> const ThrasherRideLegs =
{ {
    {  1, 10, false },
    { 11, 11, true  },
    { 12, 61, false },
    { 62, 62, true  },
    { 63, 92, false }
} };

// Retail: every leg at 18 yd/s (own speed drops to swim speed at sea).
float const ThrasherRideVelocity = 18.0f;
Milliseconds const ThrasherSetOffDelay = 2s;
// Retail: 0.15 s before a jump, 0.8 s after landing.
Milliseconds const ThrasherBeforeJumpPause = 150ms;
Milliseconds const ThrasherLandingPause = 800ms;
Milliseconds const ThrasherDropDelay = 700ms;

struct npc_bloodtalon_thrasher_ride : public ScriptedAI
{
    npc_bloodtalon_thrasher_ride(Creature* creature) : ScriptedAI(creature), _nextLeg(0), _leaving(false) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
    }

    // Keep AI on while charmed: it steers the ride.
    void OnCharmed(bool /*apply*/) override { }

    void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
    {
        Player* rider = passenger->ToPlayer();
        if (!rider)
            return;

        if (apply)
        {
            // Else the rider's client is the mover and its reports pin the Thrasher at the mount spot server-side.
            rider->SetMover(rider);
            events.ScheduleEvent(EVENT_THRASHER_NEXT_LEG, ThrasherSetOffDelay);
            return;
        }

        // Dropped or jumped off: leave.
        events.Reset();
        Leave();
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type != EFFECT_MOTION_TYPE)
            return;

        if (pointId == POINT_THRASHER_GONE)
        {
            me->DespawnOrUnsummon();
            return;
        }

        if (pointId != POINT_THRASHER_LEG || _leaving || !_nextLeg)
            return;

        if (_nextLeg >= ThrasherRideLegs.size())
        {
            events.ScheduleEvent(EVENT_THRASHER_DROP_RIDER, ThrasherDropDelay);
            return;
        }

        bool const landed = ThrasherRideLegs[_nextLeg - 1].Jump;
        events.ScheduleEvent(EVENT_THRASHER_NEXT_LEG, landed ? ThrasherLandingPause : ThrasherBeforeJumpPause);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_THRASHER_NEXT_LEG:
                    StartNextLeg();
                    break;
                case EVENT_THRASHER_DROP_RIDER:
                    DoCastSelf(SPELL_EJECT_ALL_PASSENGERS, true);
                    break;
                default:
                    break;
            }
        }
    }

private:
    void StartNextLeg()
    {
        ThrasherRideLeg const& leg = ThrasherRideLegs[_nextLeg++];

        if (!leg.Jump)
        {
            if (!MoveAlongRecordedPath(me, PATH_THRASHER_TO_SPITESCALE_COVE, POINT_THRASHER_LEG, false, ThrasherRideVelocity, leg.FirstNode, leg.LastNode))
                DoCastSelf(SPELL_EJECT_ALL_PASSENGERS, true);
            return;
        }

        Optional<Position> const landing = GetRecordedPathNode(PATH_THRASHER_TO_SPITESCALE_COVE, leg.LastNode);
        if (!landing)
        {
            DoCastSelf(SPELL_EJECT_ALL_PASSENGERS, true);
            return;
        }

        // Retail: ride speed, world gravity (sniffed 19.2911); vz = g * t / 2 gives that arc.
        float const duration = me->GetExactDist(&*landing) / ThrasherRideVelocity;
        me->GetMotionMaster()->MoveJump(*landing, ThrasherRideVelocity, Movement::gravity * duration / 2.0f, POINT_THRASHER_LEG);
    }

    void Leave()
    {
        if (_leaving)
            return;

        _leaving = true;
        if (!MoveAlongRecordedPath(me, PATH_THRASHER_LEAVE, POINT_THRASHER_GONE, false, ThrasherRideVelocity))
            me->DespawnOrUnsummon();
    }

    uint32 _nextLeg;
    bool _leaving;
};

/*######
## Spitescale Cove - 24812 "No More Mercy" / 24813 "Territorial Fetish". Cove Zuni (38932).
## Either quest accepted -> 73130 -> Zuni joins and persists through the cave; ticks restore him if lost. Leaves after both quests end.
## Retail create: CreatedBy player, spell 73131, faction 116, player's level, flags 0x8008 (PLAYER_CONTROLLED | CAN_SWIM).
######*/

enum SpitescaleCove
{
    QUEST_NO_MORE_MERCY             = 24812,
    QUEST_TERRITORIAL_FETISH        = 24813,

    NPC_COVE_ZUNI                   = 38932,


    SPELL_SUMMON_ZUNI_LVL_4_AURA    = 73130,
    SPELL_SUMMON_ZUNI_LVL_4         = 73131,
    SPELL_COVE_ZUNI_LIGHTNING_BOLT  = 73254,
    SPELL_COVE_ZUNI_HEALING_WAVE    = 73253,
    SPELL_COVE_ZUNI_EARTH_SHOCK     = 73255,

    SPELL_PLACE_TERRITORIAL_FETISH  = 72070,
    SPELL_TERRITORIAL_FETISH        = 72072,
    // Fetish pulse; retail: naga only
    SPELL_TERRITORIAL_FETISH_SHRINK = 72249,

    SAY_COVE_ZUNI_CAUGHT_UP         = 0,
    SAY_COVE_ZUNI_TAUNT             = 1,

    EVENT_COVE_ZUNI_GREET           = 1,
    EVENT_COVE_ZUNI_CHECK_OWNER     = 2,
    EVENT_COVE_ZUNI_TAUNT_READY     = 3,
    EVENT_COVE_ZUNI_DESPAWN         = 4,
    EVENT_COVE_ZUNI_EARTH_SHOCK     = 5,
    EVENT_COVE_ZUNI_HEAL            = 6,

    EVENT_FETISH_EXPIRE             = 1
};

// Retail: 1.17 s
Milliseconds const CoveZuniGreetDelay = 1200ms;
// Retail: 5 s after the second turn-in.
Milliseconds const CoveZuniLeaveDelay = 5s;
// Owner/assist poll
Milliseconds const CoveZuniOwnerCheck = 500ms;
// Retail: ~10 s between taunts
Milliseconds const CoveZuniTauntCooldown = 10s;
Milliseconds const CoveZuniEarthShockCooldown = 12s;
Milliseconds const CoveZuniHealCooldown = 8s;
uint32 const CoveZuniHealBelowPct = 50;
float const CoveZuniCastRange = 25.0f;
float const CoveZuniSearchRange = 120.0f;
// Retail: 60.3-61.0 s (3 captures)
Milliseconds const TerritorialFetishDuration = 60500ms;

static bool IsOnMorakkisQuests(Player const* player)
{
    for (uint32 questId : { uint32(QUEST_NO_MORE_MERCY), uint32(QUEST_TERRITORIAL_FETISH) })
    {
        QuestStatus const status = player->GetQuestStatus(questId);
        if (status == QUEST_STATUS_INCOMPLETE || status == QUEST_STATUS_COMPLETE)
            return true;
    }
    return false;
}

// What retail 73131 sets on the personal summon. Keep level out of this post-create
// binding: changing UnitData::Level after the creature is visible plays a level-up visual.
static void BindCoveZuniToOwner(Creature* zuni, Player* owner)
{
    zuni->SetFaction(owner->getFaction());
    zuni->SetCreatorGUID(owner->GetGUID());
    zuni->SetCreatedBySpell(SPELL_SUMMON_ZUNI_LVL_4);
    zuni->AddUnitFlag(UNIT_FLAG_PLAYER_CONTROLLED);
    zuni->SetFullHealth();
    // Backs up the 72249 condition.
    zuni->ApplySpellImmune(0, IMMUNITY_ID, SPELL_TERRITORIAL_FETISH_SHRINK, true);
}

struct npc_zuni_spitescale_cove : public ScriptedAI
{
    npc_zuni_spitescale_cove(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(Unit* summoner) override
    {
        Player* player = summoner->ToPlayer();
        if (!player)
        {
            me->DespawnOrUnsummon();
            return;
        }

        BindToOwner(player);
    }

    void Reset() override
    {
        events.Reset();
    }

    void AttackStart(Unit* who) override
    {
        AttackStartCaster(who, CoveZuniCastRange);
    }

    // Companion, no home: drop combat and follow.
    void EnterEvadeMode(EvadeReason /*why*/) override
    {
        me->CombatStop(true);
        events.Reset();
        _lastVictim.Clear();

        if (Player* player = GetOwner())
        {
            me->GetMotionMaster()->MoveFollow(player, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE);
            // Player still fighting: pick the next foe now.
            if (!_leaving)
                AssistOwner(player);
        }
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        events.ScheduleEvent(EVENT_COVE_ZUNI_EARTH_SHOCK, 2s);
        events.ScheduleEvent(EVENT_COVE_ZUNI_HEAL, 1s);
    }

    // Retail companion participates in combat but does not die during these quests.
    void DamageTaken(Unit* /*attacker*/, uint32& damage) override
    {
        if (damage >= me->GetHealth())
            damage = me->GetHealth() > 1 ? me->GetHealth() - 1 : 0;
    }

    void UpdateAI(uint32 diff) override
    {
        // Re-created AI never saw IsSummonedBy: recover the owner.
        if (!_playerGuid)
            if (TempSummon* summon = me->ToTempSummon())
                if (Unit* summoner = summon->GetSummoner())
                    if (Player* player = summoner->ToPlayer())
                    {
                        BindToOwner(player);
                    }

        _ownerEvents.Update(diff);
        while (uint32 eventId = _ownerEvents.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_COVE_ZUNI_GREET:
                    if (Player* player = GetOwner())
                        Talk(SAY_COVE_ZUNI_CAUGHT_UP, player);
                    break;
                case EVENT_COVE_ZUNI_TAUNT_READY:
                    _tauntReady = true;
                    break;
                case EVENT_COVE_ZUNI_CHECK_OWNER:
                {
                    Player* player = GetOwner();
                    if (!player || !me->IsWithinDistInMap(player, CoveZuniSearchRange))
                    {
                        me->DespawnOrUnsummon();
                        return;
                    }

                    if (!_leaving && !IsOnMorakkisQuests(player))
                    {
                        _leaving = true;
                        player->RemoveAurasDueToSpell(SPELL_SUMMON_ZUNI_LVL_4_AURA);
                        _ownerEvents.ScheduleEvent(EVENT_COVE_ZUNI_DESPAWN, CoveZuniLeaveDelay);
                    }
                    else if (!_leaving)
                        AssistOwner(player);

                    _ownerEvents.Repeat(CoveZuniOwnerCheck);
                    break;
                }
                case EVENT_COVE_ZUNI_DESPAWN:
                    me->DespawnOrUnsummon();
                    return;
                default:
                    break;
            }
        }

        if (!UpdateVictim())
            return;

        TauntNewTarget();

        events.Update(diff);
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_COVE_ZUNI_EARTH_SHOCK:
                    // Retail: interrupts casting Sirens.
                    if (me->GetVictim()->HasUnitState(UNIT_STATE_CASTING))
                    {
                        DoCastVictim(SPELL_COVE_ZUNI_EARTH_SHOCK);
                        events.ScheduleEvent(EVENT_COVE_ZUNI_EARTH_SHOCK, CoveZuniEarthShockCooldown);
                    }
                    else
                        events.ScheduleEvent(EVENT_COVE_ZUNI_EARTH_SHOCK, 1s);
                    break;
                case EVENT_COVE_ZUNI_HEAL:
                {
                    Player* player = GetOwner();
                    if (player && player->IsAlive() && player->HealthBelowPct(CoveZuniHealBelowPct))
                    {
                        DoCast(player, SPELL_COVE_ZUNI_HEALING_WAVE);
                        events.ScheduleEvent(EVENT_COVE_ZUNI_HEAL, CoveZuniHealCooldown);
                    }
                    else
                        events.ScheduleEvent(EVENT_COVE_ZUNI_HEAL, 1s);
                    break;
                }
                default:
                    break;
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        DoCastVictim(SPELL_COVE_ZUNI_LIGHTNING_BOLT);
    }

private:
    Player* GetOwner() const
    {
        return !_playerGuid.IsEmpty() ? ObjectAccessor::GetPlayer(*me, _playerGuid) : nullptr;
    }

    void BindToOwner(Player* player)
    {
        _playerGuid = player->GetGUID();
        BindCoveZuniToOwner(me, player);
        // Retail: never pulls, only assists.
        me->SetReactState(REACT_DEFENSIVE);
        me->GetMotionMaster()->MoveFollow(player, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE);

        _ownerEvents.Reset();
        _ownerEvents.ScheduleEvent(EVENT_COVE_ZUNI_GREET, CoveZuniGreetDelay);
        _ownerEvents.ScheduleEvent(EVENT_COVE_ZUNI_CHECK_OWNER, CoveZuniOwnerCheck);
    }

    // Not a controlled unit, so no OwnerAttacked hooks: poll instead.
    // Priority: player's victim > player's selection > nearest unit in combat with the player. Follows target switches.
    void AssistOwner(Player* player)
    {
        if (!player->IsInCombat())
            return;

        Unit* target = SelectOwnerFoe(player);
        if (!target)
            return;

        Unit* victim = me->GetVictim();
        if (victim == target)
            return;

        // Keep current foe unless the player picked another.
        bool const playerChoice = target == player->GetVictim() || target->GetGUID() == player->GetTarget();
        if (victim && victim->IsAlive() && player->IsInCombatWith(victim) && !playerChoice)
            return;

        if (victim)
            me->AttackStop();
        AttackStart(target);
    }

    bool IsOwnerFoe(Player* player, Unit* unit) const
    {
        return unit && unit->IsAlive() && player->IsInCombatWith(unit) && me->IsValidAttackTarget(unit)
            && me->IsWithinDistInMap(unit, CoveZuniSearchRange);
    }

    Unit* SelectOwnerFoe(Player* player) const
    {
        if (Unit* victim = player->GetVictim())
            if (IsOwnerFoe(player, victim))
                return victim;

        if (Unit* selected = ObjectAccessor::GetUnit(*player, player->GetTarget()))
            if (IsOwnerFoe(player, selected))
                return selected;

        Unit* nearest = nullptr;
        for (auto const& pair : player->GetCombatManager().GetPvECombatRefs())
        {
            CombatReference const* ref = pair.second;
            Unit* other = ref->first == player ? ref->second : ref->first;
            if (IsOwnerFoe(player, other) && (!nearest || me->GetDistance(other) < me->GetDistance(nearest)))
                nearest = other;
        }
        return nearest;
    }

    // Retail: taunt per new foe, not per pull (he rarely leaves combat).
    void TauntNewTarget()
    {
        Unit* victim = me->GetVictim();
        if (!victim || victim->GetGUID() == _lastVictim)
            return;

        _lastVictim = victim->GetGUID();
        if (!_tauntReady)
            return;

        _tauntReady = false;
        if (Player* player = GetOwner())
            Talk(SAY_COVE_ZUNI_TAUNT, player);
        _ownerEvents.ScheduleEvent(EVENT_COVE_ZUNI_TAUNT_READY, CoveZuniTauntCooldown);
    }

    EventMap _ownerEvents;
    ObjectGuid _playerGuid;
    ObjectGuid _lastVictim;
    bool _tauntReady = true;
    bool _leaving = false;
};

static Creature* FindPersonalCoveZuni(Player* player)
{
    std::list<Creature*> zunis;
    player->GetCreatureListWithEntryInGrid(zunis, NPC_COVE_ZUNI, CoveZuniSearchRange);
    for (Creature* zuni : zunis)
        if (TempSummon* summon = zuni->ToTempSummon())
            if (summon->GetSummonerGUID() == player->GetGUID() && zuni->IsAlive())
                return zuni;

    return nullptr;
}

static void EnsurePersonalCoveZuni(Player* player)
{
    if (!player || !IsOnMorakkisQuests(player) || FindPersonalCoveZuni(player))
        return;

    // 73131 is area-restricted to Durotar in 8.3.7: summon directly.
    player->SummonCreature(NPC_COVE_ZUNI, player->GetPosition(), TEMPSUMMON_MANUAL_DESPAWN);
}

// Summons on apply; ticks suppress broken 73131 and re-summon if missing.
class spell_echo_isles_summon_zuni_lvl_4_aura : public AuraScript
{
    PrepareAuraScript(spell_echo_isles_summon_zuni_lvl_4_aura);

    void HandleApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        if (Player* player = GetTarget()->ToPlayer())
            EnsurePersonalCoveZuni(player);
    }

    void HandlePeriodic(AuraEffect const* /*aurEff*/)
    {
        PreventDefaultAction();

        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;

        if (!IsOnMorakkisQuests(player))
        {
            player->RemoveAurasDueToSpell(SPELL_SUMMON_ZUNI_LVL_4_AURA);
            return;
        }

        EnsurePersonalCoveZuni(player);
    }

    void Register() override
    {
        AfterEffectApply += AuraEffectApplyFn(spell_echo_isles_summon_zuni_lvl_4_aura::HandleApply, EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL, AURA_EFFECT_HANDLE_REAL);
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_echo_isles_summon_zuni_lvl_4_aura::HandlePeriodic, EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL);
    }
};

// Retail grants 73130 when either Morakki quest is accepted. Keep the aura tied
// to quest state rather than area 4913 so cave boundaries never recreate Zuni.
class player_echo_isles_cove_zuni : public PlayerScript
{
public:
    player_echo_isles_cove_zuni() : PlayerScript("player_echo_isles_cove_zuni") { }

    void OnQuestAccept(Player* player, Quest const* quest) override
    {
        if (IsMorakkiQuest(quest->GetQuestId()))
            Sync(player);
    }

    void OnQuestStatusChange(Player* player, uint32 questId) override
    {
        if (IsMorakkiQuest(questId))
            Sync(player);
    }

    void OnLogout(Player* player) override
    {
        if (Creature* zuni = FindPersonalCoveZuni(player))
            zuni->DespawnOrUnsummon();
    }

    void OnLogin(Player* player, bool /*firstLogin*/) override
    {
        // Defensive cleanup in case a summon survived session teardown.
        if (Creature* zuni = FindPersonalCoveZuni(player))
            zuni->DespawnOrUnsummon();

        player->m_Events.AddEventAtOffset([player]()
        {
            Sync(player);
        }, 1s);
    }

private:
    static bool IsMorakkiQuest(uint32 questId)
    {
        return questId == QUEST_NO_MORE_MERCY || questId == QUEST_TERRITORIAL_FETISH;
    }

    static void Sync(Player* player)
    {
        if (IsOnMorakkisQuests(player))
        {
            if (!player->HasAura(SPELL_SUMMON_ZUNI_LVL_4_AURA))
                player->CastSpell(player, SPELL_SUMMON_ZUNI_LVL_4_AURA, true);
            else
                EnsurePersonalCoveZuni(player);
        }
        else
            player->RemoveAurasDueToSpell(SPELL_SUMMON_ZUNI_LVL_4_AURA);
    }
};

// Spitescale Flag Bunny (38560): fetish shrinks nearby naga (72249) for 60.5 s.
// 8.3.7 aura duration is short: made permanent, removed on the retail timer. No evade: it would strip the fetish.
struct npc_spitescale_flag_bunny : public ScriptedAI
{
    npc_spitescale_flag_bunny(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->SetReactState(REACT_PASSIVE);
    }

    void EnterEvadeMode(EvadeReason /*why*/) override
    {
        me->CombatStop(true);
    }

    void AttackStart(Unit* /*who*/) override { }

    void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_PLACE_TERRITORIAL_FETISH || me->HasAura(SPELL_TERRITORIAL_FETISH))
            return;

        DoCastSelf(SPELL_TERRITORIAL_FETISH, true);
        if (Aura* fetish = me->GetAura(SPELL_TERRITORIAL_FETISH))
        {
            fetish->SetMaxDuration(-1);
            fetish->SetDuration(-1);
        }

        events.RescheduleEvent(EVENT_FETISH_EXPIRE, TerritorialFetishDuration);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        if (events.ExecuteEvent() == EVENT_FETISH_EXPIRE)
            me->RemoveAurasDueToSpell(SPELL_TERRITORIAL_FETISH);
    }
};

/*######
## npc_spitescale_naga - Wavethrasher (38300, Frost Cleave) / Siren (38301, ranged). NPC damage floor vs the Darkspear line.
######*/

enum SpitescaleNaga
{
    SPELL_NAGA_FROST_CLEAVE         = 79810,
    SPELL_SIREN_WATER_BOLT          = 32011,
    SPELL_SIREN_CHAIN_LIGHTNING     = 15117,

    EVENT_NAGA_FROST_CLEAVE         = 1,
    EVENT_SIREN_CHAIN_LIGHTNING     = 2
};

float const SirenCastRange = 25.0f;

struct npc_spitescale_naga : public ScriptedAI
{
    npc_spitescale_naga(Creature* creature) : ScriptedAI(creature) { }

    bool IsSiren() const { return me->GetEntry() == NPC_SPITESCALE_SIREN; }

    void Reset() override
    {
        events.Reset();
    }

    void AttackStart(Unit* who) override
    {
        if (IsStagedCorpse(me))
            return;

        if (IsSiren())
            AttackStartCaster(who, SirenCastRange);
        else
            ScriptedAI::AttackStart(who);
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        if (IsSiren())
            events.ScheduleEvent(EVENT_SIREN_CHAIN_LIGHTNING, 5s, 8s);
        else
            events.ScheduleEvent(EVENT_NAGA_FROST_CLEAVE, 3s, 5s);
    }

    void DamageTaken(Unit* attacker, uint32& damage) override
    {
        ApplyNpcDamageFloor(me, attacker, damage);
    }

    void UpdateAI(uint32 diff) override
    {
        if (IsStagedCorpse(me) || !UpdateVictim())
            return;

        events.Update(diff);
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_NAGA_FROST_CLEAVE:
                    DoCastVictim(SPELL_NAGA_FROST_CLEAVE);
                    events.Repeat(4s, 6s);
                    break;
                case EVENT_SIREN_CHAIN_LIGHTNING:
                    DoCastVictim(SPELL_SIREN_CHAIN_LIGHTNING);
                    events.Repeat(8s, 12s);
                    break;
                default:
                    break;
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        if (IsSiren())
            DoCastVictim(SPELL_SIREN_WATER_BOLT);
        else
            DoMeleeAttackIfReady();
    }
};

/*######
## An Ancient Enemy (24814) - Zar'jira at Spitescale Cove. One shared fight; credits are 60 yd area casts on her death.
## Each step waits on the previous one (arrival, line, health, braziers), never a gossip clock. Gaps: retail 12.1.0.
##  1. Walk in; Vol'jin yells, Zar'jira answers +12.2 s, hostile +5.9 s.
##  2. Vol'jin fires +8.5 s, Vanira melees +3.6 s (totems), Zuni bolts.
##  3. One Manifestation at a time (first at 9.5 s); each death = Soul Scar.
##  4. 57 %: channel bunny, Freezing Burst, Vanira/Zuni frozen, bunny creeps to Vol'jin until 3 fires are out; Shadow Surge +5.6 s.
##  5. 9.4 %: same; Zuni runs for the fires, she kills him (+3 s line, +2.3 s), Vol'jin finishes her +1.5 s.
##     Beats are spaced out vs retail, which cut her line off.
##  6. Epilogue lines, Vanira mourns and offers the ride (73334); reset 2 min after her death.
## Health uses retail shares, not raw damage: Soul Scar 2 %/tick, Zuni bolt 0.9 %, other hits <= 5 %.
## Phases 1 and 2 >= 20 s each (retail 22/35 s), no threshold overshoot, OOC regen off.
## Manifestation death is state-driven: lethal hit -> Soul Scar visual -> short resolve -> actual death.
## At 9.4 % the encounter owns Zar'jira's health; combat damage cannot skip Zuni/Vol'jin's finale.
######*/

enum ZarjiraEvent
{
    NPC_COVE_VOLJIN                 = 38225,
    NPC_COVE_VANIRA                 = 38437,
    NPC_COVE_ZUNI_FIGHTER           = 38423,
    NPC_ZARJIRA                     = 38306,
    NPC_MANIFESTATION               = 38302,
    NPC_SEA_WITCH_CHANNEL_BUNNY     = 38452,
    NPC_FIRE_OF_THE_SEAS            = 38542,

    GOSSIP_MENU_VOLJIN_READY        = 11020,
    GOSSIP_MENU_VANIRA_RECALL       = 11107,

    // Retail: fight-only factions
    FACTION_DARKSPEAR_AT_WAR        = 1770,
    FACTION_ZARJIRA_AT_WAR          = 2102,

    SPELL_VOLJIN_SPEAK_CREDIT       = 73589,
    SPELL_SEA_WITCH_KILL_CREDIT     = 73534,
    SPELL_VOLJIN_SHOOT              = 85710,
    SPELL_VOLJIN_SHADOW_SHOCK       = 73087,
    SPELL_VOLJIN_DELUGE_OF_SHADOW   = 72044,
    SPELL_VOLJIN_SHADOW_SURGE       = 73013,
    SPELL_ZARJIRA_FROSTBOLT         = 46987,
    // Bunny's CreatedBySpell (retail)
    SPELL_SUMMON_CHANNEL_BUNNY      = 72046,
    SPELL_FREEZING_BURST            = 73297,
    SPELL_FREEZING_TOUCH            = 73004,
    SPELL_FROZEN_TORRENT            = 72045,
    SPELL_FIRE_OF_THE_SEAS          = 72250,
    SPELL_FIRE_ENERGY_BEAM          = 73294,
    SPELL_STAMP_OUT_FIRE            = 73296,
    SPELL_SOUL_SCAR                 = 73432,
    SPELL_HEALING_STREAM_TOTEM      = 71984,
    SPELL_MANA_STREAM_TOTEM         = 73393,
    SPELL_VANIRAS_RECALL            = 73334,
    SPELL_ZUNI_FROST_EXPLOSION      = 69252,

    SAY_COVE_VOLJIN_FOOLISH         = 0,
    EMOTE_COVE_VOLJIN_BRAZIERS      = 1,
    SAY_COVE_VOLJIN_IT_BE_DONE      = 2,
    SAY_COVE_VOLJIN_BEEN_WAITIN     = 3,
    SAY_COVE_VOLJIN_RETURNIN        = 4,

    SAY_ZARJIRA_WEAK                = 0,
    SAY_ZARJIRA_FIRES_OUT           = 1,
    SAY_ZARJIRA_NOT_SO_FAST         = 2,
    SAY_ZARJIRA_IDLE                = 3,

    SAY_COVE_VANIRA_SPIRITS         = 0,
    SAY_COVE_VANIRA_ZUNI_NO         = 1,
    SAY_COVE_VANIRA_NOTHIN          = 2,
    SAY_COVE_VANIRA_WATCHERS        = 3,
    SAY_COVE_VANIRA_RUSHED_OFF      = 4,

    SAY_COVE_ZUNI_THE_FIRES         = 0,

    ACTION_ZJ_START                 = 1,
    ACTION_ZJ_TAUNT,
    ACTION_ZJ_TAKE_POST,
    ACTION_ZJ_TURNED_HOSTILE,
    ACTION_ZJ_FIGHT,
    ACTION_ZJ_FIRST_SPIRIT,
    ACTION_ZJ_KNOCKED,
    ACTION_ZJ_CHANNEL,
    ACTION_ZJ_BRAZIERS_UP,
    ACTION_ZJ_BRAZIER_OUT,
    ACTION_ZJ_BRAZIERS_OUT,
    ACTION_ZJ_CHANNEL_BROKEN,
    ACTION_ZJ_UNFROZEN,
    ACTION_ZJ_ZUNI_RUNS,
    ACTION_ZJ_ZUNI_AT_FIRES,
    ACTION_ZJ_ZUNI_KILLED,
    ACTION_ZJ_ZUNI_FELL,
    ACTION_ZJ_DEFEATED,
    ACTION_ZJ_VOLJIN_DONE,
    ACTION_ZJ_VANIRA_DONE,
    ACTION_ZJ_ABORT,

    ACTION_BUNNY_DRIFT_TO_VOLJIN    = 101,
    ACTION_BUNNY_PUSH_BACK,
    ACTION_BUNNY_HOLD,
    ACTION_BUNNY_TO_VOLJIN,

    POINT_ZJ_POST                   = 1,
    POINT_ZJ_LEAVE                  = 2,
    POINT_ZJ_FIRES                  = 3,
    POINT_ZJ_BY_ZUNI                = 4,
    POINT_ZJ_BODY                   = 5,
    POINT_ZJ_TOTEMS                 = 6,

    EVENT_ZJ_WALK                   = 1,
    EVENT_ZJ_ZARJIRA_TAUNT,
    EVENT_ZJ_OPEN_FIRE,
    EVENT_ZJ_SHOOT,
    EVENT_ZJ_SHADOW_SHOCK,
    EVENT_ZJ_BRAZIER_EMOTE,
    EVENT_ZJ_SHADOW_SURGE,
    EVENT_ZJ_AFTER_1,
    EVENT_ZJ_AFTER_2,
    EVENT_ZJ_AFTER_3,
    EVENT_ZJ_WALK_OFF,
    EVENT_ZJ_HOSTILE,
    EVENT_ZJ_FROSTBOLT,
    EVENT_ZJ_MANIFESTATION,
    EVENT_ZJ_FREEZE,
    EVENT_ZJ_CHANNEL,
    EVENT_ZJ_RESUME,
    EVENT_ZJ_ZUNI_BREAKS_FREE,
    EVENT_ZJ_END_TORRENT,
    EVENT_ZJ_FACE_ZUNI,
    EVENT_ZJ_NOT_SO_FAST,
    EVENT_ZJ_FALL,
    EVENT_ZJ_ZUNI_LATE,
    EVENT_ZJ_IDLE_YELL,
    EVENT_ZJ_WATCHDOG,
    EVENT_ZJ_ENGAGE,
    EVENT_ZJ_TOTEMS,
    EVENT_ZJ_MANA_TOTEM,
    EVENT_ZJ_SPIRITS_YELL,
    EVENT_ZJ_FACE_BODY,
    EVENT_ZJ_ZUNI_NO,
    EVENT_ZJ_TO_BODY,
    EVENT_ZJ_KNEEL,
    EVENT_ZJ_STAND,
    EVENT_ZJ_BOLT,
    EVENT_ZJ_BODY_COLLECTED,
    EVENT_ZJ_LEAVE_POST,
    EVENT_ZJ_DRIFT,
    EVENT_ZJ_KILL_ZUNI,
    EVENT_ZJ_SCAR_TICK
};

Position const CoveVoljinPost      = { -720.984f,  -5595.98f,  25.4994f, 0.866826295852661132f };
Position const CoveVoljinByZuni    = { -716.1858f, -5590.329f, 25.5021f };
Position const CoveVaniraPost      = { -719.816f,  -5600.21f,  25.4997f, 0.959931075572967529f };
Position const CoveVaniraTotemPos  = { -711.5461f, -5585.8813f, 25.5046f };
Position const CoveVaniraThrownTo  = { -715.74414f, -5593.1543f, 25.502699f };
Position const CoveVaniraAtBody    = { -715.0203f, -5579.9683f, 25.4995f };
Position const CoveZuniPost        = { -730.031f,  -5594.71f,  25.4994f, 0.533622682094573974f };
Position const CoveZuniAtTheFires  = { -714.5591f, -5578.0225f, 25.5277f };

// Retail walk-in splines
Position const CoveVoljinWalkIn[] =
{
    { -739.0137f, -5613.2505f, 25.556496f }, { -734.7637f, -5609.0005f, 25.556496f }, { -720.984f, -5595.98f, 25.499432f }
};
Position const CoveVaniraWalkIn[] =
{
    { -737.8524f, -5615.2686f, 25.25716f }, { -734.8524f, -5612.5186f, 25.50716f }, { -719.816f, -5600.21f, 25.499748f }
};
Position const CoveZuniWalkIn[] =
{
    { -746.26807f, -5610.8706f, 25.37753f }, { -743.51807f, -5608.1206f, 25.62753f }, { -730.031f, -5594.71f, 25.49943f }
};
// Vol'jin's retail run home; full points so it follows the slope.
Position const CoveVoljinLeave[] =
{
    { -740.0f,     -5612.4746f, 25.525896f }, { -742.25f,    -5614.7246f, 25.275896f }, { -743.75f,    -5615.9746f, 25.025896f },
    { -745.25f,    -5617.2246f, 24.775896f }, { -746.75f,    -5618.7246f, 24.525896f }, { -748.25f,    -5619.9746f, 24.275896f },
    { -749.0f,     -5620.7246f, 24.025896f }, { -749.8143f,  -5621.6196f, 23.549692f }, { -751.6809f,  -5621.6675f, 23.655691f },
    { -752.6809f,  -5621.6675f, 23.155691f }, { -754.6809f,  -5621.9175f, 22.905691f }, { -756.6809f,  -5622.1675f, 22.655691f },
    { -758.6809f,  -5622.4175f, 22.405691f }, { -760.4309f,  -5622.6675f, 22.155691f }, { -762.4309f,  -5622.6675f, 21.655691f },
    { -764.4309f,  -5622.9175f, 21.405691f }, { -766.4309f,  -5623.1675f, 20.905691f }, { -769.4309f,  -5623.6675f, 20.405691f },
    { -771.4309f,  -5623.6675f, 19.655691f }, { -774.0139f,  -5624.2954f, 18.510447f }
};
Position const FireOfTheSeasPos[]  =
{
    { -700.205f, -5579.72f, 26.0177f, 0.0f },
    { -706.938f, -5578.52f, 26.0191f, 0.0f },
    { -711.141f, -5574.35f, 26.053f,  0.0f }
};
// Retail Manifestation spawns around the altar
Position const ManifestationSpawnPos[] =
{
    { -686.7246f, -5578.125f,  26.66772f, 0.0f },
    { -692.5295f, -5571.5225f, 25.54522f, 0.0f },
    { -706.5176f, -5563.5923f, 26.18274f, 0.0f },
    { -761.3711f, -5592.0527f, 25.49945f, 0.0f },
    { -704.2292f, -5561.7344f, 26.53496f, 0.0f }
};
float const ZarjiraFacingVoljin    = 4.008419036865234375f;
float const ZarjiraFacingZuni      = 2.373139858245849609f;
float const VaniraFacingZuni       = 1.408926010131835937f;
float const VaniraFacingPlayers    = 5.806816577911376953f;

float const ZarjiraEventRange      = 60.0f;
float const ZarjiraBrazierPhasePct = 57.0f;
float const ZarjiraLastBreathPct   = 9.4f;
// Retail shares of her 87 560 health
float const ZarjiraSoulScarTickPct = 2.0f;
uint32 const ZarjiraSoulScarTicks  = 5;
Milliseconds const ZarjiraSoulScarInterval = 500ms;
float const ZarjiraZuniBoltPct     = 0.9f;
float const ZarjiraEscortHitPct    = 0.05f;
float const ZarjiraMaxHitPct       = 5.0f;
Milliseconds const ZarjiraMinPhase1 = 20s;
Milliseconds const ZarjiraMinPhase2 = 20s;
// All actors respawn together 2 min after her death.
Seconds const ZarjiraEventCycle    = 120s;
// Checks with no living player in range before reset
uint32 const ZarjiraAbandonChecks  = 6;
// Retail: zone-wide yell every 5 min while idle
Milliseconds const ZarjiraIdleYellInterval = 5min;
// Retail: next Manifestation 0.1-5.8 s after one dies
Milliseconds const ManifestationRespawnMin = 1s;
Milliseconds const ManifestationRespawnMax = 6s;
Milliseconds const ManifestationLifetime   = 60s;
// Scene continues without Zuni after this
Milliseconds const ZuniRunTimeout          = 6s;

static Creature* FindZarjiraActor(Creature const* from, uint32 entry)
{
    return from->FindNearestCreature(entry, ZarjiraEventRange);
}

static void SignalZarjiraActor(Creature const* from, uint32 entry, int32 action)
{
    if (Creature* actor = FindZarjiraActor(from, entry))
        if (actor->IsAIEnabled)
            actor->AI()->DoAction(action);
}

// Respawn keeps the fight's faction/flags/gossip: reset to template.
static void RestoreZarjiraActor(Creature* actor)
{
    CreatureTemplate const* cInfo = actor->GetCreatureTemplate();
    actor->RestoreFaction();
    actor->SetUnitFlags(UnitFlags(cInfo->unit_flags));
    actor->SetUnitFlags2(UnitFlags2(cInfo->unit_flags2));
    actor->SetUnitFlags3(UnitFlags3(cInfo->unit_flags3));
    actor->SetNpcFlags(NPCFlags(cInfo->npcflag & 0xFFFFFFFF));
    actor->SetEmoteState(EMOTE_ONESHOT_NONE);
}

// Leave now, respawn at cycle end.
static void LeaveZarjiraEvent(Creature* actor, Seconds sinceDefeat)
{
    Seconds const respawn = sinceDefeat < ZarjiraEventCycle ? ZarjiraEventCycle - sinceDefeat : Seconds(1);
    actor->DespawnOrUnsummon(0, respawn);
}

// Freezing Touch has no duration: script removes it.
static void ThawZarjiraEscorts(Creature const* from)
{
    for (uint32 entry : { uint32(NPC_COVE_VANIRA), uint32(NPC_COVE_ZUNI_FIGHTER) })
        if (Creature* escort = FindZarjiraActor(from, entry))
        {
            escort->RemoveAurasDueToSpell(SPELL_FREEZING_TOUCH);
            if (escort->IsAIEnabled)
                escort->AI()->DoAction(ACTION_ZJ_UNFROZEN);
        }
}

// No channel target (range, mask, conditions) = beam drawn at the caster's feet: link the bunny and log it.
static void ChannelIntoBunny(Unit* caster, Creature* bunny, uint32 spellId)
{
    if (!caster || !bunny)
        return;

    caster->CastSpell(bunny, spellId, true);

    if (caster->GetChannelSpellId() != spellId)
        return;

    auto const& objects = caster->GetChannelObjects();
    if (std::find(objects.begin(), objects.end(), bunny->GetGUID()) != objects.end())
        return;

    caster->ClearChannelObjects();
    caster->AddChannelObject(bunny->GetGUID());
}

/*######
## npc_voljin_spitescale_cove - 38225, runs the event.
######*/

struct npc_voljin_spitescale_cove : public ScriptedAI
{
    npc_voljin_spitescale_cove(Creature* creature) : ScriptedAI(creature), _running(false), _atPost(false) { }

    void Reset() override
    {
        SetCombatMovement(false);
        if (!_running)
            events.Reset();
        // Freezing Burst knockback
        me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);
    }

    void JustRespawned() override
    {
        _running = false;
        _atPost = false;
        events.Reset();
        RestoreZarjiraActor(me);
    }

    void sGossipSelect(Player* player, uint32 menuId, uint32 /*gossipListId*/) override
    {
        if (menuId != GOSSIP_MENU_VOLJIN_READY)
            return;

        CloseGossipMenuFor(player);
        DoCastSelf(SPELL_VOLJIN_SPEAK_CREDIT, true);
        if (_running)
            return;

        _running = true;
        // Retail: gossip dropped on set-off.
        me->SetNpcFlags(UNIT_NPC_FLAG_NONE);
        SignalZarjiraActor(me, NPC_ZARJIRA, ACTION_ZJ_START);
        SignalZarjiraActor(me, NPC_COVE_VANIRA, ACTION_ZJ_START);
        // Retail: 0.28 s
        events.ScheduleEvent(EVENT_ZJ_WALK, 300ms);
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_ZJ_TURNED_HOSTILE:
                events.ScheduleEvent(EVENT_ZJ_OPEN_FIRE, 8500ms);
                break;
            case ACTION_ZJ_CHANNEL:
                me->InterruptNonMeleeSpells(false);
                ChannelIntoBunny(me, FindZarjiraActor(me, NPC_SEA_WITCH_CHANNEL_BUNNY), SPELL_VOLJIN_DELUGE_OF_SHADOW);
                break;
            case ACTION_ZJ_BRAZIERS_UP:
                events.ScheduleEvent(EVENT_ZJ_BRAZIER_EMOTE, 2600ms);
                break;
            case ACTION_ZJ_BRAZIERS_OUT:
                // Retail: 5.63 s after the last fire
                events.ScheduleEvent(EVENT_ZJ_SHADOW_SURGE, 5600ms);
                break;
            case ACTION_ZJ_DEFEATED:
                events.Reset();
                // Retail: 0.84 s after her death
                events.ScheduleEvent(EVENT_ZJ_LEAVE_POST, 840ms);
                break;
            case ACTION_ZJ_ABORT:
                me->DespawnOrUnsummon(0, 5s);
                break;
            default:
                break;
        }
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type != EFFECT_MOTION_TYPE)
            return;

        switch (pointId)
        {
            case POINT_ZJ_POST:
                me->SetFacingTo(CoveVoljinPost.GetOrientation());
                if (_atPost)
                    return;

                // Intro timed from arrival, not gossip.
                _atPost = true;
                Talk(SAY_COVE_VOLJIN_FOOLISH);
                events.ScheduleEvent(EVENT_ZJ_ZARJIRA_TAUNT, 12200ms);
                break;
            case POINT_ZJ_LEAVE:
                LeaveZarjiraEvent(me, Seconds(43));
                break;
            default:
                break;
        }
    }

    // Scripted fight: never evade.
    void EnterEvadeMode(EvadeReason /*why*/) override { }

    // Timers run through the endless Deluge channel; only attacks wait.
    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_ZJ_WALK:
                    // Recorded route: pathfinder made him face back at the start.
                    MoveAlongPoints(me, POINT_ZJ_POST, CoveVoljinWalkIn, std::size(CoveVoljinWalkIn), true);
                    break;
                case EVENT_ZJ_ZARJIRA_TAUNT:
                    me->SetEmoteState(EMOTE_STATE_READY1H);
                    SignalZarjiraActor(me, NPC_ZARJIRA, ACTION_ZJ_TAUNT);
                    SignalZarjiraActor(me, NPC_COVE_ZUNI_FIGHTER, ACTION_ZJ_TAKE_POST);
                    break;
                case EVENT_ZJ_OPEN_FIRE:
                    me->SetEmoteState(EMOTE_ONESHOT_NONE);
                    me->SetFaction(FACTION_DARKSPEAR_AT_WAR);
                    if (Creature* zarjira = FindZarjiraActor(me, NPC_ZARJIRA))
                    {
                        AttackStart(zarjira);
                        if (zarjira->IsAIEnabled)
                            zarjira->AI()->DoAction(ACTION_ZJ_FIGHT);
                    }
                    SignalZarjiraActor(me, NPC_COVE_VANIRA, ACTION_ZJ_FIGHT);
                    SignalZarjiraActor(me, NPC_COVE_ZUNI_FIGHTER, ACTION_ZJ_FIGHT);
                    DoCastVictim(SPELL_VOLJIN_SHADOW_SHOCK, true);
                    events.ScheduleEvent(EVENT_ZJ_SHOOT, 100ms);
                    events.ScheduleEvent(EVENT_ZJ_SHADOW_SHOCK, 8s);
                    break;
                case EVENT_ZJ_SHOOT:
                    if (me->GetVictim() && !me->HasUnitState(UNIT_STATE_CASTING))
                        DoCastVictim(SPELL_VOLJIN_SHOOT);
                    events.Repeat(2500ms, 5s);
                    break;
                case EVENT_ZJ_SHADOW_SHOCK:
                    if (me->GetVictim() && !me->HasUnitState(UNIT_STATE_CASTING))
                        DoCastVictim(SPELL_VOLJIN_SHADOW_SHOCK, true);
                    events.Repeat(8s, 9s);
                    break;
                case EVENT_ZJ_BRAZIER_EMOTE:
                    Talk(EMOTE_COVE_VOLJIN_BRAZIERS);
                    break;
                case EVENT_ZJ_SHADOW_SURGE:
                    me->InterruptNonMeleeSpells(false);
                    SignalZarjiraActor(me, NPC_SEA_WITCH_CHANNEL_BUNNY, ACTION_BUNNY_HOLD);
                    if (Creature* zarjira = FindZarjiraActor(me, NPC_ZARJIRA))
                    {
                        DoCast(zarjira, SPELL_VOLJIN_SHADOW_SURGE, true);
                        if (zarjira->IsAIEnabled)
                            zarjira->AI()->DoAction(ACTION_ZJ_CHANNEL_BROKEN);
                        AttackStart(zarjira);
                    }
                    break;
                case EVENT_ZJ_LEAVE_POST:
                    me->InterruptNonMeleeSpells(false);
                    me->ClearChannelObjects();
                    me->CombatStop(true);
                    me->SetEmoteState(EMOTE_STATE_READY1H);
                    me->SetWalk(true);
                    me->GetMotionMaster()->MovePoint(POINT_ZJ_BY_ZUNI, CoveVoljinByZuni, false);
                    // Retail: 8.3 s after her death
                    events.ScheduleEvent(EVENT_ZJ_AFTER_1, 7460ms);
                    break;
                case EVENT_ZJ_AFTER_1:
                    Talk(SAY_COVE_VOLJIN_IT_BE_DONE);
                    events.ScheduleEvent(EVENT_ZJ_AFTER_2, 5200ms);
                    break;
                case EVENT_ZJ_AFTER_2:
                    Talk(SAY_COVE_VOLJIN_BEEN_WAITIN);
                    events.ScheduleEvent(EVENT_ZJ_AFTER_3, 10200ms);
                    break;
                case EVENT_ZJ_AFTER_3:
                    Talk(SAY_COVE_VOLJIN_RETURNIN);
                    // Vanira follows Vol'jin.
                    SignalZarjiraActor(me, NPC_COVE_VANIRA, ACTION_ZJ_VOLJIN_DONE);
                    events.ScheduleEvent(EVENT_ZJ_WALK_OFF, 9600ms);
                    break;
                case EVENT_ZJ_WALK_OFF:
                    me->SetEmoteState(EMOTE_ONESHOT_NONE);
                    MoveAlongPoints(me, POINT_ZJ_LEAVE, CoveVoljinLeave, std::size(CoveVoljinLeave), false);
                    break;
                default:
                    break;
            }
        }
    }

private:
    bool _running;
    bool _atPost;
};

/*######
## npc_sea_witch_channel_bunny - 38452. Retail: arc (0.94 s) -> anchor (0.46 s) -> creep to Vol'jin (43.8 s)
## -> pushed back after the last fire (1.25 yd/s) -> stops on Shadow Surge -> snaps to Vol'jin on her death (0.53 s).
######*/

Position const SeaWitchChannelSummonPos = { -709.71356f, -5582.7065f, 27.672363f };
Position const SeaWitchChannelArcPos    = { -704.2782f,  -5576.305f,  28.368414f };
Position const SeaWitchChannelAnchor    = { -711.3347f,  -5584.6157f, 27.156559f };
Position const SeaWitchChannelNearVoljin = { -718.4109f, -5592.9497f, 26.49943f };
Position const SeaWitchChannelPushBack  = { -712.29285f, -5585.744f,  26.49945f };
Position const SeaWitchChannelOnVoljin  = { -720.34106f, -5595.2227f, 26.49943f };
float const SeaWitchChannelArcSpeedXY   = 9.0f;
float const SeaWitchChannelArcSpeedZ    = 9.8f;
float const SeaWitchChannelFastSpeed    = 24.0f;   // retail: ~11 yd in 0.46 s
float const SeaWitchChannelDriftSpeed   = 0.25f;   // retail: ~11 yd in 43.8 s
float const SeaWitchChannelPushSpeed    = 1.25f;   // retail: 7.7 yd in 6.17 s

enum SeaWitchChannelBunny
{
    POINT_SEA_WITCH_ARC    = 1,
    POINT_SEA_WITCH_ANCHOR = 2,
    POINT_SEA_WITCH_DRIFT  = 3,

    EVENT_BUNNY_TO_ANCHOR  = 1
};

struct npc_sea_witch_channel_bunny : public ScriptedAI
{
    npc_sea_witch_channel_bunny(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(Unit* /*summoner*/) override
    {
        me->SetReactState(REACT_PASSIVE);
        me->SetDisableGravity(true);
        me->SetCreatedBySpell(SPELL_SUMMON_CHANNEL_BUNNY);
        me->GetMotionMaster()->MoveJump(SeaWitchChannelArcPos, SeaWitchChannelArcSpeedXY, SeaWitchChannelArcSpeedZ, POINT_SEA_WITCH_ARC);
    }

    // Beam anchor only: never fights, takes no damage.
    void AttackStart(Unit* /*who*/) override { }
    void EnterEvadeMode(EvadeReason /*why*/) override { me->CombatStop(true); }
    void DamageTaken(Unit* /*attacker*/, uint32& damage) override { damage = 0; }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type == EFFECT_MOTION_TYPE && pointId == POINT_SEA_WITCH_ARC)
            events.ScheduleEvent(EVENT_BUNNY_TO_ANCHOR, 280ms);
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_BUNNY_DRIFT_TO_VOLJIN:
                FlyTo(SeaWitchChannelNearVoljin, SeaWitchChannelDriftSpeed, POINT_SEA_WITCH_DRIFT);
                break;
            case ACTION_BUNNY_PUSH_BACK:
                FlyTo(SeaWitchChannelPushBack, SeaWitchChannelPushSpeed, POINT_SEA_WITCH_DRIFT);
                break;
            case ACTION_BUNNY_HOLD:
                me->GetMotionMaster()->Clear();
                me->StopMoving();
                break;
            case ACTION_BUNNY_TO_VOLJIN:
                FlyTo(SeaWitchChannelOnVoljin, SeaWitchChannelFastSpeed, POINT_SEA_WITCH_DRIFT);
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        if (events.ExecuteEvent() == EVENT_BUNNY_TO_ANCHOR)
            FlyTo(SeaWitchChannelAnchor, SeaWitchChannelFastSpeed, POINT_SEA_WITCH_ANCHOR);
    }

private:
    void FlyTo(Position const& dest, float speed, uint32 pointId)
    {
        me->GetMotionMaster()->Clear();
        MoveAlongPoints(me, pointId, &dest, 1, false, true, speed);
    }
};

/*######
## npc_zarjira - 38306
######*/

enum ZarjiraPhase
{
    ZARJIRA_PHASE_IDLE,
    ZARJIRA_PHASE_INTRO,
    ZARJIRA_PHASE_FIGHT,
    ZARJIRA_PHASE_BRAZIERS,
    ZARJIRA_PHASE_FIGHT_2,
    ZARJIRA_PHASE_LAST_BREATH,
    ZARJIRA_PHASE_DONE
};

struct npc_zarjira : public ScriptedAI
{
    npc_zarjira(Creature* creature) : ScriptedAI(creature), _summons(creature), _phase(ZARJIRA_PHASE_IDLE),
        _braziersLeft(0), _abandonedChecks(0), _phaseTimer(0), _scarTicksLeft(0), _spiritCalled(false), _zuniArrived(false) { }

    void Reset() override
    {
        SetCombatMovement(false);
        // OOC regen (1/3 health per 2 s) refilled her during channel phases.
        me->DisableHealthRegen();
        // Own Freezing Burst hits her; retail never moves her. Root: EffectKnockBack checks UNIT_STATE_ROOT.
        me->AddUnitState(UNIT_STATE_ROOT);
        me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);
        me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK_DEST, true);
        if (_phase != ZARJIRA_PHASE_IDLE)
            return;

        events.Reset();
        events.ScheduleEvent(EVENT_ZJ_IDLE_YELL, 30s, ZarjiraIdleYellInterval);
    }

    void JustRespawned() override
    {
        _phase = ZARJIRA_PHASE_IDLE;
        _braziersLeft = 0;
        _abandonedChecks = 0;
        _phaseTimer = 0;
        _scarTicksLeft = 0;
        _spiritCalled = false;
        _zuniArrived = false;
        _manifestationGuid.Clear();
        _bunnyGuid.Clear();
        RestoreZarjiraActor(me);
        Reset();
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_ZJ_START:
                _phase = ZARJIRA_PHASE_INTRO;
                events.Reset();
                events.ScheduleEvent(EVENT_ZJ_WATCHDOG, 5s);
                break;
            case ACTION_ZJ_TAUNT:
                Talk(SAY_ZARJIRA_WEAK);
                events.ScheduleEvent(EVENT_ZJ_HOSTILE, 5900ms);
                break;
            case ACTION_ZJ_FIGHT:
                // First spirit with Vanira's warning (retail warning time; retail spirit rose 6 s earlier).
                _phaseTimer = 0;
                events.ScheduleEvent(EVENT_ZJ_MANIFESTATION, 9500ms);
                break;
            case ACTION_ZJ_BRAZIER_OUT:
                if (_braziersLeft && --_braziersLeft == 0)
                {
                    Talk(SAY_ZARJIRA_FIRES_OUT);
                    SignalBunny(ACTION_BUNNY_PUSH_BACK);
                    SignalZarjiraActor(me, NPC_COVE_VOLJIN, ACTION_ZJ_BRAZIERS_OUT);
                }
                break;
            case ACTION_ZJ_CHANNEL_BROKEN:
                // Retail: 1.2 s after Shadow Surge
                if (_phase == ZARJIRA_PHASE_BRAZIERS)
                    events.ScheduleEvent(EVENT_ZJ_RESUME, 1200ms);
                break;
            case ACTION_ZJ_ZUNI_AT_FIRES:
                if (_phase != ZARJIRA_PHASE_LAST_BREATH || _zuniArrived)
                    break;
                _zuniArrived = true;
                events.CancelEvent(EVENT_ZJ_ZUNI_LATE);
                // Retail from his arrival: torrent end +1.67 s, turn +2.85 s, line +3.0 s, Zuni dies +2.3 s; she falls +1.5 s.
                events.ScheduleEvent(EVENT_ZJ_END_TORRENT, 1670ms);
                events.ScheduleEvent(EVENT_ZJ_FACE_ZUNI, 2850ms);
                events.ScheduleEvent(EVENT_ZJ_NOT_SO_FAST, 3000ms);
                events.ScheduleEvent(EVENT_ZJ_KILL_ZUNI, 5300ms);
                events.ScheduleEvent(EVENT_ZJ_FALL, 6800ms);
                break;
            default:
                break;
        }
    }

    void JustSummoned(Creature* summon) override
    {
        _summons.Summon(summon);
    }

    void SummonedCreatureDespawn(Creature* summon) override
    {
        _summons.Despawn(summon);
        if (summon->GetGUID() == _manifestationGuid)
            ManifestationGone();
    }

    void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
    {
        if (summon->GetEntry() == NPC_MANIFESTATION && (_phase == ZARJIRA_PHASE_FIGHT || _phase == ZARJIRA_PHASE_FIGHT_2))
            StartSoulScar();
        if (summon->GetGUID() == _manifestationGuid)
            ManifestationGone();
    }

    void DamageTaken(Unit* attacker, uint32& damage) override
    {
        damage = GateDamage(ShapeDamage(attacker, damage));
    }

    void JustDied(Unit* /*killer*/) override
    {
        _summons.DespawnEntry(NPC_MANIFESTATION);
        _summons.DespawnEntry(NPC_FIRE_OF_THE_SEAS);
    }

    // Scripted fight: never evade.
    void EnterEvadeMode(EvadeReason /*why*/) override { }

    // Timers run through the endless Torrent channel; only attacks wait.
    void UpdateAI(uint32 diff) override
    {
        _phaseTimer += diff;
        events.Update(diff);
        while (uint32 eventId = events.ExecuteEvent())
            if (!HandleEvent(eventId))
                return;
    }

private:
    // Applies the phase rules to a hit; may start an intermission.
    uint32 GateDamage(uint32 damage)
    {
        switch (_phase)
        {
            case ZARJIRA_PHASE_IDLE:
            case ZARJIRA_PHASE_INTRO:
            case ZARJIRA_PHASE_BRAZIERS:
                // Retail: no health loss before the fight or while fires burn.
                return 0;
            case ZARJIRA_PHASE_LAST_BREATH:
            case ZARJIRA_PHASE_DONE:
                // The final sequence is scripted. Once the second intermission starts,
                // combat can continue visually but health no longer drives progression.
                return 0;
            case ZARJIRA_PHASE_FIGHT:
                if (GatePhase(damage, ZarjiraBrazierPhasePct, ZarjiraMinPhase1))
                    StartChannelPhase(ZARJIRA_PHASE_BRAZIERS);
                return damage;
            case ZARJIRA_PHASE_FIGHT_2:
                if (GatePhase(damage, ZarjiraLastBreathPct, ZarjiraMinPhase2))
                    StartChannelPhase(ZARJIRA_PHASE_LAST_BREATH);
                return damage;
            default:
                return damage;
        }
    }

    // Returns false when the AI must stop updating this tick.
    bool HandleEvent(uint32 eventId)
    {
        switch (eventId)
        {
            case EVENT_ZJ_IDLE_YELL:
                Talk(SAY_ZARJIRA_IDLE);
                events.Repeat(ZarjiraIdleYellInterval);
                break;
            case EVENT_ZJ_HOSTILE:
                _phase = ZARJIRA_PHASE_FIGHT;
                _phaseTimer = 0;
                me->SetFaction(FACTION_ZARJIRA_AT_WAR);
                me->RemoveUnitFlag(UnitFlags(UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
                me->SetFacingTo(ZarjiraFacingVoljin);
                SignalZarjiraActor(me, NPC_COVE_VOLJIN, ACTION_ZJ_TURNED_HOSTILE);
                events.ScheduleEvent(EVENT_ZJ_FROSTBOLT, 9700ms);
                break;
            case EVENT_ZJ_FROSTBOLT:
                if (me->HasUnitState(UNIT_STATE_CASTING))
                {
                    events.Repeat(500ms);
                    break;
                }
                if (Creature* voljin = FindZarjiraActor(me, NPC_COVE_VOLJIN))
                {
                    me->SetFacingToObject(voljin);
                    DoCast(voljin, SPELL_ZARJIRA_FROSTBOLT);
                }
                events.Repeat(3500ms, 4500ms);
                break;
            case EVENT_ZJ_MANIFESTATION:
                SummonManifestation();
                break;
            case EVENT_ZJ_FREEZE:
                for (uint32 entry : { uint32(NPC_COVE_VANIRA), uint32(NPC_COVE_ZUNI_FIGHTER) })
                    if (Creature* escort = FindZarjiraActor(me, entry))
                        if (!escort->HasAura(SPELL_FREEZING_TOUCH))
                            DoCast(escort, SPELL_FREEZING_TOUCH, true);
                break;
            case EVENT_ZJ_CHANNEL:
            {
                if (_phase == ZARJIRA_PHASE_BRAZIERS)
                    for (Position const& pos : FireOfTheSeasPos)
                        if (me->SummonCreature(NPC_FIRE_OF_THE_SEAS, pos, TEMPSUMMON_MANUAL_DESPAWN))
                            ++_braziersLeft;

                ChannelIntoBunny(me, GetBunny(), SPELL_FROZEN_TORRENT);
                // Keep facing Vol'jin.
                me->SetFacingTo(ZarjiraFacingVoljin);
                SignalZarjiraActor(me, NPC_COVE_VOLJIN, ACTION_ZJ_CHANNEL);
                events.ScheduleEvent(EVENT_ZJ_DRIFT, 1200ms);

                if (_phase == ZARJIRA_PHASE_BRAZIERS)
                    SignalZarjiraActor(me, NPC_COVE_VOLJIN, ACTION_ZJ_BRAZIERS_UP);
                else if (_phase == ZARJIRA_PHASE_LAST_BREATH)
                {
                    // Retail: thaw when channels meet; Zuni runs.
                    ThawZarjiraEscorts(me);
                    SignalZarjiraActor(me, NPC_COVE_ZUNI_FIGHTER, ACTION_ZJ_ZUNI_RUNS);
                    events.ScheduleEvent(EVENT_ZJ_ZUNI_LATE, ZuniRunTimeout);
                }
                break;
            }
            case EVENT_ZJ_DRIFT:
                SignalBunny(ACTION_BUNNY_DRIFT_TO_VOLJIN);
                break;
            case EVENT_ZJ_RESUME:
                _phase = ZARJIRA_PHASE_FIGHT_2;
                _phaseTimer = 0;
                EndChannel(true);
                ThawZarjiraEscorts(me);
                me->SetFacingTo(ZarjiraFacingVoljin);
                events.ScheduleEvent(EVENT_ZJ_FROSTBOLT, 2s);
                if (!_manifestationGuid)
                    events.ScheduleEvent(EVENT_ZJ_MANIFESTATION, 1s);
                break;
            case EVENT_ZJ_ZUNI_LATE:
                DoAction(ACTION_ZJ_ZUNI_AT_FIRES);
                break;
            case EVENT_ZJ_END_TORRENT:
                me->InterruptNonMeleeSpells(false);
                me->ClearChannelObjects();
                break;
            case EVENT_ZJ_FACE_ZUNI:
                me->SetFacingTo(ZarjiraFacingZuni);
                break;
            case EVENT_ZJ_NOT_SO_FAST:
                _phase = ZARJIRA_PHASE_DONE;
                Talk(SAY_ZARJIRA_NOT_SO_FAST);
                break;
            case EVENT_ZJ_KILL_ZUNI:
                SignalZarjiraActor(me, NPC_COVE_ZUNI_FIGHTER, ACTION_ZJ_ZUNI_KILLED);
                SignalZarjiraActor(me, NPC_COVE_VANIRA, ACTION_ZJ_ZUNI_FELL);
                break;
            case EVENT_ZJ_FALL:
                Fall();
                return false;
            case EVENT_ZJ_WATCHDOG:
            {
                // SelectNearestPlayer never finds players in this core's grid search.
                std::list<Player*> players;
                me->GetPlayerListInGrid(players, ZarjiraEventRange);
                if (!players.empty())
                    _abandonedChecks = 0;
                else if (++_abandonedChecks >= ZarjiraAbandonChecks)
                {
                    AbortEvent();
                    return false;
                }
                events.Repeat(5s);
                break;
            }
            case EVENT_ZJ_SCAR_TICK:
                SoulScarTick();
                break;
            default:
                break;
        }
        return true;
    }

    // Retail Soul Scar: 5 x 2 % over 2.5 s. Its caster despawns on death and casterless auras never tick here: spell is visual only.
    void StartSoulScar()
    {
        bool const ticking = _scarTicksLeft > 0;
        _scarTicksLeft += ZarjiraSoulScarTicks;
        if (!ticking)
            events.ScheduleEvent(EVENT_ZJ_SCAR_TICK, ZarjiraSoulScarInterval);
    }

    void SoulScarTick()
    {
        if (!_scarTicksLeft)
            return;

        --_scarTicksLeft;
        uint32 const damage = GateDamage(std::max<uint32>(1, uint32(me->CountPctFromMaxHealth(ZarjiraSoulScarTickPct))));
        if (damage)
            me->ModifyHealth(-int32(damage));

        if (_scarTicksLeft)
            events.ScheduleEvent(EVENT_ZJ_SCAR_TICK, ZarjiraSoulScarInterval);
    }

    // Retail health share per hit
    uint32 ShapeDamage(Unit* attacker, uint32 damage) const
    {
        if (!attacker)
            return damage;

        auto pct = [this](float value) { return std::max<uint32>(1, uint32(me->CountPctFromMaxHealth(value))); };
        switch (attacker->GetEntry())
        {
            case NPC_MANIFESTATION:
                // Scar handled by StartSoulScar().
                return 0;
            case NPC_COVE_ZUNI_FIGHTER:
                return pct(ZarjiraZuniBoltPct);
            case NPC_COVE_VOLJIN:
            case NPC_COVE_VANIRA:
                return std::min(damage, pct(ZarjiraEscortHitPct));
            default:
                return std::min(damage, pct(ZarjiraMaxHitPct));
        }
    }

    // Hold at the threshold until the phase minimum; never overshoot it.
    bool GatePhase(uint32& damage, float thresholdPct, Milliseconds minDuration)
    {
        uint32 const floorHealth = std::max<uint32>(1, uint32(me->CountPctFromMaxHealth(thresholdPct)));
        if (me->GetHealth() <= floorHealth)
        {
            damage = 0;
            return _phaseTimer >= uint32(minDuration.count());
        }

        if (me->GetHealth() - damage > floorHealth)
            return false;

        damage = me->GetHealth() - floorHealth;
        return _phaseTimer >= uint32(minDuration.count());
    }

    Creature* GetBunny() const
    {
        return !_bunnyGuid.IsEmpty() ? ObjectAccessor::GetCreature(*me, _bunnyGuid) : nullptr;
    }

    void SignalBunny(int32 action)
    {
        if (Creature* bunny = GetBunny())
            if (bunny->IsAIEnabled)
                bunny->AI()->DoAction(action);
    }

    // One bunny per intermission: remove stale ones first.
    void SummonChannelBunny()
    {
        std::list<Creature*> stale;
        me->GetCreatureListWithEntryInGrid(stale, NPC_SEA_WITCH_CHANNEL_BUNNY, ZarjiraEventRange);
        for (Creature* bunny : stale)
        {
            bunny->DespawnOrUnsummon();
        }

        _bunnyGuid.Clear();
        if (Creature* bunny = me->SummonCreature(NPC_SEA_WITCH_CHANNEL_BUNNY, SeaWitchChannelSummonPos, TEMPSUMMON_MANUAL_DESPAWN))
            _bunnyGuid = bunny->GetGUID();
    }

    void StartChannelPhase(ZarjiraPhase phase)
    {
        _phase = phase;
        events.CancelEvent(EVENT_ZJ_FROSTBOLT);
        events.CancelEvent(EVENT_ZJ_MANIFESTATION);
        me->InterruptNonMeleeSpells(false);
        SummonChannelBunny();
        DoCastSelf(SPELL_FREEZING_BURST, true);
        SignalZarjiraActor(me, NPC_COVE_VANIRA, ACTION_ZJ_KNOCKED);
        // Retail: freeze +1.0 s, channels +2.43 s
        events.ScheduleEvent(EVENT_ZJ_FREEZE, 1s);
        events.ScheduleEvent(EVENT_ZJ_CHANNEL, 2430ms);
    }

    void EndChannel(bool despawnBunny)
    {
        me->InterruptNonMeleeSpells(false);
        me->ClearChannelObjects();
        if (despawnBunny)
        {
            if (Creature* bunny = GetBunny())
                bunny->DespawnOrUnsummon();
            _bunnyGuid.Clear();
        }
        if (Creature* voljin = FindZarjiraActor(me, NPC_COVE_VOLJIN))
        {
            voljin->InterruptNonMeleeSpells(false);
            voljin->ClearChannelObjects();
        }
    }

    // One spirit at a time, retail spot, sent after a player.
    void SummonManifestation()
    {
        if (_phase != ZARJIRA_PHASE_FIGHT && _phase != ZARJIRA_PHASE_FIGHT_2)
            return;

        std::list<Player*> players;
        me->GetPlayerListInGrid(players, ZarjiraEventRange);
        players.remove_if([](Player const* player) { return !player->IsAlive() || player->IsGameMaster(); });
        if (players.empty())
        {
            events.ScheduleEvent(EVENT_ZJ_MANIFESTATION, ManifestationRespawnMin, ManifestationRespawnMax);
            return;
        }

        Player* target = Trinity::Containers::SelectRandomContainerElement(players);
        Position const& spot = Trinity::Containers::SelectRandomContainerElement(ManifestationSpawnPos);
        Creature* spirit = me->SummonCreature(NPC_MANIFESTATION, spot, TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, uint32(ManifestationLifetime.count()));
        if (!spirit)
            return;

        _manifestationGuid = spirit->GetGUID();
        spirit->AI()->AttackStart(target);

        if (!_spiritCalled)
        {
            _spiritCalled = true;
            SignalZarjiraActor(me, NPC_COVE_VANIRA, ACTION_ZJ_FIRST_SPIRIT);
        }
    }

    void ManifestationGone()
    {
        _manifestationGuid.Clear();
        if (_phase == ZARJIRA_PHASE_FIGHT || _phase == ZARJIRA_PHASE_FIGHT_2)
            events.RescheduleEvent(EVENT_ZJ_MANIFESTATION, urand(ManifestationRespawnMin.count(), ManifestationRespawnMax.count()));
    }

    void Fall()
    {
        events.Reset();
        // Credit late arrivals too.
        DoCastSelf(SPELL_VOLJIN_SPEAK_CREDIT, true);
        DoCastSelf(SPELL_SEA_WITCH_KILL_CREDIT, true);
        // Anchor snaps to Vol'jin.
        SignalBunny(ACTION_BUNNY_TO_VOLJIN);
        if (Creature* bunny = GetBunny())
            bunny->DespawnOrUnsummon(900ms);
        _bunnyGuid.Clear();
        me->InterruptNonMeleeSpells(false);
        me->ClearChannelObjects();

        // Vol'jin's killing shot
        if (Creature* voljin = FindZarjiraActor(me, NPC_COVE_VOLJIN))
            voljin->CastSpell(me, SPELL_VOLJIN_SHADOW_SHOCK, true);
        SignalZarjiraActor(me, NPC_COVE_VOLJIN, ACTION_ZJ_DEFEATED);
        SignalZarjiraActor(me, NPC_COVE_VANIRA, ACTION_ZJ_DEFEATED);
        me->KillSelf();
        me->DespawnOrUnsummon(100s, ZarjiraEventCycle - 100s);
    }

    void AbortEvent()
    {
        _summons.DespawnAll();
        for (uint32 entry : { uint32(NPC_COVE_VOLJIN), uint32(NPC_COVE_VANIRA), uint32(NPC_COVE_ZUNI_FIGHTER) })
            SignalZarjiraActor(me, entry, ACTION_ZJ_ABORT);
        me->DespawnOrUnsummon(0, 5s);
    }

    SummonList _summons;
    ZarjiraPhase _phase;
    uint32 _braziersLeft;
    uint32 _abandonedChecks;
    uint32 _phaseTimer;
    uint32 _scarTicksLeft;
    bool _spiritCalled;
    bool _zuniArrived;
    ObjectGuid _manifestationGuid;
    ObjectGuid _bunnyGuid;
};

/*######
## npc_vanira_spitescale_cove - 38437.
######*/

struct npc_vanira_spitescale_cove : public ScriptedAI
{
    npc_vanira_spitescale_cove(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        SetCombatMovement(false);
        // Freezing Burst throw is scripted (fixed retail landing).
        me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);
    }

    void JustRespawned() override
    {
        events.Reset();
        _fighting = false;
        RestoreZarjiraActor(me);
        me->SetStandState(UNIT_STAND_STATE_STAND);
    }

    void sGossipSelect(Player* player, uint32 menuId, uint32 /*gossipListId*/) override
    {
        if (menuId != GOSSIP_MENU_VANIRA_RECALL)
            return;

        CloseGossipMenuFor(player);
        DoCast(player, SPELL_VANIRAS_RECALL, true);
    }

    void DoAction(int32 action) override
    {
        switch (action)
        {
            case ACTION_ZJ_START:
                me->SetNpcFlags(UNIT_NPC_FLAG_NONE);
                events.ScheduleEvent(EVENT_ZJ_WALK, 300ms);
                break;
            case ACTION_ZJ_FIGHT:
                // Retail from Vol'jin's first shot: at war +0.4 s, melee +3.6 s, totem +4.9 s.
                me->SetFaction(FACTION_DARKSPEAR_AT_WAR);
                events.ScheduleEvent(EVENT_ZJ_ENGAGE, 3600ms);
                events.ScheduleEvent(EVENT_ZJ_TOTEMS, 4900ms);
                break;
            case ACTION_ZJ_FIRST_SPIRIT:
                // Warning with the first spirit.
                events.ScheduleEvent(EVENT_ZJ_SPIRITS_YELL, 400ms);
                break;
            case ACTION_ZJ_KNOCKED:
                // Retail: same landing spot both times.
                me->AttackStop();
                me->GetMotionMaster()->MoveJump(CoveVaniraThrownTo, 9.0f, 9.0f);
                break;
            case ACTION_ZJ_UNFROZEN:
                // Back to the totems and Zar'jira.
                if (!_fighting)
                    break;
                me->SetWalk(false);
                me->GetMotionMaster()->MovePoint(POINT_ZJ_TOTEMS, CoveVaniraTotemPos, false);
                events.RescheduleEvent(EVENT_ZJ_ENGAGE, 1100ms);
                break;
            case ACTION_ZJ_ZUNI_FELL:
                // Retail: turn to Zuni; cry +2.5 s.
                StopFighting();
                events.ScheduleEvent(EVENT_ZJ_FACE_BODY, 300ms);
                events.ScheduleEvent(EVENT_ZJ_ZUNI_NO, 2500ms);
                break;
            case ACTION_ZJ_DEFEATED:
                StopFighting();
                me->CombatStop(true);
                me->SetEmoteState(EMOTE_STATE_READY1H);
                // Then to his body.
                events.ScheduleEvent(EVENT_ZJ_TO_BODY, 2200ms);
                break;
            case ACTION_ZJ_VOLJIN_DONE:
                // Retail gaps after Vol'jin's last line.
                events.ScheduleEvent(EVENT_ZJ_AFTER_1, 12200ms);
                break;
            case ACTION_ZJ_ABORT:
                me->DespawnOrUnsummon(0, 5s);
                break;
            default:
                break;
        }
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type == EFFECT_MOTION_TYPE && pointId == POINT_ZJ_POST)
        {
            me->SetFacingTo(CoveVaniraPost.GetOrientation());
            me->SetEmoteState(EMOTE_STATE_READY1H);
        }
        else if (type == POINT_MOTION_TYPE && pointId == POINT_ZJ_BODY)
        {
            if (Creature* zuni = FindZarjiraActor(me, NPC_COVE_ZUNI_FIGHTER))
                me->SetFacingToObject(zuni);
            // Retail: kneel +1.4 s
            events.ScheduleEvent(EVENT_ZJ_KNEEL, 1400ms);
        }
    }

    void EnterEvadeMode(EvadeReason /*why*/) override { }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_ZJ_WALK:
                    me->SetEmoteState(EMOTE_ONESHOT_NONE);
                    MoveAlongPoints(me, POINT_ZJ_POST, CoveVaniraWalkIn, std::size(CoveVaniraWalkIn), true);
                    break;
                case EVENT_ZJ_ENGAGE:
                    if (me->HasAura(SPELL_FREEZING_TOUCH))
                    {
                        events.Repeat(1s);
                        break;
                    }
                    _fighting = true;
                    me->SetEmoteState(EMOTE_ONESHOT_NONE);
                    if (Creature* zarjira = FindZarjiraActor(me, NPC_ZARJIRA))
                        AttackStart(zarjira);
                    break;
                case EVENT_ZJ_TOTEMS:
                    if (me->HasAura(SPELL_FREEZING_TOUCH))
                    {
                        events.Repeat(1s);
                        break;
                    }
                    DoCastSelf(SPELL_HEALING_STREAM_TOTEM, true);
                    me->SetWalk(false);
                    me->GetMotionMaster()->MovePoint(POINT_ZJ_TOTEMS, CoveVaniraTotemPos, false);
                    events.ScheduleEvent(EVENT_ZJ_MANA_TOTEM, 4900ms);
                    events.Repeat(31s, 34s);
                    break;
                case EVENT_ZJ_MANA_TOTEM:
                    DoCastSelf(SPELL_MANA_STREAM_TOTEM, true);
                    break;
                case EVENT_ZJ_SPIRITS_YELL:
                    Talk(SAY_COVE_VANIRA_SPIRITS);
                    break;
                case EVENT_ZJ_FACE_BODY:
                    me->StopMoving();
                    me->SetFacingTo(VaniraFacingZuni);
                    break;
                case EVENT_ZJ_ZUNI_NO:
                    Talk(SAY_COVE_VANIRA_ZUNI_NO);
                    break;
                case EVENT_ZJ_TO_BODY:
                    // Direct (retail's step back to her post read as fleeing).
                    me->SetWalk(false);
                    me->GetMotionMaster()->MovePoint(POINT_ZJ_BODY, CoveVaniraAtBody, false);
                    break;
                case EVENT_ZJ_KNEEL:
                    me->SetEmoteState(EMOTE_ONESHOT_NONE);
                    me->SetStandState(UNIT_STAND_STATE_KNEEL);
                    break;
                case EVENT_ZJ_AFTER_1:
                    Talk(SAY_COVE_VANIRA_NOTHIN);
                    // Retail: rise +7.5 s, face the players.
                    events.ScheduleEvent(EVENT_ZJ_STAND, 7500ms);
                    events.ScheduleEvent(EVENT_ZJ_AFTER_2, 8500ms);
                    break;
                case EVENT_ZJ_STAND:
                    me->SetStandState(UNIT_STAND_STATE_STAND);
                    break;
                case EVENT_ZJ_AFTER_2:
                    me->SetFacingTo(VaniraFacingPlayers);
                    Talk(SAY_COVE_VANIRA_WATCHERS);
                    events.ScheduleEvent(EVENT_ZJ_AFTER_3, 9700ms);
                    break;
                case EVENT_ZJ_AFTER_3:
                    Talk(SAY_COVE_VANIRA_RUSHED_OFF);
                    // Retail: ride-back gossip (11107) from here.
                    me->SetNpcFlags(UNIT_NPC_FLAG_GOSSIP);
                    // Body collected after her last line.
                    SignalZarjiraActor(me, NPC_COVE_ZUNI_FIGHTER, ACTION_ZJ_VANIRA_DONE);
                    // Offer lasts until the cycle ends (~54 s after the death).
                    me->DespawnOrUnsummon(Seconds(100) - Seconds(54), ZarjiraEventCycle - Seconds(100));
                    break;
                default:
                    break;
            }

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;
        }

        // Retail: melee beside her totems; damage shaped by Zar'jira's script.
        if (_fighting && !me->HasAura(SPELL_FREEZING_TOUCH) && UpdateVictim())
            DoMeleeAttackIfReady();
    }

private:
    void StopFighting()
    {
        _fighting = false;
        for (uint32 eventId : { uint32(EVENT_ZJ_ENGAGE), uint32(EVENT_ZJ_TOTEMS), uint32(EVENT_ZJ_MANA_TOTEM), uint32(EVENT_ZJ_SPIRITS_YELL) })
            events.CancelEvent(eventId);
        me->InterruptNonMeleeSpells(false);
        me->AttackStop();
    }

    bool _fighting = false;
};

/*######
## npc_zuni_spitescale_fight - 38423.
######*/

struct npc_zuni_spitescale_fight : public ScriptedAI
{
    npc_zuni_spitescale_fight(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        SetCombatMovement(false);
        me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);
    }

    void JustRespawned() override
    {
        events.Reset();
        _dead = false;
        RestoreZarjiraActor(me);
    }

    void DoAction(int32 action) override
    {
        if (_dead && action != ACTION_ZJ_VANIRA_DONE && action != ACTION_ZJ_ABORT)
            return;

        switch (action)
        {
            case ACTION_ZJ_TAKE_POST:
                me->SetStandState(UNIT_STAND_STATE_STAND);
                MoveAlongPoints(me, POINT_ZJ_POST, CoveZuniWalkIn, std::size(CoveZuniWalkIn), true);
                break;
            case ACTION_ZJ_FIGHT:
                me->SetFaction(FACTION_DARKSPEAR_AT_WAR);
                AttackZarjira();
                events.ScheduleEvent(EVENT_ZJ_BOLT, 8500ms);
                break;
            case ACTION_ZJ_UNFROZEN:
                AttackZarjira();
                events.RescheduleEvent(EVENT_ZJ_BOLT, 1200ms);
                break;
            case ACTION_ZJ_ZUNI_RUNS:
                events.Reset();
                me->InterruptNonMeleeSpells(false);
                me->AttackStop();
                me->HandleEmoteCommand(EMOTE_ONESHOT_EXCLAMATION);
                Talk(SAY_COVE_ZUNI_THE_FIRES);
                // Retail: +0.4 s after his line
                events.ScheduleEvent(EVENT_ZJ_WALK, 400ms);
                break;
            case ACTION_ZJ_ZUNI_KILLED:
                events.Reset();
                me->StopMoving();
                PlayDead();
                break;
            case ACTION_ZJ_VANIRA_DONE:
                // Retail: +8.7 s after Vanira's last line
                events.ScheduleEvent(EVENT_ZJ_BODY_COLLECTED, 8700ms);
                break;
            case ACTION_ZJ_ABORT:
                me->DespawnOrUnsummon(0, 5s);
                break;
            default:
                break;
        }
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type == EFFECT_MOTION_TYPE && pointId == POINT_ZJ_POST)
            me->SetFacingTo(CoveZuniPost.GetOrientation());
        else if (type == POINT_MOTION_TYPE && pointId == POINT_ZJ_FIRES)
            SignalZarjiraActor(me, NPC_ZARJIRA, ACTION_ZJ_ZUNI_AT_FIRES);
    }

    void EnterEvadeMode(EvadeReason /*why*/) override { }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        while (uint32 eventId = events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_ZJ_BOLT:
                    if (me->GetVictim() && !me->HasAura(SPELL_FREEZING_TOUCH))
                        DoCastVictim(SPELL_COVE_ZUNI_LIGHTNING_BOLT);
                    events.Repeat(2400ms, 4s);
                    break;
                case EVENT_ZJ_WALK:
                    me->SetWalk(false);
                    me->GetMotionMaster()->MovePoint(POINT_ZJ_FIRES, CoveZuniAtTheFires, false);
                    break;
                case EVENT_ZJ_BODY_COLLECTED:
                    // ~63 s after her death; respawn aligned to the 2 min cycle.
                    LeaveZarjiraEvent(me, Seconds(63));
                    break;
                default:
                    break;
            }
        }
    }

private:
    void AttackZarjira()
    {
        if (Creature* zarjira = FindZarjiraActor(me, NPC_ZARJIRA))
            AttackStart(zarjira);
    }

    // Retail: 69252 + 29266, Flags 0x200C8010, Flags2 FEIGN_DEATH, Flags3 FAKE_DEAD. Flags set too in case the aura doesn't.
    void PlayDead()
    {
        _dead = true;
        me->CombatStop(true);
        me->InterruptNonMeleeSpells(false);
        DoCastSelf(SPELL_ZUNI_FROST_EXPLOSION, true);
        if (!me->HasAura(SPELL_PERMANENT_FEIGN_DEATH))
            DoCastSelf(SPELL_PERMANENT_FEIGN_DEATH, true);
        me->AddUnitFlag(UnitFlags(UNIT_FLAG_UNK_29 | UNIT_FLAG_STUNNED));
        me->AddUnitFlag2(UNIT_FLAG2_FEIGN_DEATH);
        me->AddUnitFlag3(UNIT_FLAG3_FAKE_DEAD);
    }

    bool _dead = false;
};

/*######
## npc_fire_of_the_seas - 38542, braziers.
######*/

struct npc_fire_of_the_seas : public ScriptedAI
{
    npc_fire_of_the_seas(Creature* creature) : ScriptedAI(creature) { }

    void IsSummonedBy(Unit* summoner) override
    {
        me->SetReactState(REACT_PASSIVE);
        DoCastSelf(SPELL_FIRE_OF_THE_SEAS, true);
        DoCast(summoner, SPELL_FIRE_ENERGY_BEAM, true);
    }

    void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_STAMP_OUT_FIRE || !caster->IsPlayer() || _out)
            return;

        _out = true;
        SignalZarjiraActor(me, NPC_ZARJIRA, ACTION_ZJ_BRAZIER_OUT);
        me->DespawnOrUnsummon();
    }

    void UpdateAI(uint32 /*diff*/) override { }

private:
    bool _out = false;
};

/*######
## npc_manifestation_of_the_sea_witch - 38302. Chases a player (60 s); its death scars Zar'jira.
######*/

enum ManifestationEvent
{
    EVENT_MANIFESTATION_FINISH_DEATH = 1
};

Milliseconds const ManifestationDeathDelay = 700ms;

struct npc_manifestation_of_the_sea_witch : public ScriptedAI
{
    npc_manifestation_of_the_sea_witch(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        events.Reset();
        _resolving = false;
    }

    void DamageTaken(Unit* /*attacker*/, uint32& damage) override
    {
        if (_resolving)
        {
            damage = 0;
            return;
        }

        if (damage < me->GetHealth())
            return;

        // Keep the caster alive briefly so the Soul Scar transfer visual can
        // leave the Manifestation before its death/despawn state is propagated.
        damage = 0;
        _resolving = true;

        me->AttackStop();
        me->CombatStop(true);
        me->SetReactState(REACT_PASSIVE);
        me->AddUnitFlag(UNIT_FLAG_NON_ATTACKABLE);

        if (Creature* zarjira = FindZarjiraActor(me, NPC_ZARJIRA))
        {
            me->SetFacingToObject(zarjira);
            DoCast(zarjira, SPELL_SOUL_SCAR, true);
        }

        events.ScheduleEvent(EVENT_MANIFESTATION_FINISH_DEATH, ManifestationDeathDelay);
    }

    void UpdateAI(uint32 diff) override
    {
        events.Update(diff);
        while (uint32 eventId = events.ExecuteEvent())
        {
            if (eventId == EVENT_MANIFESTATION_FINISH_DEATH)
            {
                me->KillSelf();
                return;
            }
        }

        if (_resolving || !UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }

private:
    bool _resolving = false;
};

void AddSC_echo_isles()
{
    RegisterCreatureAI(npc_jinthala);
    RegisterCreatureAI(npc_zuni_training_grounds);
    RegisterSpellScript(spell_echo_isles_summon_zuni_lvl_1);
    RegisterAuraScript(spell_echo_isles_zuni_lvl_1_trigger_aura);
    RegisterSpellScript(spell_echo_isles_zuni_lvl_1_trigger);
    RegisterPlayerScript(player_echo_isles_intro_zuni);
    RegisterCreatureAI(npc_tiki_target);
    RegisterCreatureAI(npc_echo_isles_sparring);
    RegisterCreatureAI(npc_echo_isles_class_trainer);
    RegisterCreatureAI(npc_tsu_the_wanderer);
    RegisterCreatureAI(npc_voljin_darkspear_hold);
    RegisterCreatureAI(npc_ardsami);
    RegisterCreatureAI(npc_darkspear_jailor);
    RegisterCreatureAI(npc_captive_spitescale_scout);
    RegisterPlayerScript(player_echo_isles_trainer_praise);
    RegisterCreatureAI(npc_zuni_raptor_pens);
    new at_echo_isles_raptor_pens_zuni();
    RegisterCreatureAI(npc_lost_bloodtalon_hatchling);
    RegisterCreatureAI(npc_najtess);
    RegisterAuraScript(spell_echo_isles_orb_of_corruption);
    RegisterCreatureAI(npc_kijara);
    RegisterCreatureAI(npc_swiftclaw_vehicle);
    RegisterCreatureAI(npc_raptor_rope_bunny);
    RegisterSpellScript(spell_echo_isles_summon_named_raptor);
    RegisterSpellScript(spell_echo_isles_raptor_rope);
    RegisterSpellScript(spell_echo_isles_ride_named_raptor);
    RegisterQuestScript(q_echo_isles_young_and_vicious);
    new at_echo_isles_raptor_pens_return();
    RegisterCreatureAI(npc_bloodtalon_thrasher_ride);
    RegisterCreatureAI(npc_zuni_spitescale_cove);
    RegisterAuraScript(spell_echo_isles_summon_zuni_lvl_4_aura);
    RegisterPlayerScript(player_echo_isles_cove_zuni);
    RegisterCreatureAI(npc_spitescale_flag_bunny);
    RegisterCreatureAI(npc_spitescale_naga);
    RegisterCreatureAI(npc_voljin_spitescale_cove);
    RegisterCreatureAI(npc_sea_witch_channel_bunny);
    RegisterCreatureAI(npc_zarjira);
    RegisterCreatureAI(npc_vanira_spitescale_cove);
    RegisterCreatureAI(npc_zuni_spitescale_fight);
    RegisterCreatureAI(npc_fire_of_the_seas);
    RegisterCreatureAI(npc_manifestation_of_the_sea_witch);
}