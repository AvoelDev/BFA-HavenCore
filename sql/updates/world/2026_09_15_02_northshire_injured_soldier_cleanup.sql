-- BFA-HavenCore
-- Northshire Valley - Injured Stormwind Infantry (50047)
-- Use the dedicated C++ AI only and remove legacy SmartAI state.

UPDATE `creature_template`
SET `AIName` = '',
    `ScriptName` = 'npc_stormwind_injured_soldier'
WHERE `entry` = 50047;

DELETE FROM `smart_scripts`
WHERE (`entryorguid` = 50047 AND `source_type` = 0)
   OR (`entryorguid` = 5004700 AND `source_type` = 9);

-- Keep the native Fear No Evil spell-click.
DELETE FROM `npc_spellclick_spells`
WHERE `npc_entry` = 50047;

INSERT INTO `npc_spellclick_spells`
(`npc_entry`, `spell_id`, `cast_flags`, `user_type`)
VALUES
(50047, 93072, 1, 0);
