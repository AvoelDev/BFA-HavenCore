/*
* 2026 BFA-HavenCore
* Copyright (C) 2006-2009 ScriptDev2 <https://scriptdev2.svn.sourceforge.net/>
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



/*######
## npc_stormwind_infantry
######*/

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedEscortAI.h"
#include "ObjectMgr.h"
#include "ScriptMgr.h"
#include "World.h"
#include "PetAI.h"
#include "PassiveAI.h"
#include "CombatAI.h"
#include "GameEventMgr.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Cell.h"
#include "CellImpl.h"
#include "SpellAuras.h"
#include "Vehicle.h"
#include "Player.h"
#include "SpellScript.h"
#include "AreaTrigger.h"
#include "AreaTriggerAI.h"

enum NorthshireCreatures
{
    NPC_STORMWIND_INFANTRY = 49869,
    NPC_BLACKROCK_WORG     = 49871
};

enum NorthshireSettings
{
    WORG_MIN_HEALTH_PCT     = 70,
    WORG_FIGHTING_FACTION   = 232,
    WORG_RESTORE_FACTION    = 7
};

enum NorthshireSpells
{
    SPELL_WORG_GROWL   = 2649,
    SPELL_RENEWED_LIFE = 93097
};

enum
{
    QUEST_FEAR_NO_EVIL_WORGEN_WARRIOR = 28813,
    QUEST_FEAR_NO_EVIL_ALLIANCE = 29082,
    QUEST_FEAR_NO_EVIL_ALLIANCE_2 = 28809,
    QUEST_FEAR_NO_EVIL_ALLIANCE_3 = 28808,
    QUEST_FEAR_NO_EVIL_ALLIANCE_4 = 28811,
    QUEST_FEAR_NO_EIVL_ALLIANCE_5 = 28810,
    QUEST_FEAR_NO_EVIL_ALLIANCE_6 = 28806,
    QUEST_FEAR_NO_EVIL_ALLIANCE_NIGHT_ELF_WARLOCK_DK = 28812,
};

