-- BFA-HavenCore
-- Northshire: Fear No Evil / Extinguishing Hope cleanup
--
-- Quest 26391: Extinguishing Hope
-- Item 58362: Milly's Fire Extinguisher
-- Item use spell 80199: Spray Water
-- Triggered spell 80208: Spray Water effect
-- Aura 80209: Fire Extinguisher
-- Fire trigger 42940: Northshire Vineyards Fire Trigger

-- ---------------------------------------------------------------------------
-- Fear No Evil
-- 28806 is a valid Human Hunter variant.  All variants have the same objective
-- wording; do not depend on ObjectID here because bad/migrated objective data can
-- otherwise retain the client fallback "<creature> slain".
-- ---------------------------------------------------------------------------

UPDATE `quest_objectives`
SET `Description` = 'Injured Soldier Revived'
WHERE `QuestID` IN (28806, 28808, 28809, 28810, 28811, 28812, 28813, 29082);

-- ---------------------------------------------------------------------------
-- Extinguishing Hope - extinguisher aura
--
-- QuestStatus enum:
--   COMPLETE   = 1 -> (1 << 1) = 2
--   INCOMPLETE = 3 -> (1 << 3) = 8
-- status mask 10 therefore keeps the aura only while the quest is active
-- (incomplete or objectives complete but not yet rewarded).
--
-- flags 3 = AUTOCAST (1) | AUTOREMOVE (2).
-- This removes 80209 on quest abort/reward and when leaving the allowed area.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_area`
WHERE `spell` = 80209;

INSERT INTO `spell_area`
(`spell`, `area`, `quest_start`, `quest_start_status`, `quest_end_status`,
 `quest_end`, `aura_spell`, `teamId`, `racemask`, `gender`, `flags`)
VALUES
(80209, 9,  26391, 10, 0, 0, 0, -1, 0, 2, 3), -- Northshire Valley
(80209, 59, 26391, 10, 0, 0, 0, -1, 0, 2, 3); -- Northshire Vineyards

-- Remove legacy Milly Osworth SmartAI rows that directly add/remove aura 80209.
-- spell_area is now the single owner of this quest aura and correctly handles
-- aborts and area changes as well as take/reward.
DELETE FROM `smart_scripts`
WHERE `entryorguid` = 9296
  AND `source_type` = 0
  AND (
       (`action_type` = 75 AND `action_param1` = 80209)
    OR (`action_type` = 28 AND `action_param1` = 80209)
  );

-- ---------------------------------------------------------------------------
-- Extinguisher use spell
--
-- SourceType 17 = spell cast condition.
-- Condition 9  = quest taken and QUEST_STATUS_INCOMPLETE.
-- Condition 23 = current area.
--
-- ElseGroups make these:
--   (quest 26391 active AND area 9)
--       OR
--   (quest 26391 active AND area 59)
--
-- This prevents using the quest item outside Northshire and after the objective
-- is complete / quest is abandoned.
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Triggered Spray Water target filter
--
-- SourceType 13 = spell implicit target condition.
-- Effect 0 of spell 80208 may only acquire NPC 42940. The spell's native
-- implicit-target radius/cone then determines which nearby vineyard fires are
-- actually hit; no arbitrary C++ distance is hardcoded.
-- ---------------------------------------------------------------------------

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

-- Reassert Haven's existing duplicate-credit protection. C++ spell_quest_extincteur
-- owns the quest credit; SmartAI may keep the fire visual/steam/despawn behavior.
UPDATE `smart_scripts`
SET `action_type` = 0
WHERE `entryorguid` = 42940
  AND `source_type` = 0
  AND `action_type` = 33;
