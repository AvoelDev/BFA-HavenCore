--  Enable scripts for creatures
UPDATE creature_template SET ScriptName='npc_fledgling_brave' WHERE entry=36942;
UPDATE creature_template SET ScriptName='npc_bristleback_invader' WHERE entry=36943;

-- PC and NPC immune, non selectable
UPDATE creature SET unit_flags=33555200 WHERE guid=260165;
UPDATE creature SET unit_flags=33555200 WHERE guid=260171;
UPDATE creature SET unit_flags=33555200 WHERE guid=260275;
UPDATE creature SET unit_flags=33555200 WHERE guid=260281;
UPDATE creature SET unit_flags=33555200 WHERE guid=260353;
UPDATE creature SET unit_flags=33555200 WHERE guid=260356;
UPDATE creature SET unit_flags=33555200 WHERE guid=260357;
UPDATE creature SET unit_flags=33555200 WHERE guid=260361;
UPDATE creature SET unit_flags=33555200 WHERE guid=260411;
UPDATE creature SET unit_flags=33555200 WHERE guid=260413;
UPDATE creature SET unit_flags=33555200 WHERE guid=260414;
UPDATE creature SET unit_flags=33555200 WHERE guid=260419;
UPDATE creature SET unit_flags=33555200 WHERE guid=260462;
UPDATE creature SET unit_flags=33555200 WHERE guid=260464;
UPDATE creature SET unit_flags=33555200 WHERE guid=260465;
UPDATE creature SET unit_flags=33555200 WHERE guid=260468;
UPDATE creature SET unit_flags=33555200 WHERE guid=260469;
UPDATE creature SET unit_flags=33555200 WHERE guid=260470;
UPDATE creature SET unit_flags=33555200 WHERE guid=260514;
UPDATE creature SET unit_flags=33555200 WHERE guid=260516;

-- Brave Windfeather - Allow waypoint_data to execute
UPDATE creature SET MovementType=2 WHERE guid=260338;

-- Brave Windfeather - Add path_id
DELETE FROM creature_addon WHERE guid=260338;
INSERT INTO creature_addon (guid, path_id, mount, bytes1, bytes2, emote, aiAnimKit, movementAnimKit, meleeAnimKit, visibilityDistanceType, auras) VALUES
(260338, 2603380, 0, 0, 0, 0, 0, 0, 0, 0, NULL);

-- Brave Windfeather - Add points
DELETE FROM waypoint_data WHERE id = 2603380;
INSERT INTO waypoint_data (id, `point`, position_x, position_y, position_z, orientation, delay, move_type, `action`, action_chance, wpguid) VALUES
(2603380, 1, -2934.37, -327.21, 58.39, 0.0, 0, 0, 0, 100, 0),
(2603380, 2, -2949.37, -347.98, 56.49, 0.0, 0, 0, 0, 100, 0),
(2603380, 3, -2970.11, -365.07, 53.43, 0.0, 0, 0, 0, 100, 0),
(2603380, 4, -2993.68, -394.35, 48.84, 0.0, 0, 0, 0, 100, 0),
(2603380, 5, -2999.32, -431.72, 46.19, 0.0, 10000, 0, 0, 100, 0),
(2603380, 6, -2993.68, -394.35, 48.84, 0.0, 0, 0, 0, 100, 0),
(2603380, 7, -2970.11, -365.07, 53.43, 0.0, 0, 0, 0, 100, 0),
(2603380, 8, -2949.37, -347.98, 56.49, 0.0, 0, 0, 0, 100, 0),
(2603380, 9, -2934.37, -327.21, 58.39, 0.0, 0, 0, 0, 100, 0),
(2603380, 10, -2930.88, -286.24, 59.16, 0.0, 0, 10000, 0, 100, 0);
