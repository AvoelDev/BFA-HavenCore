-- BFA-HavenCore
-- Northshire Valley - Fear No Evil
-- Correct the player-facing objective text for all class/race variants.

UPDATE `quest_objectives`
SET `Description` = 'Injured Soldier Revived'
WHERE `QuestID` IN (28806, 28808, 28809, 28810, 28811, 28812, 28813, 29082)
  AND `ObjectID` = 50047;
