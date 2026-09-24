-- BFA-HavenCore
-- Northshire (zone 6170) rework from the retail warrior sniff (12.1.0.69933).
--
-- Supersedes the Northshire parts of:
--   2026_08_04.sql                                   (Extinguishing Hope credit)
--   2026_09_09_00_rabbit_terrified_northshire.sql    (wrong area IDs 87/88/89)
--   2026_09_09_01_rabbit_terrified_northshire_fix.sql
--   2026_09_16_03_world_northshire_early_quests.sql
--
-- Every spell, aura, emote and anim kit below was checked against the 8.3.7
-- DB2 files; Shadowlands-only IDs from the sniff (auras 349927/349892,
-- phases 22169/22219/22373) are replaced by their 8.3.7 equivalent or dropped.
-- Idempotent: every block deletes/reasserts its own rows so the file works on
-- existing databases and on fresh source pulls.

-- ============================================================================
-- Script ownership
-- ============================================================================

UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_northshire_stormwind_infantry'         WHERE `entry` = 49869;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_northshire_blackrock_worg'             WHERE `entry` = 49871;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_northshire_brother_paxton'             WHERE `entry` = 951;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_northshire_blackrock_spy'              WHERE `entry` = 49874;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_northshire_injured_stormwind_infantry' WHERE `entry` = 50047;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_northshire_vineyard_fire'              WHERE `entry` = 42940;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_training_dummy'                        WHERE `entry` = 44548;
UPDATE `creature_template` SET `AIName` = 'SmartAI', `ScriptName` = ''                                   WHERE `entry` IN (197, 9296, 42937, 42938, 44564, 50039);

-- Legacy SmartAI replaced by C++ above (plus their action lists).
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (951, 42940, 44548, 49869, 49871, 49874, 50047, 50378);
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` IN (95100, 4986900, 4986901, 4986902, 4986903, 4987400, 4987401, 5004700, 5037800);

DELETE FROM `spell_script_names` WHERE `spell_id` = 93072 AND `ScriptName` IN ('spell_quest_fear_no_evil', 'spell_q28813_get_our_boys_back_dummy', 'spell_northshire_get_our_boys_back');
DELETE FROM `spell_script_names` WHERE `spell_id` = 80208 AND `ScriptName` IN ('spell_quest_extincteur', 'spell_northshire_spray_water');
-- 93072 needs no script: it targets the clicker, so the injured soldier's
-- OnSpellClick owns the revive and the quest credit.
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(80208, 'spell_northshire_spray_water');

-- ============================================================================
-- Template fields that differ from the sniff
-- ============================================================================

-- Blackrock Worg: FactionTemplate 32 on every create/values update.
UPDATE `creature_template` SET `faction` = 32 WHERE `entry` = 49871;

-- Injured Stormwind Infantry: faction 12, spellclick only, flags 0xC300.
UPDATE `creature_template` SET `faction` = 12, `npcflag` = 16777216, `unit_flags` = 49920, `unit_flags2` = 0, `unit_flags3` = 16 WHERE `entry` = 50047;
-- Sniff: injured soldiers keep their random 30-50% health; regeneration
-- refilled it within seconds.
UPDATE `creature_template` SET `RegenHealth` = 0 WHERE `entry` = 50047;

-- Northshire Vineyards Fire Trigger: faction 35.
UPDATE `creature_template` SET `faction` = 35 WHERE `entry` = 42940;

-- Kurtok the Slayer: NpcFlags 0 (was questgiver).
UPDATE `creature_template` SET `npcflag` = 0 WHERE `entry` = 42938;

-- ============================================================================
-- creature_template_addon (8.3.7-valid values only)
-- ============================================================================

DELETE FROM `creature_template_addon` WHERE `entry` IN (44548, 49869, 49874, 50047, 42938, 42940);
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`) VALUES
(44548, 0, 0, 0, 1,   0, 0,   0, 0, 0, '83470 98892'), -- Training Dummy: Arcane Missiles Trainer, Training Dummy Marker
(49869, 0, 0, 0, 1, 333, 0,   0, 0, 0, ''),            -- Stormwind Infantry: EMOTE_STATE_READY1H while idle
(49874, 0, 0, 0, 1,   0, 0, 565, 0, 0, '92857'),       -- Blackrock Spy: Spying (8.3.7 equivalent of 349927), sneak walk kit
(50047, 0, 0, 7, 1,   0, 0,   0, 0, 0, ''),            -- Injured Stormwind Infantry: UNIT_STAND_STATE_DEAD
(42938, 0, 0, 0, 1, 375, 0,   0, 0, 0, ''),            -- Kurtok the Slayer: EMOTE_STATE_READY2H
(42940, 0, 0, 0, 1,   0, 0,   0, 0, 3, '80175');       -- Vineyard Fire Trigger: Vineyard Fire, large visibility

-- ============================================================================
-- Equipment (sniff)
-- ============================================================================

DELETE FROM `creature_equip_template` WHERE `CreatureID` = 42937;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `AppearanceModID1`, `ItemVisual1`, `ItemID2`, `AppearanceModID2`, `ItemVisual2`, `ItemID3`, `AppearanceModID3`, `ItemVisual3`, `VerifiedBuild`) VALUES
(42937, 1, 10898, 0, 0, 12456, 0, 0, 0, 0, 0, 0),
(42937, 2, 14877, 0, 0,     0, 0, 0, 0, 0, 0, 0),
(42937, 3, 18062, 0, 0,     0, 0, 0, 0, 0, 0, 0),
(42937, 4, 17383, 0, 0,     0, 0, 0, 0, 0, 0, 0);

-- Blackrock Invaders pick one of the four sets.
UPDATE `creature` SET `equipment_id` = -1 WHERE `id` = 42937;

-- ============================================================================
-- creature_text (sniffed lines with their 8.3.7 BroadcastText IDs)
-- Lines 3-5 of 50047 and 3-4 of 951 were not rolled in the sniff but exist as
-- consecutive BroadcastText entries of the same random pool.
-- ============================================================================

DELETE FROM `creature_text` WHERE `CreatureID` IN (197, 42937, 42938, 49869, 49874, 50039, 50047, 951);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(197, 0, 0, 'You are dismissed, $n.', 12, 0, 100, 66, 0, 0, 1242, 0, 'Marshal McBride - Report to Goldshire accepted'),
(951, 0, 0, 'Be healed, $g brother:sister;!', 12, 0, 100, 0, 0, 0, 49889, 0, 'Brother Paxton - heal'),
(951, 0, 1, 'AND I LAY MY HANDS UPON YOU!', 12, 0, 100, 0, 0, 0, 49890, 0, 'Brother Paxton - heal'),
(951, 0, 2, 'Let the Holy Light embrace you!', 12, 0, 100, 0, 0, 0, 49891, 0, 'Brother Paxton - heal'),
(951, 0, 3, 'BY THE LIGHT BE RENEWED!', 12, 0, 100, 0, 0, 0, 49892, 0, 'Brother Paxton - heal'),
(951, 0, 4, 'FIGHT ON, $G BROTHER:SISTER;!', 12, 0, 100, 0, 0, 0, 49893, 0, 'Brother Paxton - heal'),
(42937, 0, 0, 'Blackrock take forest!', 12, 0, 100, 71, 0, 0, 42879, 0, 'Blackrock Invader - aggro'),
(42937, 0, 1, 'Beg for life!', 12, 0, 100, 0, 0, 0, 42877, 0, 'Blackrock Invader - aggro'),
(42937, 0, 2, 'The grapes were VERY TASTY!', 12, 0, 100, 0, 0, 0, 42880, 0, 'Blackrock Invader - aggro'),
(42938, 0, 0, 'Alliance weakling, your lands will burn!', 12, 0, 100, 5, 0, 0, 0, 0, 'Kurtok the Slayer - aggro (no 8.3.7 BroadcastText)'),
(42938, 1, 0, 'The Blackrock Clan will end you...', 12, 0, 100, 0, 0, 0, 0, 0, 'Kurtok the Slayer - death (no 8.3.7 BroadcastText)'),
(49869, 0, 0, 'I need a heal!', 12, 0, 100, 0, 0, 0, 49898, 0, 'Stormwind Infantry - call for heal'),
(49869, 0, 1, 'I could use a heal, brother!', 12, 0, 100, 0, 0, 0, 49895, 0, 'Stormwind Infantry - call for heal'),
(49869, 0, 2, 'HELP!', 12, 0, 100, 0, 0, 0, 49897, 0, 'Stormwind Infantry - call for heal'),
(49869, 0, 3, 'Make yourself useful and heal me, Paxton!', 12, 0, 100, 0, 0, 0, 49896, 0, 'Stormwind Infantry - call for heal'),
(49874, 0, 0, 'Blackrock take forest!', 12, 0, 100, 0, 0, 0, 42879, 0, 'Blackrock Spy - aggro'),
(49874, 0, 1, 'Orc KILL $r!', 12, 0, 100, 0, 0, 0, 42876, 0, 'Blackrock Spy - aggro'),
(50039, 0, 0, 'We''re gonna burn this place to the ground!', 12, 0, 100, 0, 0, 6594, 49840, 0, 'Goblin Assassin - aggro'),
(50039, 0, 1, 'Time to join your friends, kissin'' the dirt!', 12, 0, 100, 0, 0, 0, 49838, 0, 'Goblin Assassin - aggro'),
(50039, 0, 2, 'DIE!!!', 12, 0, 100, 0, 0, 6594, 49839, 0, 'Goblin Assassin - aggro'),
(50047, 0, 0, 'I... I''m ok! I''m ok!', 12, 0, 100, 5, 0, 0, 49919, 0, 'Injured Stormwind Infantry - revived'),
(50047, 0, 1, 'You''re $n! The hero that everyone has been talking about! Thank you!', 12, 0, 100, 25, 0, 0, 49922, 0, 'Injured Stormwind Infantry - revived'),
(50047, 0, 2, 'Thank the Light!', 12, 0, 100, 4, 0, 0, 49915, 0, 'Injured Stormwind Infantry - revived'),
(50047, 0, 3, 'Bless you, hero!', 12, 0, 100, 0, 0, 0, 49916, 0, 'Injured Stormwind Infantry - revived'),
(50047, 0, 4, 'I will fear no evil!', 12, 0, 100, 0, 0, 0, 49917, 0, 'Injured Stormwind Infantry - revived'),
(50047, 0, 5, 'I live to fight another day!', 12, 0, 100, 0, 0, 0, 49918, 0, 'Injured Stormwind Infantry - revived');

