-- BFA-HavenCore
-- Echo Isles rework (zone 6453): Darkspear Training Grounds, raptor pens,
-- Darkspear Hold, Spitescale Cove and the Thrall vision.
--
-- Behaviour lives in src/server/scripts/Kalimdor/zone_echo_isles.cpp; this
-- file holds the static side (script bindings, flags, factions, texts,
-- spawns, paths, visibility) from retail 12.1.0 sniffs, the 8.3.7 DB2s and
-- the broadcast_text hotfix table.
--
-- Merges and replaces:
--   2026_09_24_00_echo_isles_training_grounds.sql
--   2026_09_24_01_echo_isles_raptor_pens.sql
--   2026_09_25_00_echo_isles_legacy_cleanup.sql
--   2026_09_25_01_echo_isles_overhaul_fixes.sql
--   2026_09_26_00_echo_isles_visibility_states.sql
--   2026_09_26_01_echo_isles_ambience_audit.sql
--   2026_09_27_00_echo_isles_jornun_ride.sql
--   2026_09_28_00_echo_isles_final_stage.sql
--   2026_09_29_00_echo_isles_cavern_zuni.sql
-- Statements a later file overrode are folded into their final form.
--
-- Idempotent: every block deletes or overwrites its own rows, so the file
-- gives the same result on a fresh database and on one that already ran the
-- nine files above.

-- ============================================================================
-- Part 1 - Darkspear Training Grounds
-- ============================================================================

-- Behaviour moves to C++ (src/server/scripts/Kalimdor/zone_echo_isles.cpp):
-- Jin'thala's send-off, the personal Zuni who runs the player to the
-- training grounds, the Proving Pit Jailor and scout, and the trainers'
-- objective praise. This part keeps only the static side: script bindings,
-- flags and texts. Texts, sounds, flags and factions are taken from retail
-- 12.1.0 sniffs; BroadcastTextId values come from the server's
-- broadcast_text hotfix table, matched on the exact sniffed text.

-- ---------------------------------------------------------------------------
-- Script bindings. Every entry scripted in C++ drops its SmartAI, including
-- per-spawn (negative GUID) rows, so no two behaviour owners remain.
-- ---------------------------------------------------------------------------

UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_jinthala'                 WHERE `entry` = 37951;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_zuni_training_grounds'    WHERE `entry` = 37988;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_darkspear_jailor'         WHERE `entry` = 39062;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_captive_spitescale_scout' WHERE `entry` = 38142;

DELETE FROM `smart_scripts`
WHERE `source_type` = 0
  AND `entryorguid` IN (37951, 37988, 39062, 38142);

DELETE `ss` FROM `smart_scripts` AS `ss`
INNER JOIN `creature` AS `c`
    ON `ss`.`entryorguid` = -CAST(`c`.`guid` AS SIGNED)
WHERE `ss`.`source_type` = 0
  AND `c`.`id` IN (37951, 39062, 38142);

-- The Proving Pit cage (201968) is scenery on retail: its state never
-- changes while the scout walks out, so it needs no script at all.
UPDATE `gameobject_template` SET `AIName` = '' WHERE `entry` = 201968;

DELETE FROM `smart_scripts`
WHERE `source_type` = 1
  AND `entryorguid` = 201968;

DELETE `ss` FROM `smart_scripts` AS `ss`
INNER JOIN `gameobject` AS `g`
    ON `ss`.`entryorguid` = -CAST(`g`.`guid` AS SIGNED)
WHERE `ss`.`source_type` = 1
  AND `g`.`id` = 201968;

-- ---------------------------------------------------------------------------
-- Flags and factions (retail values).
-- ---------------------------------------------------------------------------

-- Zuni is created immune to players and NPCs so nothing on the road pulls him.
UPDATE `creature_template`
SET `unit_flags` = `unit_flags` | 768
WHERE `entry` = 37988;

-- The scout is a hostile naga held immune to players while caged; the C++
-- script lifts the immunity once it reaches the pit floor. Non-attackable
-- is dropped because retail never sets it.
UPDATE `creature_template`
SET `faction` = 634,
    `unit_flags` = (`unit_flags` & ~2) | 256
WHERE `entry` = 38142;

-- ---------------------------------------------------------------------------
-- Texts.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_text` WHERE `CreatureID` IN (37951, 37988, 39062, 38142);
DELETE FROM `creature_text`
WHERE `CreatureID` IN (38037, 38242, 38243, 38244, 38245, 38246, 38247, 63310)
  AND `GroupID` IN (0, 1);

INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
VALUES
    (37951, 0, 0, '$n. Zuni. Ya''ll find ya trainer in the trainin'' grounds to the east. Bring pride to the Darkspear.', 12, 0, 100, 1, 0, 0,     37821, 0, 'Jin''thala - On quest accept'),
    (37988, 0, 0, 'Ya, mon. Let''s crack some tiki target skulls!',                                                  12, 0, 100, 5, 0, 21366, 37818, 0, 'Zuni - Greet player'),
    (37988, 1, 0, 'Ya trainer should be somewhere in the grounds ''ere. I''ll catch you lata, mon.',                 12, 0, 100, 1, 0, 21367, 39087, 0, 'Zuni - Reached training grounds'),
    (39062, 0, 0, 'Get in the pit and show us your stuff, $G boy:girl;.',                                           12, 0, 100, 1, 0, 0,     37886,     0, 'Darkspear Jailor - Challenge accepted'),
    (38142, 0, 0, 'The Sssea Witch will kill you all.',                                                             12, 0, 100, 0, 0, 0,     39090,     0, 'Captive Spitescale Scout - Taunt'),
    (38142, 0, 1, 'I sshal tasste your blood, landling.',                                                           12, 0, 100, 0, 0, 0,     39092,     0, 'Captive Spitescale Scout - Taunt'),
    (38142, 0, 2, 'I sshal ssslaughter you, Darksspear runt!',                                                      12, 0, 100, 0, 0, 0,     39089,     0, 'Captive Spitescale Scout - Taunt'),
    (38142, 0, 3, 'They sssend you to your death, youngling.',                                                      12, 0, 100, 0, 0, 0,     39091,     0, 'Captive Spitescale Scout - Taunt'),
    (38037, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Nortet - Tiki Targets objective complete'),
    (38037, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Nortet - Proving Pit objective complete'),
    (38242, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Nekali - Tiki Targets objective complete'),
    (38242, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Nekali - Proving Pit objective complete'),
    (38243, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Zen''tabra - Tiki Targets objective complete'),
    (38243, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Zen''tabra - Proving Pit objective complete'),
    (38244, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Legati - Tiki Targets objective complete'),
    (38244, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Legati - Proving Pit objective complete'),
    (38245, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Tunari - Tiki Targets objective complete'),
    (38245, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Tunari - Proving Pit objective complete'),
    (38246, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Soratha - Tiki Targets objective complete'),
    (38246, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Soratha - Proving Pit objective complete'),
    (38247, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Ortezza - Tiki Targets objective complete'),
    (38247, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Ortezza - Proving Pit objective complete'),
    (63310, 0, 0, 'Not bad, $n. Not bad.', 12, 0, 100, 0, 0, 0, 37928, 0, 'Zabrax - Tiki Targets objective complete'),
    (63310, 1, 0, 'Well done, $n!',        12, 0, 100, 0, 0, 0, 37898, 0, 'Zabrax - Proving Pit objective complete');

-- ============================================================================
-- Part 2 - Raptor pens (quests 24622-24626)
-- ============================================================================

-- Behaviour lives in src/server/scripts/Kalimdor/zone_echo_isles.cpp; the
-- old Kijara / Swiftclaw C++ in zone_durotar.cpp and the SmartAI on these
-- entries are removed so each creature has exactly one behaviour owner.
-- Values follow retail 12.1.0 sniffs, mapped onto this server's 8.3.7
-- quest objectives (266030 "Capture Swiftclaw" = 37989,
-- 266031 "Return Swiftclaw to the Raptor Pens" = 38002).

-- Personal Zuni for "A Troll's Truest Companion" and his three triggers.
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_zuni_raptor_pens' WHERE `entry` = 38930;
UPDATE `creature_template` SET `unit_flags` = `unit_flags` | 768 WHERE `entry` = 38930;

DELETE FROM `areatrigger_scripts` WHERE `entry` IN (5677, 5777, 5778);
INSERT INTO `areatrigger_scripts` (`entry`, `ScriptName`) VALUES
    (5677, 'at_echo_isles_raptor_pens_zuni'),
    (5777, 'at_echo_isles_raptor_pens_zuni'),
    (5778, 'at_echo_isles_raptor_pens_zuni');

DELETE FROM `smart_scripts` WHERE `source_type` = 2 AND `entryorguid` IN (5677, 5777, 5778);

-- "Saving the Young": hatchlings hit by the Bloodtalon Whistle (70874)
-- are credited and follow the player.
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_lost_bloodtalon_hatchling' WHERE `entry` = 39157;

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (38930, 39157);
DELETE `ss` FROM `smart_scripts` AS `ss`
INNER JOIN `creature` AS `c`
    ON `ss`.`entryorguid` = -CAST(`c`.`guid` AS SIGNED)
WHERE `ss`.`source_type` = 0
  AND `c`.`id` = 39157;

DELETE FROM `creature_text` WHERE `CreatureID` IN (38930, 39157);
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
VALUES
    (38930, 0, 0, 'Wait up, mon!',                                                                              12, 0, 100, 5, 0, 21368, 39066, 0, 'Zuni - Joins the player'),
    (38930, 1, 0, 'You finished with ya trainin'' too? Glad you make it through, mon!',                         12, 0, 100, 6, 0, 21370, 39067, 0, 'Zuni - Area trigger 5777'),
    (38930, 2, 0, 'I know dis is prolly busy work, but I don''t mind. Dese baby raptors are cute lil devils.', 12, 0, 100, 1, 0, 21371, 39068, 0, 'Zuni - Area trigger 5778'),
    (38930, 3, 0, 'Try not ta make me look too bad, eh?',                                                       12, 0, 100, 1, 0, 21373, 39069, 0, 'Zuni - Saving the Young accepted'),
    (39157, 0, 0, '%s lets out a little screech.',                                   16, 0, 100, 0, 0, 0, 37762, 0, 'Lost Bloodtalon Hatchling - Rescued'),
    (39157, 0, 1, '%s taps his little claws on the ground as he runs to you.',       16, 0, 100, 0, 0, 0, 37766, 0, 'Lost Bloodtalon Hatchling - Rescued'),
    (39157, 0, 2, '%s bobbles after you happily.',                                   16, 0, 100, 0, 0, 0, 37732, 0, 'Lost Bloodtalon Hatchling - Rescued'),
    (39157, 0, 3, '%s skips after you.',                                             16, 0, 100, 0, 0, 0, 37764, 0, 'Lost Bloodtalon Hatchling - Rescued');

-- ---------------------------------------------------------------------------
-- "Young and Vicious": the 8.3.7 spell chain drives the scene (see the
-- script header); the world-spawned Swiftclaw (37989) is scenery again.
-- ---------------------------------------------------------------------------

UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_kijara'             WHERE `entry` = 37969;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_swiftclaw_vehicle', `npcflag` = 0 WHERE `entry` = 38002;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_raptor_rope_bunny' WHERE `entry` = 37995;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = '', `npcflag` = 0        WHERE `entry` = 37989;
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 37989;

-- The zone's quest bunnies (38003) polled for a nearby 37989 every 5 s to
-- detect the old return; the pens area trigger now has the nearest bunny
-- cast retail's "Raptor Turn-in Credit" instead.
UPDATE `creature_template` SET `AIName` = '' WHERE `entry` = 38003;

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (37969, 37989, 37995, 38002, 38003);
DELETE `ss` FROM `smart_scripts` AS `ss`
INNER JOIN `creature` AS `c`
    ON `ss`.`entryorguid` = -CAST(`c`.`guid` AS SIGNED)
WHERE `ss`.`source_type` = 0
  AND `c`.`id` IN (37969, 37989, 38003);

UPDATE `quest_template_addon` SET `ScriptName` = 'q_echo_isles_young_and_vicious' WHERE `ID` = 24626;

DELETE FROM `spell_script_names` WHERE `spell_id` IN (70898, 70925, 70927);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
    (70898, 'spell_echo_isles_summon_named_raptor'),
    (70925, 'spell_echo_isles_ride_named_raptor'),
    (70927, 'spell_echo_isles_raptor_rope');

DELETE FROM `areatrigger_scripts` WHERE `entry` = 5675;
INSERT INTO `areatrigger_scripts` (`entry`, `ScriptName`) VALUES
    (5675, 'at_echo_isles_raptor_pens_return');
DELETE FROM `smart_scripts` WHERE `source_type` = 2 AND `entryorguid` = 5675;

-- Implicit-target filters the 8.3.7 spells expect: without them the entry
-- checks fall back to default targets (the ride would find no raptor).
DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 13
  AND `SourceEntry` IN (70874, 70898, 70925, 70927, 70941);
INSERT INTO `conditions`
    (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
     `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
     `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
    (13, 1, 70874, 0, 0, 51, 0, 5, 39157, 0, 0, 0, 0, '', 'Bloodtalon Whistle - target Lost Bloodtalon Hatchling'),
    (13, 1, 70898, 0, 0, 51, 0, 5, 38002, 0, 0, 0, 0, '', 'Summon Named Raptor - check for Swiftclaw'),
    (13, 1, 70925, 0, 0, 51, 0, 5, 38002, 0, 0, 0, 0, '', 'Ride Named Raptor - target Swiftclaw'),
    (13, 1, 70927, 0, 0, 51, 0, 5, 38002, 0, 0, 0, 0, '', 'Raptor Rope - target Swiftclaw'),
    (13, 2, 70941, 0, 0, 51, 0, 5, 38002, 0, 0, 0, 0, '', 'Raptor Turn-in Credit - hit Swiftclaw');

DELETE FROM `creature_text` WHERE `CreatureID` = 38002;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
VALUES
    (38002, 0, 0, 'Swiftclaw isn''t stopping!  Steer him back to the raptor pens near Darkspear Hold.', 42, 0, 100, 0, 0, 0, 37757, 0, 'Swiftclaw - Lassoed');

-- Retail's escape circuit around the pens (loop of the sniffed splines).
DELETE FROM `waypoint_data` WHERE `id` = 3800200;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `move_type`) VALUES
    (3800200, 1, -1529.5903, -5251.9863, 5.4496, 1),
    (3800200, 2, -1546.0192, -5244.1006, 5.8820, 1),
    (3800200, 3, -1571.2101, -5227.3057, 2.9056, 1),
    (3800200, 4, -1588.7570, -5226.8438, 2.6599, 1),
    (3800200, 5, -1592.7344, -5240.2520, 4.7744, 1),
    (3800200, 6, -1587.3733, -5256.4150, 6.2273, 1),
    (3800200, 7, -1558.6423, -5270.4790, 7.6515, 1),
    (3800200, 8, -1550.7344, -5285.7780, 8.6433, 1),
    (3800200, 9, -1563.1615, -5320.4517, 8.0627, 1),
    (3800200, 10, -1584.1666, -5326.9240, 7.4514, 1),
    (3800200, 11, -1589.4305, -5312.0957, 7.5004, 1),
    (3800200, 12, -1588.4844, -5282.4050, 7.7721, 1),
    (3800200, 13, -1631.5938, -5272.8960, 3.2074, 1),
    (3800200, 14, -1633.1250, -5292.2880, 3.0673, 1),
    (3800200, 15, -1606.4705, -5307.8994, 6.5894, 1),
    (3800200, 16, -1603.6077, -5325.4740, 6.2866, 1),
    (3800200, 17, -1647.5312, -5337.8022, 0.8760, 1),
    (3800200, 18, -1646.4375, -5353.6840, 1.1910, 1),
    (3800200, 19, -1613.6771, -5353.1080, 4.5910, 1),
    (3800200, 20, -1589.5834, -5354.0503, 6.3341, 1),
    (3800200, 21, -1583.7726, -5371.5300, 2.0310, 1),
    (3800200, 22, -1612.6875, -5366.1840, 3.2010, 1),
    (3800200, 23, -1599.4080, -5349.4775, 6.0315, 1),
    (3800200, 24, -1573.6962, -5351.2310, 5.9431, 1),
    (3800200, 25, -1562.0122, -5336.0903, 7.8113, 1),
    (3800200, 26, -1549.7986, -5324.8560, 7.4586, 1),
    (3800200, 27, -1532.8004, -5335.0957, 6.8970, 1),
    (3800200, 28, -1532.9479, -5342.7430, 6.4056, 1),
    (3800200, 29, -1542.2051, -5354.5510, 5.5681, 1),
    (3800200, 30, -1531.8125, -5367.3370, 4.3370, 1),
    (3800200, 31, -1516.9601, -5356.2935, 6.3588, 1),
    (3800200, 32, -1509.0538, -5333.0454, 5.4124, 1),
    (3800200, 33, -1531.2848, -5315.3350, 7.1992, 1),
    (3800200, 34, -1552.4305, -5298.3735, 9.1047, 1),
    (3800200, 35, -1576.7379, -5285.8525, 8.2044, 1),
    (3800200, 36, -1585.9913, -5272.2330, 7.8017, 1),
    (3800200, 37, -1561.3872, -5265.1250, 7.2425, 1),
    (3800200, 38, -1526.9462, -5293.3384, 6.9647, 1),
    (3800200, 39, -1513.4219, -5261.7676, 5.9903, 1);

-- ---------------------------------------------------------------------------
-- Ambient movement. Retail hatchlings shuffle within ~3 yd of their spawn
-- (90th percentile 2.7 yd) and Corrupted Bloodtalons roam ~10 yd
-- (median 6.8 yd); both stand still in the current data.
-- ---------------------------------------------------------------------------

UPDATE `creature` SET `MovementType` = 1, `spawndist` = 3  WHERE `id` = 39157;
UPDATE `creature` SET `MovementType` = 1, `spawndist` = 10 WHERE `id` = 37961;

-- Hatchlings are rescued with the whistle, not by talking to them.
UPDATE `creature_template` SET `npcflag` = 0 WHERE `entry` = 39157;

-- ============================================================================
-- Legacy cleanup
-- ============================================================================

-- Earlier migrations tuned parts of the Echo Isles in ways the rework now
-- owns in C++ or corrects against retail. This section neutralises them so the
-- sections that follow start from a known state:
--  * 2026_08_21_03 (Tiki Target): NullCreatureAI and fixed per-spawn visual
--    auras; the new AI picks a random visual and plays the death visual.
--  * 2026_08_17_02 (Echo Isles section): immune-to-NPC flags that retail
--    never sets on these mobs (their colour comes from the faction).
--  * SmartAI rows that only ever did harm here: Vol'jin and the visions
--    called timed action lists that do not exist, Zen'tabra and Ortezza
--    walked to (0, 0, 0), and Voldreka summoned an imp retail never shows.
-- (2026_08_21_05, the Proving Pit SmartAI, is neutralised in part 1.)

-- Tiki Target (38038)
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 38038;

-- Retail unit flags (2026_08_17_02 added immune-to-NPC to the first three).
UPDATE `creature_template` SET `unit_flags` = 32768 WHERE `entry` IN (38046, 37956, 37961);
UPDATE `creature_template` SET `unit_flags` = 0     WHERE `entry` = 39004;

-- Broken SmartAI on NPCs the overhaul scripts.
UPDATE `creature_template` SET `AIName` = ''
WHERE `entry` IN (38037, 38242, 38243, 38244, 38245, 38246, 38247, 42618, 63310, 38966);
DELETE FROM `smart_scripts`
WHERE `source_type` = 0
  AND `entryorguid` IN (38037, 38242, 38243, 38244, 38245, 38246, 38247, 42618, 63310, 38966, 38938, 38953);

-- ============================================================================
-- Overhaul fixes
-- ============================================================================

-- Script bindings, spell-script hooks and the static data the new C++ in
-- src/server/scripts/Kalimdor/zone_echo_isles.cpp relies on. Every value is
-- from retail 12.1.0 sniffs, the 8.3.7 DB2s or the broadcast_text table.

-- ---------------------------------------------------------------------------
-- Intro Zuni: "Summon Zuni (Lvl 1)" (91404) on entering the zone, and the
-- "Zuni Lvl 1 Trigger" (71037) cue fired by Jin'thala's tracking spell.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_script_names` WHERE `spell_id` IN (91404, 93342, 71037);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
    (91404, 'spell_echo_isles_summon_zuni_lvl_1'),
    (93342, 'spell_echo_isles_zuni_lvl_1_trigger_aura'),
    (71037, 'spell_echo_isles_zuni_lvl_1_trigger');

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 13
  AND `SourceEntry` IN (91404, 71037);
