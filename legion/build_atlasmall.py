#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AtlasMall generator: Legion 7.3.5 AtlasLoot Enhanced item IDs -> server SQL.
Sources: AtlasLoot Enhanced 8.07.13 GPL-2.0 from pernamiau1/wow-legion-7.3.5-addons.
Do not distribute the addon; fetch the pinned public data files at build time.
Only numeric, explicit item IDs in active AtlasLoot content tables are used.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
import urllib.request
from collections import OrderedDict
from pathlib import Path

ADDON_REPO = "pernamiau1/wow-legion-7.3.5-addons"
ADDON_SHA = "1003e6078fc6d14508df9e8548bd5ecc51409a3c"
MODULES = [
    ("Classic", "Classic"),
    ("BurningCrusade", "TBC"),
    ("WrathoftheLichKing", "WotLK"),
    ("Cataclysm", "Cataclysm"),
    ("MistsofPandaria", "Pandaria"),
    ("WarlordsofDraenor", "Draenor"),
    ("Legion", "Legion"),
    ("Collections", "Коллекции"),
    ("Factions", "Репутация"),
    ("PvP", "PvP"),
    ("Crafting", "Профессии"),
    ("WorldEvents", "События"),
]
SECTION_RE = re.compile(r'(?m)^\s*data\["([^"]+)"\]\s*=\s*\{')
ITEM_RE = re.compile(r'(?m)^\s*\{\s*\d{1,3}\s*,\s*(\d{3,6})(?=\s*[,}])')
TYPE_RE = re.compile(r'\bContentType\s*=\s*(RAID_CONTENT|DUNGEON_CONTENT)\b')
MAX_ITEMS = 115     # LegionCore MAX_VENDOR_ITEMS is 150
ENTRY_START = 997100
ENTRY_END = 997999
GUID_START = 99610000
TELEPORT_ID = 997099
VENDOR_TEMPLATE = 120687  # Violet Shadowmend, verified existing vendor in upstream SQL
BUILD = 26972

