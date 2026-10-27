-- AzerothCore 3.3.5a / GM Island AlterShop: additive, reversible data only.
-- Builds a NEW shop in the style of AlterShop, NOT the destructive 2011
-- TrinityCore/MaNGOS AlterShop fun-server mod (which rewrites gameplay).
-- Install ONLY into acore_world with worldserver stopped; back up first.
-- Tested for MySQL 8.4 syntax/schema layout; live spawn terrain still needs GM inspection.
-- GM teleport: .tele GMIsland (already shipped) or .tele AlterShop (added here).
-- NPC entries: 930101..930112; no core/quest/item_template overwrites.
-- Shop prices use the original item_template.BuyPrice; this script adds no free-price hacks.
-- Every vendor is limited to 140 entries (AzerothCore/client hard limit: 150).
SET NAMES utf8mb4;

-- Only add the convenient alias if not already present.
SET @alt_tele_id := (SELECT COALESCE(MAX(`id`),0)+1 FROM `game_tele`);
INSERT IGNORE INTO `game_tele` (`id`,`position_x`,`position_y`,`position_z`,`orientation`,`map`,`name`)
SELECT @alt_tele_id, t.`position_x`, t.`position_y`, t.`position_z`, t.`orientation`, t.`map`, 'AlterShop'
FROM `game_tele` t
WHERE t.`name`='GMIsland'
  AND NOT EXISTS (SELECT 1 FROM `game_tele` check_alias WHERE check_alias.`name`='AlterShop')
LIMIT 1;

CREATE TEMPORARY TABLE `tmp_acore_altershop` (
 `entry` INT UNSIGNED NOT NULL PRIMARY KEY,
 `name` VARCHAR(100) NOT NULL,
 `subname` VARCHAR(100) NOT NULL,
 `name_ru` VARCHAR(100) NOT NULL,
 `subname_ru` VARCHAR(100) NOT NULL,
 `dx` FLOAT NOT NULL,
 `dy` FLOAT NOT NULL,
 `tier` TINYINT UNSIGNED NOT NULL,
 `armor_type` TINYINT UNSIGNED NOT NULL
);
INSERT INTO `tmp_acore_altershop`
(`entry`,`name`,`subname`,`name_ru`,`subname_ru`,`dx`,`dy`,`tier`,`armor_type`) VALUES
(930101,'AlterShop T1','T1 classic','Альтершоп — Т1','Классические комплекты',-8,-5,1,0),
(930102,'AlterShop T2','T2 classic','Альтершоп — Т2','Классические комплекты',-5,-5,2,0),
(930103,'AlterShop T6','T6 Outland','Альтершоп — Т6','Запределье',-2,-5,3,0),
(930104,'AlterShop T9 Cloth','T9 cloth','Альтершоп — Т9: ткань','Сеты для 80 уровня',1,-5,9,1),
(930105,'AlterShop T9 Leather','T9 leather','Альтершоп — Т9: кожа','Сеты для 80 уровня',4,-5,9,2),
(930106,'AlterShop T9 Mail','T9 mail','Альтершоп — Т9: кольчуга','Сеты для 80 уровня',7,-5,9,3),
(930107,'AlterShop T9 Plate','T9 plate','Альтершоп — Т9: латы','Сеты для 80 уровня',10,-5,9,4),
(930108,'AlterShop T10 Cloth','T10 cloth','Альтершоп — Т10: ткань','Сеты для 80 уровня',-8,5,10,1),
(930109,'AlterShop T10 Leather','T10 leather','Альтершоп — Т10: кожа','Сеты для 80 уровня',-5,5,10,2),
(930110,'AlterShop T10 Mail','T10 mail','Альтершоп — Т10: кольчуга','Сеты для 80 уровня',-2,5,10,3),
(930111,'AlterShop T10 Plate','T10 plate','Альтершоп — Т10: латы','Сеты для 80 уровня',1,5,10,4),
(930112,'AlterShop Supplies','Gems and Bags','Альтершоп — припасы','Сумки, камни, зелья',4,5,0,0);

