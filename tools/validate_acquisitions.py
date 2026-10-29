"""Validate D047/D048 sources and their optional typed Zone references."""
import math
import re

KINDS = ("pokemon_trades", "pokemon_vendors", "item_vendors")
VERSIONS = ("firered", "leafgreen")


def identifier(value, prefix):
    return isinstance(value, str) and re.fullmatch(prefix + r"[a-z0-9]+(?:_[a-z0-9]+)*", value) is not None


def validate_acquisitions(data, zones, report):
    for kind in KINDS:
        sources = data.get(kind + ".json")
        if not isinstance(sources, list):
            report.error(f"{kind}: expected a top-level array")
            sources = []
        ids = set()
        for source in sources:
            if not isinstance(source, dict):
                report.error(f"{kind}: expected a source object")
                continue
            sid = source.get("id")
            location = f"{kind}:{sid}"
            if not identifier(sid, kind.removesuffix("s") + "_"):
                report.error(f"{location}: invalid source id")
            elif sid in ids:
                report.error(f"{location}: duplicate source id")
            else:
                ids.add(sid)
            if "requires" not in source or (source["requires"] is not None and not identifier(source["requires"], "state_")):
                report.error(f"{location}: requires must be null or a state_* id")
            field = "exchanges" if kind == "pokemon_trades" else "offers"
            entries = source.get(field)
            if not isinstance(entries, list) or not entries:
                report.error(f"{location}: {field} must be a non-empty array")
                continue
            counts = dict.fromkeys(VERSIONS, 0)
            for index, entry in enumerate(entries):
                label = f"{location}:{field}[{index}]"
                if not isinstance(entry, dict):
                    report.error(f"{label}: expected an entry object")
                    continue
                versions = entry.get("versions", list(VERSIONS))
                if (not isinstance(versions, list) or not versions
                        or any(not isinstance(v, str) or v not in VERSIONS for v in versions)):
                    report.error(f"{label}: invalid versions")
                elif len(set(versions)) != len(versions):
                    report.error(f"{label}: duplicate versions")
                else:
                    for version in versions:
                        counts[version] += 1
                if type(entry.get("repeatable")) is not bool:
                    report.error(f"{label}: repeatable must be boolean")
                if kind == "pokemon_trades":
                    if not identifier(entry.get("requested_pokemon"), "species_"):
                        report.error(f"{label}: invalid requested_pokemon")
                    if entry.get("level_rule") != "match_requested_pokemon":
                        report.error(f"{label}: unknown level_rule")
                    if "held_item" not in entry or (entry["held_item"] is not None and not identifier(entry["held_item"], "item_")):
                        report.error(f"{label}: held_item must be null or an item_* id")
                else:
                    price = entry.get("price")
                    if not ((type(price) is int and price > 0)
                            or (type(price) is float and math.isfinite(price) and price > 0)):
                        report.error(f"{label}: price must be a positive finite number")
                    if entry.get("currency") not in ("money", "coins"):
                        report.error(f"{label}: unknown currency")
                if kind == "item_vendors":
                    if not identifier(entry.get("item"), "item_"):
                        report.error(f"{label}: invalid item")
                    if type(entry.get("quantity")) is not int or entry["quantity"] <= 0:
                        report.error(f"{label}: quantity must be a positive integer")
                else:
                    if not identifier(entry.get("pokemon"), "species_"):
                        report.error(f"{label}: invalid pokemon")
                    if kind == "pokemon_vendors":
                        levels = entry.get("levels")
                        if (not isinstance(levels, list) or not levels
                                or any(type(level) is not int or not 1 <= level <= 100 for level in levels)):
                            report.error(f"{label}: invalid levels")
                        elif len(set(levels)) != len(levels):
                            report.error(f"{label}: duplicate levels")
            if kind == "pokemon_trades" and any(count != 1 for count in counts.values()):
                report.error(f"{location}: exactly one exchange is required per game")
        for zone in zones:
            refs = zone.get(kind, [])
            if not isinstance(refs, list):
                report.error(f"{zone['id']}: {kind} must be an array")
                continue
            seen = set()
            for ref in refs:
                if not isinstance(ref, str) or ref not in ids:
                    report.error(f"{zone['id']}: unknown {kind} source {ref!r}")
                elif ref in seen:
                    report.error(f"{zone['id']}: duplicate {kind} reference {ref}")
                else:
                    seen.add(ref)
