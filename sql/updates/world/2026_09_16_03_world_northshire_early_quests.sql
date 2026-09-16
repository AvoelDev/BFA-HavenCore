-- BFA-HavenCore
-- Northshire Valley consolidated fixes
--
-- Consolidates the former:
--   2026_09_15_00_northshire_fear_no_evil.sql
--   2026_09_15_00_world_northshire_worg_combat.sql
--   2026_09_15_02_northshire_injured_soldier_cleanup.sql
--   2026_09_15_03_northshire_fear_no_evil_spellclick_conditions.sql
--   2026_09_15_04_northshire_extinguishing_hope.sql
--   2026_09_15_05_northshire_fear_no_evil_stand_state.sql
--   2026_09_15_06_northshire_retail_ambient.sql
--
-- This migration is intentionally idempotent: DELETE/INSERT/UPDATE reassert
-- the final desired world state if older split migrations were already applied.

-- ============================================================================
-- Fear No Evil - Injured Stormwind Infantry (50047)
-- ============================================================================

-- Dedicated C++ AI owns injured/revived behavior; remove legacy SmartAI.
UPDATE `creature_template`
SET `AIName` = '',
    `ScriptName` = 'npc_stormwind_injured_soldier'
WHERE `entry` = 50047;

DELETE FROM `smart_scripts`
WHERE (`entryorguid` = 50047 AND `source_type` = 0)
   OR (`entryorguid` = 5004700 AND `source_type` = 9);

-- Native spell-click interaction:
-- 93072 = Get Our Boys Back Dummy.
DELETE FROM `npc_spellclick_spells`
WHERE `npc_entry` = 50047;

INSERT INTO `npc_spellclick_spells`
(`npc_entry`, `spell_id`, `cast_flags`, `user_type`)
VALUES
(50047, 93072, 1, 0);