class npc_stormwind_infantry : public CreatureScript
{
public:
    npc_stormwind_infantry() : CreatureScript("npc_stormwind_infantry") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_stormwind_infantryAI(creature);
    }

    struct npc_stormwind_infantryAI : public ScriptedAI
    {
        npc_stormwind_infantryAI(Creature* creature) : ScriptedAI(creature) { }

        uint32 waitTime;
        ObjectGuid wolfTarget;

        void Reset() override
        {
            wolfTarget = ObjectGuid::Empty;
            me->SetSheath(SHEATH_STATE_MELEE);
            waitTime = urand(0, 2000);
        }

        void DamageTaken(Unit* doneBy, uint32& damage) override
        {
            if (doneBy->ToCreature())
                if (me->GetHealth() <= damage || me->GetHealthPct() <= 80.0f)
                    damage = 0;
        }

        void DamageDealt(Unit* target, uint32& damage, DamageEffectType /*damageType*/) override
        {
            if (target->ToCreature())
                if (target->GetHealth() <= damage || target->GetHealthPct() <= WORG_MIN_HEALTH_PCT)
                    damage = 0;
        }

        void SummonedCreatureDies(Creature* summon, Unit* /*killer*/) override
        {
            if (summon->GetGUID() == wolfTarget)
                ReturnHomeAfterWorg();
        }

        void SummonedCreatureDespawn(Creature* summon) override
        {
            if (summon->GetGUID() == wolfTarget)
                ReturnHomeAfterWorg();
        }

        void ReturnHomeAfterWorg()
        {
            wolfTarget = ObjectGuid::Empty;
            me->DeleteThreatList();
            me->CombatStop(true);
            me->GetMotionMaster()->MoveTargetedHome();
            waitTime = urand(10000, 20000);
        }

        bool IsAtHome() const
        {
            Position const& home = me->GetHomePosition();
            return me->GetDistance2d(home.GetPositionX(), home.GetPositionY()) <= 1.0f;
        }

        bool HandleUnassignedCombat()
        {
            if (!wolfTarget.IsEmpty())
                return false;

            // The infantry may temporarily help against another infantry's worg.
            // A foreign worg is only a combat victim; it is never adopted as
            // this infantry's assigned wolfTarget.
            if (Unit* victim = me->GetVictim())
            {
                if (victim->IsAlive() && me->IsValidAttackTarget(victim))
                    return true;

                me->AttackStop();
            }

            // A foreign target can disappear while the combat flag/threat list
            // remains set. Clear that stale combat state before returning home.
            if (me->IsInCombat())
            {
                me->DeleteThreatList();
                me->CombatStop(true);
            }

            // After any unassigned/assist combat, always recover to the
            // infantry's original DB/home position before spawning its worg.
            if (!IsAtHome())
            {
                me->GetMotionMaster()->MoveTargetedHome();
                return true;
            }

            return false;
        }

        void UpdateAI(uint32 diff) override
        {
            DoMeleeAttackIfReady();

            if (HandleUnassignedCombat())
                return;

            if (waitTime && waitTime >= diff)
            {
                waitTime -= diff;
                return;
            }

            waitTime = urand(10000, 20000);

            if (!wolfTarget.IsEmpty())
            {
                if (Creature* wolf = ObjectAccessor::GetCreature(*me, wolfTarget))
                {
                    if (wolf->IsAlive())
                    {
                        // Keep the infantry on its assigned worg. Do not force the
                        // worg back onto the infantry here: player threat is allowed
                        // to take over and both creatures may chase the player.
                        if (me->GetVictim() != wolf)
                        {
                            me->getThreatManager().addThreat(wolf, 1000000.0f);
                            wolf->getThreatManager().addThreat(me, 1000000.0f);
                            AttackStart(wolf);
                        }
                    }
                    else
                    {
                        ReturnHomeAfterWorg();
                        wolf->DespawnOrUnsummon();
                    }
                }
                else
                    ReturnHomeAfterWorg();
            }
            else
            {
                Position wolfPos = me->GetPosition();
                GetPositionWithDistInFront(me, 2.5f, wolfPos);

                float z = me->GetMap()->GetHeight(me->GetPhaseShift(), wolfPos.GetPositionX(), wolfPos.GetPositionY(), wolfPos.GetPositionZ());
                wolfPos.m_positionZ = z;

                if (Creature* wolf = me->SummonCreature(NPC_BLACKROCK_WORG, wolfPos))
                {
                    // HeronCore uses a temporary combat faction for the staged
                    // infantry-vs-worg fight. The worg AI restores Haven's normal
                    // faction (7) when it leaves combat.
                    wolf->SetFaction(WORG_FIGHTING_FACTION);

                    me->getThreatManager().addThreat(wolf, 1000000.0f);
                    wolf->getThreatManager().addThreat(me, 1000000.0f);

                    AttackStart(wolf);

                    // One-time reciprocal start. Unlike the previous experiment,
                    // this is not re-applied while a player owns the worg's threat.
                    if (wolf->IsAIEnabled)
                        wolf->AI()->AttackStart(me);

                    me->SetFacingToObject(wolf);
                    wolf->SetFacingToObject(me);
                    wolfTarget = wolf->GetGUID();
                }
            }
        }
    };
};

/*######
## npc_blackrock_battle_worg
######*/

class npc_blackrock_battle_worg : public CreatureScript
{
public:
    npc_blackrock_battle_worg() : CreatureScript("npc_blackrock_battle_worg") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_blackrock_battle_worgAI(creature);
    }

    struct npc_blackrock_battle_worgAI : public ScriptedAI
    {
        npc_blackrock_battle_worgAI(Creature* creature) : ScriptedAI(creature) { }

        uint32 seekTimer;
        uint32 growlTimer;

        void Reset() override
        {
            seekTimer = urand(1000, 2000);
            growlTimer = urand(8500, 10000);
            me->SetFaction(WORG_RESTORE_FACTION);
        }

        void DamageTaken(Unit* attacker, uint32& damage) override
        {
            if (attacker->GetTypeId() == TYPEID_PLAYER || attacker->IsPet())
            {
                // A player/pet attacking the staged worg takes over its threat.
                // The infantry deliberately keeps chasing the worg.
                me->getThreatManager().resetAllAggro();
                me->getThreatManager().addThreat(attacker, 1000000.0f);
                AttackStart(attacker);
            }

            // Infantry must not kill the ambient battle worg on its own.
            if (attacker->GetEntry() == NPC_STORMWIND_INFANTRY)
                if (me->GetHealth() <= damage || me->GetHealthPct() <= WORG_MIN_HEALTH_PCT)
                    damage = 0;
        }

        void UpdateAI(uint32 diff) override
        {
            if (seekTimer <= diff)
            {
                if (me->IsAlive() && !me->IsInCombat())
                {
                    Position const& home = me->GetHomePosition();
                    if (me->GetDistance2d(home.GetPositionX(), home.GetPositionY()) <= 1.0f)
                    {
                        // Haven summons the staged worg 2.5 yards in front of the
                        // infantry, so use 5 yards rather than HeronCore's 1 yard.
                        if (Creature* infantry = me->FindNearestCreature(NPC_STORMWIND_INFANTRY, 5.0f, true))
                        {
                            me->SetFaction(WORG_FIGHTING_FACTION);
                            me->getThreatManager().addThreat(infantry, 1.0f);
                            infantry->getThreatManager().addThreat(me, 1.0f);
                            AttackStart(infantry);
                        }
                    }
                }

                seekTimer = urand(1000, 2000);
            }
            else
                seekTimer -= diff;

            if (!UpdateVictim())
            {
                // Outside the staged fight the creature returns to Haven's
                // normal 49871 faction rather than remaining globally hostile.
                me->SetFaction(WORG_RESTORE_FACTION);
                return;
            }

            if (growlTimer <= diff)
            {
                DoCastVictim(SPELL_WORG_GROWL);
                growlTimer = urand(8500, 10000);
            }
            else
                growlTimer -= diff;

            DoMeleeAttackIfReady();
        }
    };
};

