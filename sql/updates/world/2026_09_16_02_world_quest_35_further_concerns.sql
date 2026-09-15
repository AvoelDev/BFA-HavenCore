-- Quest 35 - Further Concerns
-- Marshal Dughan (240) / Stormwind Charger (42260)
--
-- Canonical HavenCore implementation.
-- Consolidates the proven gossip/vehicle setup and the working 39-node
-- Stormwind Charger route into a single idempotent world update.
--
-- Behavior:
-- - Marshal Dughan offers the charger only while quest 35 is complete and not rewarded.
-- - His existing SmartAI casts Force Stormwind Charger (78854).
-- - Stormwind Charger uses VehicleId 882 and npc_elwynn_stormwind_charger.
-- - Manual spell-click control is removed.
-- - The charger follows DB waypoint path 4226000 node-by-node and ejects at the end.

-- Marshal Dughan gossip option.
DELETE FROM `gossip_menu_option`
WHERE `MenuId` = 11611
  AND `OptionIndex` = 0;

INSERT INTO `gossip_menu_option`
(`MenuId`, `OptionIndex`, `OptionIcon`, `OptionText`, `OptionBroadcastTextId`, `OptionType`, `OptionNpcflag`, `VerifiedBuild`)
VALUES
(11611, 0, 0, 'I wish to ride the Stormwind charger, sir.', 42173, 1, 1, 25881);

-- Show the charger option while quest 35 is complete but not yet rewarded.
DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 15
  AND `SourceGroup` = 11611
  AND `SourceEntry` = 0;

INSERT INTO `conditions`
(
    `SourceTypeOrReferenceId`,
    `SourceGroup`,
    `SourceEntry`,
    `SourceId`,
    `ElseGroup`,
    `ConditionTypeOrReference`,
    `ConditionTarget`,
    `ConditionValue1`,
    `ConditionValue2`,
    `ConditionValue3`,
    `NegativeCondition`,
    `ErrorType`,
    `ErrorTextId`,
    `ScriptName`,
    `Comment`
)
VALUES
(
    15,     -- CONDITION_SOURCE_TYPE_GOSSIP_MENU_OPTION
    11611,  -- Marshal Dughan gossip menu
    0,      -- OptionIndex 0: Stormwind Charger
    0,
    0,
    28,     -- CONDITION_QUEST_COMPLETE
    0,
    35,     -- Further Concerns
    0,
    0,
    0,
    0,
    0,
    '',
    'Marshal Dughan - Show Stormwind Charger while quest 35 is complete and not rewarded'
);

-- Stormwind Charger scripted taxi vehicle.
UPDATE `creature_template`
SET `speed_run` = 2,
    `VehicleId` = 882,
    `ScriptName` = 'npc_elwynn_stormwind_charger'
WHERE `entry` = 42260;

-- Boarding is handled by the quest/vehicle script. Do not expose the manual
-- spell-click Control interaction on this taxi vehicle.
DELETE FROM `npc_spellclick_spells`
WHERE `npc_entry` = 42260;

-- Retail-style Goldshire -> Guard Thomas route.
-- Haven drives this node-by-node with MovePath(4226000, false).
DELETE FROM `waypoint_data`
WHERE `id` = 4226000;

INSERT INTO `waypoint_data`
(`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `move_type`, `delay`, `action`, `action_chance`)
VALUES
(4226000, 1, -9465.488, 64.75174, 55.9232, 0, 1, 0, 0, 100),
(4226000, 2, -9489.841, 64.25694, 55.95109, 0, 1, 0, 0, 100),
(4226000, 3, -9503.804, 35.873264, 56.39156, 0, 1, 0, 0, 100),
(4226000, 4, -9523.1455, -2.920139, 55.85599, 0, 1, 0, 0, 100),
(4226000, 5, -9541.677, -38.56597, 56.474117, 0, 1, 0, 0, 100),
(4226000, 6, -9547.922, -69.87327, 57.372242, 0, 1, 0, 0, 100),
(4226000, 7, -9549.37, -110.31077, 57.489456, 0, 1, 0, 0, 100),
(4226000, 8, -9555.764, -137.2448, 57.400364, 0, 1, 0, 0, 100),
(4226000, 9, -9575.194, -159.01389, 57.548084, 0, 1, 0, 0, 100),
(4226000, 10, -9586.826, -197.10591, 57.53395, 0, 1, 0, 0, 100),
(4226000, 11, -9603.833, -239.58333, 57.28743, 0, 1, 0, 0, 100),
(4226000, 12, -9615.153, -277.39062, 57.83489, 0, 1, 0, 0, 100),
(4226000, 13, -9619.554, -310.06946, 57.385513, 0, 1, 0, 0, 100),
(4226000, 14, -9620.591, -344.71353, 57.166138, 0, 1, 0, 0, 100),
(4226000, 15, -9620.62, -373.00348, 57.503777, 0, 1, 0, 0, 100),
(4226000, 16, -9618.868, -401.0625, 57.791756, 0, 1, 0, 0, 100),
(4226000, 17, -9611.052, -427.99478, 57.386707, 0, 1, 0, 0, 100),
(4226000, 18, -9597.004, -456.90973, 57.62922, 0, 1, 0, 0, 100),
(4226000, 19, -9589.788, -484.03995, 57.71283, 0, 1, 0, 0, 100),
(4226000, 20, -9596.089, -506.9896, 57.407463, 0, 1, 0, 0, 100),
(4226000, 21, -9610.698, -531.625, 54.788067, 0, 1, 0, 0, 100),
(4226000, 22, -9617.52, -558.88196, 54.451187, 0, 1, 0, 0, 100),
(4226000, 23, -9622.382, -607.8733, 52.419804, 0, 1, 0, 0, 100),
(4226000, 24, -9626.333, -636.25696, 51.19875, 0, 1, 0, 0, 100),
(4226000, 25, -9638.899, -656.44617, 49.511, 0, 1, 0, 0, 100),
(4226000, 26, -9644.645, -673.96875, 48.639606, 0, 1, 0, 0, 100),
(4226000, 27, -9655.107, -718.59375, 44.738724, 0, 1, 0, 0, 100),
(4226000, 28, -9655.63, -745.4809, 44.562298, 0, 1, 0, 0, 100),
(4226000, 29, -9652.263, -776.8698, 44.270496, 0, 1, 0, 0, 100),
(4226000, 30, -9647.052, -797.9809, 43.50934, 0, 1, 0, 0, 100),
(4226000, 31, -9631.623, -816.98267, 43.828598, 0, 1, 0, 0, 100),
(4226000, 32, -9609.665, -840.8333, 43.67657, 0, 1, 0, 0, 100),
(4226000, 33, -9589.141, -863.5243, 43.705048, 0, 1, 0, 0, 100),
(4226000, 34, -9582.302, -898.25, 43.62359, 0, 1, 0, 0, 100),
(4226000, 35, -9587.446, -930.15454, 43.31383, 0, 1, 0, 0, 100),
(4226000, 36, -9609.941, -959.48956, 43.61531, 0, 1, 0, 0, 100),
(4226000, 37, -9619.147, -980.625, 43.67072, 0, 1, 0, 0, 100),
(4226000, 38, -9621.516, -1009.3889, 41.507584, 0, 1, 0, 0, 100),
(4226000, 39, -9618.427, -1032.1129, 39.71602, 0, 1, 0, 0, 100);
