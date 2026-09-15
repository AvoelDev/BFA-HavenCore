-- BFA-HavenCore
-- Northshire retail ambient behavior
--
-- Brother Paxton (951)
-- Blackrock Spy (49874)
--
-- Retail validation:
-- * Brother Paxton is stationary and periodically heals nearby Stormwind Infantry.
-- * Static Blackrock Spies use Spying (92857) + Spyglass (80676).
-- * Roaming Blackrock Spies use Spying (92857) only.
--
-- Aura selection for Blackrock Spy is owned by npc_blackrock_spy in C++;
-- the script uses the creature's configured MovementType to distinguish
-- static from roaming spawns.

-- Brother Paxton: dedicated C++ support AI, no waypoint roaming.
UPDATE `creature_template`
SET `AIName` = '',
    `ScriptName` = 'npc_brother_paxton'
WHERE `entry` = 951;

DELETE FROM `smart_scripts`
WHERE (`entryorguid` = 951 AND `source_type` = 0)
   OR (`entryorguid` = 95100 AND `source_type` = 9);

UPDATE `creature`
SET `spawndist` = 0,
    `MovementType` = 0
WHERE `id` = 951;

UPDATE `creature_addon` ca
INNER JOIN `creature` c ON c.`guid` = ca.`guid`
SET ca.`path_id` = 0
WHERE c.`id` = 951;

-- Historical Northshire Paxton path is no longer used.
DELETE FROM `waypoint_data`
WHERE `id` = 95100;

-- Blackrock Spy: C++ owns retail static/roaming aura presentation.
UPDATE `creature_template`
SET `AIName` = '',
    `ScriptName` = 'npc_blackrock_spy'
WHERE `entry` = 49874;

DELETE FROM `smart_scripts`
WHERE (`entryorguid` = 49874 AND `source_type` = 0)
   OR (`entryorguid` = 4987400 AND `source_type` = 9);

-- Do not rewrite Blackrock Spy MovementType/path data here.
-- Existing DB movement determines the retail presentation:
--   MovementType 0 (idle/static) -> 92857 + 80676
--   roaming/path movement        -> 92857 only