/*######
## npc_stormwind_injured_soldier
######*/

// 50047 - Injured Stormwind Infantry
struct npc_stormwind_injured_soldier : public ScriptedAI
{
    npc_stormwind_injured_soldier(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        ScriptedAI::Reset();

        _clickerGuid.Clear();

        me->NearTeleportTo(me->GetHomePosition());
        me->SetStandState(UNIT_STAND_STATE_DEAD);

        // Fear No Evil uses the native spell-click interaction.
        // Do not expose a gossip interaction for this creature.
        me->RemoveNpcFlag(UNIT_NPC_FLAG_GOSSIP);
        me->AddNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
    }

    void OnSpellClick(Unit* clicker, bool& result) override
    {
        Player* player = clicker ? clicker->ToPlayer() : nullptr;
        if (!player || !HasFearNoEvilQuest(player))
        {
            result = false;
            return;
        }

        _clickerGuid = player->GetGUID();

        // 93072 is executed by npc_spellclick_spells and supplies quest credit.
        // The soldier itself owns the revive visual, matching the reference
        // implementation and avoiding player-owned/minion presentation.
        me->CastSpell(me, SPELL_RENEWED_LIFE, true);

        me->RemoveNpcFlag(UNIT_NPC_FLAG_SPELLCLICK);
        me->SetStandState(UNIT_STAND_STATE_STAND);

        me->GetScheduler().Schedule(1s, [this](TaskContext /*task*/)
        {
            if (Player* player = ObjectAccessor::GetPlayer(*me, _clickerGuid))
            {
                me->SetFacingToObject(player);

                // Passing the player supplies the context used by $N in
                // creature_text.
                Talk(0, player);
            }
            else
                Talk(0);

            me->HandleEmoteCommand(EMOTE_ONESHOT_SALUTE);
        });

        me->GetScheduler().Schedule(3s, [this](TaskContext /*task*/)
        {
            me->GetMotionMaster()->MoveRandom(10.0f);
            me->ForcedDespawn(3000, 15s);
        });
    }

private:
    static bool HasFearNoEvilQuest(Player const* player)
    {
        return player->GetQuestStatus(QUEST_FEAR_NO_EVIL_WORGEN_WARRIOR) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_2) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_3) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_4) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_FEAR_NO_EIVL_ALLIANCE_5) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_6) == QUEST_STATUS_INCOMPLETE
            || player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_NIGHT_ELF_WARLOCK_DK) == QUEST_STATUS_INCOMPLETE;
    }

    ObjectGuid _clickerGuid;
};

/*######
## npc_training_dummy_elwynn
######*/

enum eTrainingDummySpells
{
    SPELL_CHARGE        = 100,
    SPELL_AUTORITE      = 105361, // OnDamage
    SPELL_ASSURE        = 56641,
    SPELL_EVISCERATION  = 2098,
    SPELL_MOT_DOULEUR_1 = 589,
    SPELL_MOT_DOULEUR_2 = 124464, // Je ne sais pas si un des deux est le bon
    SPELL_NOVA          = 122,
    SPELL_CORRUPTION_1  = 172,
    SPELL_CORRUPTION_2  = 87389,
    SPELL_CORRUPTION_3  = 131740,
    SPELL_PAUME_TIGRE   = 100787
};

class npc_training_dummy_start_zones : public CreatureScript
{
public:
    npc_training_dummy_start_zones() : CreatureScript("npc_training_dummy_start_zones") { }