INSERT INTO `conditions`
    (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
     `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
     `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
    (13, 1, 91404, 0, 0, 51, 0, 5, 37951, 0, 0, 0, 0, '', 'Summon Zuni (Lvl 1) - next to Jin''thala'),
    (13, 1, 71037, 0, 0, 51, 0, 5, 37988, 0, 0, 0, 0, '', 'Zuni Lvl 1 Trigger - hit Zuni');

-- ---------------------------------------------------------------------------
-- Tiki Targets, class trainers, Vol'jin's vision.
-- ---------------------------------------------------------------------------

UPDATE `creature_template` SET `ScriptName` = 'npc_echo_isles_class_trainer'
WHERE `entry` IN (38037, 38242, 38243, 38244, 38245, 38246, 38247, 42618, 63310);
UPDATE `creature_template` SET `ScriptName` = 'npc_voljin_darkspear_hold' WHERE `entry` = 38966;
-- The visions only talk; they must never pick a fight (Garrosh's is hostile).
UPDATE `creature_template` SET `AIName` = 'PassiveAI' WHERE `entry` IN (38938, 38953);

DELETE FROM `creature_text` WHERE `CreatureID` IN (38966, 38938, 38953);
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
VALUES
    (38966, 0, 0, 'I have sometin'' to show ya. It be easier to understand if ya see it yourself.', 12, 0, 100, 1, 0, 20097, 38892, 0, 'Vol''jin - More Than Expected turned in'),
    (38966, 1, 0, 'Tha Darkspear are ''ere because I led dem here.  Orgrimmar be no home as long as it be under Hellscream''s hand.', 12, 0, 100, 1, 0, 20105, 42869, 0, 'Vol''jin - After the vision'),
    (38966, 2, 0, 'Still, I fear I was lettin'' my temper drive me ta bein'' rash. Thrall devoted himself to makin'' the Horde what it is, so I''ve no eagerness to be leavin'' it on a whim.  Dis will be needin'' much more thought.', 12, 0, 100, 1, 0, 20106, 42870, 0, 'Vol''jin - After the vision'),
    (38966, 3, 0, 'But dese be worries for older minds.  Ya still have much to learn.  Go help tha people of tha Darkspear.  I am sure we''ll be speakin'' again real soon.', 12, 0, 100, 1, 0, 20107, 43774, 0, 'Vol''jin - After the vision'),
    (38938, 0, 0, 'Don''t talk back to me, troll.  You know who was left in charge here.  Haven''t you stopped to ask yourself why Thrall chose me instead of you?', 12, 0, 100, 25, 0, 20508, 38897, 0, 'Vision of Garrosh'),
    (38938, 1, 0, 'You are lucky that I don''t gut you right here, whelp.  You are foolish to think that you can speak to your Warchief in such ways.', 12, 0, 100, 5, 0, 20512, 38903, 0, 'Vision of Garrosh'),
    (38938, 2, 0, 'And what exactly do you think that you are going to do about it?  Your threats are hollow.  Go slink away with the rest of your kind to the slums, I will endure your filth in my throne room no longer.', 12, 0, 100, 1, 0, 20509, 38904, 0, 'Vision of Garrosh'),
    (38938, 3, 0, 'You have sealed your fate, troll.', 12, 0, 100, 1, 0, 20510, 38901, 0, 'Vision of Garrosh'),
    (38938, 4, 0, '%s spits at Vol''jin''s feet.', 16, 0, 100, 0, 0, 0, 38906, 0, 'Vision of Garrosh'),
    (38953, 0, 0, 'Dere be no question why, Garrosh.  He gave ya tha title because ya be Grom''s son and because tha people be wantin'' a war hero.', 12, 0, 100, 5, 0, 20098, 38898, 0, 'Vision of Vol''jin'),
    (38953, 1, 0, 'I tink ya be even more like ya father den ya thought, even witout da demon blood.', 12, 0, 100, 1, 0, 20099, 43773, 0, 'Vision of Vol''jin'),
    (38953, 2, 0, 'Ya be no Warchief of mine.  Ya not earned my respect and I''ll not be seein'' tha Horde destroyed by ya foolish thirst for war.', 12, 0, 100, 1, 0, 20100, 38899, 0, 'Vision of Vol''jin'),
    (38953, 3, 0, 'I know exactly what I''ll be doin'' about it, son of Hellscream.  I''ll watch and wait as ya people slowly become aware of ya ineptitude.  I''ll laugh as dey grow ta despise ya as I do.', 12, 0, 100, 1, 0, 20101, 38900, 0, 'Vision of Vol''jin'),
    (38953, 4, 0, 'And when tha time comes dat ya failure is complete and ya "power" is meaningless, I will be dere to end ya rule swiftly and silently.', 12, 0, 100, 1, 0, 20102, 38905, 0, 'Vision of Vol''jin'),
    (38953, 5, 0, 'Ya will spend ya reign glancin'' over ya shoulda and fearin'' tha shadows, for when tha time comes and ya blood be slowly drainin'' out, ya will know exactly who fired tha arrow dat pierced ya black heart.', 12, 0, 100, 1, 0, 20103, 38944, 0, 'Vision of Vol''jin'),
    (38953, 6, 0, 'And you yours, "Warchief."', 12, 0, 100, 1, 0, 20104, 38947, 0, 'Vision of Vol''jin');

-- Recorded retail routes replayed as splines by the scripts:
--   3798800         intro Zuni to the training grounds
--   3906200/01      south Proving Pit Jailor to the cage / back
--   3906202/03      north Proving Pit Jailor to the cage / back
--   <trainer>00/01  each class trainer to the pit (last node = facing) / home
DELETE FROM `waypoint_data`
WHERE `id` IN (3798800, 3906200, 3906201, 3906202, 3906203,
               3803700, 3803701, 3824200, 3824201, 3824300, 3824301, 3824400, 3824401,
               3824500, 3824501, 3824600, 3824601, 3824700, 3824701, 6331000, 6331001,
               4261800, 4261801);
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`) VALUES
    (3798800, 1, -1173.1345, -5281.4766, 1.5589, 0.0000, 0),
    (3798800, 2, -1173.1345, -5283.2266, 1.5589, 0.0000, 0),
    (3798800, 3, -1173.0981, -5286.5050, 1.7540, 0.0000, 0),
    (3798800, 4, -1173.0981, -5288.5050, 2.2540, 0.0000, 0),
    (3798800, 5, -1173.0981, -5290.5050, 2.7540, 0.0000, 0),
    (3798800, 6, -1172.8481, -5291.5050, 3.0040, 0.0000, 0),
    (3798800, 7, -1172.8481, -5293.5050, 3.5040, 0.0000, 0),
    (3798800, 8, -1172.8481, -5296.5050, 4.5040, 0.0000, 0),
    (3798800, 9, -1172.8481, -5299.0050, 5.5040, 0.0000, 0),
    (3798800, 10, -1173.5981, -5301.0050, 6.2540, 0.0000, 0),
    (3798800, 11, -1174.5981, -5303.7550, 7.5040, 0.0000, 0),
    (3798800, 12, -1174.8481, -5304.5050, 7.5040, 0.0000, 0),
    (3798800, 13, -1175.0981, -5305.0050, 7.5040, 0.0000, 0),
    (3798800, 14, -1175.3481, -5307.7550, 8.7540, 0.0000, 0),
    (3798800, 15, -1175.3481, -5310.7550, 9.7540, 0.0000, 0),
    (3798800, 16, -1175.5981, -5313.7550, 10.7540, 0.0000, 0),
    (3798800, 17, -1175.8481, -5315.7550, 11.2540, 0.0000, 0),
    (3798800, 18, -1175.8481, -5316.5050, 11.7540, 0.0000, 0),
    (3798800, 19, -1176.5981, -5318.2550, 12.0040, 0.0000, 0),
    (3798800, 20, -1176.8481, -5318.5050, 12.2540, 0.0000, 0),
    (3798800, 21, -1176.8481, -5320.5050, 12.5040, 0.0000, 0),
    (3798800, 22, -1176.3075, -5321.9717, 13.2579, 0.0000, 0),
    (3798800, 23, -1176.3075, -5322.9717, 13.5079, 0.0000, 0),
    (3798800, 24, -1175.8075, -5324.9717, 13.7579, 0.0000, 0),
    (3798800, 25, -1175.8075, -5326.7217, 14.0079, 0.0000, 0),
    (3798800, 26, -1176.3075, -5327.7217, 14.0079, 0.0000, 0),
    (3798800, 27, -1175.8075, -5329.7217, 14.2579, 0.0000, 0),
    (3798800, 28, -1175.5575, -5331.7217, 14.5079, 0.0000, 0),
    (3798800, 29, -1174.8075, -5332.9717, 14.7579, 0.0000, 0),
    (3798800, 30, -1174.0575, -5335.9717, 15.0079, 0.0000, 0),
    (3798800, 31, -1173.3075, -5337.7217, 15.2579, 0.0000, 0),
    (3798800, 32, -1171.8567, -5340.8870, 15.3808, 0.0000, 0),
    (3798800, 33, -1171.6067, -5341.6370, 15.3808, 0.0000, 0),
    (3798800, 34, -1172.1067, -5343.6370, 15.3808, 0.0000, 0),
    (3798800, 35, -1172.6067, -5344.6370, 15.3808, 0.0000, 0),
    (3798800, 36, -1171.6067, -5344.8870, 15.3808, 0.0000, 0),
    (3798800, 37, -1171.1067, -5345.8870, 15.3808, 0.0000, 0),
    (3798800, 38, -1170.8567, -5350.8870, 15.3808, 0.0000, 0),
    (3798800, 39, -1170.8567, -5352.8870, 14.8808, 0.0000, 0),
    (3798800, 40, -1166.5176, -5366.6840, 14.5271, 0.0000, 0),
    (3798800, 41, -1165.0176, -5369.1840, 14.2771, 0.0000, 0),
    (3798800, 42, -1164.5176, -5369.4340, 14.2771, 0.0000, 0),
    (3798800, 43, -1164.5176, -5371.4340, 14.0271, 0.0000, 0),
    (3798800, 44, -1164.0176, -5374.4340, 13.0271, 0.0000, 0),
    (3798800, 45, -1164.0176, -5375.1840, 12.7771, 0.0000, 0),
    (3798800, 46, -1163.7676, -5377.1840, 12.5271, 0.0000, 0),
    (3798800, 47, -1162.0435, -5391.7466, 12.0032, 0.0000, 0),
    (3803700, 1, -1167.4033, -5434.6855, 12.5818, 0.0000, 0),
    (3803700, 2, -1166.1533, -5432.9355, 12.5818, 0.0000, 0),
    (3803700, 3, -1164.9033, -5430.6855, 12.8318, 0.0000, 0),
    (3803700, 4, -1163.9033, -5428.9355, 12.8318, 0.0000, 0),
    (3803700, 5, -1162.1533, -5426.4355, 13.3318, 0.0000, 0),
    (3803700, 6, -1160.1533, -5422.9355, 13.3318, 0.0000, 0),
    (3803700, 7, -1158.9900, -5421.1400, 13.2190, 0.2094, 0),
    (3803701, 1, -1160.1533, -5422.9355, 13.3318, 0.0000, 0),
    (3803701, 2, -1162.1533, -5426.4355, 13.3318, 0.0000, 0),
    (3803701, 3, -1163.9033, -5428.9355, 12.8318, 0.0000, 0),
    (3803701, 4, -1164.9033, -5430.6855, 12.8318, 0.0000, 0),
    (3803701, 5, -1166.1533, -5432.9355, 12.5818, 0.0000, 0),
    (3803701, 6, -1167.4033, -5434.6855, 12.5818, 0.0000, 0),
    (3803701, 7, -1171.3500, -5440.7900, 12.0421, 5.3058, 0),
    (3824200, 1, -1157.7177, -5399.3730, 12.7475, 0.0000, 0),
    (3824200, 2, -1156.4677, -5401.1230, 12.9975, 0.0000, 0),
    (3824200, 3, -1155.7177, -5402.3730, 13.2475, 0.0000, 0),
    (3824200, 4, -1154.9677, -5403.3730, 13.2475, 0.0000, 0),
    (3824200, 5, -1152.2200, -5407.6000, 13.2634, 4.9044, 0),
    (3824201, 1, -1154.9677, -5403.3730, 13.2475, 0.0000, 0),
    (3824201, 2, -1155.7177, -5402.3730, 13.2475, 0.0000, 0),
    (3824201, 3, -1156.4677, -5401.1230, 12.9975, 0.0000, 0),
    (3824201, 4, -1157.7177, -5399.3730, 12.7475, 0.0000, 0),
    (3824201, 5, -1160.2100, -5396.1500, 12.3103, 2.8798, 0),
    (3824300, 1, -1158.8100, -5533.0800, 11.9392, 0.3142, 0),
    (3824301, 1, -1175.7500, -5540.4600, 12.0612, 4.7473, 0),
    (3824400, 1, -1131.3159, -5442.2603, 12.5388, 0.0000, 0),
    (3824400, 2, -1135.3159, -5439.0103, 12.7888, 0.0000, 0),
    (3824400, 3, -1137.3159, -5437.5103, 12.7888, 0.0000, 0),
    (3824400, 4, -1138.8159, -5436.2603, 13.0388, 0.0000, 0),
    (3824400, 5, -1140.3159, -5435.0103, 13.5388, 0.0000, 0),
    (3824400, 6, -1141.0659, -5434.2603, 13.7888, 0.0000, 0),
    (3824400, 7, -1146.6700, -5430.0500, 13.5963, 1.4835, 0),
    (3824401, 1, -1141.0659, -5434.2603, 13.7888, 0.0000, 0),
    (3824401, 2, -1140.3159, -5435.0103, 13.5388, 0.0000, 0),
    (3824401, 3, -1138.8159, -5436.2603, 13.0388, 0.0000, 0),
    (3824401, 4, -1137.3159, -5437.5103, 12.7888, 0.0000, 0),
    (3824401, 5, -1135.3159, -5439.0103, 12.7888, 0.0000, 0),
    (3824401, 6, -1131.3159, -5442.2603, 12.5388, 0.0000, 0),
    (3824401, 7, -1125.9600, -5446.9700, 12.0594, 0.2269, 0),
    (3824500, 1, -1137.0000, -5528.2300, 11.9798, 3.1765, 0),
    (3824501, 1, -1118.1600, -5539.9600, 12.0580, 6.1610, 0),
    (3824600, 1, -1146.9655, -5547.5020, 12.2118, 0.0000, 0),
    (3824600, 2, -1146.4655, -5545.5020, 12.4618, 0.0000, 0),
    (3824600, 3, -1145.9500, -5543.1300, 12.4886, 1.7279, 0),
    (3824601, 1, -1146.4655, -5545.5020, 12.4618, 0.0000, 0),
    (3824601, 2, -1146.9655, -5547.5020, 12.2118, 0.0000, 0),
    (3824601, 3, -1151.9100, -5569.5600, 12.0630, 4.3110, 0),
    (3824700, 1, -1131.5381, -5516.0986, 12.2390, 0.0000, 0),
    (3824700, 2, -1136.4600, -5525.1300, 11.9967, 3.3161, 0),
    (3824701, 1, -1131.5381, -5516.0986, 12.2390, 0.0000, 0),
    (3824701, 2, -1128.1200, -5510.0700, 12.0599, 0.0175, 0),
    (3906200, 1, -1158.1545, -5524.8184, 12.2297, 0.0000, 0),
    (3906200, 2, -1156.1545, -5519.3184, 12.2297, 0.0000, 0),
    (3906200, 3, -1154.1545, -5518.8184, 12.2297, 0.0000, 0),
    (3906200, 4, -1153.5295, -5518.6094, 12.0057, 0.0000, 0),
    (3906201, 1, -1154.1545, -5518.8184, 12.2297, 0.0000, 0),
    (3906201, 2, -1154.6545, -5519.5684, 12.2297, 0.0000, 0),
    (3906201, 3, -1156.4045, -5521.3184, 12.2297, 0.0000, 0),
    (3906201, 4, -1156.4045, -5522.0684, 12.7297, 0.0000, 0),
    (3906201, 5, -1156.9045, -5522.3184, 12.4797, 0.0000, 0),
    (3906201, 6, -1157.6545, -5524.3184, 12.2297, 0.0000, 0),
    (3906201, 7, -1157.9045, -5525.3184, 11.9797, 0.0000, 0),
    (3906201, 8, -1158.4045, -5527.0684, 12.2297, 0.0000, 0),
    (3906201, 9, -1159.2795, -5530.0280, 11.9538, 0.0000, 0),
    (3906202, 1, -1141.5304, -5431.1104, 14.0663, 0.0000, 0),
    (3906202, 2, -1139.0304, -5428.8604, 14.0663, 0.0000, 0),
    (3906202, 3, -1138.5304, -5427.8604, 14.0663, 0.0000, 0),
    (3906202, 4, -1138.0304, -5426.8604, 13.8163, 0.0000, 0),
    (3906202, 5, -1138.0304, -5425.8604, 13.8163, 0.0000, 0),
    (3906202, 6, -1137.5304, -5424.8604, 13.8163, 0.0000, 0),
    (3906202, 7, -1136.5304, -5424.3604, 13.8163, 0.0000, 0),
    (3906202, 8, -1137.0304, -5423.6104, 13.8163, 0.0000, 0),
    (3906202, 9, -1136.5304, -5421.1104, 13.5663, 0.0000, 0),
    (3906202, 10, -1135.8698, -5416.7570, 13.2690, 0.0000, 0),
    (3906203, 1, -1136.5938, -5422.6720, 13.4854, 0.0000, 0),
    (3906203, 2, -1137.3093, -5428.8500, 13.7445, 0.0000, 0),
    (3906203, 3, -1140.0593, -5429.3500, 13.9945, 0.0000, 0),
    (3906203, 4, -1143.1910, -5429.9634, 13.8636, 0.0000, 0),
    (6331000, 1, -1149.7153, -5439.0557, 12.6691, 0.0000, 0),
    (6331000, 2, -1150.2153, -5437.0557, 12.6691, 0.0000, 0),
    (6331000, 3, -1150.4653, -5435.3057, 13.1691, 0.0000, 0),
    (6331000, 4, -1150.7153, -5432.3057, 13.4191, 0.0000, 0),
    (6331000, 5, -1151.5400, -5429.8600, 13.2918, 1.2566, 0),
    (6331001, 1, -1150.7153, -5432.3057, 13.4191, 0.0000, 0),
    (6331001, 2, -1150.4653, -5435.3057, 13.1691, 0.0000, 0),
    (6331001, 3, -1150.2153, -5437.0557, 12.6691, 0.0000, 0),
    (6331001, 4, -1149.7153, -5439.0557, 12.6691, 0.0000, 0),
    (6331001, 5, -1149.3900, -5441.2500, 12.0429, 0.0860, 0),
    (4261800, 1, -1128.4678, -5396.4670, 12.7220, 0.0000, 0),
    (4261800, 2, -1129.4678, -5396.9670, 12.7220, 0.0000, 0),
    (4261800, 3, -1131.2178, -5397.9670, 12.7220, 0.0000, 0),
    (4261800, 4, -1136.4678, -5400.7170, 12.9720, 0.0000, 0),
    (4261800, 5, -1140.7178, -5402.7170, 12.9720, 0.0000, 0),
    (4261800, 6, -1142.4678, -5403.4670, 13.2220, 0.0000, 0),
    (4261800, 7, -1149.9200, -5407.4600, 13.2400, 4.9600, 0),
    (4261801, 1, -1142.4678, -5403.4670, 13.2220, 0.0000, 0),
    (4261801, 2, -1140.7178, -5402.7170, 12.9720, 0.0000, 0),
    (4261801, 3, -1136.4678, -5400.7170, 12.9720, 0.0000, 0),
    (4261801, 4, -1131.2178, -5397.9670, 12.7220, 0.0000, 0),
    (4261801, 5, -1129.4678, -5396.9670, 12.7220, 0.0000, 0),
    (4261801, 6, -1128.4678, -5396.4670, 12.7220, 0.0000, 0),
    (4261801, 7, -1126.5200, -5395.4700, 12.3099, 5.9167, 0);

-- ---------------------------------------------------------------------------
-- World Swiftclaw (37989) runs the same circuit as the personal one.
-- ---------------------------------------------------------------------------

UPDATE `creature` SET `MovementType` = 2 WHERE `id` = 37989;
INSERT INTO `creature_addon` (`guid`, `path_id`)
SELECT `guid`, 3800200 FROM `creature` WHERE `id` = 37989
ON DUPLICATE KEY UPDATE `path_id` = 3800200;

-- ---------------------------------------------------------------------------
-- Gameobject flags (retail): quest objects are only usable while a quest
-- needs them, the mailbox works. The Darkspear Cage (201968) is locked on
-- retail; 8.3.7 still offers the use cursor on a locked goober, so it is
-- also unselectable (GO_FLAG_LOCKED 0x02 | GO_FLAG_NOT_SELECTABLE 0x10).
-- ---------------------------------------------------------------------------

INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`) VALUES
    (201905, 0, 4),
    (201968, 0, 18),
    (202113, 0, 65536),
    (202215, 0, 4),
    (202216, 0, 4),
    (202217, 0, 4),
    (202589, 0, 0),
    (205076, 0, 4)
ON DUPLICATE KEY UPDATE `flags` = VALUES(`flags`);

-- ---------------------------------------------------------------------------
-- Quest texts: retail wording. Several enUS rows held Russian text, the
-- class reward texts were one copy for every class, and some were missing.
-- ---------------------------------------------------------------------------

INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
    (24607, 'Anotha newblood, eh?$B$BYa actually look ta be in shape though. Steady hands. Fierce eyes. I may be able ta turn ya into a real $c.$B$BLets not waste anymore time ''den.', 35662),
    (24623, 'Thank ya so much! They can be vicious when provoked, but most of da time dey don''t know betta.', 35662),
    (24624, 'Thank you, $c.$B$BIt will be takin'' brave and determined people like you ta drive da Darkspear up again. I hope dere are more people even half as dedicated to come.', 35662),
    (24625, 'Well done, $n! Dis naga has set us back quite some time, but nothin'' will be holdin'' us down foreva.$B$BIt''s good ta be havin'' ya wit us, $n. Ya have a fierce heart within ya.', 35662),
    (24626, 'Swiftclaw! Kijara was tellin'' me about him and he sounded like he''d be a handful. I don''t mind da challenge - it''s da spirited ones like dat that be makin'' da bravest and truest companions when real times of need be comin''.$B$BTank ya, hon. Ya''ve been very helpful.', 35662),
    (24750, 'Anotha newblood, eh?$B$BYa actually have an intense look about ya though. Fiery eyes. You might have the makings of a real $c.$B$BLets not waste anymore time ''den.', 35662),
    (24751, 'Not bad, mon. Ya have a natural flow to ya spells - you may have a talent for dis.$B$BSome rough edges ta be sure, but we''ll get dose ironed out here and I''ll teach ya a few new tings as we go.', 35662),
    (24758, 'Anotha newblood, eh?$B$BYa actually have a weathered look about ya though. Wise eyes. You might have the makings of a real $c.$B$BLets not waste anymore time ''den.', 35662),
    (24759, 'Not bad, mon. Ya have a natural flow to ya spells - you may have a talent for dis.$B$BSome rough edges ta be sure, but we''ll get dose ironed out here and I''ll teach ya a few new tings as we go.', 35662),
    (24782, 'Anotha newblood, eh?$B$BYa actually have a balanced look about ya though. Calm eyes. You might have the makings of a real $c.$B$BLets not waste anymore time ''den.', 35662),
    (24783, 'Not bad, mon. Ya have a natural flow to ya spells - you may have a talent for dis.$B$BSome rough edges ta be sure, but we''ll get dose ironed out here and I''ll teach ya a few new tings as we go.', 35662),
    (24812, 'Well fought, young $r.', 35662),
    (24813, 'Dat should keep dem at bay.', 35662),
    (24814, 'Tha power dat burst forth when tha Sea Witch died was immense. I can use dis power ta enact a vision of places far away.$B$BObserve, youngblood. I want ya ta be here when I make contact wit'' Thrall, perhaps it will be grantin'' ya insight as well.', 35662),
    (25035, 'Good to have ya, $G brotha:sista;.$B$BVol''jin makes us all proud in dese moments. It feels good ta be tacklin'' threats head on.', 35662),
    (25073, 'Welcome, young $r.$B$BYa come highly recommended, mon. It''s nice ta finally be meetin'' ya in person.', 35662),
    (31158, 'Not bad, mon. Ya have a natural flow to ya punches - you may have a talent for dis.$B$BSome rough edges ta be sure, but we''ll get dose ironed out here and I''ll teach ya a few new tings as we go.', 35662),
    (31159, 'Anotha newblood, eh?$B$BYa actually look ta be in shape though. Steady hands. Fierce eyes. I may be able ta turn ya into a real $c.$B$BLets not waste anymore time ''den.', 35662),
    (31160, 'Dese are some fine pelts, $G boy:girl;. We could make some hefty cloaks outta dese.', 35662),
    (31161, 'Ya handle yerself quite well. Ya gonna be quite powerful some day.', 35662)
ON DUPLICATE KEY UPDATE `RewardText` = VALUES(`RewardText`);
INSERT INTO `quest_request_items` (`ID`, `CompletionText`, `VerifiedBuild`) VALUES
    (24761, 'I doubt dey too much of a challenge, mon, but they''ll still claw up ya ankles if ya don''t stay quick footed.', 35662),
    (24773, 'I doubt dey too much of a challenge, mon, but they''ll still claw up ya ankles if ya don''t stay quick footed.', 35662),
    (24785, 'I doubt dey too much of a challenge, mon, but they''ll still claw up ya ankles if ya don''t stay quick footed.', 35662),
    (31160, 'I doubt dey too much of a challenge, mon, but they''ll still claw up ya ankles if ya don''t stay quick footed.', 35662)
ON DUPLICATE KEY UPDATE `CompletionText` = VALUES(`CompletionText`);

-- ---------------------------------------------------------------------------
-- Quest POIs missing from the 8.3.7 initialization dump. The points below are
-- retail 12.1.0 SMSG_QUEST_POI_QUERY_RESPONSE values. 24782 is folded in from
-- the one-time priest POI update so this rework is complete on a fresh DB.
-- ---------------------------------------------------------------------------

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (24639, 24771, 24782, 25035);
DELETE FROM `quest_poi`        WHERE `QuestID` IN (24639, 24771, 24782, 25035);

INSERT INTO `quest_poi`
    (`QuestID`, `BlobIndex`, `Idx1`, `ObjectiveIndex`, `QuestObjectiveID`, `QuestObjectID`, `MapID`, `UiMapID`,
     `Priority`, `Flags`, `WorldEffectID`, `PlayerConditionID`, `SpawnTrackingID`, `AlwaysAllowMergingBlobs`, `VerifiedBuild`)
VALUES
    -- 24639 - The Basics: Hitting Things (warrior)
    (24639, 0, 0, -1,      0,     0, 1, 463, 0, 0, 0, 0,      0, 0, 35662),
    (24639, 0, 1,  0, 265453, 38038, 1, 463, 0, 0, 0, 0,      0, 0, 35662),
    (24639, 0, 2, 32,      0,     0, 1,  12, 0, 2, 0, 0,      0, 0, 35662),
    (24639, 1, 3, 32,      0,     0, 1, 463, 0, 0, 0, 0, 343382, 0, 35662),

    -- 24771 - The Basics: Hitting Things (rogue)
    (24771, 0, 0, -1,      0,     0, 1, 463, 0, 0, 0, 0,      0, 0, 35662),
    (24771, 0, 1,  0, 265466, 38038, 1, 463, 0, 0, 0, 0,      0, 0, 35662),
    (24771, 0, 2, 32,      0,     0, 1,  12, 0, 2, 0, 0,      0, 0, 35662),
    (24771, 1, 3, 32,      0,     0, 1, 463, 0, 0, 0, 0, 345558, 0, 35662),

    -- 24782 - The Rise of the Darkspear (priest)
    (24782, 0, 0, -1, 0, 0, 1, 463, 0, 0, 0, 0,      0, 0, 35662),
    (24782, 0, 1, 32, 0, 0, 1,  12, 0, 2, 0, 0,      0, 0, 35662),
    (24782, 1, 2, 32, 0, 0, 1, 463, 0, 0, 0, 0, 342252, 0, 35662),

    -- 25035 - Breaking the Line
    (25035, 0, 0, -1, 0, 0, 1, 463, 0, 2, 0, 0, 0, 0, 35662),
    (25035, 0, 1, 32, 0, 0, 1,  12, 0, 2, 0, 0, 0, 0, 35662),
    (25035, 1, 2, 32, 0, 0, 1, 463, 0, 2, 0, 0, 0, 0, 35662);

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
    (24639, 0,  0, -1171, -5441, 35662),
    (24639, 1,  0, -1155, -5595, 35662),
    (24639, 1,  1, -1125, -5593, 35662),
    (24639, 1,  2, -1120, -5590, 35662),
    (24639, 1,  3, -1102, -5565, 35662),
    (24639, 1,  4, -1095, -5510, 35662),
    (24639, 1,  5, -1101, -5446, 35662),
    (24639, 1,  6, -1109, -5397, 35662),
    (24639, 1,  7, -1150, -5384, 35662),
    (24639, 1,  8, -1177, -5388, 35662),
    (24639, 1,  9, -1200, -5407, 35662),
    (24639, 1, 10, -1193, -5525, 35662),
    (24639, 1, 11, -1168, -5586, 35662),
    (24639, 2,  0, -1171, -5440, 35662),
    (24639, 3,  0, -1171, -5441, 35662),

    (24771, 0,  0, -1126, -5447, 35662),
    (24771, 1,  0, -1155, -5595, 35662),
    (24771, 1,  1, -1125, -5593, 35662),
    (24771, 1,  2, -1120, -5590, 35662),
    (24771, 1,  3, -1102, -5565, 35662),
    (24771, 1,  4, -1095, -5510, 35662),
    (24771, 1,  5, -1101, -5446, 35662),
    (24771, 1,  6, -1109, -5397, 35662),
    (24771, 1,  7, -1150, -5384, 35662),
    (24771, 1,  8, -1177, -5388, 35662),
    (24771, 1,  9, -1200, -5407, 35662),
    (24771, 1, 10, -1193, -5525, 35662),
    (24771, 1, 11, -1168, -5586, 35662),
    (24771, 2,  0, -1125, -5446, 35662),
    (24771, 3,  0, -1126, -5447, 35662),

    (24782, 0, 0, -1118, -5540, 35662),
    (24782, 1, 0, -1168, -5265, 35662),
    (24782, 2, 0, -1168, -5265, 35662),

    (25035, 0, 0,  -802, -5555, 35662),
    (25035, 1, 0, -1329, -5555, 35662),
    (25035, 2, 0, -1329, -5556, 35662);

-- ============================================================================
-- Visibility states: Darkspear Hold before/after 24626 and 24814
-- ============================================================================

-- Retail does this with generic quest invisibility, not phase IDs: the
-- player is given a "See Quest Invis" aura per area and quest state, and
-- NPCs carry the matching "Generic Quest Invisibility" aura. Sniffed on
-- retail 12.1.0:
--   * Darkspear Isle, Training Grounds, Darkspear Hold (4875, 4865, 4866):
--     73147 (detects type 7) always; 73206 (type 4) before 24626 is taken;
--     73205 (type 9) from the moment it is taken.
--   * Bloodtalon Shore (4863): 49416 (type 7) only while 24622 is in progress.
-- spell_area.quest_start_status is a mask of allowed QuestStatus values:
-- 1 = NONE, 2 = COMPLETE, 8 = INCOMPLETE, 32 = FAILED, 64 = REWARDED.

-- After the Sea Witch (24814 complete) the Hold returns to its first layout
-- (73206) and shows the Thrall vision (73148, detects 49415); 73147 and
-- 73205 end there (quest_end_status 41 = NONE | INCOMPLETE | FAILED).
DELETE FROM `spell_area` WHERE `spell` IN (73147, 73148, 73205, 73206) AND `area` IN (4865, 4866, 4875);
DELETE FROM `spell_area` WHERE `spell` = 49416 AND `area` = 4863;
INSERT INTO `spell_area` (`spell`, `area`, `quest_start`, `quest_end`, `aura_spell`, `teamId`, `racemask`, `gender`, `flags`, `quest_start_status`, `quest_end_status`) VALUES
    (73147, 4865,     0, 24814, 0, -1, 0, 2, 3,  0, 41),
    (73147, 4866,     0, 24814, 0, -1, 0, 2, 3,  0, 41),
    (73147, 4875,     0, 24814, 0, -1, 0, 2, 3,  0, 41),
    (73206, 4865, 24626,     0, 0, -1, 0, 2, 3,  1,  0),
    (73206, 4866, 24626,     0, 0, -1, 0, 2, 3,  1,  0),
    (73206, 4875, 24626,     0, 0, -1, 0, 2, 3,  1,  0),
    (73205, 4865, 24626, 24814, 0, -1, 0, 2, 3, 74, 41),
    (73205, 4866, 24626, 24814, 0, -1, 0, 2, 3, 74, 41),
    (73205, 4875, 24626, 24814, 0, -1, 0, 2, 3, 74, 41),
    (73206, 4865, 24814,     0, 0, -1, 0, 2, 3, 66,  0),
    (73206, 4866, 24814,     0, 0, -1, 0, 2, 3, 66,  0),
    (73206, 4875, 24814,     0, 0, -1, 0, 2, 3, 66,  0),
    (73148, 4865, 24814,     0, 0, -1, 0, 2, 3, 66,  0),
    (73148, 4866, 24814,     0, 0, -1, 0, 2, 3, 66,  0),
    (73148, 4875, 24814,     0, 0, -1, 0, 2, 3, 66,  0),
    (49416, 4863, 24622,     0, 0, -1, 0, 2, 3, 10,  0);

-- Darkspear Hold before 24626: Tortunga, Jornun and Vanira in their first
-- places, Morakki on his rounds (his addon already carries 65017).
UPDATE `creature_addon` SET `auras` = '65017' WHERE `guid` IN (10591708, 251556, 251702);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`)
SELECT c.`guid`, 0, a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`, a.`aiAnimKit`, a.`movementAnimKit`, a.`meleeAnimKit`, a.`visibilityDistanceType`, '65017'
FROM `creature` c
JOIN `creature_template_addon` a ON a.`entry` = c.`id`
LEFT JOIN `creature_addon` ca ON ca.`guid` = c.`guid`
WHERE c.`guid` IN (10591708, 251556, 251702) AND ca.`guid` IS NULL;

-- Darkspear Hold after 24626: the same three at their new spots (copied
-- from the pre-state spawn so every other column matches), Zuni (38931)
-- and the mounted Watchers (39028, already spawned, template aura 60921).
DELETE FROM `creature` WHERE `guid` IN (10700000, 10700001, 10700002);
DELETE FROM `creature_addon` WHERE `guid` IN (10700000, 10700001, 10700002);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`)
SELECT 10700000, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, -1329.8906, -5556.5815, 21.55126, 4.276057, `spawntimesecs`, 0, 0, `curhealth`, `curmana`, 0, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild` FROM `creature` WHERE `guid` = 10591708;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`)
SELECT 10700001, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, -1330.8368, -5558.896, 21.48784, 1.031499, `spawntimesecs`, 0, 0, `curhealth`, `curmana`, 0, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild` FROM `creature` WHERE `guid` = 251556;
-- Vanira paces between two spots (path 3902700, see the ambience migration).
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`)
SELECT 10700002, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, -1317.8993, -5539.1963, 20.964787, 2.199115, `spawntimesecs`, 0, 0, `curhealth`, `curmana`, 2, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild` FROM `creature` WHERE `guid` = 251702;

INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`)
SELECT c.`guid`, IF(c.`guid` = 10700002, 3902700, 0), a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`, a.`aiAnimKit`, a.`movementAnimKit`, a.`meleeAnimKit`, a.`visibilityDistanceType`, '60921'
FROM `creature` c
JOIN `creature_template_addon` a ON a.`entry` = c.`id`
WHERE c.`guid` IN (10700000, 10700001, 10700002);

UPDATE `creature_addon` SET `auras` = '60921' WHERE `guid` = 210115897;

-- World Swiftclaw (37989): a plain creature on retail, not a vehicle, and
-- visible only through 49416 at Bloodtalon Shore; a player on 24626 sees
-- only the personal Swiftclaw (38002).
UPDATE `creature_template` SET `VehicleId` = 0, `unit_flags` = 32768 WHERE `entry` = 37989;
UPDATE `creature_addon` SET `auras` = '49414' WHERE `guid` = 10583484;

-- Vol'jin's visions: retail VisFlags 1 (bytes1 byte 2).
UPDATE `creature_template_addon` SET `bytes1` = 65536 WHERE `entry` IN (38938, 38953);

-- ============================================================================
-- Ambient life and retail audit
-- ============================================================================

-- All paths, pauses and facings are the retail 12.1.0 sniff values.

-- Scripted creatures. Their old SmartAI rows (Naj'tess' casts) move into
-- the C++ AI; the others had none. The novices' bindings are in the
-- hybrid pass 2 section.
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (39072, 63309);
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_najtess'          WHERE `entry` = 39072;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_tsu_the_wanderer' WHERE `entry` = 63309;

-- Novices: retail's tiki-training faction (hostile to the tikis' faction 7
-- only) and they stand at their dummy.
UPDATE `creature_template` SET `faction` = 2215 WHERE `entry` IN (38268, 38272, 38278, 38279, 38280, 38281, 38282, 42619);
UPDATE `creature` SET `MovementType` = 0, `spawndist` = 0 WHERE `id` IN (38268, 38272, 38278, 38279, 38280, 38281, 38282, 42619);

