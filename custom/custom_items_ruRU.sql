-- AzerothCore 3.3.5a / MySQL 8.4
-- Three example custom items using EXISTING client display IDs.
-- Execute once (or again safely) against your AzerothCore WORLD database.
-- IMPORTANT: back up your world database first. Never run on auth/characters.
-- Intended custom IDs: 910001-910003. Check that they are unused in your server.
SET NAMES utf8mb4;

-- 910001: weapon copied from Thunderfury (19019). Keeps its proven model,
-- weapon stats and spells; changes only ID, names, description.
DROP TEMPORARY TABLE IF EXISTS `custom_item_stage`;
CREATE TEMPORARY TABLE `custom_item_stage` LIKE `item_template`;
INSERT INTO `custom_item_stage`
  SELECT * FROM `item_template` WHERE `entry` = 19019;
UPDATE `custom_item_stage`
  SET `entry` = 910001,
      `name` = 'Blade of the Northern Storm',
      `description` = 'A blade forged for the heroes of Northrend.'
  WHERE `entry` = 19019;
INSERT IGNORE INTO `item_template` SELECT * FROM `custom_item_stage`;
DROP TEMPORARY TABLE IF EXISTS `custom_item_stage`;

-- 910002: two-handed mace copied from Sulfuras (17182).
CREATE TEMPORARY TABLE `custom_item_stage` LIKE `item_template`;
INSERT INTO `custom_item_stage`
  SELECT * FROM `item_template` WHERE `entry` = 17182;
UPDATE `custom_item_stage`
  SET `entry` = 910002,
      `name` = 'Hammer of the Frozen Flame',
      `description` = 'Fire and frost bound by an unknown smith.'
  WHERE `entry` = 17182;
INSERT IGNORE INTO `item_template` SELECT * FROM `custom_item_stage`;
DROP TEMPORARY TABLE IF EXISTS `custom_item_stage`;

-- 910003: hearthstone clone (6948) for demonstration.
-- It uses the original hearthstone spell/cooldown; no client-side changes.
CREATE TEMPORARY TABLE `custom_item_stage` LIKE `item_template`;
INSERT INTO `custom_item_stage`
  SELECT * FROM `item_template` WHERE `entry` = 6948;
UPDATE `custom_item_stage`
  SET `entry` = 910003,
      `name` = 'Wanderer\'s Hearthstone',
      `description` = 'A warm stone to guide a traveler home.'
  WHERE `entry` = 6948;
INSERT IGNORE INTO `item_template` SELECT * FROM `custom_item_stage`;
DROP TEMPORARY TABLE IF EXISTS `custom_item_stage`;

-- Russian locale. enUS fallback names are in the item_template table.
INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`)
SELECT 910001, 'ruRU', 'Клинок северной бури', 'Клинок, выкованный для героев Нордскола.'
WHERE EXISTS (SELECT 1 FROM `item_template` WHERE `entry` = 910001)
ON DUPLICATE KEY UPDATE
  `Name` = 'Клинок северной бури',
  `Description` = 'Клинок, выкованный для героев Нордскола.';

INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`)
SELECT 910002, 'ruRU', 'Молот ледяного пламени', 'Огонь и лёд, соединённые неизвестным кузнецом.'
WHERE EXISTS (SELECT 1 FROM `item_template` WHERE `entry` = 910002)
ON DUPLICATE KEY UPDATE
  `Name` = 'Молот ледяного пламени',
  `Description` = 'Огонь и лёд, соединённые неизвестным кузнецом.';

INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`)
SELECT 910003, 'ruRU', 'Камень возвращения странника', 'Тёплый камень, указывающий путь домой.'
WHERE EXISTS (SELECT 1 FROM `item_template` WHERE `entry` = 910003)
ON DUPLICATE KEY UPDATE
  `Name` = 'Камень возвращения странника',
  `Description` = 'Тёплый камень, указывающий путь домой.';

SELECT `entry`, `name` FROM `item_template`
WHERE `entry` IN (910001, 910002, 910003);
