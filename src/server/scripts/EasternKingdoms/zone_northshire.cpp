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

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "ScriptedEscortAI.h"
#include "ObjectMgr.h"
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

#define NPC_WOLF 49871

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
                if (target->GetHealth() <= damage || target->GetHealthPct() <= 70.0f)
                    damage = 0;
        }

        void UpdateAI(uint32 diff) override
        {
            DoMeleeAttackIfReady();

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
                        if (me->GetVictim() != wolf)
                        {
                            me->getThreatManager().addThreat(wolf, 1000000.0f);
                            wolf->getThreatManager().addThreat(me, 1000000.0f);
                            me->Attack(wolf, true);
                        }
                    }
                    else
                    {
                        wolf->DespawnOrUnsummon();
                        wolfTarget = ObjectGuid::Empty;
                    }
                }
            }
            else
            {
                Position wolfPos = me->GetPosition();
                GetPositionWithDistInFront(me, 2.5f, wolfPos);

                float z = me->GetMap()->GetHeight(me->GetPhaseShift(), wolfPos.GetPositionX(), wolfPos.GetPositionY(), wolfPos.GetPositionZ());
                wolfPos.m_positionZ = z;

                if (Creature* wolf = me->SummonCreature(NPC_WOLF, wolfPos))
                {
                    me->getThreatManager().addThreat(wolf, 1000000.0f);
                    wolf->getThreatManager().addThreat(me, 1000000.0f);
                    AttackStart(wolf);
                    wolf->SetFacingToObject(me);
                    wolfTarget = wolf->GetGUID();
                }
            }
        }
    };
};

struct npc_stormwind_injured_soldier : public ScriptedAI
{
    npc_stormwind_injured_soldier(Creature* creature) : ScriptedAI(creature) { }

    void Reset() override
    {
        ScriptedAI::Reset();
        me->NearTeleportTo(me->GetHomePosition());
        me->SetStandState(UNIT_STAND_STATE_DEAD);
    }

    void sGossipHello(Player* player) override
    {
        CloseGossipMenuFor(player);
        if (player->GetQuestStatus(QUEST_FEAR_NO_EVIL_WORGEN_WARRIOR) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_2) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_3) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_4) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(QUEST_FEAR_NO_EIVL_ALLIANCE_5) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_6) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(QUEST_FEAR_NO_EVIL_ALLIANCE_NIGHT_ELF_WARLOCK_DK) == QUEST_STATUS_INCOMPLETE)
        {
            me->RemoveNpcFlag(UNIT_NPC_FLAG_GOSSIP);
            player->CastSpell(me, 93072, true);
            me->SetStandState(UNIT_STAND_STATE_STAND);
            me->GetScheduler().Schedule(1s, [this, player](TaskContext /*task*/)
            {
                me->SetFacingToObject(player);
                me->HandleEmoteCommand(EMOTE_ONESHOT_SALUTE);
                Talk(0);
            });
            me->GetScheduler().Schedule(3s, [this](TaskContext /*task*/)
            {
                me->GetMotionMaster()->MoveRandom(10.0f);
                me->ForcedDespawn(3000, 15s);
            });
        }
    }
};

enum eTrainingDummySpells
{
    SPELL_CHARGE        = 100,
    SPELL_AUTORITE      = 105361,
    SPELL_ASSURE        = 56641,
    SPELL_EVISCERATION  = 2098,
    SPELL_MOT_DOULEUR_1 = 589,
    SPELL_MOT_DOULEUR_2 = 124464,
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

    struct npc_training_dummy_start_zonesAI : public Scripted_NoMovementAI
    {
        npc_training_dummy_start_zonesAI(Creature* creature) : Scripted_NoMovementAI(creature) { }

        uint32 resetTimer;

        void Reset() override
        {
            me->SetControlled(true, UNIT_STATE_STUNNED);
            me->ApplySpellImmune(0, IMMUNITY_EFFECT, SPELL_EFFECT_KNOCK_BACK, true);
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

        void SpellHit(Unit* caster, const SpellInfo* spell) override
        {
            switch (spell->Id)
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
                    if (Player* player = caster->ToPlayer())
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
                me->SetControlled(true, UNIT_STATE_STUNNED);

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
    RegisterCreatureAI(npc_stormwind_injured_soldier);
    new npc_training_dummy_start_zones();
    new spell_quest_fear_no_evil();
    new spell_quest_extincteur();
}