-- Naj'tess wanders from C++ now (her AI stops the wander to channel).
UPDATE `creature` SET `MovementType` = 0, `spawndist` = 0 WHERE `id` = 39072;

-- Ardsami: "Read Scroll" only while at the mailbox, not permanently.
UPDATE `creature_template` SET `unit_flags` = 33024 WHERE `entry` = 90113;
UPDATE `creature_template_addon` SET `auras` = '' WHERE `entry` = 90113;
UPDATE `creature_addon` SET `auras` = '' WHERE `guid` = 210115506;

-- Tsu and Zabrax spar in the monk ready stance (EMOTE_STATE_MONKOFFENSE_READYUNARMED).
UPDATE `creature_template_addon` SET `emote` = 510 WHERE `entry` IN (63309, 63310);

-- Retail unit flags (runtime combat/PvP bits excluded).
UPDATE `creature_template` SET `unit_flags` = 33536 WHERE `entry` IN (37951, 38931, 38966, 63309);
UPDATE `creature_template` SET `unit_flags` = 33088 WHERE `entry` IN (38440, 38442);
UPDATE `creature_template` SET `unit_flags` = 33024, `faction` = 126 WHERE `entry` = 39062;

-- Echo Isles Quest Bunnies (38003): static and unselectable, and one
-- duplicate spawn 1.6 yd from a retail one.
UPDATE `creature_template` SET `unit_flags` = 33554432 WHERE `entry` = 38003;
UPDATE `creature` SET `MovementType` = 0, `spawndist` = 0 WHERE `id` = 38003;
DELETE FROM `creature_addon` WHERE `guid` = 10583664;
DELETE FROM `creature` WHERE `guid` = 10583664;

