-- BFA-HavenCore
-- Northshire Valley - Fear No Evil
-- Injured Stormwind Infantry (50047)
--
-- The dedicated C++ AI owns the injured/revived stand state.
-- Do not also force UNIT_STAND_STATE_DEAD through creature_template_addon,
-- otherwise the template state can conflict with the live revive sequence.

UPDATE `creature_template_addon`
SET `bytes1` = 0
WHERE `entry` = 50047;
