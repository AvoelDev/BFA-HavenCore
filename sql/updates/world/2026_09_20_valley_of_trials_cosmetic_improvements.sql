-- Increase creature spawnDist
-- Vile Familiar 3101
-- Scorpid Worker 3124
-- Sarkoth 3281
-- Northwatch Scout 39317
UPDATE creature SET spawndist=10.0 WHERE id IN(3101,3124,3281,39317);

-- Add missing Lazy Peons
DELETE FROM creature WHERE guid IN(3530203330003165,3530203330003162,3530203330003161,3530203330003160,3530203330003159);
INSERT INTO creature (guid, id, `map`, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup, terrainSwapMap, modelid, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, spawndist, currentwaypoint, curhealth, curmana, MovementType, npcflag, unit_flags, unit_flags2, unit_flags3, dynamicflags, ScriptName, VerifiedBuild) VALUES
(3530203330003165, 10556, 1, 0, 0, '0', 0, 0, 0, -1, 0, 1, -651.131, -4295.72, 40.6558, 5.04779, 300, 0.0, 0, 52, 0, 0, 0, 0, 0, 0, 0, '', 0),
(3530203330003162, 10556, 1, 0, 0, '0', 0, 0, 0, -1, 0, 1, -512.948, -4373.73, 45.925, 1.89913, 300, 0.0, 0, 52, 0, 0, 0, 0, 0, 0, 0, '', 0),
(3530203330003161, 10556, 1, 0, 0, '0', 0, 0, 0, -1, 0, 1, -558.36, -4065.85, 73.1606, 4.93863, 300, 0.0, 0, 52, 0, 0, 0, 0, 0, 0, 0, '', 0),
(3530203330003160, 10556, 1, 0, 0, '0', 0, 0, 0, -1, 0, 1, -372.138, -4015.37, 50.5857, 4.58912, 300, 0.0, 0, 52, 0, 0, 0, 0, 0, 0, 0, '', 0),
(3530203330003159, 10556, 1, 0, 0, '0', 0, 0, 0, -1, 0, 1, -333.308, -4432.77, 53.9485, 2.13083, 300, 0.0, 0, 52, 0, 0, 0, 0, 0, 0, 0, '', 0);

--  Lazy Peon gear near wood not on top of it, also improve movement behavior
DELETE FROM smart_scripts WHERE entryorguid IN(10556,1055600);
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param_string, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_x, target_y, target_z, target_o, comment) VALUES
(10556, 0, 0, 1, 25, 0, 100, 0, 0, 0, 0, 0, 0, '', 90, 3, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - On Reset - Set Stand State Sleep'),
(10556, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 75, 17743, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - On Reset - Add Sleep Aura 17743'),
(10556, 0, 2, 3, 8, 0, 100, 0, 19938, 0, 0, 0, 0, '', 33, 10556, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Spell 19938 Hit - Give Peon Credit'),
(10556, 0, 3, 4, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 28, 17743, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Wake - Remove Sleep Aura 17743'),
(10556, 0, 4, 5, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 91, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Wake - Stand Up'),
(10556, 0, 5, 6, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 1, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Wake - Speak to Invoker'),
(10556, 0, 6, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, '', 80, 1055600, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Wake - Start Work Action List'),
(1055600, 9, 0, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, '', 69, 0, 0, 0, 1, 0, 0, 20, 175784, 20, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Work - Go to Nearest Lumber'),
(1055600, 9, 1, 0, 0, 0, 100, 0, 2000, 2000, 0, 0, 0, '', 66, 0, 0, 0, 0, 0, 0, 20, 175784, 20, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Work - Face Nearest Lumber'),
(1055600, 9, 2, 0, 0, 0, 100, 0, 5000, 5000, 0, 0, 0, '', 17, 234, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Work - Chop Wood'),
(1055600, 9, 3, 0, 0, 0, 100, 0, 60000, 180000, 0, 0, 0, '', 24, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 'Lazy Peon - Work - Evade and Reset');