-- Critters wander on retail.
UPDATE `creature` SET `MovementType` = 1, `spawndist` = 5  WHERE `id` = 49743 AND `zoneId` = 6453;
UPDATE `creature` SET `MovementType` = 1, `spawndist` = 10 WHERE `id` IN (49837, 62114) AND `zoneId` = 6453;

-- Patrols. Morakki (pre-state) and Notera loop their stops; Moraya's
-- hatchling circles her; Vanira (post-state spawn 10700002) paces.
UPDATE `creature` SET `position_x` = -1302.5695, `position_y` = -5523.547, `position_z` = 19.983624, `orientation` = 2.274369, `MovementType` = 2, `spawndist` = 0 WHERE `guid` = 251557;
UPDATE `creature_addon` SET `path_id` = 3844200 WHERE `guid` = 251557;
UPDATE `creature` SET `MovementType` = 2, `spawndist` = 0 WHERE `guid` = 251761;
UPDATE `creature` SET `position_x` = -1292.04, `position_y` = -5519.14, `position_z` = 20.76695, `orientation` = 1.570796, `MovementType` = 2, `spawndist` = 0 WHERE `guid` = 251544;
DELETE FROM `creature_addon` WHERE `guid` IN (251761, 251544);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`)
SELECT c.`guid`, IF(c.`guid` = 251761, 3898800, 3796000), a.`mount`, a.`bytes1`, a.`bytes2`, a.`emote`, a.`aiAnimKit`, a.`movementAnimKit`, a.`meleeAnimKit`, a.`visibilityDistanceType`, a.`auras`
FROM `creature` c
JOIN `creature_template_addon` a ON a.`entry` = c.`id`
WHERE c.`guid` IN (251761, 251544);

-- Recorded routes:
--   3893000 / 3893001  Zuni (38930) to the raptor pens, then to the hatchlings
--   9011300 / 9011301  Ardsami cauldron -> mailbox -> cauldron
--   3796900..3796902   Kijara post -> nest -> nest -> post
--   3844200            Morakki
--   3898800            Notera (the leg from her fourth stop back to the
--                      fifth was never sniffed and is walked straight)
--   3796000            Moraya's hatchling (37960)
--   3902700            Vanira, post-state
DELETE FROM `waypoint_data` WHERE `id` IN (3893000, 3893001, 9011300, 9011301, 3796900, 3796901, 3796902, 3844200, 3898800, 3796000, 3902700);
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`) VALUES
    (3893000, 1, -1430.2723, -5334.1733, 4.4841, 0.0, 0, 0),
    (3893000, 2, -1431.3323, -5333.5620, 4.5181, 0.0, 0, 0),
    (3893000, 3, -1431.5117, -5333.4585, 4.6433, 0.0, 0, 0),
    (3893000, 4, -1431.7170, -5333.3400, 4.6228, 0.0, 0, 0),
    (3893000, 5, -1433.9580, -5332.0470, 4.3613, 0.0, 0, 0),
    (3893000, 6, -1437.2477, -5330.1490, 4.1071, 0.0, 0, 0),
    (3893000, 7, -1440.8296, -5328.0825, 3.9880, 0.0, 0, 0),
    (3893000, 8, -1443.9688, -5326.2715, 3.3984, 0.0, 0, 0),
    (3893000, 9, -1447.1719, -5322.0840, 2.9674, 0.0, 0, 0),
    (3893000, 10, -1449.2530, -5322.4010, 2.9138, 0.0, 0, 0),
    (3893000, 11, -1453.8756, -5323.1050, 2.6807, 0.0, 0, 0),
    (3893000, 12, -1455.2344, -5323.3120, 2.4963, 0.0, 0, 0),
    (3893000, 13, -1456.7550, -5323.5435, 2.4608, 0.0, 0, 0),
    (3893000, 14, -1462.0405, -5324.3486, 2.0154, 0.0, 0, 0),
    (3893000, 15, -1465.7620, -5322.9727, 1.8446, 0.0, 0, 0),
    (3893000, 16, -1470.2344, -5323.6150, 1.8673, 0.0, 0, 0),
    (3893000, 17, -1478.7500, -5321.9900, 1.8139, 0.0, 0, 0),
    (3893000, 18, -1486.9039, -5318.2400, 1.9479, 0.0, 0, 0),
    (3893000, 19, -1489.7416, -5316.9365, 1.8867, 0.0, 0, 0),
    (3893000, 20, -1491.1445, -5315.1035, 1.3984, 0.0, 0, 0),
    (3893000, 21, -1492.0664, -5314.7170, 1.5934, 0.0, 0, 0),
    (3893000, 22, -1493.9102, -5313.9434, 2.1436, 0.0, 0, 0),
    (3893000, 23, -1494.8320, -5313.5566, 2.4252, 0.0, 0, 0),
    (3893000, 24, -1496.6758, -5312.7830, 2.7096, 0.0, 0, 0),
    (3893000, 25, -1497.5977, -5312.3965, 2.9080, 0.0, 0, 0),
    (3893000, 26, -1499.4414, -5311.6230, 3.3522, 0.0, 0, 0),
    (3893000, 27, -1501.2852, -5310.8496, 3.8486, 0.0, 0, 0),
    (3893000, 28, -1503.1289, -5310.0760, 4.4445, 0.0, 0, 0),
    (3893000, 29, -1504.9727, -5309.3027, 4.7442, 0.0, 0, 0),
    (3893000, 30, -1506.8164, -5308.5293, 5.3124, 0.0, 0, 0),
    (3893000, 31, -1507.7383, -5308.1426, 5.5043, 0.0, 0, 0),
    (3893000, 32, -1509.5820, -5307.3690, 5.7128, 0.0, 0, 0),
    (3893000, 33, -1514.1914, -5305.4355, 5.9403, 0.0, 0, 0),
    (3893000, 34, -1516.0352, -5304.6620, 6.1660, 0.0, 0, 0),
    (3893000, 35, -1517.8789, -5303.8887, 6.3631, 0.0, 0, 0),
    (3893000, 36, -1520.6445, -5302.7285, 6.5592, 0.0, 0, 0),
    (3893000, 37, -1521.1354, -5302.4966, 6.6168, 0.0, 0, 0),
    (3893000, 38, -1539.1632, -5292.6390, 7.7205, 0.0, 0, 0),
    (3893000, 39, -1553.8976, -5295.5780, 9.1100, 5.182681, 0, 0),
    (3893001, 1, -1518.7240, -5284.0190, 6.7945, 0.0, 0, 0),
    (3893001, 2, -1491.9618, -5264.3280, 0.9798, 0.0, 0, 0),
    (3893001, 3, -1469.6841, -5248.7812, -2.9796, 0.0, 0, 0),
    (3893001, 4, -1449.7291, -5235.2954, -1.6291, 0.0, 0, 0),
    (3893001, 5, -1426.0938, -5219.6494, 1.8762, 0.0, 0, 0),
    (9011300, 1, -1306.9913, -5559.1216, 21.0346, 0.0, 0, 0),
    (9011300, 2, -1300.5973, -5560.8022, 21.3103, 0.0, 0, 0),
    (9011300, 3, -1295.1476, -5563.1820, 21.3188, 0.0, 0, 0),
    (9011300, 4, -1290.8298, -5565.1875, 21.0377, 5.84983, 0, 0),
    (9011301, 1, -1301.4705, -5562.3090, 21.3638, 0.0, 0, 0),
    (9011301, 2, -1308.0435, -5559.7954, 21.0488, 0.0, 0, 0),
    (9011301, 3, -1311.8837, -5556.9410, 21.0438, 0.0, 0, 0),
    (3796900, 1, -1559.9688, -5304.7310, 8.8628, 0.0, 0, 0),
    (3796901, 1, -1555.2084, -5296.3490, 9.1222, 0.0, 0, 0),
    (3796902, 1, -1553.4757, -5311.2344, 8.2979, 0.0, 0, 0),
    (3796902, 2, -1549.8872, -5314.8960, 8.0224, 0.0, 0, 0),
    (3844200, 1, -1286.4774, -5550.0034, 20.9128, 0.0, 0, 0),
    (3844200, 2, -1273.7830, -5551.6006, 20.9346, 0.0, 0, 0),
    (3844200, 3, -1261.0260, -5544.8975, 20.3543, 0.0, 0, 0),
    (3844200, 4, -1253.3959, -5542.6130, 18.9820, 0.05236, 34000, 0),
    (3844200, 5, -1277.4567, -5553.0680, 20.9464, 0.0, 0, 0),
    (3844200, 6, -1286.6459, -5549.5140, 20.9113, 0.0, 0, 0),
    (3844200, 7, -1290.4149, -5537.6130, 20.8451, 0.0, 0, 0),
    (3844200, 8, -1302.5695, -5523.5470, 19.9836, 2.274369, 38000, 0),
    (3898800, 1, -1318.9723, -5436.3457, 14.5583, 0.0, 0, 0),
    (3898800, 2, -1321.9132, -5445.7830, 14.6331, 0.0, 0, 0),
    (3898800, 3, -1325.4028, -5455.4810, 14.8093, 0.0, 0, 0),
    (3898800, 4, -1320.6423, -5462.5034, 14.6297, 0.855211, 36000, 0),
    (3898800, 5, -1288.1562, -5450.1130, 14.5070, 0.241239, 37000, 0),
    (3898800, 6, -1300.1442, -5440.6080, 14.7398, 3.926991, 36000, 0),
    (3796000, 1, -1295.3993, -5525.8247, 20.6257, 0.0, 0, 0),
    (3796000, 2, -1287.3942, -5535.8804, 20.9569, 0.0, 0, 0),
    (3796000, 3, -1285.0747, -5533.7760, 20.9492, 0.0, 0, 0),
    (3796000, 4, -1286.2031, -5529.0470, 20.8156, 0.0, 0, 0),
    (3796000, 5, -1292.0555, -5524.9620, 20.7532, 0.0, 0, 0),
    (3796000, 6, -1291.1528, -5523.0034, 20.7670, 5.689773, 32000, 0),
    (3796000, 7, -1292.0400, -5519.1400, 20.7670, 1.570796, 36000, 0),
    (3902700, 1, -1333.3142, -5545.3003, 21.0201, 1.797689, 29000, 0),
    (3902700, 2, -1317.8993, -5539.1963, 20.9648, 2.199115, 29000, 0);