-- Only create custom NPCs when the entry is unused; do not replace others.
INSERT IGNORE INTO `creature_template`
(`entry`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`unit_class`,`unit_flags`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`AIName`,`MovementType`,`HoverHeight`,`RacialLeader`,`movementId`,`RegenHealth`,`CreatureImmunitiesId`,`flags_extra`,`ScriptName`)
SELECT `entry`,`name`,`subname`,'Buy',0,80,80,2,35,128,0,0,2000,0,1,2,7,0,0,0,0,'',0,1,0,0,1,0,8192,''
FROM `tmp_acore_altershop`;

INSERT IGNORE INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT `entry`,0,19646,1,1,0 FROM `tmp_acore_altershop`;

INSERT IGNORE INTO `creature_template_locale`
(`entry`,`locale`,`Name`,`Title`)
SELECT `entry`,'ruRU',`name_ru`,`subname_ru` FROM `tmp_acore_altershop`;

-- T1/T2: verified classic class item-set IDs 201..218.
-- T6: precise BC raid set IDs 668..684 (17 original tier-six class sets).
-- The original old fan-server patch is NOT installed; this uses AzerothCore data.
-- T9/T10: wrath level-80 set pieces at their tier item levels and armor class.
-- Split cloth/leather/mail/plate to keep each shop under the vendor page limit.
-- Retail class restrictions and vendor buy prices are kept intact.
INSERT IGNORE INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT ranked.`vendor`,0,ranked.`item`,0,0,0,0
FROM (
 SELECT v.`entry` AS `vendor`,i.`entry` AS `item`,
 ROW_NUMBER() OVER (PARTITION BY v.`entry` ORDER BY i.`ItemSet`,i.`entry`) AS `n`
 FROM `tmp_acore_altershop` v
 JOIN `item_template` i ON
    (v.`tier`=1 AND i.`ItemSet` BETWEEN 201 AND 209)
 OR (v.`tier`=2 AND i.`ItemSet` BETWEEN 210 AND 218)
 OR (v.`tier`=3 AND i.`ItemSet` BETWEEN 668 AND 684)
 OR (v.`tier`=9 AND i.`ItemSet`>0 AND i.`RequiredLevel`=80 AND i.`ItemLevel` IN (232,245,258) AND i.`class`=4 AND i.`subclass`=v.`armor_type`)
 OR (v.`tier`=10 AND i.`ItemSet`>0 AND i.`RequiredLevel`=80 AND i.`ItemLevel` IN (251,264,277) AND i.`class`=4 AND i.`subclass`=v.`armor_type`)
) ranked
WHERE ranked.`n` <= 140;

-- Supplies: bounded list of real WotLK item entries, only insert those present.
INSERT IGNORE INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT 930112,0,i.`entry`,0,0,0,0 FROM `item_template` i
WHERE i.`entry` IN (21841,41599,33447,33448,40112,40113,40114,40115,
 40119,40130,40155,36913,36910,43102,49908,34052,34057,36908);

-- Automatically spawn beside the existing, verified GMIsland .tele point.
-- We allocate GUIDs above MAX(guid); skip templates with a pre-existing map-1 spawn.
-- Every vendor is stationary and non-combat. Offset layout can be tweaked in game.
SET @alt_spawn_guid := (SELECT COALESCE(MAX(`guid`),0)+100 FROM `creature`);
INSERT IGNORE INTO `creature`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`)
SELECT @alt_spawn_guid+(v.`entry`-930100),v.`entry`,t.`map`,0,0,1,1,0,
 t.`position_x`+v.`dx`,t.`position_y`+v.`dy`,t.`position_z`,t.`orientation`,
 120,0,0,1,0,0
FROM `tmp_acore_altershop` v
JOIN `game_tele` t ON t.`name`='GMIsland'
WHERE NOT EXISTS (
 SELECT 1 FROM `creature` s WHERE s.`id`=v.`entry` AND s.`map`=t.`map`
);

SELECT `entry`,`name`,(SELECT COUNT(*) FROM `npc_vendor` n WHERE n.`entry`=v.`entry`) AS `items`
FROM `tmp_acore_altershop` v ORDER BY `entry`;
SELECT `name`,`map`,`position_x`,`position_y`,`position_z`
FROM `game_tele` WHERE `name` IN ('GMIsland','AlterShop');