-- ============================================================================
-- SmartAI: only standalone behaviour of three rows or fewer
-- ============================================================================

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (197, 9296, 42937, 42938, 44564, 50039);
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param_string`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(197,   0, 0, 0, 19, 0, 100, 0, 54, 0, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Marshal McBride - On Quest ''Report to Goldshire'' Taken - Say Line 0'),
(197,   0, 1, 0, 19, 0, 100, 0, 54, 0, 0, 0, 0, '', 11, 6245, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Marshal McBride - On Quest ''Report to Goldshire'' Taken - Cast ''Force Target - Salute'''),
(42937, 0, 0, 0, 4,  0, 20,  0, 0, 0, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Blackrock Invader - On Aggro - Say Line 0'),
(42937, 0, 1, 0, 1,  0, 100, 0, 7000, 28000, 7000, 28000, 0, '', 5, 71, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Blackrock Invader - Out of Combat - Play Emote ''OneShotCheerNoSheathe'''),
(42938, 0, 0, 0, 4,  0, 100, 0, 0, 0, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Kurtok the Slayer - On Aggro - Say Line 0'),
(42938, 0, 1, 0, 6,  0, 100, 0, 0, 0, 0, 0, 0, '', 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Kurtok the Slayer - On Death - Say Line 1'),
(44564, 0, 0, 0, 1,  0, 100, 0, 0, 30000, 180000, 390000, 0, '', 11, 46577, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Wounded Trainee - Out of Combat - Cast ''Wounded'''),
(50039, 0, 0, 0, 4,  0, 30,  0, 0, 0, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 'Goblin Assassin - On Aggro - Say Line 0');
-- Milly Osworth (9296) intentionally has no rows: spell_area owns aura 80209.

-- ============================================================================
-- Fear No Evil - spellclick and objective
-- ============================================================================

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 50047;
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(50047, 93072, 1, 0);

-- One OR branch per class variant; ConditionType 9 = quest taken (incomplete).
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 18 AND `SourceGroup` = 50047 AND `SourceEntry` = 93072;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(18, 50047, 93072, 0, 0, 9, 0, 28806, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Hunter) taken'),
(18, 50047, 93072, 0, 1, 9, 0, 28808, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Mage) taken'),
(18, 50047, 93072, 0, 2, 9, 0, 28809, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Paladin) taken'),
(18, 50047, 93072, 0, 3, 9, 0, 28810, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Priest) taken'),
(18, 50047, 93072, 0, 4, 9, 0, 28811, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Rogue) taken'),
(18, 50047, 93072, 0, 5, 9, 0, 28812, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Warlock) taken'),
(18, 50047, 93072, 0, 6, 9, 0, 28813, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Warrior) taken'),
(18, 50047, 93072, 0, 7, 9, 0, 29082, 0, 0, 0, 0, 0, '', 'Injured Stormwind Infantry - Fear No Evil (Monk) taken');

UPDATE `quest_objectives` SET `Description` = 'Injured Soldier revived' WHERE `ObjectID` = 50047 AND `QuestID` IN (28806, 28808, 28809, 28810, 28811, 28812, 28813, 29082);

-- ============================================================================
-- Extinguishing Hope (26391)
-- ============================================================================

-- 80209 Fire Extinguisher: quest status mask 10 = COMPLETE | INCOMPLETE,
-- flags 3 = AUTOCAST | AUTOREMOVE.
DELETE FROM `spell_area` WHERE `spell` = 80209;
INSERT INTO `spell_area` (`spell`, `area`, `quest_start`, `quest_start_status`, `quest_end_status`, `quest_end`, `aura_spell`, `teamId`, `racemask`, `gender`, `flags`) VALUES
(80209, 9,  26391, 10, 0, 0, 0, -1, 0, 2, 3),
(80209, 59, 26391, 10, 0, 0, 0, -1, 0, 2, 3);

-- 80199 Spray Water (item use): only while the quest is active, in areas 9/59.
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 17 AND `SourceEntry` = 80199;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(17, 0, 80199, 0, 0,  9, 0, 26391, 0, 0, 0, 0, 0, '', 'Spray Water - Extinguishing Hope taken'),
(17, 0, 80199, 0, 0, 23, 0,     9, 0, 0, 0, 0, 0, '', 'Spray Water - in Northshire Valley'),
(17, 0, 80199, 0, 1,  9, 0, 26391, 0, 0, 0, 0, 0, '', 'Spray Water - Extinguishing Hope taken'),
(17, 0, 80199, 0, 1, 23, 0,    59, 0, 0, 0, 0, 0, '', 'Spray Water - in Northshire Vineyards');

-- 80208 Spray Water (effect): effect 0 only hits the fire trigger.
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceEntry` = 80208;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(13, 1, 80208, 0, 0, 31, 0, 3, 42940, 0, 0, 0, 0, '', 'Spray Water - target Northshire Vineyards Fire Trigger');

-- ============================================================================
-- Rabbit (721) Terrified: the sniff shows no Terrified cast or aura on any
-- Northshire critter, so the rabbit's proximity cast is disabled inside
-- Northshire (zone 6170) and left untouched elsewhere.
-- ============================================================================

DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 22 AND ((`SourceGroup` = 721 AND `SourceEntry` = 0) OR (`SourceGroup` = 1 AND `SourceEntry` = 721));
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(22, 1, 721, 0, 0, 4, 1, 6170, 0, 0, 1, 0, 0, '', 'Rabbit - never cast Terrified in Northshire');

-- ============================================================================
-- Quests
-- ============================================================================

-- Fear No Evil prerequisites were crossed: the sniff shows a warrior receiving
-- 28813 after Join the Battle! 28789, so 28809 belongs to the paladin (28785).
UPDATE `quest_template_addon` SET `PrevQuestID` = 28785, `AllowableClasses` = 2   WHERE `ID` = 28809;
UPDATE `quest_template_addon` SET `PrevQuestID` = 28789, `AllowableClasses` = 1   WHERE `ID` = 28813;
UPDATE `quest_template_addon` SET `AllowableClasses` = 4   WHERE `ID` = 28806;
UPDATE `quest_template_addon` SET `AllowableClasses` = 128 WHERE `ID` = 28808;
UPDATE `quest_template_addon` SET `AllowableClasses` = 16  WHERE `ID` = 28810;
UPDATE `quest_template_addon` SET `AllowableClasses` = 8   WHERE `ID` = 28811;
UPDATE `quest_template_addon` SET `AllowableClasses` = 256 WHERE `ID` = 28812;

-- Quest givers the sniff does not show.
DELETE FROM `creature_queststarter` WHERE (`id` = 197 AND `quest` = 28823) OR (`id` = 42938 AND `quest` = 26390) OR (`id` = 240 AND `quest` = 54);
DELETE FROM `creature_queststarter` WHERE `id` = 50039 AND `quest` IN (28791, 28792, 28793, 28794, 28795, 28796, 28797, 29081, 31144);

UPDATE `quest_template` SET `QuestDescription` = 'Have you ever seen a goblin, $n? They''re wretched little monsters that love only two things: gold and themselves.$B$BThe Blackrock orcs have enlisted the aid of goblin assassins to kill our soldiers. If you look to the field in the north you can barely make out their silhouettes, sneaking about in the grass.$B$BI need you to head out there and kill every goblin that you see. They need to learn that nobody messes with the Alliance!' WHERE `ID` IN (28791, 28792, 28793, 28794, 28795, 28796, 28797, 29081, 31144);
UPDATE `quest_template` SET `QuestDescription` = 'The rampaging orc horde is led by a savage beast known as Kurtok the Slayer! Kurtok is responsible for the recent invasion and must be killed if we are to have peace in the valley.$B$BVenture back east, across the river and through the vineyard, and look for the passage leading into the mountains. Kurtok will be there, preparing for another assault. Kill him and return to me.' WHERE `ID` = 26390;
UPDATE `quest_template` SET `QuestDescription` = '$n, you are a $c with proven interest in the security of Northshire. You are now tasked with the protection of the surrounding Elwynn Forest.' WHERE `ID` = 54;

