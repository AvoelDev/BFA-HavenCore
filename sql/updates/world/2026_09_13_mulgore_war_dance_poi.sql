DELETE FROM quest_poi WHERE QuestID = 24540;
INSERT INTO quest_poi (QuestID, BlobIndex, Idx1, ObjectiveIndex, QuestObjectiveID, QuestObjectID, MapID, UiMapID, Priority, Flags, WorldEffectID, PlayerConditionID, SpawnTrackingID, AlwaysAllowMergingBlobs, VerifiedBuild) VALUES
(24540, 0, 0, -1, 0, 0, 1, 7, 0, 1, 0, 0, 0, 0, 35662),
(24540, 0, 1, 0, 252638, 0, 1, 7, 0, 0, 0, 0, 0, 0, 35662);

DELETE FROM quest_poi_points WHERE QuestID = 24540;
INSERT INTO quest_poi_points (QuestID, Idx1, Idx2, X, Y, VerifiedBuild) VALUES
(24540, 0, 0,-1209, -112, 35662),
(24540, 1, 0,-600, 189, 35662);