-- ============================================================================
-- Jornun's ride to Spitescale Cove
-- ============================================================================

-- Jornun (38989, the after-"Young and Vicious" copy) offers the ride; the
-- player's answer makes him cast "Forcecast Summon Bloodtalon Thrasher"
-- (73209), which has the player summon and mount a possessed Thrasher
-- (73208, 38991). The Thrasher's route lives in npc_bloodtalon_thrasher_ride.

-- Retail's answer text (BroadcastText 38979).
UPDATE `gossip_menu_option` SET `OptionText` = 'Yes.  Do you have a raptor that can take me there?', `OptionBroadcastTextId` = 38979
WHERE `MenuId` = 11131 AND `OptionIndex` = 0;

-- Only the after-state Jornun offers the ride: the player needs "See Quest
-- Invis 3" (73205), which the Darkspear Hold grants once 24626 is taken.
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 15 AND `SourceGroup` = 11131 AND `SourceEntry` = 0;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
    (15, 11131, 0, 0, 0, 1, 0, 73205, 0, 0, 0, 0, 0, '', 'Jornun - ride to Spitescale Cove only in the Darkspear Hold after-state');

DELETE FROM `smart_scripts` WHERE `entryorguid` = 38989 AND `source_type` = 0;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param_string`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
    (38989, 0, 0, 1, 62, 0, 100, 0, 11131, 0, 0, 0, 0, '', 72,     0, 0, 0, 0, 0, 0,  0,     0,  0, 0, 0, 0, 0, 0, 'Jornun - On gossip option 0 selected - Close gossip'),
    (38989, 0, 1, 2, 61, 0, 100, 0,     0, 0, 0, 0, 0, '', 11, 73209, 0, 0, 0, 0, 0,  7,     0,  0, 0, 0, 0, 0, 0, 'Jornun - Linked - Cast Forcecast Summon Bloodtalon Thrasher on invoker'),
    (38989, 0, 2, 0, 61, 0, 100, 0,     0, 0, 0, 0, 0, '',  1,     0, 0, 0, 0, 0, 0, 19, 38931, 10, 0, 0, 0, 0, 0, 'Jornun - Linked - Zuni says Not so fast');

-- Zuni (38931, after-state) as the player rides off (BroadcastText 39064).
DELETE FROM `creature_text` WHERE `CreatureID` = 38931 AND `GroupID` = 0;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (38931, 0, 0, 'Not so fast! Save some for me, mon!', 12, 0, 100, 0, 0, 0, 39064, 0, 'Zuni - Jornun''s ride');

UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_bloodtalon_thrasher_ride' WHERE `entry` = 38991;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 38991 AND `source_type` = 0;

-- ============================================================================
-- Final stage: Spitescale Cove to the Thrall vision
-- ============================================================================

-- Scripts ----------------------------------------------------------------
DELETE FROM `spell_script_names` WHERE `spell_id` IN (79782, 73131);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
    (79782, 'spell_echo_isles_orb_of_corruption');

-- Their old SmartAI (and its one action list) moves into C++.
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (38225, 38306, 38437, 38423, 38302, 38542, 38560, 38452, 38932);
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` = 3822500;

