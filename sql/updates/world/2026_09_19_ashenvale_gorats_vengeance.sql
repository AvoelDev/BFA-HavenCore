-- Gorat - He shouldn't be able to start quest 13618, only quest 13619. Currently 2 creatures are set as quest starter
DELETE FROM creature_queststarter WHERE id=33294 AND quest=13618;

--  Spirit of Gorat - slowdown walking speed
UPDATE creature_template SET speed_walk=0.8 WHERE entry=33304;

--  Add emote to Gorat text
DELETE FROM creature_text WHERE CreatureID=33304;
INSERT INTO creature_text (CreatureID, GroupID, ID, `Text`, `Type`, `Language`, Probability, Emote, Duration, Sound, BroadcastTextId, TextRange, comment) VALUES
(33304, 0, 0, 'Thank you, friend. I could not rest knowing that my mission had not been completed.', 12, 0, 100.0, 0, 0, 0, 0, 0, 'Gorat Says'),
(33304, 1, 0, '...and that my mens'' sacrifice had not been avenged.', 12, 0, 100.0, 0, 0, 0, 0, 0, 'Gorat Says'),
(33304, 2, 0, 'We must hurry, now. I sense that my time is short.', 12, 0, 100.0, 0, 0, 0, 0, 0, 'Gorat Says'),
(33304, 3, 0, 'Follow me closely, and prepare for battle!', 12, 0, 100.0, 0, 0, 0, 0, 0, 'Gorat Says'),
(33304, 4, 0, 'Captain Elendilad conceals himself on the island ahead, cowardly issuing orders to his underlings.', 12, 0, 100.0, 0, 0, 0, 0, 0, 'Gorat Says'),
(33304, 5, 0, 'He must fall!', 12, 0, 100.0, 5, 0, 0, 0, 0, 'Gorat Says'),
(33304, 6, 0, 'Show yourself, elf-coward! Face your death with honor!', 14, 0, 100.0, 0, 0, 0, 0, 0, 'Gorat Yells');

-- Spirit of Gorat - Remove poison aura and add spirit particles aura
DELETE FROM creature_template_addon WHERE entry=33304;
INSERT INTO creature_template_addon (entry, path_id, mount, bytes1, bytes2, emote, aiAnimKit, movementAnimKit, meleeAnimKit, visibilityDistanceType, auras) VALUES
(33304, 0, 0, 7, 0, 0, 0, 0, 0, 0, '36725');

-- Gorat - remove spirit particles aura
UPDATE creature_template_addon SET auras='' WHERE entry=33294;

-- Gorat's Target Bunny - set movement to idle and orientation for summon
UPDATE creature SET MovementType=0,orientation=1.65 WHERE guid=238110;