def fetch_lua(module: str) -> str:
    url = "https://raw.githubusercontent.com/{}/{}/AtlasLoot_{}/data.lua".format(
        ADDON_REPO, ADDON_SHA, module)
    req = urllib.request.Request(url, headers={"User-Agent": "Legion735-AtlasMall/1.0"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read().decode("utf-8-sig")

def extract_sections(lua: str, label: str) -> dict[str, list[int]]:
    # Drop block comments, then ignore line comments. Achievement/spell/mount
    # references stored as quoted strings are not treated as purchasable items.
    lua = re.sub(r'--\[\[.*?\]\]', '', lua, flags=re.DOTALL)
    matches = list(SECTION_RE.finditer(lua))
    groups: dict[str, list[int]] = OrderedDict()
    for idx, match in enumerate(matches):
        body = lua[match.end():matches[idx + 1].start() if idx + 1 < len(matches) else len(lua)]
        if "items" not in body:
            continue
        kind = TYPE_RE.search(body)
        if label in ("Classic", "TBC", "WotLK", "Cataclysm", "Pandaria", "Draenor", "Legion"):
            if not kind:
                continue
            group = "{} {}".format(label, "рейды" if kind.group(1) == "RAID_CONTENT" else "подземелья")
        else:
            group = label
        items = groups.setdefault(group, [])
        for ln in body.splitlines():
            if ln.lstrip().startswith("--"):
                continue
            # Remove trailing comments to avoid importing commented-out IDs.
            ln = re.split(r'--', ln, maxsplit=1)[0]
            for item in ITEM_RE.findall(ln):
                value = int(item)
                if value >= 500 and value <= 200000:
                    items.append(value)
    return groups

def build_catalogue(loader=fetch_lua):
    groups: dict[str, list[int]] = OrderedDict()
    stats = {}
    for module, label in MODULES:
        lua = loader(module)
        extracted = extract_sections(lua, label)
        stats[module] = sum(len(rows) for rows in extracted.values())
        for group, rows in extracted.items():
            groups.setdefault(group, []).extend(rows)
    result = OrderedDict()
    for label, rows in groups.items():
        unique = list(OrderedDict.fromkeys(rows))
        if unique:
            result[label] = unique
    return result, stats

def chunks(values, size=MAX_ITEMS):
    for start in range(0, len(values), size):
        yield values[start:start + size]

def escape_sql(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")

def render_sql(groups: dict[str, list[int]]) -> tuple[str, list[dict]]:
    shops = []
    for label, items in groups.items():
        for page, page_items in enumerate(chunks(items), start=1):
            shops.append({"entry": ENTRY_START + len(shops), "label": label,
                          "page": page, "items": page_items})
    if not shops:
        raise RuntimeError("AtlasLoot parser extracted no items; refusing empty shop")
    if shops[-1]["entry"] > ENTRY_END:
        raise RuntimeError("More shop pages than reserved creature entries: {}".format(len(shops)))
    lines = [
        "-- AtlasMall for Legion 7.3.5 (build 26972). GENERATED: do not edit by hand.",
        "-- Source: AtlasLoot Enhanced v8.07.13, GPL-2.0; https://github.com/" + ADDON_REPO,
        "-- Revision: " + ADDON_SHA,
        "-- Custom IDs only; existing AzerothCore/WotLK databases are never accessed.",
        "-- Source creature NPC 120687 is an existing upstream Legion vendor.",
        "-- Full AtlasLoot item IDs; bonus lists, modes, and difficulty-specific variants are NOT reproduced.",
        "DELETE FROM npc_vendor WHERE entry BETWEEN {} AND {};".format(ENTRY_START, ENTRY_END),
        "DELETE FROM creature WHERE guid BETWEEN {} AND {};".format(GUID_START, GUID_START + ENTRY_END - ENTRY_START),
        "DELETE FROM creature_template_wdb WHERE Entry BETWEEN {} AND {};".format(ENTRY_START, ENTRY_END),
        "DELETE FROM creature_template WHERE entry BETWEEN {} AND {};".format(ENTRY_START, ENTRY_END),
        "DELETE FROM game_tele WHERE id IN ({}, {});".format(TELEPORT_ID, TELEPORT_ID + 1),
        "INSERT IGNORE INTO game_tele (id, position_x, position_y, position_z, orientation, map, name) VALUES",
        "({}, 16222.22, 16252.62, 12.62, 1.27, 1, 'AtlasMall'),".format(TELEPORT_ID),
        "({}, 16222.22, 16252.62, 12.62, 1.27, 1, 'GMIsland');".format(TELEPORT_ID + 1),
        "-- Clone a real, build-compatible creature from this SAME world database.",
        "CREATE TEMPORARY TABLE _atlas_vendor_tpl SELECT * FROM creature_template WHERE entry = {} LIMIT 0;".format(VENDOR_TEMPLATE),
        "CREATE TEMPORARY TABLE _atlas_vendor_wdb SELECT * FROM creature_template_wdb WHERE Entry = {} LIMIT 0;".format(VENDOR_TEMPLATE),
        "",
    ]
    # Compact 14-column showroom around the landmark. All NPCs at ground height;
    # verify positions during live in-game testing on this particular client map.
    columns = 14
    for index, shop in enumerate(shops):
        entry = shop["entry"]
        page = shop["page"]
        name = escape_sql("AtlasLoot {} {:02d}".format(shop["label"], page))
        x = 16201.75 + (index % columns) * 3.14
        y = 16230.75 + (index // columns) * 3.14
        z = 12.62
        guid = GUID_START + index
        lines.extend([
            "TRUNCATE TABLE _atlas_vendor_tpl;",
            "INSERT INTO _atlas_vendor_tpl SELECT * FROM creature_template WHERE entry = {};".format(VENDOR_TEMPLATE),
            "UPDATE _atlas_vendor_tpl SET entry = {}, npcflag = 128, npcflag2 = 0, faction = 35, minlevel = 110, maxlevel = 110, AIName = '', ScriptName = '';".format(entry),
            "INSERT INTO creature_template SELECT * FROM _atlas_vendor_tpl;",
            "TRUNCATE TABLE _atlas_vendor_wdb;",
            "INSERT INTO _atlas_vendor_wdb SELECT * FROM creature_template_wdb WHERE Entry = {};".format(VENDOR_TEMPLATE),
            "UPDATE _atlas_vendor_wdb SET Entry = {}, Name1 = '{}', Title = 'AtlasLoot Enhanced';".format(entry, name),
            "INSERT INTO creature_template_wdb SELECT * FROM _atlas_vendor_wdb;",
            "INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, PhaseId, modelid, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, spawndist, currentwaypoint, curhealth, curmana, MovementType, npcflag, npcflag2, unit_flags, dynamicflags) VALUES",
            "({}, {}, 1, 0, 0, 1, 1, 0, 0, 0, {:.2f}, {:.2f}, {:.2f}, 1.57, 120, 0, 0, 100000, 0, 0, 128, 0, 0, 0);".format(guid, entry, x, y, z),
            "INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, type, PlayerConditionID, IgnoreFiltering, Context, VerifiedBuild) VALUES",
            ",\n".join("({}, {}, {}, 0, 0, 0, 1, 0, 1, 0, {})".format(entry, slot, item, BUILD)
                       for slot, item in enumerate(shop["items"])) + ";",
            "",
        ])
    lines += [
        "DROP TEMPORARY TABLE _atlas_vendor_tpl;",
        "DROP TEMPORARY TABLE _atlas_vendor_wdb;",
        "-- /mall: GM-only command registered in cs_tele.cpp by workflow source patch.",
        "-- Also available: .tele AtlasMall, .tele GMIsland (unless an existing GMIsland name is registered)."
    ]
    return "\n".join(lines) + "\n", shops

def test_parser() -> None:
    text = '''
data["Starter"] = {
  ContentType = DUNGEON_CONTENT,
  items = { { [NORMAL_DIFF] = {
    { 1, 137403 }, -- gear
    { 2, "ac123" }, -- achievement not an item
    -- { 3, 999001 }, -- excluded
  } }, },
}
--[[ data["Old"] = { ContentType = RAID_CONTENT, items = { { 1, 12345 }, }, } ]]
data["Raid"] = {
  ContentType = RAID_CONTENT,
  items = { { [NORMAL_DIFF] = { { 1, 140001 }, { 2, 140001 }, }, }, },
}'''
    groups = extract_sections(text, "Legion")
    assert groups["Legion подземелья"] == [137403], groups
    assert groups["Legion рейды"] == [140001, 140001], groups
    sql, shops = render_sql({"Legion рейды": [140001, 140001, 140002]})
    assert len(shops) == 1 and "140002" in sql and "AtlasMall" in sql
    assert "999001" not in sql
    print("AtlasMall parser and SQL smoke-test: OK")

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--output", default="legion-src/sql/updates/world/2026_10_28_90_atlasmall.sql")
    p.add_argument("--manifest", default="legion/ATLASMALL_MANIFEST.json")
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()
    test_parser()
    if args.self_test:
        return 0
    groups, stats = build_catalogue()
    if not groups.get("Legion рейды") or not groups.get("Legion подземелья"):
        raise RuntimeError("Required Legion loot tables absent from addon data.")
    total = sum(len(items) for items in groups.values())
    if total < 2500:
        raise RuntimeError("Unusually small AtlasLoot item catalogue: {}".format(total))
    sql, shops = render_sql(groups)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(sql, encoding="utf-8")
    manifest = {
        "addon_repo": ADDON_REPO,
        "addon_revision": ADDON_SHA,
        "build": BUILD,
        "source_modules": stats,
        "category_unique_item_counts": {name: len(items) for name, items in groups.items()},
        "items": total,
        "vendor_count": len(shops),
        "max_items_per_vendor": MAX_ITEMS,
        "first_entry": shops[0]["entry"],
        "last_entry": shops[-1]["entry"],
        "teleport": ".mall / .tele AtlasMall",
        "caveats": [
            "AtlasLoot lists base item IDs; bonus IDs/raid difficulties are not encoded.",
            "Runtime availability of each item ID and precise GM Island terrain still need in-game verification."
        ],
    }
    manifest_file = Path(args.manifest)
    manifest_file.parent.mkdir(parents=True, exist_ok=True)
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print("AtlasMall: {} distinct catalogue entries in {} categories, {} vendors, {} SQL bytes".format(
        total, len(groups), len(shops), len(sql.encode("utf-8"))))
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("AtlasMall generator failed: {}".format(exc), file=sys.stderr)
        raise
