#!/usr/bin/env python3
"""Generate copy/paste JSON skeletons for FRLG Tracker world data."""

from __future__ import annotations

import argparse
import json


def dump(value) -> None:
    print(json.dumps(value, indent=2, ensure_ascii=False))


def prompt(label: str, default: str | None = None) -> str:
    suffix = f" [{default}]" if default else ""
    value = input(f"{label}{suffix}: ").strip()
    return value or (default or "")


def csv(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def zone_object(zone_id: str) -> dict:
    return {
        "id": zone_id,
        "connections": [],
        "warps": [],
        "encounter_sources": [],
        "item_sources": [],
        "trainers": [],
    }


def interactive() -> None:
    kind = prompt("Generate (connection / portal / zone / container / choice)").lower()
    if kind == "connection":
        dump({
            "id": prompt("Connection id", "conn_"),
            "type": prompt("Type", "border"),
            "zones": [prompt("Zone A", "zone_"), prompt("Zone B", "zone_")],
            "requires": (lambda v: None if v.lower() in {"", "null", "none"} else v)(prompt("Requirement", "null")),
        })
    elif kind == "portal":
        link_type = prompt("Type (normal / drop)", "normal").lower()
        if link_type not in {"normal", "drop"}:
            raise SystemExit(f"Unknown Warp link type: {link_type}")
        dump({
            "type": link_type,
            "warps": [prompt("Warp A (departure for a drop)", "warp_"), prompt("Warp B (destination)", "warp_")],
        })
    elif kind == "zone":
        dump(zone_object(prompt("Zone id", "zone_")))
    elif kind == "container":
        oid = prompt("Container id")
        name = prompt("Display name")
        zones = csv(prompt("Zone ids (comma-separated)", f"zone_{oid}"))
        dump({"id": oid, "name": name, "zones": [zone_object(z) for z in zones]})
    elif kind == "choice":
        choice_id = prompt("Choice id", "choice_")
        option_type = prompt("Option type (item_pickup / pokemon_gift)", "item_pickup")
        if option_type not in {"item_pickup", "pokemon_gift"}:
            raise SystemExit(f"Unknown choice option type: {option_type}")
        dump({
            "id": choice_id,
            "option_type": option_type,
            "options": csv(prompt("Option ids (comma-separated)")),
            "max_selections": 1,
            "requires": (lambda v: None if v.lower() in {"", "null", "none"} else v)(prompt("Requirement", "null")),
        })
    else:
        raise SystemExit(f"Unknown generator type: {kind}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command")

    p = sub.add_parser("connection")
    p.add_argument("--id", required=True)
    p.add_argument("--type", required=True, choices=["border", "cut_tree", "water", "ledge"])
    p.add_argument("--zone-a", required=True)
    p.add_argument("--zone-b", required=True)
    p.add_argument("--requires", default=None)

    p = sub.add_parser("portal")
    p.add_argument("--type", choices=["normal", "drop"], default="normal")
    p.add_argument("--warp-a", required=True)
    p.add_argument("--warp-b", required=True)

    p = sub.add_parser("zone")
    p.add_argument("--id", required=True)

    p = sub.add_parser("container")
    p.add_argument("--id", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--zones", nargs="+", required=True)

    p = sub.add_parser("choice")
    p.add_argument("--id", required=True)
    p.add_argument("--option-type", choices=["item_pickup", "pokemon_gift"], required=True)
    p.add_argument("--options", nargs="+", required=True)
    p.add_argument("--max-selections", type=int, choices=[1], default=1)
    p.add_argument("--requires", default=None)

    args = parser.parse_args()
    if args.command is None:
        interactive()
    elif args.command == "connection":
        dump({"id": args.id, "type": args.type, "zones": [args.zone_a, args.zone_b], "requires": args.requires})
    elif args.command == "portal":
        dump({"type": args.type, "warps": [args.warp_a, args.warp_b]})
    elif args.command == "zone":
        dump(zone_object(args.id))
    elif args.command == "container":
        dump({"id": args.id, "name": args.name, "zones": [zone_object(z) for z in args.zones]})
    elif args.command == "choice":
        dump({"id": args.id, "option_type": args.option_type, "options": args.options, "max_selections": args.max_selections, "requires": args.requires})


if __name__ == "__main__":
    main()