-- Gorat's Target Bunny - summon temporary creature on spell hit
DELETE FROM smart_scripts WHERE entryorguid=33336;
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param_string, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment) VALUES
(33336, 0, 0, 0, 8, 0, 100, 0, 62792, 0, 0, 0, 0, '', 12, 33302, 3, 120000, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Gorat''s Target Bunny - On Just Summoned - Summon Captain Elendilad');

-- Spirit of Gorat
DELETE FROM smart_scripts WHERE entryorguid IN(33304,3330400,3330401,3330402);
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param_string, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment)
VALUES
(33304, 0, 0, 0, 54, 0, 100, 0, 0, 0, 0, 0, 0, '', 80, 3330400, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On just Summoned - Run Script'),
(33304, 0, 1, 0, 40, 0, 100, 1, 3, 33304, 0, 0, 0, '', 80, 3330401, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Waypoint 3 - Run Script'),
(33304, 0, 2, 0, 40, 0, 100, 1, 7, 33304, 0, 0, 0, '', 80, 3330402, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On Reached Waypoint 7 - Run Script'),
(33304, 0, 3, 0, 34, 0, 100, 0, 0, 6, 0, 0, 0, '', 1, 6, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On Waypoint 6 reached - Talk Text 6'),
(33304, 0, 4, 0, 38, 0, 100, 0, 1, 1, 0, 0, 0, '', 41, 2000, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On Data Set 1 1 - Reset Script'),
(33304, 0, 5, 0, 38, 0, 100, 0, 1, 1, 0, 0, 0, '', 41, 1000, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'SetData - Despawn'),
(3330400, 9, 0, 0, 0, 0, 100, 0, 100, 100, 0, 0, 0, '', 59, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Set Run Off'),
(3330400, 9, 1, 0, 0, 0, 100, 0, 100, 100, 0, 0, 0, '', 66, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Set Orientation to Invoker'),
(3330400, 9, 2, 0, 0, 0, 100, 0, 3000, 3000, 0, 0, 0, '', 90, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Set Stand State Stand'),
(3330400, 9, 3, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Talk Text 0'),
(3330400, 9, 4, 0, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, '', 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Talk Text 1'),
(3330400, 9, 5, 0, 0, 0, 100, 0, 7000, 7000, 0, 0, 0, '', 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Talk Text 2'),
(3330400, 9, 6, 0, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, '', 1, 3, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Talk Text 3'),
(3330400, 9, 7, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, '', 53, 0, 33304, 0, 0, 0, 1, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Wp Start'),
(3330401, 9, 0, 1, 0, 0, 100, 0, 0, 0, 0, 0, 0, '', 54, 15000, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Pause at Waypoint 3'),
(3330401, 9, 1, 2, 0, 0, 100, 0, 0, 0, 0, 0, 0, '', 66, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Set Orientation to Invoker'),
(3330401, 9, 2, 3, 0, 0, 100, 0, 100, 100, 0, 0, 0, '', 1, 4, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Talk Text 4'),
(3330401, 9, 3, 4, 0, 0, 100, 0, 6000, 6000, 0, 0, 0, '', 1, 5, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Talk Text 5'),
(3330401, 9, 4, 0, 0, 0, 100, 0, 2000, 2000, 0, 0, 0, '', 65, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Resume Waypoint Path'),
(3330402, 9, 0, 0, 0, 0, 100, 0, 100, 100, 0, 0, 0, '', 40, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Set Ranged weapon'),
(3330402, 9, 1, 0, 0, 0, 100, 0, 3000, 3000, 0, 0, 0, '', 11, 62792, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Cast Spell 62792');

-- Spirit of Gorat
DELETE FROM waypoints WHERE entry=33304;
INSERT INTO waypoints (entry, pointid, position_x, position_y, position_z, point_comment) VALUES
(33304, 1, 1432.58, -2016.19, 93.7049, 'Spirit of Gorat'),
(33304, 2, 1443.27, -2027.89, 93.61, 'Spirit of Gorat'),
(33304, 3, 1463.54, -2049.56, 93.1884, 'Spirit of Gorat'),
(33304, 4, 1471.42, -2066.36, 92.7038, 'Spirit of Gorat'),
(33304, 5, 1487.35, -2082.78, 93.5265, 'Spirit of Gorat'),
(33304, 6, 1513.84, -2088.52, 91.0716, 'Spirit of Gorat'),
(33304, 7, 1513.79, -2089.49, 90.6745, 'Spirit of Gorat');

-- Captain Elendilad
DELETE FROM smart_scripts WHERE entryorguid IN(33302,3330200);
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param_string, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment) VALUES
(33302, 0, 0, 0, 9, 0, 100, 0, 0, 5, 13600, 14500, 0, '', 11, 78828, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Cast Bladestorm on Close'),
(33302, 0, 1, 0, 0, 0, 100, 0, 8000, 9000, 120000, 120000, 0, '', 11, 78823, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Cast Commanding Shout'),
(33302, 0, 2, 0, 54, 0, 100, 0, 0, 0, 0, 0, 0, '', 80, 3330200, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On Just Summoned - Run Script'),
(33302, 0, 3, 4, 6, 0, 100, 0, 0, 0, 0, 0, 0, '', 1, 1, 1, 0, 0, 0, 0, 7, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On Death - Say'),
(33302, 0, 4, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 45, 1, 1, 0, 0, 0, 0, 19, 33304, 50, 0, 0.0, 0.0, 0.0, 0.0, 'On Death - Set Data 1 1 On Gorat'),
(3330200, 9, 0, 0, 0, 0, 100, 0, 2000, 2000, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Talk Say on Summon'),
(3330200, 9, 1, 0, 0, 0, 100, 0, 3000, 3000, 0, 0, 0, '', 97, 35, 15, 0, 0, 0, 0, 1, 0, 0, 0, 1514.0, -2095.0, 87.0, 0.0, 'Jump');
