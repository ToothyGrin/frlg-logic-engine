"""Validate gift payloads and exclusive groups; fossil rewards remain references only."""
from validate_acquisitions import identifier


def validate_choices(data, zones, report):
    gifts = data.get("pokemon_gifts.json")
    groups = data.get("choices.json")
    if not isinstance(gifts, list):
        report.error("pokemon_gifts: expected an array")
        gifts = []
    if not isinstance(groups, list):
        report.error("choices: expected an array")
        groups = []
    gift_ids = set()
    placed = {"pokemon_gift": set(), "item_pickup": set()}
    for gift in gifts:
        if not isinstance(gift, dict):
            report.error("pokemon_gifts: expected an object")
            continue
        sid = gift.get("id")
        if not identifier(sid, "pokemon_gift_") or sid in gift_ids:
            report.error(f"pokemon_gifts: invalid or duplicate id {sid!r}")
        else:
            gift_ids.add(sid)
        if not identifier(gift.get("pokemon"), "species_"):
            report.error(f"{sid}: invalid pokemon")
        levels = gift.get("levels")
        if (not isinstance(levels, list) or not levels
                or any(type(n) is not int or not 1 <= n <= 100 for n in levels)):
            report.error(f"{sid}: invalid levels")
        elif len(set(levels)) != len(levels):
            report.error(f"{sid}: duplicate levels")
        if type(gift.get("repeatable")) is not bool:
            report.error(f"{sid}: repeatable must be boolean")
        if gift.get("requires") is not None and not identifier(gift["requires"], "state_"):
            report.error(f"{sid}: invalid requires")
    for zone in zones:
        for field, kind in (("pokemon_gifts", "pokemon_gift"), ("item_pickups", "item_pickup"), ("item_sources", "item_pickup")):
            refs = zone.get(field, [])
            if not isinstance(refs, list):
                report.error(f"{zone['id']}: {field} must be an array")
                continue
            seen = set()
            for ref in refs:
                if field == "item_sources" and not identifier(ref, "item_pickup_"):
                    continue  # Other draft gift/item references remain outside this schema.
                if not identifier(ref, kind + "_"):
                    report.error(f"{zone['id']}: invalid {field} reference {ref!r}")
                elif ref in seen:
                    report.error(f"{zone['id']}: duplicate {field} reference {ref}")
                elif kind == "pokemon_gift" and ref not in gift_ids:
                    report.error(f"{zone['id']}: unknown gift {ref}")
                else:
                    placed[kind].add(ref)
                    seen.add(ref)
    group_ids = set()
    members = set()
    for group in groups:
        if not isinstance(group, dict):
            report.error("choices: expected an object")
            continue
        gid = group.get("id")
        if not identifier(gid, "choice_") or gid in group_ids:
            report.error(f"choices: invalid or duplicate id {gid!r}")
        else:
            group_ids.add(gid)
        kind = group.get("option_type")
        if not isinstance(kind, str) or kind not in placed:
            report.error(f"{gid}: unsupported option_type")
            continue
        if type(group.get("max_selections")) is not int or group["max_selections"] != 1:
            report.error(f"{gid}: max_selections must be 1")
        if group.get("requires") is not None and not identifier(group["requires"], "state_"):
            report.error(f"{gid}: invalid requires")
        options = group.get("options")
        if not isinstance(options, list) or len(options) < 2:
            report.error(f"{gid}: options must contain at least two sources")
            continue
        for sid in options:
            if not identifier(sid, kind + "_"):
                report.error(f"{gid}: invalid option {sid!r}")
            elif sid not in placed[kind]:
                report.error(f"{gid}: option is not a declared Zone source: {sid}")
            elif sid in members:
                report.error(f"{gid}: source belongs to multiple options/groups: {sid}")
            else:
                members.add(sid)
