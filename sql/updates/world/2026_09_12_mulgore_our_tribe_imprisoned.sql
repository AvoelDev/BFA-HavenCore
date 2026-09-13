--  Change quest objective from gameobject to creature so the kill credit doesn't trigger twice
UPDATE quest_objectives SET Type=0,ObjectID=12999,Description='Braves Freed' WHERE ID=265317 AND QuestID=24852;

--  Quilboar Cage (202112) - swap data2 to data1 to set proper requirement
UPDATE gameobject_template SET Data0=1691,Data1=24852,Data2=0 WHERE entry=202112;

--  Captured Brave (38345) - reduce spawn timer to match cage
UPDATE creature SET spawntimesecs=60 WHERE id=38345;

-- Quilboar Cage (202122) - reduce spawn timer to match Captured Brave
UPDATE gameobject SET spawntimesecs=60 WHERE id=202112;

-- Quilboar Cage - Set data to creature 38345
DELETE FROM smart_scripts WHERE entryorguid = 202112 AND source_type = 1;
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param_string, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment)
VALUES
(202112, 1, 0, 1, 70, 0, 100, 0, 2, 0, 0, 0, 0, '', 45, 1, 1, 0, 0, 0, 0, 19, 38345, 5, 0, 0.0, 0.0, 0.0, 0.0, 'On State Change 2 Active- Set Data to creature 38345'),
(202112, 1, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 41, 20, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Link - Despawn'),
(202112, 1, 2, 0, 11, 0, 100, 0, 0, 0, 0, 0, 0, '', 47, 1, 0, 0, 0, 0, 0, 19, 38345, 5, 0, 0.0, 0.0, 0.0, 0.0, 'On reset - Set Visibility 1 - Creature 38345');

-- Captured Brave - Quest behavior
DELETE FROM smart_scripts WHERE entryorguid IN(38345, 3834500);
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param_string, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment)
VALUES
(38345, 0, 0, 1, 38, 0, 100, 1, 1, 1, 0, 0, 0, '', 90, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On Data Set 1 - Clear Kneel flag'),
(38345, 0, 1, 2, 61, 0, 100, 1, 1, 1, 0, 0, 0, '', 33, 12999, 0, 0, 0, 0, 0, 18, 10, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Link - Give Kill Credit to Players in range'),
(38345, 0, 2, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 80, 3834500, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Link - Run Timed ActionList 3834500'),
(38345, 0, 3, 4, 34, 0, 100, 0, 0, 0, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'On Movement Inform - Talk Group 0'),
(38345, 0, 4, 5, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 47, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Link - Set Visibility 0'),
(38345, 0, 5, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 24, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Link - Reset Creature'),
(3834500, 9, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, '', 59, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'ActionList 0ms - Set Run Mode'),
(3834500, 9, 1, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, '', 114, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 15.0, 0.0, 0.0, 'ActionList 1000ms - Move Forward 15');