    struct npc_training_dummy_start_zonesAI : Scripted_NoMovementAI
    {
        npc_training_dummy_start_zonesAI(Creature* creature) : Scripted_NoMovementAI(creature)
        {}

        uint32 resetTimer;

        void Reset() override
        {
            me->SetControlled(true, UNIT_STATE_STUNNED);//disable rotate
            me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);//imune to knock aways like blast wave

            resetTimer = 5000;
        }

        void EnterEvadeMode(EvadeReason /*why*/) override
        {
            if (!_EnterEvadeMode())
                return;

            Reset();
        }

        void MoveInLineOfSight(Unit* p_Who) override
        {
            if (!me->IsWithinDistInMap(p_Who, 25.f) && p_Who->IsInCombat())
            {
                me->RemoveAllAurasByCaster(p_Who->GetGUID());
                me->getHostileRefManager().deleteReference(p_Who);
            }
        }

        void DamageTaken(Unit* doneBy, uint32& damage) override
        {
            resetTimer = 5000;
            damage = 0;

            if (doneBy->HasAura(SPELL_AUTORITE))
            {
                if (Player* player = doneBy->ToPlayer())
                {
                    player->KilledMonsterCredit(44175);
                    player->KilledMonsterCredit(44548);

                }
            }
        }

        void EnterCombat(Unit* /*who*/) override
        {
            return;
        }

        void SpellHit(Unit* Caster, const SpellInfo* Spell) override
        {
            switch (Spell->Id)
            {
                case SPELL_CHARGE:
                case SPELL_ASSURE:
                case SPELL_EVISCERATION:
                case SPELL_MOT_DOULEUR_1:
                case SPELL_MOT_DOULEUR_2:
                case SPELL_NOVA:
                case SPELL_CORRUPTION_1:
                case SPELL_CORRUPTION_2:
                case SPELL_CORRUPTION_3:
                case SPELL_PAUME_TIGRE:
                {
                    if (Player* player = Caster->ToPlayer())
                    {
                        player->KilledMonsterCredit(44175);
                        player->KilledMonsterCredit(44548);
                    }
                    break;
                }
                default:
                    break;
            }
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            if (!me->HasUnitState(UNIT_STATE_STUNNED))
                me->SetControlled(true, UNIT_STATE_STUNNED);//disable rotate

            if (resetTimer <= diff)
            {
                EnterEvadeMode(EVADE_REASON_OTHER);
                resetTimer = 5000;
            }
            else
                resetTimer -= diff;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_training_dummy_start_zonesAI(creature);
    }
};

/*######
## spell_quest_fear_no_evil
######*/

class spell_quest_fear_no_evil : public SpellScriptLoader
{
public:
    spell_quest_fear_no_evil() : SpellScriptLoader("spell_quest_fear_no_evil") { }

    class spell_quest_fear_no_evil_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_quest_fear_no_evil_SpellScript);

        void OnDummy(SpellEffIndex /*effIndex*/)
        {
            if (GetCaster())
                if (GetCaster()->ToPlayer())
                    GetCaster()->ToPlayer()->KilledMonsterCredit(50047);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_quest_fear_no_evil_SpellScript::OnDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    SpellScript* GetSpellScript() const override
    {
        return new spell_quest_fear_no_evil_SpellScript();
    }

};

/*######
## spell_quest_extincteur
######*/

enum eSpellQuestExtincteur
{
    NPC_FIRE = 42940,
};

class spell_quest_extincteur : public SpellScriptLoader
{
public:
    spell_quest_extincteur() : SpellScriptLoader("spell_quest_extincteur") { }

    class spell_quest_extincteur_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_quest_extincteur_SpellScript);

        void OnDummy(SpellEffIndex /*effIndex*/)
        {
            Unit* caster = GetCaster();
            Creature* fire = GetHitCreature();

            if (!caster || !fire)
                return;

            if (fire->GetEntry() != NPC_FIRE)
                return;

            if (Player* player = caster->ToPlayer())
                player->KilledMonsterCredit(NPC_FIRE, fire->GetGUID());

            fire->DespawnOrUnsummon();
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_quest_extincteur_SpellScript::OnDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    SpellScript* GetSpellScript() const override
    {
        return new spell_quest_extincteur_SpellScript();
    }

};

void AddSC_northshire()
{
    new npc_stormwind_infantry();
    new npc_blackrock_battle_worg();
    RegisterCreatureAI(npc_stormwind_injured_soldier);
    new npc_training_dummy_start_zones();
    new spell_quest_fear_no_evil();
    new spell_quest_extincteur();
}

