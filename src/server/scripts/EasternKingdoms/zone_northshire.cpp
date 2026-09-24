/*
 * This file is part of BFA-HavenCore.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Northshire (zone 6170) - human starting area.
 *
 * Source of truth: retail warrior sniff (build 12.1.0.69933), with every
 * spell, emote and anim kit validated against the 8.3.7 DB2 files.
 * Static data (texts, auras, emote states, patrols, spawns, quest links)
 * lives in sql/updates/world; this file only holds behaviour the database
 * cannot express without chaining SmartAI rows.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "Log.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include "SpellScript.h"
#include "TaskScheduler.h"
#include <array>

namespace Northshire
{
    enum Creatures
    {
        NPC_STORMWIND_INFANTRY          = 49869,
        NPC_BLACKROCK_WORG              = 49871,
        NPC_INJURED_STORMWIND_INFANTRY  = 50047,
        NPC_VINEYARD_FIRE_TRIGGER       = 42940
    };

    enum Spells
    {
        // Brother Paxton
        SPELL_PAXTON_RENEW              = 93094,
        SPELL_PAXTON_FLASH_HEAL         = 17843,
        SPELL_PAXTON_PENANCE            = 47757,
        SPELL_PAXTON_PRAYER_OF_HEALING  = 93091,

        // Blackrock Spy
        SPELL_SPYGLASS                  = 80676,

        // Injured Stormwind Infantry
        SPELL_RENEWED_LIFE              = 93097,
        SPELL_SET_HEALTH_RANDOM         = 53034,

        // Northshire Vineyards Fire Trigger
        SPELL_VINEYARD_FIRE             = 80175,
        SPELL_STEAM                     = 80223,
        SPELL_SPRAY_WATER               = 80208
    };

    enum Quests
    {
        QUEST_EXTINGUISHING_HOPE        = 26391
    };

    enum Texts
    {
        SAY_INFANTRY_CALL_FOR_HEAL      = 0,
        SAY_PAXTON_HEAL                 = 0,
        SAY_SPY_AGGRO                   = 0,
        SAY_INJURED_REVIVED             = 0
    };

    enum Points
    {
        POINT_INJURED_ROUTE_FIRST       = 1
    };

    enum SchedulerGroups
    {
        GROUP_IDLE                      = 1,
        GROUP_COMBAT                    = 2
    };

    // Sniff: every Stormwind Infantry vs Blackrock Worg exchange stops dealing
    // damage at exactly 85% health (3721 of 4378) on both sides.
    constexpr uint32 STAGED_FIGHT_HEALTH_FLOOR_PCT = 85;

    // Sniff: an idle worg only picks up an infantry standing right next to it.
    constexpr float WORG_ENGAGE_INFANTRY_RANGE = 10.0f;

    // Retail keeps the worg on FactionTemplate 32 and the infantry on 2321.
    // In the 8.3.7 FactionTemplate.db2 they are neutral to each other, and the
    // core only lets two creatures fight when one of them is hostile. On top of
    // that, any Stormwind NPC treats a neutral unit attacking a friendly one as
    // a valid target (Creature::_IsTargetAcceptable) and will ride over to help,
    // which is what dismounted the Royal Guard riders. So for the length of a
    // staged fight the worg is UNIT_FLAG_IMMUNE_TO_NPC, which shuts out every
    // other NPC, and its infantry is UNIT_FLAG_PVP_ATTACKABLE, the one flag that
    // lets a creature bypass both that immunity and the hostility test.
    // Players are unaffected: they already carry UNIT_FLAG_PVP_ATTACKABLE.

    // Sniff: every healed infantry stood within 17.1 yards of Paxton; the next
    // one out (41.9 yards) called for heals but was never healed.
    constexpr float PAXTON_HEAL_RANGE = 20.0f;

    // Sniff: Paxton resumes pacing about 6 seconds after starting a heal.
    constexpr uint32 PAXTON_HEAL_PAUSE_MS = 6000;

    // Sniff: 3 of 14 Paxton casts were accompanied by a line.
    constexpr uint32 PAXTON_TALK_CHANCE = 25;

    // Sniff: 2 aggro lines over roughly 10 spy kills.
    constexpr uint32 SPY_AGGRO_TALK_CHANCE = 20;

    // Sniff: every revived soldier joins the same route at its nearest node
    // and runs it to the abbey entrance, where it despawns.
    std::array<Position, 9> const InjuredInfantryRoute =
    { {
        { -8836.79f, -154.60f, 80.44f },
        { -8853.48f, -147.54f, 80.92f },
        { -8880.70f, -134.43f, 80.62f },
        { -8899.06f, -127.00f, 81.65f },
        { -8911.90f, -126.35f, 81.40f },
        { -8912.00f, -134.30f, 80.50f },
        { -8909.18f, -144.83f, 81.99f },
        { -8904.67f, -156.71f, 81.99f },
        { -8901.26f, -160.19f, 82.02f }
    } };

    // The staged infantry/worg fight is only protected while no player is
    // involved; once a player tags either side, damage goes through normally.
    void ClampStagedFightDamage(Unit* victim, Unit* attacker, uint32& damage)
    {
        if (!attacker || attacker->IsControlledByPlayer())
            return;

        uint64 const floor = victim->CountPctFromMaxHealth(STAGED_FIGHT_HEALTH_FLOOR_PCT);
        if (victim->GetHealth() <= floor)
        {
            damage = 0;
            return;
        }

        uint64 const headroom = victim->GetHealth() - floor;
        if (damage > headroom)
            damage = uint32(headroom);
    }
}

using namespace Northshire;

// 49869 - Stormwind Infantry
struct npc_northshire_stormwind_infantry : public ScriptedAI
{
    npc_northshire_stormwind_infantry(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->RemoveUnitFlag(UNIT_FLAG_PVP_ATTACKABLE);
        me->GetScheduler().CancelAll();
        ScheduleIdleShout();
    }

    void MoveInLineOfSight(Unit* /*who*/) override
    {
        // Sniff: infantry never leave their post to chase a worg; the worg
        // always starts the fight.
    }

    void JustReachedHome() override
    {
        // Restores the template ready stance (EmoteState 333) after a fight.
        me->LoadCreaturesAddon();
    }

    void JustEngagedWith(Unit* /*who*/) override
    {
        // Sniff: EmoteState drops from 333 to 0 as soon as a worg is targeted.
        me->SetEmoteState(EMOTE_ONESHOT_NONE);
        me->GetScheduler().CancelGroup(GROUP_IDLE);

        me->GetScheduler().Schedule(40s, 90s, GROUP_COMBAT, [this](TaskContext context)
        {
            Talk(SAY_INFANTRY_CALL_FOR_HEAL);
            context.Repeat(40s, 90s);
        });
    }

    void DamageTaken(Unit* attacker, uint32& damage) override
    {
        if (attacker && attacker->GetEntry() == NPC_BLACKROCK_WORG)
            ClampStagedFightDamage(me, attacker, damage);
    }

    void UpdateAI(uint32 /*diff*/) override
    {
        if (!UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }

private:
    void ScheduleIdleShout()
    {
        // Sniff: an infantry without a worg shouts every 20-60 seconds.
        me->GetScheduler().Schedule(20s, 60s, GROUP_IDLE, [this](TaskContext context)
        {
            me->HandleEmoteCommand(EMOTE_ONESHOT_SHOUT);
            context.Repeat(20s, 60s);
        });
    }
};