UPDATE `creature_template` SET `npcflag` = 0 WHERE `entry` IN (38300, 38301);

-- Staged Wavethrasher corpses. Retail create-object state is 0x20048100 /
-- 0x00000801 / 0x00002000. Keep only the static portion here; Permanent
-- Feign Death (29266) supplies UNIT_FLAG_UNK_29, UNIT_FLAG2_FEIGN_DEATH and
-- UNIT_FLAG3_FAKE_DEAD at runtime. Living Wavethrashers keep normal flags.
UPDATE `creature` `c`
INNER JOIN `creature_addon` `ca` ON `ca`.`guid` = `c`.`guid`
SET `c`.`unit_flags` = 295168, -- 0x00048100: STUNNED | UNK_15 | IMMUNE_TO_PC
    `c`.`unit_flags2` = 2048   -- 0x00000800: REGENERATE_POWER
WHERE `c`.`id` = 38300
  AND CONCAT(' ', TRIM(`ca`.`auras`), ' ') LIKE '% 29266 %';
UPDATE `creature_template` SET `dynamicflags` = 0 WHERE `entry` = 38300;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_zuni_spitescale_cove', `minlevel` = 6, `maxlevel` = 6, `unit_flags` = 32768 WHERE `entry` = 38932;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_spitescale_flag_bunny', `npcflag` = 0, `unit_flags` = 33554432 WHERE `entry` = 38560;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_voljin_spitescale_cove', `npcflag` = 1, `faction` = 126 WHERE `entry` = 38225;
-- Retail create-object state for the Spitescale Cove Vol'jin. His encounter
-- walk is owned by C++; SQL only fixes the static/home state he starts from.
UPDATE `creature`
SET `position_x` = -741.5434,
    `position_y` = -5615.5210,
    `position_z` = 25.113562,
    `orientation` = 0.872664630413055419,
    `spawndist` = 0,
    `MovementType` = 0
WHERE `id` = 38225;

-- No DB waypoint path may compete with npc_voljin_spitescale_cove.
UPDATE `creature_addon` `ca`
INNER JOIN `creature` `c` ON `c`.`guid` = `ca`.`guid`
SET `ca`.`path_id` = 0
WHERE `c`.`id` = 38225;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_zarjira', `npcflag` = 0, `faction` = 2205, `unit_flags` = 33600 WHERE `entry` = 38306;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_vanira_spitescale_cove', `faction` = 126, `unit_flags` = 32832 WHERE `entry` = 38437;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_zuni_spitescale_fight', `faction` = 126, `unit_flags` = 33024 WHERE `entry` = 38423;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_fire_of_the_seas' WHERE `entry` = 38542;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_manifestation_of_the_sea_witch' WHERE `entry` = 38302;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_sea_witch_channel_bunny', `unit_flags` = 33554432 WHERE `entry` = 38452;

-- The fetish and the fires are placed by the scripts, not worn permanently.
UPDATE `creature_template_addon` SET `auras` = '' WHERE `entry` IN (38560, 38542);

-- Quest givers that never gave these quests on retail.
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((38300, 24812), (38306, 24814), (38560, 24813), (38225, 24814));

-- Retail objective text for Territorial Fetish (objective 267327 on 12.1.0).
UPDATE `quest_objectives`
SET `Description` = 'Territorial Fetish placed'
WHERE `QuestID` = 24813 AND `ObjectID` = 38560;

-- The braziers exist only during the fight; they use the known historical
-- spawn GUIDs.
DELETE FROM `creature_addon` WHERE `guid` IN (302893, 302894, 302895);
DELETE FROM `creature` WHERE `guid` IN (302893, 302894, 302895);

-- A brazier click stamps it out, nothing else.
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 38542 AND `spell_id` IN (58961, 73294);

-- Gossip ------------------------------------------------------------------
UPDATE `gossip_menu_option` SET `OptionBroadcastTextId` = 38317 WHERE `MenuId` = 11020 AND `OptionIndex` = 0;

-- Spell targets and gossip conditions -------------------------------------
-- 13 = spell implicit target (SourceGroup = effect mask), 15 = gossip option.
-- 51 = object entry (value1 5 = unit), 52 = type mask (16 = player),
-- 1 = aura, 9 = quest taken, 28 = quest objectives complete.
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceEntry` IN (73004, 72056, 72045, 72044, 73294, 73013, 73432, 72070, 73589, 73534);
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 15 AND `SourceGroup` IN (11020, 11107) AND `SourceEntry` = 0;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
    (13, 3, 73004, 0, 0, 51, 0, 5, 38423, 0, 0, 0, 0, '', 'Freezing Touch - Zuni'),
    (13, 3, 73004, 0, 1, 51, 0, 5, 38437, 0, 0, 0, 0, '', 'Freezing Touch - Vanira'),
    (13, 1, 72056, 0, 0, 52, 0, 16, 0, 0, 0, 0, 0, '', 'Summon Manifestation AICast - players only'),
    (13, 1, 72045, 0, 0, 51, 0, 5, 38452, 0, 0, 0, 0, '', 'Frozen Torrent - Sea Witch Channel Bunny'),
    (13, 1, 72044, 0, 0, 51, 0, 5, 38452, 0, 0, 0, 0, '', 'Deluge of Shadow - Sea Witch Channel Bunny'),
    (13, 1, 73294, 0, 0, 51, 0, 5, 38306, 0, 0, 0, 0, '', 'Fire of the Seas Energy Beam - Zar''jira'),
    (13, 1, 73013, 0, 0, 51, 0, 5, 38306, 0, 0, 0, 0, '', 'Shadow Surge - Zar''jira'),
    (13, 1, 73432, 0, 0, 51, 0, 5, 38306, 0, 0, 0, 0, '', 'Soul Scar - Zar''jira'),
    (13, 1, 72070, 0, 0, 51, 0, 5, 38560, 0, 0, 0, 0, '', 'Place Territorial Fetish - Spitescale Flag Bunny'),
    (13, 1, 72070, 0, 0, 1, 0, 72072, 0, 0, 1, 0, 0, '', 'Place Territorial Fetish - flag without a fetish'),
    (13, 1, 73589, 0, 0, 52, 0, 16, 0, 0, 0, 0, 0, '', 'Vol''jin Speak Credit - players only'),
    (13, 1, 73534, 0, 0, 52, 0, 16, 0, 0, 0, 0, 0, '', 'Sea Witch Kill Credit - players only'),
    (15, 11020, 0, 0, 0, 9, 0, 24814, 0, 0, 0, 0, 0, '', 'Vol''jin - I am ready, while An Ancient Enemy is active'),
    (15, 11020, 0, 0, 0, 28, 0, 24814, 0, 0, 1, 0, 0, '', 'Vol''jin - I am ready, not once it is complete'),
    (15, 11107, 0, 0, 0, 28, 0, 24814, 0, 0, 0, 0, 0, '', 'Vanira - Teleport back once An Ancient Enemy is complete');

-- Darkspear Hold after the Sea Witch: its spell_area rows are in the
-- visibility section.

-- One Vol'jin and one vision bunny per scene on the same spot.
DELETE FROM `creature_addon` WHERE `guid` IN (251569, 10700003, 10700004);
DELETE FROM `creature` WHERE `guid` IN (10700003, 10700004);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`)
SELECT 10700003, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, 0.890118, `spawntimesecs`, 0, 0, `curhealth`, `curmana`, 0, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild` FROM `creature` WHERE `guid` = 251569;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`)
SELECT 10700004, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, 0, 0, `curhealth`, `curmana`, 0, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild` FROM `creature` WHERE `guid` = 251568;
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`)
SELECT c.`guid`, 0, IFNULL(a.`mount`, 0), IFNULL(a.`bytes1`, 0), IFNULL(a.`bytes2`, 0), IFNULL(a.`emote`, 0), IFNULL(a.`aiAnimKit`, 0), IFNULL(a.`movementAnimKit`, 0), IFNULL(a.`meleeAnimKit`, 0), IFNULL(a.`visibilityDistanceType`, 0), IF(c.`guid` = 251569, '49414', '49415')
FROM `creature` c
LEFT JOIN `creature_template_addon` a ON a.`entry` = c.`id`
WHERE c.`guid` IN (251569, 10700003, 10700004);

