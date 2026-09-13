-- Sniffed
-- Quests: 9283 (Spirits of the Drowned), 9294 (Healing the Lake)

DELETE FROM `quest_poi` WHERE `QuestID` IN (9283, 9294);
INSERT INTO `quest_poi` (`QuestID`, `BlobIndex`, `Idx1`, `ObjectiveIndex`, `QuestObjectiveID`, `QuestObjectID`, `MapID`, `UiMapID`, `Priority`, `Flags`, `WorldEffectID`, `PlayerConditionID`, `SpawnTrackingID`, `AlwaysAllowMergingBlobs`, `VerifiedBuild`) VALUES
(9283, 0, 2, 32, 0, 0, 530, 468, 0, 0, 0, 0, 136398, 0, 69814),
(9283, 0, 1, 0, 261114, 16483, 530, 468, 0, 0, 0, 0, 0, 0, 69814),
(9283, 0, 0, -1, 0, 0, 530, 468, 0, 0, 0, 0, 0, 0, 69814),
(9294, 0, 2, 32, 0, 0, 530, 468, 0, 0, 0, 0, 136400, 0, 69814),
(9294, 0, 1, 0, 260415, 88791, 530, 468, 0, 0, 0, 0, 0, 0, 69814),
(9294, 0, 0, -1, 0, 0, 530, 468, 0, 0, 0, 0, 0, 0, 69814);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (9283, 9294);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(9283, 2, 0, -4118, -13763, 69814),
(9283, 1, 8, -3966, -13833, 69814),
(9283, 1, 7, -4319, -13549, 69814),
(9283, 1, 6, -4381, -13482, 69814),
(9283, 1, 5, -4396, -13349, 69814),
(9283, 1, 4, -4319, -13327, 69814),
(9283, 1, 3, -3925, -13476, 69814),
(9283, 1, 2, -3887, -13533, 69814),
(9283, 1, 1, -3858, -13748, 69814),
(9283, 1, 0, -3885, -13845, 69814),
(9283, 0, 0, -4118, -13763, 69814),
(9294, 2, 0, -4057, -13722, 69814),
(9294, 1, 0, -4387, -13632, 69814),
(9294, 0, 0, -4057, -13722, 69814);