// 49871 - Blackrock Worg
struct npc_northshire_blackrock_worg : public ScriptedAI
{
    npc_northshire_blackrock_worg(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->RemoveUnitFlag(UNIT_FLAG_IMMUNE_TO_NPC);
        me->GetScheduler().CancelAll();

        // Two stationary creatures never trigger MoveInLineOfSight for each
        // other, so the partner worg has to look for its infantry itself.
        me->GetScheduler().Schedule(1s, [this](TaskContext context)
        {
            if (!me->IsEngaged())
                TryEngageInfantry();
            context.Repeat(2s);
        });
    }

    void DamageTaken(Unit* attacker, uint32& damage) override
    {
        if (attacker && attacker->GetEntry() == NPC_STORMWIND_INFANTRY)
            ClampStagedFightDamage(me, attacker, damage);
    }

    void UpdateAI(uint32 /*diff*/) override
    {
        if (!UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }

private:
    void TryEngageInfantry()
    {
        std::list<Creature*> infantry;
        me->GetCreatureListWithEntryInGrid(infantry, NPC_STORMWIND_INFANTRY, WORG_ENGAGE_INFANTRY_RANGE);

        Creature* target = nullptr;
        for (Creature* candidate : infantry)
        {
            if (!candidate->IsAlive() || candidate->IsEngaged())
                continue;

            if (!target || me->GetExactDist2d(candidate) < me->GetExactDist2d(target))
                target = candidate;
        }

        if (!target)
            return;

        TC_LOG_DEBUG("scripts", "Northshire: worg %s engages infantry %s.",
            me->GetGUID().ToString().c_str(), target->GetGUID().ToString().c_str());

        me->AddUnitFlag(UNIT_FLAG_IMMUNE_TO_NPC);
        target->AddUnitFlag(UNIT_FLAG_PVP_ATTACKABLE);
        AttackStart(target);
        target->AI()->AttackStart(me);
    }
};

// 951 - Brother Paxton
struct npc_northshire_brother_paxton : public ScriptedAI
{
    npc_northshire_brother_paxton(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        me->GetScheduler().CancelAll();

        // Sniff: heal casts on nearby infantry every 20-40 seconds.
        me->GetScheduler().Schedule(20s, 40s, [this](TaskContext context)
        {
            TryHealInfantry();
            context.Repeat(20s, 40s);
        });
    }

