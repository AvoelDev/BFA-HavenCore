-- BFA-HavenCore
-- Northshire Valley - Fear No Evil
-- Restrict Injured Stormwind Infantry (50047) spell-click to players
-- who currently have one of the Fear No Evil quest variants INCOMPLETE.

SET @NPC   := 50047;
SET @SPELL := 93072;

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 18
  AND `SourceGroup` = @NPC
  AND `SourceEntry` = @SPELL;

-- SourceType 18 = SpellClick.
-- ConditionType 9 = Quest Taken, and Haven evaluates it only while the
-- quest status is QUEST_STATUS_INCOMPLETE.
--
-- Different ElseGroup values are OR branches:
-- any one active Fear No Evil variant enables the spell-click.
INSERT INTO `conditions`
(`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`,
 `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`,
 `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
 `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
(18, @NPC, @SPELL, 0, 0, 9, 0, 28806, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Hunter - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 1, 9, 0, 28808, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Mage - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 2, 9, 0, 28809, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Paladin - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 3, 9, 0, 28810, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Priest - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 4, 9, 0, 28811, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Rogue - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 5, 9, 0, 28812, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Warlock - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 6, 9, 0, 28813, 0, 0, 0, 0, 0, '', 'Fear No Evil - Human Warrior - quest must be incomplete'),
(18, @NPC, @SPELL, 0, 7, 9, 0, 29082, 0, 0, 0, 0, 0, '', 'Fear No Evil - Alliance Northshire variant - quest must be incomplete');
