-- BFA-HavenCore merge audit (read-only: SELECTs only, safe to run on live DBs).
-- Run each section against the database named in its header and fix every
-- returned row before merging the related core change.

-- ============================================================================
-- 1. [world] SmartAI vehicles that will lose their AI when boarded
--    Core/SmartAI (e9edbd5): a charmed SmartAI creature now switches to
--    PossessedAI unless one of its events has SMART_EVENT_FLAG_WHILE_CHARMED
--    (0x200). Vehicles that move the player on their own need the flag.
-- ============================================================================
SELECT ct.`entry`, ct.`name`, ct.`VehicleId`
FROM `creature_template` AS ct
WHERE ct.`AIName` = 'SmartAI'
  AND ct.`VehicleId` <> 0
  AND NOT EXISTS (
      SELECT 1 FROM `smart_scripts` AS s
      WHERE s.`source_type` = 0 AND s.`entryorguid` = ct.`entry`
        AND (s.`event_flags` & 0x200) <> 0)
ORDER BY ct.`entry`;

-- Same check for spawn-scoped (negative guid) SmartAI scripts.
SELECT c.`guid`, c.`id`, ct.`name`
FROM `creature` AS c
JOIN `creature_template` AS ct ON ct.`entry` = c.`id`
WHERE ct.`VehicleId` <> 0
  AND EXISTS (SELECT 1 FROM `smart_scripts` AS s
              WHERE s.`source_type` = 0 AND s.`entryorguid` = -CAST(c.`guid` AS SIGNED))
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` AS s
                  WHERE s.`source_type` = 0 AND s.`entryorguid` = -CAST(c.`guid` AS SIGNED)
                    AND (s.`event_flags` & 0x200) <> 0)
ORDER BY c.`guid`;

-- Opt-in template for a vehicle that must keep its script while ridden
-- (review each one first; only the events that drive the ride need it):
-- UPDATE `smart_scripts` SET `event_flags` = `event_flags` | 0x200
-- WHERE `source_type` = 0 AND `entryorguid` = <entry> AND `id` IN (<event ids>);

-- ============================================================================
-- 2. [world] Spell-click creatures with no npc_spellclick_spells row
--    Non-vehicles keep their cursor (script-only OnSpellClick still works).
--    Vehicles listed here lose the cursor: add a row if they should be
--    clickable, otherwise nothing to do.
-- ============================================================================
SELECT ct.`entry`, ct.`name`, ct.`ScriptName`, ct.`VehicleId`
FROM `creature_template` AS ct
LEFT JOIN `npc_spellclick_spells` AS sc ON sc.`npc_entry` = ct.`entry`
WHERE (ct.`npcflag` & 0x01000000) <> 0
  AND ct.`VehicleId` <> 0
  AND sc.`npc_entry` IS NULL
ORDER BY ct.`entry`;

-- ============================================================================
-- 3. [characters] Characters above the 25 regular-quest cap
--    Nothing is lost any more (all 125 slots load), but these players cannot
--    accept new regular quests until they drop below 25. The count below
--    includes world quests / bonus objectives, so treat it as an upper bound.
-- ============================================================================
SELECT `guid`, COUNT(*) AS `active_quests`
FROM `character_queststatus`
WHERE `status` <> 0
GROUP BY `guid`
HAVING `active_quests` > 25
ORDER BY `active_quests` DESC;