    void UpdateAI(uint32 /*diff*/) override
    {
        // Healing an infantry that is fighting pulls Paxton into its combat
        // (Spell::DoSpellHitOnUnit assist rules) without giving him anyone to
        // attack; UpdateVictim would then evade and walk him home mid-heal.
        // In the sniff he never fights, so assist-only combat is dropped and
        // he only defends himself when something actually threatens him.
        if (!me->IsThreatened())
        {
            if (me->IsInCombat())
                me->CombatStop();
            return;
        }

        if (!UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }

private:
    void TryHealInfantry()
    {
        if (me->IsThreatened() || me->HasUnitState(UNIT_STATE_CASTING))
            return;

        Unit* target = DoSelectBelowHpPctFriendlyWithEntry(NPC_STORMWIND_INFANTRY, PAXTON_HEAL_RANGE, 100);
        if (!target)
            return;

        uint32 const spellId = PickHealSpell();

        // Sniff: Paxton stops pacing and turns to the soldier for every cast.
        // Waypoint movement ignores casting, so pause it explicitly or the
        // cast-time heals would be interrupted by the next node.
        me->GetMotionMaster()->MoveDistract(PAXTON_HEAL_PAUSE_MS);
        me->SetFacingToObject(target);
        DoCast(target, spellId);

        // Sniff: lines were only paired with Renew and Flash Heal.
        if ((spellId == SPELL_PAXTON_RENEW || spellId == SPELL_PAXTON_FLASH_HEAL) && roll_chance_i(PAXTON_TALK_CHANCE))
            Talk(SAY_PAXTON_HEAL, target);
    }

    static uint32 PickHealSpell()
    {
        // Sniff distribution over 14 casts: Renew 5, Flash Heal 5, Penance 3,
        // Prayer of Healing 1.
        uint32 const roll = urand(1, 14);
        if (roll <= 5)
            return SPELL_PAXTON_RENEW;
        if (roll <= 10)
            return SPELL_PAXTON_FLASH_HEAL;
        if (roll <= 13)
            return SPELL_PAXTON_PENANCE;
        return SPELL_PAXTON_PRAYER_OF_HEALING;
    }
};

// 49874 - Blackrock Spy
struct npc_northshire_blackrock_spy : public ScriptedAI
{
    npc_northshire_blackrock_spy(Creature* creature) : ScriptedAI(creature) { }

    void JustEngagedWith(Unit* who) override
    {
        // Sniff: kneeling spies drop the spyglass and stand up on aggro.
        me->RemoveAurasDueToSpell(SPELL_SPYGLASS);
        me->SetStandState(UNIT_STAND_STATE_STAND);

        if (roll_chance_i(SPY_AGGRO_TALK_CHANCE))
            Talk(SAY_SPY_AGGRO, who);
    }

    void JustReachedHome() override
    {
        // The per-spawn addon decides whether this spy kneels with a
        // spyglass or sneak-patrols; reapply it instead of hardcoding either.
        me->LoadCreaturesAddon();
    }

    void UpdateAI(uint32 /*diff*/) override
    {
        if (!UpdateVictim())
            return;

        DoMeleeAttackIfReady();
    }
};

// 50047 - Injured Stormwind Infantry
struct npc_northshire_injured_stormwind_infantry : public ScriptedAI
{
    npc_northshire_injured_stormwind_infantry(Creature* creature) : ScriptedAI(creature), _reviving(false) { }

    void Reset() override
    {
        me->GetScheduler().CancelAll();
        _reviving = false;
        _rescuerGuid.Clear();

        // Sniff: every injured soldier spawns at a random 30-50% health.
        // Reset runs before the creature is in the world on spawn, where the
        // cast would be dropped, so it waits for the first update.
        me->GetScheduler().Schedule(500ms, [this](TaskContext /*context*/)
        {
            DoCastSelf(SPELL_SET_HEALTH_RANDOM, true);
        });
    }

