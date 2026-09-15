-- BFA-HavenCore
-- Northshire Valley - Fear No Evil
-- Restore the native spell-click interaction for Injured Stormwind Infantry.

-- 50047 uses spell 93072 ("Get Our Boys Back Dummy") when clicked.
-- cast_flags = 1 keeps the historical/reference spell-click behavior.
DELETE FROM `npc_spellclick_spells`
WHERE `npc_entry` = 50047;

INSERT INTO `npc_spellclick_spells`
(`npc_entry`, `spell_id`, `cast_flags`, `user_type`)
VALUES
(50047, 93072, 1, 0);

-- Correct the player-name substitution token used by the acknowledgement line.
UPDATE `creature_text`
SET `Text` = 'You''re $N! The hero that everyone has been talking about! Thank you!'
WHERE `CreatureID` = 50047
  AND `GroupID` = 0
  AND `ID` = 4;