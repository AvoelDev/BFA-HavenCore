-- Quest 37112 - Rest and Relaxation
-- Restore missing enUS turn-in / OfferReward text.

UPDATE `quest_offer_reward`
SET `RewardText` =
'Rest and relaxation for the tired and cold -- that\'s our motto! Please, take a seat by the fire and rest your weary bones.$B$BWould you like to try a sampling of some of our fine food and drink?'
WHERE `ID` = 37112;