    void OnSpellClick(Unit* clicker, bool& result) override
    {
        // 93072 targets the clicker, not this soldier, so neither SpellHit nor
        // a spell effect on the soldier fires; the click itself drives the scene.
        if (!result || _reviving)
            return;

        Player* rescuer = clicker ? clicker->ToPlayer() : nullptr;
        if (!rescuer)
            return;

        _reviving = true;
        _rescuerGuid = rescuer->GetGUID();

        // The spellclick conditions already limit this to an incomplete
        // Fear No Evil variant.
        rescuer->KilledMonsterCredit(NPC_INJURED_STORMWIND_INFANTRY, me->GetGUID());

        TC_LOG_DEBUG("scripts", "Northshire: injured infantry %s revived by %s.",
            me->GetGUID().ToString().c_str(), rescuer->GetGUID().ToString().c_str());

        // Sniff: the soldier casts Renewed Life and becomes unselectable in the
        // same update as the click.
        DoCastSelf(SPELL_RENEWED_LIFE, true);
        me->RemoveNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
        me->AddUnitFlag(UNIT_FLAG_NOT_SELECTABLE);

        // Sniff timings: stand up +2.1s, face and talk +0.9s, run +2.3s.
        me->GetScheduler().Schedule(2100ms, [this](TaskContext context)
        {
            me->SetStandState(UNIT_STAND_STATE_STAND);

            context.Schedule(900ms, [this](TaskContext context)
            {
                Player* rescuer = ObjectAccessor::GetPlayer(*me, _rescuerGuid);
                if (rescuer)
                    me->SetFacingToObject(rescuer);

                // Each line carries its own one-shot emote in creature_text.
                Talk(SAY_INJURED_REVIVED, rescuer);

                context.Schedule(2300ms, [this](TaskContext /*context*/)
                {
                    StartRouteToAbbey();
                });
            });
        });
    }

    void MovementInform(uint32 type, uint32 pointId) override
    {
        if (type != POINT_MOTION_TYPE || !_reviving)
            return;

        uint32 const nextIndex = pointId - POINT_INJURED_ROUTE_FIRST + 1;
        if (nextIndex >= InjuredInfantryRoute.size())
        {
            me->DespawnOrUnsummon();
            return;
        }

        MoveToRouteIndex(nextIndex);
    }

    void UpdateAI(uint32 /*diff*/) override { }

private:
    void StartRouteToAbbey()
    {
        size_t nearest = 0;
        float nearestDist = me->GetExactDist2d(InjuredInfantryRoute[0]);
        for (size_t i = 1; i < InjuredInfantryRoute.size(); ++i)
        {
            float const dist = me->GetExactDist2d(InjuredInfantryRoute[i]);
            if (dist < nearestDist)
            {
                nearest = i;
                nearestDist = dist;
            }
        }

        me->SetWalk(false);
        MoveToRouteIndex(uint32(nearest));
    }

    void MoveToRouteIndex(uint32 index)
    {
        me->GetMotionMaster()->MovePoint(POINT_INJURED_ROUTE_FIRST + index, InjuredInfantryRoute[index]);
    }

    bool _reviving;
    ObjectGuid _rescuerGuid;
};

// 42940 - Northshire Vineyards Fire Trigger
struct npc_northshire_vineyard_fire : public ScriptedAI
{
    npc_northshire_vineyard_fire(Creature* creature) : ScriptedAI(creature) { }

    void SpellHit(Unit* /*caster*/, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SPELL_SPRAY_WATER || !me->HasAura(SPELL_VINEYARD_FIRE))
            return;

        // Sniff: the fire aura is removed and Steam is cast in the same update;
        // the trigger then despawns and respawns burning.
        me->RemoveAurasDueToSpell(SPELL_VINEYARD_FIRE);
        DoCastSelf(SPELL_STEAM, true);
        me->DespawnOrUnsummon(2s);
    }

    void UpdateAI(uint32 /*diff*/) override { }
};

// 80208 - Spray Water
class spell_northshire_spray_water : public SpellScript
{
    PrepareSpellScript(spell_northshire_spray_water);

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        Creature* fire = GetHitCreature();
        if (!player || !fire || fire->GetEntry() != NPC_VINEYARD_FIRE_TRIGGER)
            return;

        // A fire that was already put out this cycle must not grant credit twice.
        if (!fire->HasAura(SPELL_VINEYARD_FIRE))
            return;

        if (player->GetQuestStatus(QUEST_EXTINGUISHING_HOPE) != QUEST_STATUS_INCOMPLETE)
            return;

        player->KilledMonsterCredit(NPC_VINEYARD_FIRE_TRIGGER, fire->GetGUID());
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_northshire_spray_water::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

void AddSC_northshire()
{
    RegisterCreatureAI(npc_northshire_stormwind_infantry);
    RegisterCreatureAI(npc_northshire_blackrock_worg);
    RegisterCreatureAI(npc_northshire_brother_paxton);
    RegisterCreatureAI(npc_northshire_blackrock_spy);
    RegisterCreatureAI(npc_northshire_injured_stormwind_infantry);
    RegisterCreatureAI(npc_northshire_vineyard_fire);
    RegisterSpellScript(spell_northshire_spray_water);
}