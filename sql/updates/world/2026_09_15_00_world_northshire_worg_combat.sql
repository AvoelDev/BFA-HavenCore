-- Northshire Valley: use the Blackrock Worg C++ AI for the staged
-- combat between Blackrock Worgs and Stormwind Infantry.
UPDATE `creature_template`
SET `ScriptName` = 'npc_blackrock_battle_worg'
WHERE `entry` = 49871;