-- Texts (retail BroadcastText) ---------------------------------------------
-- TextRange 2 = zone: Zar'jira's idle yells carried across the island.
DELETE FROM `creature_text` WHERE `CreatureID` IN (38225, 38306, 38437, 38423, 38932, 38939);
DELETE FROM `creature_text` WHERE `CreatureID` = 38966 AND `GroupID` BETWEEN 4 AND 14;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (38966, 4, 0, 'Tha Sea Witch is dead, our home is reclaimed, but our future still be uncertain.', 12, 0, 100, 1, 0, 0, 38876, 0, 'Vol''jin - Thrall vision'),
    (38966, 5, 0, 'I''ve no love for Garrosh, dat much is sure, but leavin'' tha Horde is not a decision I be takin'' lightly.', 12, 0, 100, 1, 0, 0, 38878, 0, 'Vol''jin - Thrall vision'),
    (38966, 6, 0, 'Dere''s only one with tha answers I seek. Ya can stay and watch if ya like.', 12, 0, 100, 1, 0, 0, 38877, 0, 'Vol''jin - Thrall vision'),
    (38966, 7, 0, 'Thrall!  I am glad ya be well.  Dere were rumors otherwise.', 12, 0, 100, 1, 0, 0, 38880, 0, 'Vol''jin - Thrall vision'),
    (38966, 8, 0, 'I must beg ya council, my friend.  I can''t be standin'' by Garrosh while he be turnin'' our people against each other for tha sake of war.  My respect for you does not extend to dis new Horde... I am tinkin'' of leadin'' my people away.', 12, 0, 100, 1, 0, 0, 38882, 0, 'Vol''jin - Thrall vision'),
    (38966, 9, 0, 'I understand, brotha. I will tink on this and be troublin'' ya no furtha. You have a world to be savin''.', 12, 0, 100, 6, 0, 0, 38885, 0, 'Vol''jin - Thrall vision'),
    (38966, 10, 0, 'Ya be strong and proud, youngblood.  Tha Darkspear will be honored ta have you fight beside d''em.', 12, 0, 100, 1, 0, 0, 38887, 0, 'Vol''jin - Thrall vision'),
    (38966, 11, 0, 'Dese be dark times, but our people will be stayin'' with tha Horde for tha good of all.  ', 12, 0, 100, 1, 0, 0, 38889, 0, 'Vol''jin - Thrall vision'),
    (38966, 12, 0, 'Thrall''s words be true. Dey always be. The Horde is much more den a few old, stubborn leaders and a handful of heroes from Northrend. The people be cryin'' Garrosh''s name... at least for now.', 12, 0, 100, 1, 0, 0, 38890, 0, 'Vol''jin - Thrall vision'),
    (38966, 13, 0, 'Still, I be hopin'' Thrall will return to us one day. Tha future right now be lookin'' very grim... and very bloody.', 12, 0, 100, 1, 0, 0, 43777, 0, 'Vol''jin - Thrall vision'),
    (38966, 14, 0, 'Go now. Make tha Darkspear proud. Dere are many wars ahead of us, an'' I''m sure ya be havin'' a part to play in all of dem.', 12, 0, 100, 1, 0, 0, 43778, 0, 'Vol''jin - Thrall vision'),
    (38939, 0, 0, 'Vol''jin.  It''s good to see you, brother.', 12, 0, 100, 1, 0, 0, 42871, 0, 'Vision of Thrall'),
    (38939, 1, 0, 'Indeed.  Someone did try to kill me, but that is not my greatest concern at this moment.  The world itself calls for my aid.', 12, 0, 100, 1, 0, 0, 38879, 0, 'Vision of Thrall'),
    (38939, 2, 0, 'Vol''jin, I chose Garrosh because he has the strength to lead our people in these trying times. ', 12, 0, 100, 1, 0, 0, 38881, 0, 'Vision of Thrall'),
    (38939, 3, 0, 'For all my supposed wisdom, there have been moments that I''ve barely been able to hold the Horde together. The Wrath Gate and Undercity displayed that clearly enough.', 12, 0, 100, 1, 0, 0, 38883, 0, 'Vision of Thrall'),
    (38939, 4, 0, 'The Horde cries for a hero of old. An orc of true blood that will bow to no human and bear no betrayal. A warrior that will make our people proud again. Garrosh can be that hero.', 12, 0, 100, 1, 0, 0, 38884, 0, 'Vision of Thrall'),
    (38939, 5, 0, 'I did not make this decision lightly, Vol''jin. I know our alliances will suffer for it. I know the Horde will be irreversibly changed. But I made this choice with confidence that Garrosh is exactly what the Horde needs.', 12, 0, 100, 1, 0, 0, 43775, 0, 'Vision of Thrall'),
    (38939, 6, 0, 'I''m trusting you and the other leaders to not let this divide our people. You are stronger than that.', 12, 0, 100, 1, 0, 0, 43776, 0, 'Vision of Thrall'),
    (38939, 7, 0, 'Throm''ka, old friend.', 12, 0, 100, 66, 0, 0, 38888, 0, 'Vision of Thrall'),
    (38225, 0, 0, 'Ya were foolish to come ''ere, Sea Witch. Ya escaped our vengeance once, but the Darkspear Tribe will not abide ya trespassin'' again.', 14, 0, 100, 1, 0, 0, 38318, 0, 'Vol''jin - An Ancient Enemy start'),
    (38225, 1, 0, 'She''s drawing power from the fires! Stamp out the braziers, quickly!', 41, 0, 100, 0, 0, 0, 38825, 0, 'Vol''jin - braziers'),
    (38225, 2, 0, 'It be done. Our ancient enemy is defeated.', 12, 0, 100, 1, 0, 0, 38829, 0, 'Vol''jin - Zar''jira defeated'),
    (38225, 3, 0, 'I been waitin'' a long time for a chance to avenge my father. A great weight has been lifted from my shoulders.', 12, 0, 100, 1, 0, 0, 38833, 0, 'Vol''jin - Zar''jira defeated'),
    (38225, 4, 0, 'I must be returnin'' ta Darkspear Hold. Please meet me there once Vanira is done with her healin'' of the boy.', 12, 0, 100, 1, 0, 0, 38834, 0, 'Vol''jin - Zar''jira defeated'),
    (38306, 0, 0, 'You are weak Vol''jin, like your father was weak. Today I will finish what I started long ago - the Darkspear shall be wiped from existence!', 14, 0, 100, 1, 0, 0, 38294, 0, 'Zar''jira - fight start'),
    (38306, 1, 0, 'Leave the fire alone, pesky trolls! Just give up and die.', 14, 0, 100, 1, 0, 0, 38819, 0, 'Zar''jira - braziers stamped out'),
    (38306, 1, 1, 'No! I will make your death slow and painful, little trolls.', 14, 0, 100, 1, 0, 0, 38820, 0, 'Zar''jira - braziers stamped out'),
    (38306, 1, 2, 'You were a fool to touch my fires! When Vol''jin falls, you know who dies next!', 14, 0, 100, 1, 0, 0, 38821, 0, 'Zar''jira - braziers stamped out'),
    (38306, 2, 0, 'Not so fast, little troll!', 14, 0, 100, 1, 0, 0, 39045, 0, 'Zar''jira - last breath'),
    (38306, 3, 0, 'I have returned to finish what I started, Darkspear. These islands shall run with your blood.', 14, 0, 100, 0, 0, 0, 39012, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38306, 3, 1, 'Your father was a weakling, Vol''jin. I shall enjoy sucking the life from you as I did him.', 14, 0, 100, 0, 0, 0, 39014, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38306, 3, 2, 'Ah, another Darkspear Warrior sacrificed on my altar. One by one, you shall all perish.', 14, 0, 100, 0, 0, 0, 39015, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38306, 3, 3, 'Thrall is not here to save you this time, Darkspear. Slink away to the shadows, for I shall hunt every last one of you down.', 14, 0, 100, 0, 0, 0, 39016, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38306, 3, 4, 'The tides shall wash away the entire Darkspear Tribe.', 14, 0, 100, 0, 0, 0, 39017, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38306, 3, 5, 'Troll weaklings, there is no hope. Your death has been foretold by the tides.', 14, 0, 100, 0, 0, 0, 39018, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38306, 3, 6, 'When I am finished with your tribe, I shall hunt down that orcish cur that saved you from my wrath once before. None will survive.', 14, 0, 100, 0, 0, 0, 39019, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38306, 3, 7, 'You were fools to leave the safety of your city. Your return to the ocean has assured your demise.', 14, 0, 100, 0, 0, 0, 39020, 2, 'Zar''jira - idle, zone-wide every 5 min'),
    (38437, 0, 0, 'Take care of her spirits! We be handlin'' Zar''jira.', 14, 0, 100, 5, 0, 0, 38826, 0, 'Vanira - spirits'),
    (38437, 1, 0, 'ZUNI! NOOOO!', 14, 0, 100, 5, 0, 0, 39044, 0, 'Vanira - Zuni falls'),
    (38437, 2, 0, 'I''m afraid there''s nothin'' I can do for our brother... her power tore away at his soul.', 12, 0, 100, 1, 0, 0, 38835, 0, 'Vanira - after the fight'),
    (38437, 3, 0, 'I''ll send some watchers ta get his body so we can offer a proper farewell... I wish I could do more.', 12, 0, 100, 1, 0, 0, 38836, 0, 'Vanira - after the fight'),
    (38437, 4, 0, 'Vol''jin rushed off in eagerness, but I can take us back to safety. Just give me the word when ya ready, mon.', 12, 0, 100, 1, 0, 0, 38837, 0, 'Vanira - ride back offer'),
    (38423, 0, 0, 'I''ll get the fires dis time!', 14, 0, 100, 5, 0, 0, 39043, 0, 'Zuni - runs for the fires'),
    (38932, 0, 0, 'Ha! I caught up with ya! Let''s stick together in ''ere, okay?', 12, 0, 100, 1, 0, 0, 39070, 0, 'Zuni - joins the player'),
    (38932, 1, 0, 'Ya momma was bait fish.', 12, 0, 100, 0, 0, 0, 38255, 0, 'Zuni - taunts the naga'),
    (38932, 1, 1, 'Die snakefish!', 12, 0, 100, 0, 0, 0, 38256, 0, 'Zuni - taunts the naga'),
    (38932, 1, 2, 'If I fished ya up, I''d throw ya back. Waste of good fish meat.', 12, 0, 100, 0, 0, 0, 38257, 0, 'Zuni - taunts the naga'),
    (38932, 1, 3, 'Go suck on a trident.', 12, 0, 100, 0, 0, 0, 38258, 0, 'Zuni - taunts the naga'),
    (38932, 1, 4, 'Ya mest with da wrong trolls, fishhead.', 12, 0, 100, 0, 0, 0, 38259, 0, 'Zuni - taunts the naga'),
    (38932, 1, 5, 'Ya about to be darkspeared.', 12, 0, 100, 0, 0, 0, 38260, 0, 'Zuni - taunts the naga'),
    (38932, 1, 6, 'Wow. Ya even ugly for a naga.', 12, 0, 100, 0, 0, 0, 38261, 0, 'Zuni - taunts the naga');

-- ============================================================================
-- Zuni accompanies 24812 / 24813 from quest acceptance
-- ============================================================================

-- Retail gives the player "Summon Zuni (Lvl 4) Aura" (73130) when either
-- Morakki quest is accepted. The 8.3.7 periodic trigger (73131) is restricted
-- to the old Durotar area, so C++ owns the quest-state lifecycle and creates
-- the personal Zuni directly while preserving 73130 as the controlling aura.
-- Remove the old cavern-only spell_area workaround: entering area 4913 must
-- not despawn/recreate a Zuni that already joined on quest acceptance.

DELETE FROM `smart_scripts` WHERE `entryorguid` = 38442 AND `source_type` = 0;
UPDATE `creature_template` SET `AIName` = '' WHERE `entry` = 38442;

DELETE FROM `spell_area` WHERE `spell` = 73130;

DELETE FROM `spell_script_names` WHERE `spell_id` = 73130;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
    (73130, 'spell_echo_isles_summon_zuni_lvl_4_aura');
-- ============================================================================
-- 2026-09-24 hybrid pass 2: supersede legacy world updates / sniff corrections
-- ============================================================================

-- Current upstream 2026_08_21_03_world_quest_26273_tiki_target.sql installs
-- NullCreatureAI and per-spawn 71064/71066 auras. The C++ tiki target owns
-- this behavior now; the retail target state is template aura 7056.
UPDATE `creature_template`
SET `AIName` = '', `ScriptName` = 'npc_tiki_target', `npcflag` = 0, `unit_flags` = 393216
WHERE `entry` = 38038;

UPDATE `creature_addon` ca
JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`auras` = ''
WHERE c.`id` = 38038;

