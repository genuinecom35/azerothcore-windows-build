-- Safe, repeatable registration of Transmog NPC templates for AzerothCore 3.3.5a.
-- Based on azerothcore/mod-transmog data/sql/db-world/2016_11_17_transmog_npc.sql.
-- Unlike the upstream import, this NEVER drops/deletes/replaces existing creatures.
-- Apply to acore_world while worldserver is STOPPED, after backing it up.
-- Registered IDs: 190010 Warpweaver, 190011 Ethereal Warpweaver.

INSERT IGNORE INTO `creature_template`
(`entry`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`unit_class`,`unit_flags`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`AIName`,`MovementType`,`HoverHeight`,`RacialLeader`,`movementId`,`RegenHealth`,`CreatureImmunitiesId`,`flags_extra`,`ScriptName`)
VALUES
(190010,'Warpweaver','Transmogrifier',NULL,0,80,80,2,35,1,0,0,2000,0,1,0,7,138936390,0,0,0,'',0,1,0,0,1,0,0,'npc_transmogrifier'),
(190011,'Ethereal Warpweaver','Transmogrifier',NULL,0,80,80,2,35,1,0,0,2000,0,1,0,7,138936390,0,0,0,'',0,1,0,0,1,0,0,'npc_transmogrifier');

-- Reattach only the module's known named templates if ScriptName is empty.
-- Never overwrite another NPC's custom script.
UPDATE `creature_template`
SET `ScriptName` = 'npc_transmogrifier'
WHERE ((`entry` = 190010 AND `name` = 'Warpweaver')
    OR (`entry` = 190011 AND `name` = 'Ethereal Warpweaver'))
  AND (`ScriptName` IS NULL OR `ScriptName` = '');

INSERT IGNORE INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(190010,0,19646,1,1,0),
(190011,0,19646,1,1,0);

INSERT IGNORE INTO `creature_template_locale`
(`entry`,`locale`,`Name`,`Title`)
VALUES
(190010,'ruRU','Warpweaver','Трансмогрификатор'),
(190011,'ruRU','Ethereal Warpweaver','Трансмогрификатор');

-- Inspect what is installed. Both records should have ScriptName npc_transmogrifier.
SELECT `entry`,`name`,`ScriptName`
FROM `creature_template` WHERE `entry` IN (190010,190011);