-- Only players with an active Fear No Evil class/race variant may use it.
-- SourceType 18 = SpellClick.
-- ConditionType 9 = quest taken / QUEST_STATUS_INCOMPLETE in Haven.
-- Separate ElseGroup values are OR branches.
--
-- Quest 28807 is deliberately NOT included: it is "Expert Opinion", an
-- unrelated level-84 Stormwind quest, despite appearing in one old donor list.
SET @NPC   := 50047;
SET @SPELL := 93072;

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 18
  AND `SourceGroup` = @NPC
  AND `SourceEntry` = @SPELL;

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`,
 `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`,
 `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
 `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
(18, @NPC, @SPELL, 0, 0, 9, 0, 28806, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Hunter - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 1, 9, 0, 28808, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Mage - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 2, 9, 0, 28809, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Paladin - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 3, 9, 0, 28810, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Priest - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 4, 9, 0, 28811, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Rogue - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 5, 9, 0, 28812, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Warlock - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 6, 9, 0, 28813, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Warrior - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 7, 9, 0, 29082, 0, 0, 0, 0, 0, '', 'Fear No Evil - Alliance Northshire variant - quest must be incomplete');

-- Correct enUS acknowledgement token.
UPDATE `creature_text`
SET `Text` = 'You''re $N! The hero that everyone has been talking about! Thank you!'
WHERE `CreatureID` = 50047
  AND `GroupID` = 0
  AND `ID` = 4;

-- All Fear No Evil variants share the same objective wording.
UPDATE `quest_objectives`
SET `Description` = 'Injured Soldier Revived'
WHERE `QuestID` IN (28806, 28808, 28809, 28810, 28811, 28812, 28813, 29082);

-- C++ owns the injured/revived stand state; prevent template addon conflicts.
UPDATE `creature_template_addon`
SET `bytes1` = 0
WHERE `entry` = 50047;

-- ============================================================================
-- Northshire staged Worg combat
-- ============================================================================

UPDATE `creature_template`
SET `ScriptName` = 'npc_blackrock_battle_worg'
WHERE `entry` = 49871;

-- ============================================================================
-- Extinguishing Hope (26391)
-- ============================================================================

-- 80209 = Fire Extinguisher aura.
-- Quest status mask 10 = COMPLETE (2) | INCOMPLETE (8).
-- flags 3 = AUTOCAST | AUTOREMOVE.
DELETE FROM `spell_area`
WHERE `spell` = 80209;

INSERT INTO `spell_area`
(`spell`, `area`, `quest_start`, `quest_start_status`, `quest_end_status`,
 `quest_end`, `aura_spell`, `teamId`, `racemask`, `gender`, `flags`)
VALUES
(80209, 9,  26391, 10, 0, 0, 0, -1, 0, 2, 3), -- Northshire Valley
(80209, 59, 26391, 10, 0, 0, 0, -1, 0, 2, 3); -- Northshire Vineyards

-- spell_area is the single owner of aura 80209.
DELETE FROM `smart_scripts`
WHERE `entryorguid` = 9296
  AND `source_type` = 0
  AND (
       (`action_type` = 75 AND `action_param1` = 80209)
    OR (`action_type` = 28 AND `action_param1` = 80209)
  );

-- 80199 = Spray Water item-use spell.
-- Allow only while quest 26391 is incomplete and in area 9 or 59.
DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 17
  AND `SourceEntry` = 80199;

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
 `ConditionTypeOrReference`, `ConditionTarget`,
 `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
 `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
(17, 0, 80199, 0, 0,  9, 0, 26391, 0, 0, 0, 0, 0, '', 'Spray Water - Extinguishing Hope must be active'),
(17, 0, 80199, 0, 0, 23, 0,     9, 0, 0, 0, 0, 0, '', 'Spray Water - player must be in Northshire Valley'),
(17, 0, 80199, 0, 1,  9, 0, 26391, 0, 0, 0, 0, 0, '', 'Spray Water - Extinguishing Hope must be active'),
(17, 0, 80199, 0, 1, 23, 0,    59, 0, 0, 0, 0, 0, '', 'Spray Water - player must be in Northshire Vineyards');

-- 80208 = triggered Spray Water effect.
-- Effect 0 may only acquire Northshire Vineyards Fire Trigger (42940).
DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 13
  AND `SourceEntry` = 80208;

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
 `ConditionTypeOrReference`, `ConditionTarget`,
 `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
 `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
(13, 1, 80208, 0, 0, 31, 0, 3, 42940, 0, 0, 0, 0, '',
 'Spray Water effect 0 only targets Northshire Vineyards Fire Trigger');

-- C++ spell_quest_extincteur owns quest credit; SmartAI may retain visuals,
-- steam and despawn behavior without granting duplicate credit.
UPDATE `smart_scripts`
SET `action_type` = 0
WHERE `entryorguid` = 42940
  AND `source_type` = 0
  AND `action_type` = 33;

-- ============================================================================
-- Retail ambient behavior
-- ============================================================================

-- Brother Paxton (951): stationary C++ support AI.
UPDATE `creature_template`
SET `AIName` = '',
    `ScriptName` = 'npc_brother_paxton'
WHERE `entry` = 951;

DELETE FROM `smart_scripts`
WHERE (`entryorguid` = 951 AND `source_type` = 0)
   OR (`entryorguid` = 95100 AND `source_type` = 9);

UPDATE `creature`
SET `spawndist` = 0,
    `MovementType` = 0
WHERE `id` = 951;

UPDATE `creature_addon` ca
INNER JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`path_id` = 0
WHERE c.`id` = 951;

DELETE FROM `waypoint_data`
WHERE `id` = 95100;

-- Blackrock Spy (49874): C++ selects retail aura presentation according to
-- existing spawn MovementType (static vs roaming).
UPDATE `creature_template`
SET `AIName` = '',
    `ScriptName` = 'npc_blackrock_spy'
WHERE `entry` = 49874;

DELETE FROM `smart_scripts`
WHERE (`entryorguid` = 49874 AND `source_type` = 0)
   OR (`entryorguid` = 4987400 AND `source_type` = 9);

-- Existing Blackrock Spy MovementType/path data is intentionally preserved.