INSERT INTO `creature_template_addon`
(`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`aiAnimKit`,`movementAnimKit`,`meleeAnimKit`,`visibilityDistanceType`,`auras`)
VALUES (38038,0,0,0,0,0,0,0,0,0,'7056')
ON DUPLICATE KEY UPDATE `auras` = VALUES(`auras`);

-- Current upstream 2026_08_21_05_world_quest_24780_proving_pit.sql contains
-- both entry-based and spawn-GUID SmartAI. Remove every superseded branch;
-- npc_darkspear_jailor / npc_captive_spitescale_scout own the flow.
DELETE FROM `smart_scripts`
WHERE (`source_type` = 0 AND `entryorguid` IN (39062,38142,-251547))
   OR (`source_type` = 1 AND `entryorguid` = -172893);

-- Two Darkspear Tribesmen in the July DB are ~3.8 yd above the ground.
-- Retail create packets repeatedly place these two actors on the lower ledge.
UPDATE `creature`
SET `position_x` = -1001.8616, `position_y` = -5643.1440, `position_z` = 10.288658, `orientation` = 0.34682217
WHERE `guid` = 251853 AND `id` = 38324;

UPDATE `creature`
SET `position_x` = -1000.1979, `position_y` = -5639.4620, `position_z` = 10.444925, `orientation` = 5.95157290
WHERE `guid` = 251885 AND `id` = 38324;

-- Zuni 38930: fixed retail bridge route. Three complete captures agree on
-- the same broad trajectory from Darkspear Hold to the Bloodtalon pens.
-- It replaces MoveFollow on the bridge; 5778 only delivers the line.
DELETE FROM `waypoint_data` WHERE `id` = 3893002;
INSERT INTO `waypoint_data`
(`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`) VALUES
(3893002,  1, -1324.0000, -5396.0000, 14.2000, 0, 0, 0),
(3893002,  2, -1336.0000, -5388.0000, 15.5000, 0, 0, 0),
(3893002,  3, -1347.0000, -5381.0000, 14.5000, 0, 0, 0),
(3893002,  4, -1368.0000, -5368.0000, 12.4000, 0, 0, 0),
(3893002,  5, -1377.0000, -5362.0000, 10.7000, 0, 0, 0),
(3893002,  6, -1397.0000, -5349.0000,  7.5000, 0, 0, 0),
(3893002,  7, -1414.0000, -5339.0000,  5.6000, 0, 0, 0),
(3893002,  8, -1428.0000, -5335.0000,  4.9000, 0, 0, 0),
(3893002,  9, -1430.2723, -5334.1733,  4.4841, 0, 0, 0),
(3893002, 10, -1443.9688, -5326.2715,  3.3984, 0, 0, 0),
(3893002, 11, -1470.2344, -5323.6150,  1.8673, 0, 0, 0),
(3893002, 12, -1493.9102, -5313.9434,  2.1436, 0, 0, 0),
(3893002, 13, -1520.6445, -5302.7285,  6.5592, 0, 0, 0),
(3893002, 14, -1539.1632, -5292.6390,  7.7205, 0, 0, 0),
(3893002, 15, -1553.8976, -5295.5780,  9.1100, 5.182681, 0, 0);

-- Our C++ is authoritative for the ambient trainees and shore combatants.
-- Remove any old entry-based SAI that can be reintroduced by earlier updates.
DELETE FROM `smart_scripts`
WHERE `source_type` = 0
  AND `entryorguid` IN (38268,38272,38278,38279,38280,38281,38282,42619,38324,38326,38300,38301,90113);

UPDATE `creature_template`
SET `AIName` = '', `ScriptName` = 'npc_echo_isles_sparring'
WHERE `entry` IN (38268,38272,38278,38279,38280,38281,38282,42619,38324,38326);

UPDATE `creature_template`
SET `AIName` = '', `ScriptName` = 'npc_spitescale_naga'
WHERE `entry` IN (38300,38301);

UPDATE `creature_template`
SET `AIName` = '', `ScriptName` = 'npc_ardsami'
WHERE `entry` = 90113;

-- ============================================================================
-- Echo Isles - Spitescale Cove / An Ancient Enemy / Darkspear training fixes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Territorial Fetish (24813): the placed fetish pulses 72249, the shrink.
-- Retail hit only Spitescale Wavethrashers (38300) and Sirens (38301) with it
-- (aura ActiveFlags 7 = all three effects); the player's Zuni was shrunk here.
-- 13 = spell implicit target, SourceGroup = effect mask, 51 = object entry.
-- ----------------------------------------------------------------------------
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceEntry` = 72249;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
    (13, 7, 72249, 0, 0, 51, 0, 5, 38300, 0, 0, 0, 0, '', 'Territorial Fetish shrink - Spitescale Wavethrasher'),
    (13, 7, 72249, 0, 1, 51, 0, 5, 38301, 0, 0, 0, 0, '', 'Territorial Fetish shrink - Spitescale Siren');

-- ----------------------------------------------------------------------------
-- Sea Witch Channel Bunny (38452): summoned by the script, once per
-- intermission. Any static spawn is a second anchor for the two channels.
-- It flies its retail route between Zar'jira and Vol'jin (InhabitType 4).
-- ----------------------------------------------------------------------------
DELETE `ca` FROM `creature_addon` `ca` INNER JOIN `creature` `c` ON `c`.`guid` = `ca`.`guid` WHERE `c`.`id` = 38452;
DELETE FROM `creature` WHERE `id` = 38452;
UPDATE `creature_template` SET `InhabitType` = `InhabitType` | 4 WHERE `entry` = 38452;

-- ----------------------------------------------------------------------------
-- Breaking the Line: Jornun's Bloodtalon Thrasher (38991). Every retail
-- spline of the ride carries CanSwim; the core only sets it when the
-- template may enter water, so the sea leg after the second jump was drawn
-- as a hover for a second or two.
-- ----------------------------------------------------------------------------
UPDATE `creature_template` SET `InhabitType` = `InhabitType` | 2 WHERE `entry` = 38991;

-- The ride and the run back hold every point of retail's splines (two
-- captures agree), not just their end points: straight lines between end
-- points cut over the slopes, and the run back left the Thrasher in the
-- air. Legs in zone_echo_isles.cpp: run 1-10, jump 11, run 12-61, jump 62,
-- run 63-92 (drop-off); 3899101 is the swim out to sea where it despawns.
DELETE FROM `waypoint_data` WHERE `id` IN (3899100, 3899101);
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`) VALUES
    (3899100, 1, -1333.0230, -5556.3660, 21.3899, 0, 0, 0),
    (3899100, 2, -1320.9377, -5557.9707, 21.3135, 0, 0, 0),
    (3899100, 3, -1298.9934, -5561.0576, 21.5391, 0, 0, 0),
    (3899100, 4, -1291.4934, -5562.0576, 21.2891, 0, 0, 0),
    (3899100, 5, -1289.2434, -5563.8076, 21.2891, 0, 0, 0),
    (3899100, 6, -1277.5073, -5571.9060, 21.1034, 0, 0, 0),
    (3899100, 7, -1267.2573, -5582.6560, 20.8534, 0, 0, 0),
    (3899100, 8, -1266.5073, -5583.6560, 20.8534, 0, 0, 0),
    (3899100, 9, -1263.0073, -5584.6560, 20.8534, 0, 0, 0),
    (3899100, 10, -1251.1180, -5588.0570, 20.7362, 0, 0, 0),
    (3899100, 11, -1217.9700, -5601.6200, 14.3847, 0, 0, 0),
    (3899100, 12, -1215.8270, -5602.2070, 14.4299, 0, 0, 0),
    (3899100, 13, -1214.8270, -5602.7070, 14.4299, 0, 0, 0),
    (3899100, 14, -1213.8270, -5602.9570, 13.9299, 0, 0, 0),
    (3899100, 15, -1213.0770, -5603.2070, 13.4299, 0, 0, 0),
    (3899100, 16, -1212.0770, -5603.4570, 13.1799, 0, 0, 0),
    (3899100, 17, -1208.3270, -5604.9570, 12.9299, 0, 0, 0),
    (3899100, 18, -1200.8270, -5607.4570, 13.1799, 0, 0, 0),
    (3899100, 19, -1195.9135, -5609.0420, 13.9057, 0, 0, 0),
    (3899100, 20, -1194.9135, -5609.5420, 13.9057, 0, 0, 0),
    (3899100, 21, -1193.1635, -5610.0420, 14.1557, 0, 0, 0),
    (3899100, 22, -1192.1635, -5610.5420, 14.4057, 0, 0, 0),
    (3899100, 23, -1188.4135, -5611.7920, 14.6557, 0, 0, 0),
    (3899100, 24, -1172.4135, -5617.0420, 14.6557, 0, 0, 0),
    (3899100, 25, -1165.6635, -5617.0420, 14.9057, 0, 0, 0),
    (3899100, 26, -1160.3317, -5617.3670, 15.1048, 0, 0, 0),
    (3899100, 27, -1148.3317, -5617.6170, 14.8548, 0, 0, 0),
    (3899100, 28, -1136.0817, -5617.8670, 14.8548, 0, 0, 0),
    (3899100, 29, -1128.9851, -5618.3170, 14.6187, 0, 0, 0),
    (3899100, 30, -1105.7351, -5620.3170, 14.6187, 0, 0, 0),
    (3899100, 31, -1101.7351, -5621.5670, 14.8687, 0, 0, 0),
    (3899100, 32, -1099.6309, -5622.2373, 15.1961, 0, 0, 0),
    (3899100, 33, -1092.8809, -5624.2373, 14.9461, 0, 0, 0),
    (3899100, 34, -1089.1309, -5625.4873, 14.9461, 0, 0, 0),
    (3899100, 35, -1081.3809, -5627.7373, 14.9461, 0, 0, 0),
    (3899100, 36, -1065.1035, -5640.8887, 14.9872, 0, 0, 0),
    (3899100, 37, -1061.9656, -5643.4110, 15.3484, 0, 0, 0),
    (3899100, 38, -1058.2156, -5646.4110, 15.3484, 0, 0, 0),
    (3899100, 39, -1055.2156, -5646.1610, 15.0984, 0, 0, 0),
    (3899100, 40, -1044.2354, -5645.4463, 14.8469, 0, 0, 0),
    (3899100, 41, -1040.2354, -5645.1963, 14.8469, 0, 0, 0),
    (3899100, 42, -1024.0824, -5631.6730, 14.8924, 0, 0, 0),
    (3899100, 43, -1023.5824, -5630.4230, 15.1424, 0, 0, 0),
    (3899100, 44, -1023.0824, -5628.4230, 15.6424, 0, 0, 0),
    (3899100, 45, -1022.8324, -5627.4230, 15.6424, 0, 0, 0),
    (3899100, 46, -1022.3324, -5625.4230, 15.8924, 0, 0, 0),
    (3899100, 47, -1021.5824, -5622.6730, 15.6424, 0, 0, 0),
    (3899100, 48, -1021.0824, -5620.6730, 15.3924, 0, 0, 0),
    (3899100, 49, -1020.5824, -5618.6730, 15.1424, 0, 0, 0),
    (3899100, 50, -1020.5824, -5617.6730, 14.8924, 0, 0, 0),
    (3899100, 51, -1019.8324, -5614.9230, 14.8924, 0, 0, 0),
    (3899100, 52, -1017.5824, -5606.4230, 15.1424, 0, 0, 0),
    (3899100, 53, -1013.2028, -5599.5070, 14.9404, 0, 0, 0),
    (3899100, 54, -1010.9528, -5596.2570, 14.9404, 0, 0, 0),
    (3899100, 55, -1004.5476, -5587.3164, 14.8511, 0, 0, 0),
    (3899100, 56, -992.2976, -5580.3164, 14.8511, 0, 0, 0),
    (3899100, 57, -988.5476, -5578.5664, 15.1011, 0, 0, 0),
    (3899100, 58, -984.0476, -5576.8164, 14.8511, 0, 0, 0),
    (3899100, 59, -977.2976, -5574.8164, 14.6011, 0, 0, 0),
    (3899100, 60, -975.2976, -5574.0664, 14.3511, 0, 0, 0),
    (3899100, 61, -967.6268, -5571.5850, 14.1235, 0, 0, 0),
    (3899100, 62, -935.7920, -5557.0800, -0.0171, 0, 0, 0),
    (3899100, 63, -935.0305, -5555.9062, -0.3621, 0, 0, 0),
    (3899100, 64, -934.0305, -5554.1562, -0.6121, 0, 0, 0),
    (3899100, 65, -933.0305, -5552.4062, -0.8621, 0, 0, 0),
    (3899100, 66, -931.5305, -5549.9062, -1.1121, 0, 0, 0),
    (3899100, 67, -930.5305, -5548.1562, -0.1121, 0, 0, 0),
    (3899100, 68, -929.5305, -5546.4062, -0.1121, 0, 0, 0),
    (3899100, 69, -928.5814, -5544.6430, -0.3697, 0, 0, 0),
    (3899100, 70, -928.0814, -5543.8930, -0.3697, 0, 0, 0),
    (3899100, 71, -927.5814, -5542.8930, -1.3697, 0, 0, 0),
    (3899100, 72, -927.0814, -5542.1430, -1.3697, 0, 0, 0),
    (3899100, 73, -924.0814, -5536.8930, -1.1197, 0, 0, 0),
    (3899100, 74, -917.0814, -5524.6430, -1.1197, 0, 0, 0),
    (3899100, 75, -879.4793, -5520.9490, -0.9110, 0, 0, 0),
    (3899100, 76, -842.4445, -5532.7275, -1.1507, 0, 0, 0),
    (3899100, 77, -841.6660, -5529.1660, -1.1509, 0, 0, 0),
    (3899100, 78, -832.4551, -5536.8535, -1.3327, 0, 0, 0),
    (3899100, 79, -830.9199, -5538.1350, -0.9998, 0, 0, 0),
    (3899100, 80, -830.1523, -5538.7754, -0.7825, 0, 0, 0),
    (3899100, 81, -828.6172, -5540.0566, -0.5620, 0, 0, 0),
    (3899100, 82, -827.8496, -5540.6973, -0.3363, 0, 0, 0),
    (3899100, 83, -826.3144, -5541.9785, -0.1169, 0, 0, 0),
    (3899100, 84, -824.7793, -5543.2600, 0.2422, 0, 0, 0),
    (3899100, 85, -823.2441, -5544.5410, 0.4408, 0, 0, 0),
    (3899100, 86, -822.4766, -5545.1816, 0.6168, 0, 0, 0),
    (3899100, 87, -820.9414, -5546.4630, 0.8050, 0, 0, 0),
    (3899100, 88, -819.4062, -5547.7440, 0.9908, 0, 0, 0),
    (3899100, 89, -816.6660, -5550.0000, 1.0935, 0, 0, 0),
    (3899100, 90, -815.3144, -5551.3555, 2.4101, 0, 0, 0),
    (3899100, 91, -814.2095, -5551.8516, 3.3053, 0, 0, 0),
    (3899100, 92, -810.5312, -5553.5176, 4.2153, 0, 0, 0),
    (3899101, 1, -807.6857, -5554.4863, 4.9872, 0, 0, 0),
    (3899101, 2, -809.4357, -5553.9863, 4.7372, 0, 0, 0),
    (3899101, 3, -813.6857, -5552.7363, 3.7372, 0, 0, 0),
    (3899101, 4, -815.6857, -5552.2363, 3.2372, 0, 0, 0),
    (3899101, 5, -818.1857, -5552.2363, 1.7372, 0, 0, 0),
    (3899101, 6, -819.9357, -5551.4863, 1.4872, 0, 0, 0),
    (3899101, 7, -821.9357, -5550.7363, 1.2372, 0, 0, 0),
    (3899101, 8, -824.6857, -5549.4863, 0.9872, 0, 0, 0),
    (3899101, 9, -826.4357, -5548.7363, 0.7372, 0, 0, 0),
    (3899101, 10, -827.4357, -5548.2363, 0.4872, 0, 0, 0),
    (3899101, 11, -829.1857, -5547.4863, 0.2372, 0, 0, 0),
    (3899101, 12, -831.9357, -5546.2363, -0.2628, 0, 0, 0),
    (3899101, 13, -833.6857, -5545.4863, -0.5128, 0, 0, 0),
    (3899101, 14, -835.6857, -5544.7363, -0.7628, 0, 0, 0),
    (3899101, 15, -885.7594, -5523.0810, -1.0145, 0, 0, 0),
    (3899101, 16, -912.2594, -5519.8310, -1.2645, 0, 0, 0),
    (3899101, 17, -913.3368, -5519.6562, -1.3610, 0, 0, 0);

-- ----------------------------------------------------------------------------
-- Vanira (38437): her teleport back after An Ancient Enemy. Retail: gossip 11107
-- with one option (GossipOptionID 37251), shown from her last line on
-- (the script sets the gossip flag then; the fight clears it). The option
-- is a plain gossip option the script answers with Vanira's Recall (73334).
-- ----------------------------------------------------------------------------
UPDATE `creature_template` SET `gossip_menu_id` = 11107, `npcflag` = `npcflag` | 1 WHERE `entry` = 38437;
DELETE FROM `gossip_menu_option` WHERE `MenuId` = 11107 AND `OptionIndex` = 0;
INSERT INTO `gossip_menu_option` (`MenuId`, `OptionIndex`, `OptionIcon`, `OptionText`, `OptionBroadcastTextId`, `OptionType`, `OptionNpcFlag`) VALUES
    (11107, 0, 0, 'Take me back to Darkspear Hold if you would, Vanira.', 39071, 1, 1);
DELETE FROM `gossip_menu_option_action` WHERE `MenuId` = 11107 AND `OptionIndex` = 0;

-- ----------------------------------------------------------------------------
-- Darkspear Rogue novice (38272): ClassId 4, DisplayPower 3 (energy),
-- 100/100. The script gives the pool; the class decides the power type.
-- ----------------------------------------------------------------------------
UPDATE `creature_template` SET `unit_class` = 4 WHERE `entry` = 38272;

-- Darkspear Warrior novice (38268): ClassId 1, DisplayPower 3 (rage),
-- 100/100. The script gives the pool; the class decides the power type.
-- ----------------------------------------------------------------------------
UPDATE `creature_template` SET `unit_class` = 1 WHERE `entry` = 38268;