UPDATE `quest_offer_reward` SET `RewardText` = 'With Kurtok slain, we are safe once again from the orcish hordes. I will send peasants to the pass in an attempt to seal the passage so that no more orcs may come through into our territory.$B$BYou have the thanks of Stormwind and of the Alliance, hero!' WHERE `ID` = 26390;
UPDATE `quest_offer_reward` SET `RewardText` = 'Bless your heart, $n. You truly are a hero of the Alliance! Though the land is completely incinerated and there is nothing left of the vineyard but ash and debris, I still might be able to recover. Right? How bad can it be?' WHERE `ID` = 26391;

-- Sniffed quest-giver emotes, applied to every class variant of the quest.
DELETE FROM `quest_details` WHERE `ID` IN (54, 26389, 26390, 26391, 28757, 28759, 28762, 28763, 28764, 28765, 28766, 28767, 28769, 28770, 28771, 28772, 28773, 28774, 28780, 28784, 28785, 28786, 28787, 28788, 28789, 28791, 28792, 28793, 28794, 28795, 28796, 28797, 28806, 28808, 28809, 28810, 28811, 28812, 28813, 28817, 28818, 28819, 28820, 28821, 28822, 28823, 29078, 29079, 29080, 29081, 29082, 29083, 31139, 31140, 31143, 31144, 31145, 37112);
INSERT INTO `quest_details` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `VerifiedBuild`) VALUES
(54, 1, 0, 0, 0, 0, 0, 0, 0, 0),
(26389, 1, 1, 1, 0, 0, 0, 0, 0, 0),
(26390, 1, 1, 0, 0, 0, 0, 0, 0, 0),
(26391, 1, 1, 20, 0, 0, 0, 0, 0, 0),
(28757, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(28759, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(28762, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(28763, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(28764, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(28765, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(28766, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(28767, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(28769, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(28770, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(28771, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(28772, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(28773, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(28774, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(28780, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(28784, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(28785, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(28786, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(28787, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(28788, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(28789, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(28791, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(28792, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(28793, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(28794, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(28795, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(28796, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(28797, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(28806, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(28808, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(28809, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(28810, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(28811, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(28812, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(28813, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(28817, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(28818, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(28819, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(28820, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(28821, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(28822, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(28823, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(29078, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(29079, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(29080, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(29081, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(29082, 6, 5, 5, 20, 0, 0, 0, 0, 0),
(29083, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(31139, 6, 2, 1, 5, 0, 0, 0, 0, 0),
(31140, 274, 1, 25, 5, 0, 0, 0, 0, 0),
(31143, 1, 1, 1, 1, 0, 0, 0, 0, 0),
(31144, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(31145, 273, 0, 0, 0, 0, 0, 0, 0, 0),
(37112, 1, 1, 0, 0, 0, 0, 0, 0, 0);

UPDATE `quest_offer_reward` SET `Emote1` = 4, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 26389;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 5, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 26390;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 5, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 26391;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28757;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 28759;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28762;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28763;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28764;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28765;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28766;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28767;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 28769;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 28770;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 28771;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 28772;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 28773;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 28774;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28780;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28784;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28785;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28786;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28787;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28788;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28789;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28791;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28792;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28793;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28794;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28795;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28796;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28797;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28806;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28808;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28809;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28810;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28811;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28812;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 28813;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 28817;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 28818;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 28819;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 28820;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 28821;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 28822;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 28823;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 29078;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 29079;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 29080;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 29081;
UPDATE `quest_offer_reward` SET `Emote1` = 273, `Emote2` = 4, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 29082;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 29083;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 31139;
UPDATE `quest_offer_reward` SET `Emote1` = 21, `Emote2` = 1, `Emote3` = 5, `Emote4` = 0 WHERE `ID` = 31140;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 31143;
UPDATE `quest_offer_reward` SET `Emote1` = 0, `Emote2` = 0, `Emote3` = 0, `Emote4` = 0 WHERE `ID` = 31144;
UPDATE `quest_offer_reward` SET `Emote1` = 1, `Emote2` = 1, `Emote3` = 1, `Emote4` = 5 WHERE `ID` = 31145;

UPDATE `quest_request_items` SET `EmoteOnComplete` = 6 WHERE `ID` = 26389;

-- ============================================================================
-- Spawns
-- Custom GUID block 280010000-280010099 is reserved for this file.
-- ============================================================================

DELETE FROM `creature_addon` WHERE `guid` BETWEEN 280010000 AND 280010099;
DELETE FROM `creature` WHERE `guid` BETWEEN 280010000 AND 280010099;

-- Blackrock Worg partners: 11 infantry fight a worg standing next to them in
-- the sniff; none of the existing worg spawns is within 17 yards of one.
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
-- The last four rows are the infantry that fight a worg arriving later in the
-- sniff; the worg is placed where that fight happened, 2 yards in front.
(280010000, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8979.491, -66.0018, 90.2411, 0.7743, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010001, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8949.374, -91.4042, 86.6072, 1.8037, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010002, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -9006.292, -130.3938, 84.1027, 2.8855, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010003, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8976.918, -56.091, 91.5876, 5.4356, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010004, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8984.577, -148.784, 81.512, 0.7347, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010005, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8970.746, -82.9759, 87.0266, 4.8435, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010006, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8958.347, -228.5892, 77.662, 2.4336, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010007, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8819.729, -140.2604, 81.1097, 3.907, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010008, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -9017.747, -119.0098, 87.0215, 1.7412, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010009, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8809.524, -149.9288, 83.0105, 2.9953, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010010, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8805.082, -162.1457, 81.8812, 4.9395, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010011, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8913.0336, -77.6985, 87.3991, 4.8305, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010012, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8873.7802, -119.037, 81.274, 4.7881, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010013, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8856.2832, -133.5369, 81.2662, 3.8675, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010014, 49871, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8837.8725, -148.3034, 80.8318, 0.1567, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0);

-- Stormwind Infantry 10189903 is not in the sniff (15 infantry, all matched
-- to other spawns).
DELETE FROM `creature_addon` WHERE `guid` = 10189903;
DELETE FROM `creature` WHERE `guid` = 10189903;

-- Northshire Vineyards Fire Trigger: 25 fire positions seen in the sniff but
-- missing from the database.
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(280010020, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9092.8125, -302.8438, 73.6411, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010021, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9078.201, -288.5556, 73.6935, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010022, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9058.917, -304.9236, 73.5485, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010023, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9052.04, -323.1823, 73.5352, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010024, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9091.698, -324.2135, 73.5365, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010025, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9041.719, -363.3177, 75.2282, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010026, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9030.243, -349.7083, 75.5618, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010027, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9015.167, -332.1094, 74.9659, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010028, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9034.441, -322.9931, 73.6083, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010029, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9052.895, -350.2639, 76.0264, 1.85, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010030, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9048.427, -346.8385, 73.5409, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010031, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9067.018, -328.7934, 73.5351, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010032, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9047.935, -333.974, 75.4837, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010033, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9047.776, -308.2274, 73.7371, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010034, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9043.076, -303.3889, 74.2259, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010035, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9079.915, -364.2344, 73.5351, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010036, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9071.726, -309.1146, 73.535, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010037, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9103.622, -321.0695, 73.3702, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010038, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9118.252, -325.9149, 75.7834, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010039, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9112.3545, -341.6545, 73.4368, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010040, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9101.982, -363.0573, 75.02, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010041, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9093.609, -358.816, 73.5358, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010042, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9078.141, -325.8733, 73.5351, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010043, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9125.844, -339.1076, 73.8136, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010044, 42940, 0, 6170, 59, '0', 0, 0, 0, -1, 0, 0, -9080.944, -314.651, 73.534, 0, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0);

-- Sniff: extinguished fires relit after 100-240 seconds.
UPDATE `creature` SET `spawntimesecs` = 180 WHERE `id` = 42940;

-- Random movement radii measured from the sniff.
UPDATE `creature` SET `spawndist` = 10, `MovementType` = 1 WHERE `id` = 49871 AND `guid` NOT BETWEEN 280010000 AND 280010099;
UPDATE `creature` SET `spawndist` = 7,  `MovementType` = 1 WHERE `id` = 50039;
UPDATE `creature` SET `spawndist` = 5 WHERE `id` = 42937 AND `MovementType` = 1;

-- Blackrock Spy: 14 kneel with a spyglass, 8 sneak-patrol fixed loops.
UPDATE `creature` SET `MovementType` = 0, `spawndist` = 0 WHERE `guid` IN (178205, 178233, 178238, 178242, 178250, 178271, 178340, 178341, 178342, 178345, 178347, 178432, 178484, 280001862);
UPDATE `creature` SET `position_x` = -8966.63, `position_y` = -181.8872, `position_z` = 81.0374, `orientation` = 0.733 WHERE `guid` = 280001862;
UPDATE `creature` SET `position_x` = -8790.717, `position_y` = -87.0955, `position_z` = 87.3718, `orientation` = 4.2586 WHERE `guid` = 178341;
DELETE FROM `creature_addon` WHERE `guid` IN (178184, 178204, 178205, 178233, 178238, 178242, 178248, 178250, 178254, 178271, 178280, 178340, 178341, 178342, 178345, 178347, 178432, 178460, 178475, 178484, 280001862);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`) VALUES
(178205, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178233, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178238, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178242, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178250, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178271, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178340, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178341, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178345, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178347, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178432, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178484, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(280001862, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(178342, 0, 0, 0, 1, 0, 0, 565, 0, 0, '92857'),
(178184, 1781840, 0, 0, 1, 0, 0, 565, 0, 0, '92857'),
(178204, 1782040, 0, 0, 1, 0, 0, 565, 0, 0, '92857'),
(178248, 1782480, 0, 0, 1, 0, 0, 565, 0, 0, '92857'),
(178254, 1782540, 0, 0, 1, 0, 0, 565, 0, 0, '92857'),
(178280, 1782800, 0, 0, 1, 0, 0, 565, 0, 0, '92857'),
(178460, 1784600, 0, 0, 1, 0, 0, 565, 0, 0, '92857'),
(178475, 1784750, 0, 0, 1, 0, 0, 565, 0, 0, '92857');

UPDATE `creature` SET `MovementType` = 2, `spawndist` = 0 WHERE `guid` IN (178184, 178204, 178248, 178254, 178280, 178460, 178475);
DELETE FROM `waypoint_data` WHERE `id` IN (1781840, 1782040, 1782480, 1782540, 1782800, 1784600, 1784750);
-- Sniff: spies loop continuously; the long single pauses in the capture are
-- visibility gaps, not waits.
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(1781840, 1, -8964.95, -58.192, 92.152, 0, 0, 0, 0, 100, 0),
(1781840, 2, -8966.633, -59.51, 92.128, 0, 0, 0, 0, 100, 0),
(1782040, 1, -8901.797, -42.234, 87.62, 0, 0, 0, 0, 100, 0),
(1782040, 2, -8906.135, -39.24, 89.253, 0, 0, 0, 0, 100, 0),
(1782040, 3, -8911.556, -40.547, 89.5, 0, 0, 0, 0, 100, 0),
(1782040, 4, -8908.584, -39.859, 89.28, 0, 0, 0, 0, 100, 0),
(1782480, 1, -8982.419, -206.398, 74.37, 0, 0, 0, 0, 100, 0),
(1782480, 2, -8982.058, -208.523, 74.275, 0, 0, 0, 0, 100, 0),
(1782480, 3, -8979.217, -209.502, 74.197, 0, 0, 0, 0, 100, 0),
(1782480, 4, -8982.428, -204.725, 74.621, 0, 0, 0, 0, 100, 0),
(1782540, 1, -8932.197, -244.814, 79.211, 0, 0, 0, 0, 100, 0),
(1782540, 2, -8933.184, -246.451, 79.023, 0, 0, 0, 0, 100, 0),
(1782800, 1, -8929.105, -68.804, 90.029, 0, 0, 0, 0, 100, 0),
(1782800, 2, -8923.313, -71.062, 89.502, 0, 0, 0, 0, 100, 0),
(1784600, 1, -8876.063, -91.867, 83.806, 0, 0, 0, 0, 100, 0),
(1784600, 2, -8874.354, -91.518, 83.482, 0, 0, 0, 0, 100, 0),
(1784600, 3, -8871.784, -92.55, 83.052, 0, 0, 0, 0, 100, 0),
(1784750, 1, -9022.004, -181.549, 76.764, 0, 0, 0, 0, 100, 0),
(1784750, 2, -9026.17, -174.002, 77.444, 0, 0, 0, 0, 100, 0),
(1784750, 3, -9024.731, -167.98, 78.554, 0, 0, 0, 0, 100, 0),
(1784750, 4, -9025.848, -172.296, 78.032, 0, 0, 0, 0, 100, 0),
(1784750, 5, -9025.581, -176.481, 77.16, 0, 0, 0, 0, 100, 0),
(1784750, 6, -9024.15, -179.122, 76.927, 0, 0, 0, 0, 100, 0);

-- Two spies present in the sniff but missing from the database.
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnDifficulties`, `phaseUseFlags`, `PhaseId`, `PhaseGroup`, `terrainSwapMap`, `modelid`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `spawndist`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `dynamicflags`, `ScriptName`, `VerifiedBuild`) VALUES
(280010060, 49874, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8839.67, -119.2448, 80.5284, 3.4034, 300, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(280010061, 49874, 0, 6170, 9, '0', 0, 0, 0, -1, 0, 0, -8774.663, -81.41, 89.014, 0, 300, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, '', 0);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`) VALUES
(280010060, 0, 0, 8, 1, 0, 0, 565, 0, 0, '92857 80676'),
(280010061, 2800100610, 0, 0, 1, 0, 0, 565, 0, 0, '92857');
DELETE FROM `waypoint_data` WHERE `id` = 2800100610;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(2800100610, 1, -8774.663, -81.41, 89.014, 0, 0, 0, 0, 100, 0),
(2800100610, 2, -8775.49, -79.972, 89.169, 0, 0, 0, 0, 100, 0),
(2800100610, 3, -8780.172, -78.83, 89.705, 0, 0, 0, 0, 100, 0),
(2800100610, 4, -8778.455, -78.921, 89.68, 0, 0, 0, 0, 100, 0);

-- Northshire Peasant: every peasant in the sniff stands still chopping
-- (EmoteState 234); the pathing ones walked around mid-chop.
UPDATE `creature` SET `MovementType` = 0, `spawndist` = 0 WHERE `id` = 11260 AND `zoneId` = 6170;
UPDATE `creature_addon` SET `path_id` = 0 WHERE `guid` IN (6364, 177909, 280001861);
DELETE FROM `waypoint_data` WHERE `id` IN (6364, 177909, 280001861);

-- Stormwind Royal Guard: the sniff has two unmounted guards standing at the
-- abbey and four riders; no lone walking guard and no aura on any of them.
DELETE FROM `creature_addon` WHERE `guid` = 280001863;
DELETE FROM `waypoint_data` WHERE `id` = 280001863;
DELETE FROM `creature` WHERE `guid` = 280001863;

-- Stormwind Flag Carrier (78855) is recast every second out of combat by the
-- shared 42218 script; no Northshire guard carries it in the sniff.
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 22 AND `SourceGroup` = 9 AND `SourceEntry` = 42218 AND `SourceId` = 0;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(22, 9, 42218, 0, 0, 4, 1, 6170, 0, 0, 1, 0, 0, '', 'Stormwind Royal Guard - no Stormwind Flag Carrier in Northshire');

-- Mounted patrol: overridden from the sniff (see the Riders block below).

-- The route walked by 280001864 is the sniffed Northshire Guard patrol,
-- not a Royal Guard.
UPDATE `creature` SET `id` = 1642, `modelid` = 0, `equipment_id` = 1 WHERE `guid` = 280001864;
UPDATE `creature_addon` SET `auras` = '18950' WHERE `guid` = 280001864;

-- Both Northshire Guard foot patrols, one full lap each from the sniff.
UPDATE `creature` SET `position_x` = -9031.2, `position_y` = 4.6, `position_z` = 88.19, `MovementType` = 2, `spawndist` = 0 WHERE `guid` = 177881;
DELETE FROM `waypoint_data` WHERE `id` = 1778810;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(1778810, 1, -9031.2, 4.6, 88.19, 0, 0, 0, 0, 100, 0),
(1778810, 2, -9020.28, 3.15, 88.42, 0, 0, 0, 0, 100, 0),
(1778810, 3, -9012.08, -14.76, 88.37, 0, 0, 0, 0, 100, 0),
(1778810, 4, -9010.28, -34.81, 88.04, 0, 0, 0, 0, 100, 0),
(1778810, 5, -9009.69, -53.73, 87.29, 0, 0, 0, 0, 100, 0),
(1778810, 6, -9007.62, -70.44, 86.66, 0, 0, 0, 0, 100, 0),
(1778810, 7, -9006.88, -78.34, 86.55, 0, 1500, 0, 0, 100, 0),
(1778810, 8, -9009.57, -58.1, 87.15, 0, 0, 0, 0, 100, 0),
(1778810, 9, -9009.41, -31.61, 88.2, 0, 0, 0, 0, 100, 0),
(1778810, 10, -9014.08, -3.77, 88.76, 0, 0, 0, 0, 100, 0),
(1778810, 11, -9024.77, 4.27, 88.23, 0, 0, 0, 0, 100, 0),
(1778810, 12, -9035.09, 2.46, 88.23, 0, 0, 0, 0, 100, 0),
(1778810, 13, -9041.21, -21.52, 88.24, 0, 0, 0, 0, 100, 0),
(1778810, 14, -9043.39, -35.01, 88.26, 0, 0, 0, 0, 100, 0),
(1778810, 15, -9045.4, -42.91, 88.35, 0, 2000, 0, 0, 100, 0),
(1778810, 16, -9043.86, -30.39, 88.29, 0, 0, 0, 0, 100, 0),
(1778810, 17, -9040.35, -11.37, 88.24, 0, 0, 0, 0, 100, 0),
(1778810, 18, -9037.48, -0.49, 88.28, 0, 0, 0, 0, 100, 0);
UPDATE `creature` SET `position_x` = -9013.88, `position_y` = -90.98, `position_z` = 86.54, `MovementType` = 2, `spawndist` = 0 WHERE `guid` = 280001864;
DELETE FROM `waypoint_data` WHERE `id` = 280001864;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(280001864, 1, -9013.88, -90.98, 86.54, 0, 2300, 0, 0, 100, 0),
(280001864, 2, -9007.52, -81.2, 86.53, 0, 0, 0, 0, 100, 0),
(280001864, 3, -9021.59, -96.39, 87.04, 0, 0, 0, 0, 100, 0),
(280001864, 4, -9035.88, -102.09, 87.72, 0, 1700, 0, 0, 100, 0),
(280001864, 5, -9046.87, -96.74, 88.06, 0, 0, 0, 0, 100, 0),
(280001864, 6, -9052.14, -86.49, 87.92, 0, 0, 0, 0, 100, 0),
(280001864, 7, -9047.83, -67.83, 88.15, 0, 0, 0, 0, 100, 0),
(280001864, 8, -9046.55, -51.21, 88.2, 0, 0, 0, 0, 100, 0),
(280001864, 9, -9046.15, -44.84, 88.33, 0, 0, 0, 0, 100, 0),
(280001864, 10, -9047.81, -66.25, 88.14, 0, 0, 0, 0, 100, 0),
(280001864, 11, -9051.52, -86.36, 87.96, 0, 0, 0, 0, 100, 0),
(280001864, 12, -9047.5, -95.98, 88.07, 0, 0, 0, 0, 100, 0),
(280001864, 13, -9037.52, -101.63, 87.81, 0, 0, 0, 0, 100, 0),
(280001864, 14, -9024.47, -99.4, 87.35, 0, 0, 0, 0, 100, 0);

-- Brother Paxton: paces four points at the abbey entrance and waits ~4s at
-- both ends (sniff). The old path was ~20 yards off.
UPDATE `creature` SET `position_x` = -8821.775, `position_y` = -148.2708, `position_z` = 81.1155, `orientation` = 2.616, `MovementType` = 2, `spawndist` = 0 WHERE `guid` = 280001860;
DELETE FROM `creature_addon` WHERE `guid` = 280001860;
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`) VALUES
(280001860, 280001860, 0, 0, 257, 0, 0, 0, 0, 0, '13864');
DELETE FROM `waypoint_data` WHERE `id` = 280001860;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(280001860, 1, -8825.132, -146.5087, 80.6217, 0, 4000, 0, 0, 100, 0),
(280001860, 2, -8819.92,  -149.533,  81.1093, 0, 0,    0, 0, 100, 0),
(280001860, 3, -8816.466, -153.0781, 81.5844, 0, 0,    0, 0, 100, 0),
(280001860, 4, -8814.294, -157.2969, 81.6237, 0, 3500, 0, 0, 100, 0),
(280001860, 5, -8816.466, -153.0781, 81.5844, 0, 0,    0, 0, 100, 0),
(280001860, 6, -8819.92,  -149.533,  81.1093, 0, 0,    0, 0, 100, 0);

-- ============================================================================
-- Stormwind Royal Guard riders (177929 leader, 177930-177932)
-- Overridden from the sniff: the leader rides a cyclic 42-point spline
-- (170.4 s per lap at walking speed 2.5); the riders keep a 2x2 box measured
-- from their sniffed positions: left 4.04y, behind-left 5.18y, behind 4.03y.
-- Formation angles are measured from the direction behind the leader.
-- ============================================================================

UPDATE `creature` SET `position_x` = -9018.372, `position_y` = -91.8056, `position_z` = 86.8332, `orientation` = 0.7085, `MovementType` = 2, `spawndist` = 0 WHERE `guid` = 177929;
UPDATE `creature` SET `position_x` = -9020.9632, `position_y` = -88.706, `position_z` = 86.8332, `orientation` = 0.7085, `MovementType` = 0, `spawndist` = 0 WHERE `guid` = 177930;
UPDATE `creature` SET `position_x` = -9023.4763, `position_y` = -90.9235, `position_z` = 86.8332, `orientation` = 0.7085, `MovementType` = 0, `spawndist` = 0 WHERE `guid` = 177932;
UPDATE `creature` SET `position_x` = -9021.5865, `position_y` = -94.2362, `position_z` = 86.8332, `orientation` = 0.7085, `MovementType` = 0, `spawndist` = 0 WHERE `guid` = 177931;
DELETE FROM `creature_addon` WHERE `guid` IN (177929, 177930, 177931, 177932);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `aiAnimKit`, `movementAnimKit`, `meleeAnimKit`, `visibilityDistanceType`, `auras`) VALUES
(177929, 177929, 28912, 0, 257, 0, 0, 0, 0, 0, ''),
(177930, 0, 28912, 0, 257, 0, 0, 0, 0, 0, ''),
(177931, 0, 28912, 0, 257, 0, 0, 0, 0, 0, ''),
(177932, 0, 28912, 0, 257, 0, 0, 0, 0, 0, '');
DELETE FROM `creature_formations` WHERE `leaderGUID` = 177929 OR `memberGUID` IN (177929, 177930, 177931, 177932);
INSERT INTO `creature_formations` (`leaderGUID`, `memberGUID`, `dist`, `angle`, `groupAI`, `point_1`, `point_2`) VALUES
(177929, 177929, 0, 0, 515, 0, 0),
(177929, 177930, 4.04, 269.3, 515, 0, 0),
(177929, 177932, 5.18, 309.6, 515, 0, 0),
(177929, 177931, 4.03, 356.5, 515, 0, 0);
DELETE FROM `waypoint_data` WHERE `id` = 177929;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(177929, 1, -9018.372, -91.8056, 86.8332, 0, 0, 0, 0, 100, 0),
(177929, 2, -9006.399, -81.5451, 86.4465, 0, 0, 0, 0, 100, 0),
(177929, 3, -8998.6045, -86.2361, 85.8491, 0, 0, 0, 0, 100, 0),
(177929, 4, -8992.842, -91.9653, 85.691, 0, 0, 0, 0, 100, 0),
(177929, 5, -8983.901, -100.5868, 85.4158, 0, 0, 0, 0, 100, 0),
(177929, 6, -8974.481, -109.2691, 84.603, 0, 0, 0, 0, 100, 0),
(177929, 7, -8966.538, -112.3733, 84.0327, 0, 0, 0, 0, 100, 0),
(177929, 8, -8955.513, -112.7257, 83.5085, 0, 0, 0, 0, 100, 0),
(177929, 9, -8946.6875, -112.2205, 83.0202, 0, 0, 0, 0, 100, 0),
(177929, 10, -8941.082, -112.6944, 82.7311, 0, 0, 0, 0, 100, 0),
(177929, 11, -8931.592, -114.8924, 82.4603, 0, 0, 0, 0, 100, 0),
(177929, 12, -8925.044, -119.3229, 82.1549, 0, 0, 0, 0, 100, 0),
(177929, 13, -8931.326, -113.9826, 82.5936, 0, 0, 0, 0, 100, 0),
(177929, 14, -8941.308, -111.8837, 82.7908, 0, 0, 0, 0, 100, 0),
(177929, 15, -8947.933, -112.4705, 83.0724, 0, 0, 0, 0, 100, 0),
(177929, 16, -8955.493, -113.1128, 83.4913, 0, 0, 0, 0, 100, 0),
(177929, 17, -8965.458, -112.9705, 83.9191, 0, 0, 0, 0, 100, 0),
(177929, 18, -8970.988, -111.1684, 84.3429, 0, 0, 0, 0, 100, 0),
(177929, 19, -8978.109, -105.934, 84.8735, 0, 0, 0, 0, 100, 0),
(177929, 20, -8984.401, -99.809, 85.4475, 0, 0, 0, 0, 100, 0),
(177929, 21, -8992.832, -92.224, 85.6966, 0, 0, 0, 0, 100, 0),
(177929, 22, -9000.424, -84.4931, 86.0029, 0, 0, 0, 0, 100, 0),
(177929, 23, -9004.776, -75.7378, 86.4009, 0, 0, 0, 0, 100, 0),
(177929, 24, -9006.566, -66.9514, 86.7155, 0, 0, 0, 0, 100, 0),
(177929, 25, -9008.176, -55.5174, 87.2101, 0, 0, 0, 0, 100, 0),
(177929, 26, -9009.259, -40.8524, 87.6965, 0, 0, 0, 0, 100, 0),
(177929, 27, -9009.361, -28.1719, 88.3135, 0, 0, 0, 0, 100, 0),
(177929, 28, -9011.491, -14.3872, 88.4008, 0, 0, 0, 0, 100, 0),
(177929, 29, -9013.333, -5.2969, 88.7014, 0, 0, 0, 0, 100, 0),
(177929, 30, -9018.06, 3.158, 88.5354, 0, 0, 0, 0, 100, 0),
(177929, 31, -9028.255, 5.4913, 88.1654, 0, 0, 0, 0, 100, 0),
(177929, 32, -9035.278, 0.5347, 88.3031, 0, 0, 0, 0, 100, 0),
(177929, 33, -9038.627, -7.4479, 88.2418, 0, 0, 0, 0, 100, 0),
(177929, 34, -9041.927, -18.7361, 88.2418, 0, 0, 0, 0, 100, 0),
(177929, 35, -9043.243, -29.2569, 88.3176, 0, 0, 0, 0, 100, 0),
(177929, 36, -9046.4375, -41.2552, 88.3114, 0, 0, 0, 0, 100, 0),
(177929, 37, -9046.841, -56.8785, 88.1197, 0, 0, 0, 0, 100, 0),
(177929, 38, -9048.52, -79.3785, 88.2133, 0, 0, 0, 0, 100, 0),
(177929, 39, -9049.904, -89.158, 87.9893, 0, 0, 0, 0, 100, 0),
(177929, 40, -9044.969, -97.4566, 88.0189, 0, 0, 0, 0, 100, 0),
(177929, 41, -9036.893, -101.7309, 87.7767, 0, 0, 0, 0, 100, 0),
(177929, 42, -9028.38, -100.8056, 87.5408, 0, 0, 0, 0, 100, 0);

-- ============================================================================
-- Quest POI for every Northshire quest and every class variant.
-- Source: the sniffed warrior quests; class variants share objectives, so
-- each copy only swaps QuestID and its own QuestObjectiveID.
-- ============================================================================

DELETE FROM `quest_poi` WHERE `QuestID` IN (28757, 28762, 28763, 28764, 28765, 28766, 28767, 29078, 31139, 28759, 28769, 28770, 28771, 28772, 28773, 28774, 29079, 31140, 28780, 28784, 28785, 28786, 28787, 28788, 28789, 29080, 31143, 28791, 28792, 28793, 28794, 28795, 28796, 28797, 29081, 31144, 28806, 28808, 28809, 28810, 28811, 28812, 28813, 29082, 28817, 28818, 28819, 28820, 28821, 28822, 28823, 29083, 31145, 26389, 26390, 26391, 54, 37112);
DELETE FROM `quest_poi_points` WHERE `QuestID` IN (28757, 28762, 28763, 28764, 28765, 28766, 28767, 29078, 31139, 28759, 28769, 28770, 28771, 28772, 28773, 28774, 29079, 31140, 28780, 28784, 28785, 28786, 28787, 28788, 28789, 29080, 31143, 28791, 28792, 28793, 28794, 28795, 28796, 28797, 29081, 31144, 28806, 28808, 28809, 28810, 28811, 28812, 28813, 29082, 28817, 28818, 28819, 28820, 28821, 28822, 28823, 29083, 31145, 26389, 26390, 26391, 54, 37112);
INSERT INTO `quest_poi` (`QuestID`, `BlobIndex`, `Idx1`, `ObjectiveIndex`, `QuestObjectiveID`, `QuestObjectID`, `MapID`, `UiMapID`, `Priority`, `Flags`, `WorldEffectID`, `PlayerConditionID`, `SpawnTrackingID`, `AlwaysAllowMergingBlobs`, `VerifiedBuild`) VALUES
(28757, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28757, 0, 1, 0, 252810, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28757, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(28762, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28762, 0, 1, 0, 253905, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28762, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(28763, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28763, 0, 1, 0, 253857, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28763, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(28764, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28764, 0, 1, 0, 253916, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28764, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(28765, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28765, 0, 1, 0, 254088, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28765, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(28766, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28766, 0, 1, 0, 254141, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28766, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(28767, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28767, 0, 1, 0, 254418, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28767, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(29078, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(29078, 0, 1, 0, 251906, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29078, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(31139, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(31139, 0, 1, 0, 268165, 49871, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(31139, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 13833, 0, 0),
(28759, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28759, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28759, 0, 1, 0, 252952, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28759, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28769, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28769, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28769, 0, 1, 0, 254430, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28769, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28770, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28770, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28770, 0, 1, 0, 254546, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28770, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28771, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28771, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28771, 0, 1, 0, 254612, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28771, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28772, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28772, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28772, 0, 1, 0, 255264, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28772, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28773, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28773, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28773, 0, 1, 0, 255513, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28773, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28774, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28774, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28774, 0, 1, 0, 255615, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28774, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29079, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(29079, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(29079, 0, 1, 0, 252034, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29079, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(31140, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(31140, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(31140, 0, 1, 0, 268166, 49874, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(31140, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28780, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28780, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28780, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28784, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28784, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28784, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28785, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28785, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28785, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28786, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28786, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28786, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28787, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28787, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28787, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28788, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28788, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28788, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28789, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(28789, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(28789, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29080, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(29080, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(29080, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(31143, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(31143, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(31143, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28791, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28791, 0, 1, 0, 259128, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28791, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28792, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28792, 0, 1, 0, 259304, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28792, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28793, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28793, 0, 1, 0, 259861, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28793, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28794, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28794, 0, 1, 0, 259834, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28794, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28795, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28795, 0, 1, 0, 259675, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28795, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28796, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28796, 0, 1, 0, 260807, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28796, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28797, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28797, 0, 1, 0, 260876, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28797, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29081, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(29081, 0, 1, 0, 252125, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29081, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(31144, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(31144, 0, 1, 0, 268171, 50039, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(31144, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28806, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(28806, 0, 1, 0, 261586, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28806, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28808, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(28808, 0, 1, 0, 264425, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28808, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28809, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(28809, 0, 1, 0, 264852, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28809, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28810, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(28810, 0, 1, 0, 265064, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28810, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28811, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(28811, 0, 1, 0, 264923, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28811, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28812, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(28812, 0, 1, 0, 265241, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28812, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28813, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(28813, 0, 1, 0, 265231, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28813, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29082, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 533939, 0, 0),
(29082, 0, 1, 0, 252087, 50047, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29082, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28817, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28817, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28818, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28818, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28819, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28819, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28820, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28820, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28821, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28821, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28822, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28822, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(28823, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(28823, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(29083, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(29083, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(31145, 0, 1, 32, 0, 0, 0, 425, 0, 0, 0, 0, 428053, 0, 0),
(31145, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(26389, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(26389, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(26389, 0, 1, 0, 265960, 58361, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(26389, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(26390, 1, 3, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(26390, 0, 2, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(26390, 0, 1, 0, 266814, 42938, 0, 425, 0, 1, 0, 0, 428087, 0, 0),
(26390, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(26391, 0, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 90340, 0, 0),
(26391, 0, 1, 0, 266871, 42940, 0, 425, 0, 3, 0, 0, 0, 0, 0),
(26391, 0, 0, -1, 0, 0, 0, 425, 0, 1, 0, 0, 0, 0, 0),
(54, 1, 2, 32, 0, 0, 0, 425, 0, 0, 0, 0, 13833, 0, 0),
(54, 0, 1, 32, 0, 0, 230, 242, 0, 0, 0, 0, 90937, 0, 0),
(54, 0, 0, -1, 0, 0, 0, 37, 0, 1, 0, 0, 0, 0, 0),
(37112, 0, 1, 32, 0, 0, 0, 37, 0, 0, 0, 0, 79782, 0, 0),
(37112, 0, 0, -1, 0, 0, 0, 37, 0, 1, 0, 0, 0, 0, 0);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(28757, 2, 0, -8913, -137, 0),
(28757, 1, 6, -8949, -94, 0),
(28757, 1, 5, -8992, -77, 0),
(28757, 1, 4, -8965, -33, 0),
(28757, 1, 3, -8804, -37, 0),
(28757, 1, 2, -8785, -106, 0),
(28757, 1, 1, -8828, -156, 0),
(28757, 1, 0, -8894, -138, 0),
(28757, 0, 0, -8913, -137, 0),
(28762, 2, 0, -8913, -137, 0),
(28762, 1, 6, -8949, -94, 0),
(28762, 1, 5, -8992, -77, 0),
(28762, 1, 4, -8965, -33, 0),
(28762, 1, 3, -8804, -37, 0),
(28762, 1, 2, -8785, -106, 0),
(28762, 1, 1, -8828, -156, 0),
(28762, 1, 0, -8894, -138, 0),
(28762, 0, 0, -8913, -137, 0),
(28763, 2, 0, -8913, -137, 0),
(28763, 1, 6, -8949, -94, 0),
(28763, 1, 5, -8992, -77, 0),
(28763, 1, 4, -8965, -33, 0),
(28763, 1, 3, -8804, -37, 0),
(28763, 1, 2, -8785, -106, 0),
(28763, 1, 1, -8828, -156, 0),
(28763, 1, 0, -8894, -138, 0),
(28763, 0, 0, -8913, -137, 0),
(28764, 2, 0, -8913, -137, 0),
(28764, 1, 6, -8949, -94, 0),
(28764, 1, 5, -8992, -77, 0),
(28764, 1, 4, -8965, -33, 0),
(28764, 1, 3, -8804, -37, 0),
(28764, 1, 2, -8785, -106, 0),
(28764, 1, 1, -8828, -156, 0),
(28764, 1, 0, -8894, -138, 0),
(28764, 0, 0, -8913, -137, 0),
(28765, 2, 0, -8913, -137, 0),
(28765, 1, 6, -8949, -94, 0),
(28765, 1, 5, -8992, -77, 0),
(28765, 1, 4, -8965, -33, 0),
(28765, 1, 3, -8804, -37, 0),
(28765, 1, 2, -8785, -106, 0),
(28765, 1, 1, -8828, -156, 0),
(28765, 1, 0, -8894, -138, 0),
(28765, 0, 0, -8913, -137, 0),
(28766, 2, 0, -8913, -137, 0),
(28766, 1, 6, -8949, -94, 0),
(28766, 1, 5, -8992, -77, 0),
(28766, 1, 4, -8965, -33, 0),
(28766, 1, 3, -8804, -37, 0),
(28766, 1, 2, -8785, -106, 0),
(28766, 1, 1, -8828, -156, 0),
(28766, 1, 0, -8894, -138, 0),
(28766, 0, 0, -8913, -137, 0),
(28767, 2, 0, -8913, -137, 0),
(28767, 1, 6, -8949, -94, 0),
(28767, 1, 5, -8992, -77, 0),
(28767, 1, 4, -8965, -33, 0),
(28767, 1, 3, -8804, -37, 0),
(28767, 1, 2, -8785, -106, 0),
(28767, 1, 1, -8828, -156, 0),
(28767, 1, 0, -8894, -138, 0),
(28767, 0, 0, -8913, -137, 0),
(29078, 2, 0, -8913, -137, 0),
(29078, 1, 6, -8949, -94, 0),
(29078, 1, 5, -8992, -77, 0),
(29078, 1, 4, -8965, -33, 0),
(29078, 1, 3, -8804, -37, 0),
(29078, 1, 2, -8785, -106, 0),
(29078, 1, 1, -8828, -156, 0),
(29078, 1, 0, -8894, -138, 0),
(29078, 0, 0, -8913, -137, 0),
(31139, 2, 0, -8913, -137, 0),
(31139, 1, 6, -8949, -94, 0),
(31139, 1, 5, -8992, -77, 0),
(31139, 1, 4, -8965, -33, 0),
(31139, 1, 3, -8804, -37, 0),
(31139, 1, 2, -8785, -106, 0),
(31139, 1, 1, -8828, -156, 0),
(31139, 1, 0, -8894, -138, 0),
(31139, 0, 0, -8913, -137, 0),
(28759, 3, 0, -8913, -138, 0),
(28759, 2, 0, 833, -335, 0),
(28759, 1, 6, -8962, -60, 0),
(28759, 1, 5, -8978, -38, 0),
(28759, 1, 4, -8841, -36, 0),
(28759, 1, 3, -8795, -45, 0),
(28759, 1, 2, -8784, -79, 0),
(28759, 1, 1, -8791, -86, 0),
(28759, 1, 0, -8831, -124, 0),
(28759, 0, 0, -8913, -137, 0),
(28769, 3, 0, -8913, -138, 0),
(28769, 2, 0, 833, -335, 0),
(28769, 1, 6, -8962, -60, 0),
(28769, 1, 5, -8978, -38, 0),
(28769, 1, 4, -8841, -36, 0),
(28769, 1, 3, -8795, -45, 0),
(28769, 1, 2, -8784, -79, 0),
(28769, 1, 1, -8791, -86, 0),
(28769, 1, 0, -8831, -124, 0),
(28769, 0, 0, -8913, -137, 0),
(28770, 3, 0, -8913, -138, 0),
(28770, 2, 0, 833, -335, 0),
(28770, 1, 6, -8962, -60, 0),
(28770, 1, 5, -8978, -38, 0),
(28770, 1, 4, -8841, -36, 0),
(28770, 1, 3, -8795, -45, 0),
(28770, 1, 2, -8784, -79, 0),
(28770, 1, 1, -8791, -86, 0),
(28770, 1, 0, -8831, -124, 0),
(28770, 0, 0, -8913, -137, 0),
(28771, 3, 0, -8913, -138, 0),
(28771, 2, 0, 833, -335, 0),
(28771, 1, 6, -8962, -60, 0),
(28771, 1, 5, -8978, -38, 0),
(28771, 1, 4, -8841, -36, 0),
(28771, 1, 3, -8795, -45, 0),
(28771, 1, 2, -8784, -79, 0),
(28771, 1, 1, -8791, -86, 0),
(28771, 1, 0, -8831, -124, 0),
(28771, 0, 0, -8913, -137, 0),
(28772, 3, 0, -8913, -138, 0),
(28772, 2, 0, 833, -335, 0),
(28772, 1, 6, -8962, -60, 0),
(28772, 1, 5, -8978, -38, 0),
(28772, 1, 4, -8841, -36, 0),
(28772, 1, 3, -8795, -45, 0),
(28772, 1, 2, -8784, -79, 0),
(28772, 1, 1, -8791, -86, 0),
(28772, 1, 0, -8831, -124, 0),
(28772, 0, 0, -8913, -137, 0),
(28773, 3, 0, -8913, -138, 0),
(28773, 2, 0, 833, -335, 0),
(28773, 1, 6, -8962, -60, 0),
(28773, 1, 5, -8978, -38, 0),
(28773, 1, 4, -8841, -36, 0),
(28773, 1, 3, -8795, -45, 0),
(28773, 1, 2, -8784, -79, 0),
(28773, 1, 1, -8791, -86, 0),
(28773, 1, 0, -8831, -124, 0),
(28773, 0, 0, -8913, -137, 0),
(28774, 3, 0, -8913, -138, 0),
(28774, 2, 0, 833, -335, 0),
(28774, 1, 6, -8962, -60, 0),
(28774, 1, 5, -8978, -38, 0),
(28774, 1, 4, -8841, -36, 0),
(28774, 1, 3, -8795, -45, 0),
(28774, 1, 2, -8784, -79, 0),
(28774, 1, 1, -8791, -86, 0),
(28774, 1, 0, -8831, -124, 0),
(28774, 0, 0, -8913, -137, 0),
(29079, 3, 0, -8913, -138, 0),
(29079, 2, 0, 833, -335, 0),
(29079, 1, 6, -8962, -60, 0),
(29079, 1, 5, -8978, -38, 0),
(29079, 1, 4, -8841, -36, 0),
(29079, 1, 3, -8795, -45, 0),
(29079, 1, 2, -8784, -79, 0),
(29079, 1, 1, -8791, -86, 0),
(29079, 1, 0, -8831, -124, 0),
(29079, 0, 0, -8913, -137, 0),
(31140, 3, 0, -8913, -138, 0),
(31140, 2, 0, 833, -335, 0),
(31140, 1, 6, -8962, -60, 0),
(31140, 1, 5, -8978, -38, 0),
(31140, 1, 4, -8841, -36, 0),
(31140, 1, 3, -8795, -45, 0),
(31140, 1, 2, -8784, -79, 0),
(31140, 1, 1, -8791, -86, 0),
(31140, 1, 0, -8831, -124, 0),
(31140, 0, 0, -8913, -137, 0),
(28780, 2, 0, -8913, -138, 0),
(28780, 1, 0, 833, -335, 0),
(28780, 0, 0, -8828, -159, 0),
(28784, 2, 0, -8913, -138, 0),
(28784, 1, 0, 833, -335, 0),
(28784, 0, 0, -8828, -159, 0),
(28785, 2, 0, -8913, -138, 0),
(28785, 1, 0, 833, -335, 0),
(28785, 0, 0, -8828, -159, 0),
(28786, 2, 0, -8913, -138, 0),
(28786, 1, 0, 833, -335, 0),
(28786, 0, 0, -8828, -159, 0),
(28787, 2, 0, -8913, -138, 0),
(28787, 1, 0, 833, -335, 0),
(28787, 0, 0, -8828, -159, 0),
(28788, 2, 0, -8913, -138, 0),
(28788, 1, 0, 833, -335, 0),
(28788, 0, 0, -8828, -159, 0),
(28789, 2, 0, -8913, -138, 0),
(28789, 1, 0, 833, -335, 0),
(28789, 0, 0, -8828, -159, 0),
(29080, 2, 0, -8913, -138, 0),
(29080, 1, 0, 833, -335, 0),
(29080, 0, 0, -8828, -159, 0),
(31143, 2, 0, -8913, -138, 0),
(31143, 1, 0, 833, -335, 0),
(31143, 0, 0, -8828, -159, 0),
(28791, 2, 0, -8828, -159, 0),
(28791, 1, 6, -8809, -257, 0),
(28791, 1, 5, -8826, -213, 0),
(28791, 1, 4, -8771, -102, 0),
(28791, 1, 3, -8752, -89, 0),
(28791, 1, 2, -8691, -78, 0),
(28791, 1, 1, -8728, -201, 0),
(28791, 1, 0, -8767, -279, 0),
(28791, 0, 0, -8828, -159, 0),
(28792, 2, 0, -8828, -159, 0),
(28792, 1, 6, -8809, -257, 0),
(28792, 1, 5, -8826, -213, 0),
(28792, 1, 4, -8771, -102, 0),
(28792, 1, 3, -8752, -89, 0),
(28792, 1, 2, -8691, -78, 0),
(28792, 1, 1, -8728, -201, 0),
(28792, 1, 0, -8767, -279, 0),
(28792, 0, 0, -8828, -159, 0),
(28793, 2, 0, -8828, -159, 0),
(28793, 1, 6, -8809, -257, 0),
(28793, 1, 5, -8826, -213, 0),
(28793, 1, 4, -8771, -102, 0),
(28793, 1, 3, -8752, -89, 0),
(28793, 1, 2, -8691, -78, 0),
(28793, 1, 1, -8728, -201, 0),
(28793, 1, 0, -8767, -279, 0),
(28793, 0, 0, -8828, -159, 0),
(28794, 2, 0, -8828, -159, 0),
(28794, 1, 6, -8809, -257, 0),
(28794, 1, 5, -8826, -213, 0),
(28794, 1, 4, -8771, -102, 0),
(28794, 1, 3, -8752, -89, 0),
(28794, 1, 2, -8691, -78, 0),
(28794, 1, 1, -8728, -201, 0),
(28794, 1, 0, -8767, -279, 0),
(28794, 0, 0, -8828, -159, 0),
(28795, 2, 0, -8828, -159, 0),
(28795, 1, 6, -8809, -257, 0),
(28795, 1, 5, -8826, -213, 0),
(28795, 1, 4, -8771, -102, 0),
(28795, 1, 3, -8752, -89, 0),
(28795, 1, 2, -8691, -78, 0),
(28795, 1, 1, -8728, -201, 0),
(28795, 1, 0, -8767, -279, 0),
(28795, 0, 0, -8828, -159, 0),
(28796, 2, 0, -8828, -159, 0),
(28796, 1, 6, -8809, -257, 0),
(28796, 1, 5, -8826, -213, 0),
(28796, 1, 4, -8771, -102, 0),
(28796, 1, 3, -8752, -89, 0),
(28796, 1, 2, -8691, -78, 0),
(28796, 1, 1, -8728, -201, 0),
(28796, 1, 0, -8767, -279, 0),
(28796, 0, 0, -8828, -159, 0),
(28797, 2, 0, -8828, -159, 0),
(28797, 1, 6, -8809, -257, 0),
(28797, 1, 5, -8826, -213, 0),
(28797, 1, 4, -8771, -102, 0),
(28797, 1, 3, -8752, -89, 0),
(28797, 1, 2, -8691, -78, 0),
(28797, 1, 1, -8728, -201, 0),
(28797, 1, 0, -8767, -279, 0),
(28797, 0, 0, -8828, -159, 0),
(29081, 2, 0, -8828, -159, 0),
(29081, 1, 6, -8809, -257, 0),
(29081, 1, 5, -8826, -213, 0),
(29081, 1, 4, -8771, -102, 0),
(29081, 1, 3, -8752, -89, 0),
(29081, 1, 2, -8691, -78, 0),
(29081, 1, 1, -8728, -201, 0),
(29081, 1, 0, -8767, -279, 0),
(29081, 0, 0, -8828, -159, 0),
(31144, 2, 0, -8828, -159, 0),
(31144, 1, 6, -8809, -257, 0),
(31144, 1, 5, -8826, -213, 0),
(31144, 1, 4, -8771, -102, 0),
(31144, 1, 3, -8752, -89, 0),
(31144, 1, 2, -8691, -78, 0),
(31144, 1, 1, -8728, -201, 0),
(31144, 1, 0, -8767, -279, 0),
(31144, 0, 0, -8828, -159, 0),
(28806, 2, 0, -8823, -150, 0),
(28806, 1, 7, -8810, -218, 0),
(28806, 1, 6, -8793, -113, 0),
(28806, 1, 5, -8766, -93, 0),
(28806, 1, 4, -8736, -95, 0),
(28806, 1, 3, -8715, -113, 0),
(28806, 1, 2, -8724, -162, 0),
(28806, 1, 1, -8752, -250, 0),
(28806, 1, 0, -8786, -263, 0),
(28806, 0, 0, -8823, -150, 0),
(28808, 2, 0, -8823, -150, 0),
(28808, 1, 7, -8810, -218, 0),
(28808, 1, 6, -8793, -113, 0),
(28808, 1, 5, -8766, -93, 0),
(28808, 1, 4, -8736, -95, 0),
(28808, 1, 3, -8715, -113, 0),
(28808, 1, 2, -8724, -162, 0),
(28808, 1, 1, -8752, -250, 0),
(28808, 1, 0, -8786, -263, 0),
(28808, 0, 0, -8823, -150, 0),
(28809, 2, 0, -8823, -150, 0),
(28809, 1, 7, -8810, -218, 0),
(28809, 1, 6, -8793, -113, 0),
(28809, 1, 5, -8766, -93, 0),
(28809, 1, 4, -8736, -95, 0),
(28809, 1, 3, -8715, -113, 0),
(28809, 1, 2, -8724, -162, 0),
(28809, 1, 1, -8752, -250, 0),
(28809, 1, 0, -8786, -263, 0),
(28809, 0, 0, -8823, -150, 0),
(28810, 2, 0, -8823, -150, 0),
(28810, 1, 7, -8810, -218, 0),
(28810, 1, 6, -8793, -113, 0),
(28810, 1, 5, -8766, -93, 0),
(28810, 1, 4, -8736, -95, 0),
(28810, 1, 3, -8715, -113, 0),
(28810, 1, 2, -8724, -162, 0),
(28810, 1, 1, -8752, -250, 0),
(28810, 1, 0, -8786, -263, 0),
(28810, 0, 0, -8823, -150, 0),
(28811, 2, 0, -8823, -150, 0),
(28811, 1, 7, -8810, -218, 0),
(28811, 1, 6, -8793, -113, 0),
(28811, 1, 5, -8766, -93, 0),
(28811, 1, 4, -8736, -95, 0),
(28811, 1, 3, -8715, -113, 0),
(28811, 1, 2, -8724, -162, 0),
(28811, 1, 1, -8752, -250, 0),
(28811, 1, 0, -8786, -263, 0),
(28811, 0, 0, -8823, -150, 0),
(28812, 2, 0, -8823, -150, 0),
(28812, 1, 7, -8810, -218, 0),
(28812, 1, 6, -8793, -113, 0),
(28812, 1, 5, -8766, -93, 0),
(28812, 1, 4, -8736, -95, 0),
(28812, 1, 3, -8715, -113, 0),
(28812, 1, 2, -8724, -162, 0),
(28812, 1, 1, -8752, -250, 0),
(28812, 1, 0, -8786, -263, 0),
(28812, 0, 0, -8823, -150, 0),
(28813, 2, 0, -8823, -150, 0),
(28813, 1, 7, -8810, -218, 0),
(28813, 1, 6, -8793, -113, 0),
(28813, 1, 5, -8766, -93, 0),
(28813, 1, 4, -8736, -95, 0),
(28813, 1, 3, -8715, -113, 0),
(28813, 1, 2, -8724, -162, 0),
(28813, 1, 1, -8752, -250, 0),
(28813, 1, 0, -8786, -263, 0),
(28813, 0, 0, -8823, -150, 0),
(29082, 2, 0, -8823, -150, 0),
(29082, 1, 7, -8810, -218, 0),
(29082, 1, 6, -8793, -113, 0),
(29082, 1, 5, -8766, -93, 0),
(29082, 1, 4, -8736, -95, 0),
(29082, 1, 3, -8715, -113, 0),
(29082, 1, 2, -8724, -162, 0),
(29082, 1, 1, -8752, -250, 0),
(29082, 1, 0, -8786, -263, 0),
(29082, 0, 0, -8823, -150, 0),
(28817, 1, 0, -8828, -159, 0),
(28817, 0, 0, -8913, -137, 0),
(28818, 1, 0, -8828, -159, 0),
(28818, 0, 0, -8913, -137, 0),
(28819, 1, 0, -8828, -159, 0),
(28819, 0, 0, -8913, -137, 0),
(28820, 1, 0, -8828, -159, 0),
(28820, 0, 0, -8913, -137, 0),
(28821, 1, 0, -8828, -159, 0),
(28821, 0, 0, -8913, -137, 0),
(28822, 1, 0, -8828, -159, 0),
(28822, 0, 0, -8913, -137, 0),
(28823, 1, 0, -8828, -159, 0),
(28823, 0, 0, -8913, -137, 0),
(29083, 1, 0, -8828, -159, 0),
(29083, 0, 0, -8913, -137, 0),
(31145, 1, 0, -8828, -159, 0),
(31145, 0, 0, -8913, -137, 0),
(26389, 3, 0, -8913, -138, 0),
(26389, 2, 0, 833, -335, 0),
(26389, 1, 9, -9042, -448, 0),
(26389, 1, 8, -9113, -410, 0),
(26389, 1, 7, -9133, -356, 0),
(26389, 1, 6, -9139, -325, 0),
(26389, 1, 5, -9116, -257, 0),
(26389, 1, 4, -9103, -218, 0),
(26389, 1, 3, -8886, -360, 0),
(26389, 1, 2, -8863, -382, 0),
(26389, 1, 1, -8881, -435, 0),
(26389, 1, 0, -8923, -453, 0),
(26389, 0, 0, -8940, -132, 0),
(26390, 3, 0, -8913, -138, 0),
(26390, 2, 0, 833, -335, 0),
(26390, 1, 0, -8883, -442, 0),
(26390, 0, 0, -8940, -132, 0),
(26391, 2, 0, -8924, -136, 0),
(26391, 1, 10, -9069, -381, 0),
(26391, 1, 9, -9102, -363, 0),
(26391, 1, 8, -9126, -339, 0),
(26391, 1, 7, -9117, -326, 0),
(26391, 1, 6, -9093, -303, 0),
(26391, 1, 5, -9078, -288, 0),
(26391, 1, 4, -9064, -278, 0),
(26391, 1, 3, -9035, -305, 0),
(26391, 1, 2, -9015, -332, 0),
(26391, 1, 1, -9030, -351, 0),
(26391, 1, 0, -9060, -384, 0),
(26391, 0, 0, -8929, -149, 0),
(54, 2, 0, -8913, -138, 0),
(54, 1, 0, 833, -335, 0),
(54, 0, 0, -9466, 74, 0),
(37112, 1, 0, -9074, -39, 0),
(37112, 0, 0, -9463, 16, 0);