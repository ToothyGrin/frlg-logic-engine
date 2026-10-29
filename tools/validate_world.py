#!/usr/bin/env python3
"""Validate the FRLG Tracker world-topology JSON files.

Draft mode (default) treats references to not-yet-authored zones/warps as warnings.
Strict mode promotes those warnings to errors.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

WORLD_FILES = {
    "connections.json": Path("connections.json"),
    "portals.json": Path("portals.json"),
    "buildings.json": Path("containers") / "buildings.json",
    "instances.json": Path("containers") / "instances.json",
    "routes.json": Path("containers") / "routes.json",
    "settlements.json": Path("containers") / "settlements.json",
}

CONTAINER_FILES = (
    "buildings.json",
    "instances.json",
    "routes.json",
    "settlements.json",
)
ID_RE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
CONNECTION_TYPES = {"border", "cut_tree", "water", "ledge"}
WARP_LINK_TYPES = {"normal", "drop"}


class Report:
    def __init__(self, strict: bool = False) -> None:
        self.strict = strict
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warning(self, message: str, *, incomplete: bool = False) -> None:
        if incomplete and self.strict:
            self.errors.append(message)
        else:
            self.warnings.append(message)


def load_json(path: Path, report: Report):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        report.error(f"Missing required file: {path}")
    except json.JSONDecodeError as exc:
        report.error(
            f"{path}: invalid JSON at line {exc.lineno}, "
            f"column {exc.colno}: {exc.msg}"
        )
    return None


def walk_empty_strings(value, path: str = ""):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from walk_empty_strings(child, f"{path}.{key}" if path else key)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_empty_strings(child, f"{path}[{index}]")
    elif value == "":
        yield path


def validate(root: Path, strict: bool = False) -> Report:
    report = Report(strict=strict)
    data = {
        name: load_json(root / relative_path, report)
        for name, relative_path in WORLD_FILES.items()
    }
    if report.errors:
        return report

    return validate_data(data, strict=strict)


def validate_data(data: dict, strict: bool = False) -> Report:
    """Validate assembled collections before generated files are written."""
    report = Report(strict=strict)

    # Empty-string placeholders are always invalid. Use [] or omit unfinished objects.
    for filename, content in data.items():
        for path in walk_empty_strings(content):
            report.error(f"{filename}: empty-string placeholder at {path}")

    # Collect containers/zones/refs.
    container_ids: dict[str, str] = {}
    zone_owners: dict[str, tuple[str, str]] = {}
    zone_connections: defaultdict[str, set[str]] = defaultdict(set)
    zone_warps: dict[str, tuple[str, str, str]] = {}

    for filename in CONTAINER_FILES:
        objects = data[filename]

        if not isinstance(objects, list):
            report.error(f"{filename}: expected a top-level array")
            continue

        for obj in objects:
            if not isinstance(obj, dict):
                report.error(f"{filename}: every container must be an object")
                continue
            oid = obj.get("id")
            if not isinstance(oid, str) or not ID_RE.fullmatch(oid):
                report.error(f"{filename}: invalid container id {oid!r}")
            elif oid in container_ids:
                report.error(f"Duplicate container id {oid!r}: {container_ids[oid]} and {filename}")
            else:
                container_ids[oid] = filename

            zones = obj.get("zones")
            if not isinstance(zones, list) or not zones:
                report.error(f"{filename}:{oid}: zones must be a non-empty array")
                continue

            for zone in zones:
                if not isinstance(zone, dict):
                    report.error(f"{filename}:{oid}: every zone must be an object")
                    continue
                zid = zone.get("id")
                if not isinstance(zid, str) or not ID_RE.fullmatch(zid):
                    report.error(f"{filename}:{oid}: invalid zone id {zid!r}")
                    continue
                if not zid.startswith("zone_"):
                    report.error(f"{filename}:{oid}: zone id must start with 'zone_': {zid}")
                if zid in zone_owners:
                    prev = zone_owners[zid]
                    report.error(f"Duplicate zone id {zid!r}: {prev[0]}:{prev[1]} and {filename}:{oid}")
                else:
                    zone_owners[zid] = (filename, oid)

                for field in ("connections", "warps", "encounter_sources", "item_sources", "trainers"):
                    if field in zone and not isinstance(zone[field], list):
                        report.error(f"{filename}:{oid}:{zid}: {field} must be an array")

                refs = zone.get("connections", [])
                for cid in refs if isinstance(refs, list) else []:
                    if not isinstance(cid, str) or not ID_RE.fullmatch(cid):
                        report.error(f"{filename}:{oid}:{zid}: invalid connection id {cid!r}")
                    else:
                        zone_connections[zid].add(cid)
                warps = zone.get("warps", [])
                for wid in warps if isinstance(warps, list) else []:
                    if not isinstance(wid, str) or not ID_RE.fullmatch(wid):
                        report.error(f"{filename}:{oid}:{zid}: invalid warp id {wid!r}")
                    elif not wid.startswith("warp_"):
                        report.error(f"{filename}:{oid}:{zid}: warp id must start with 'warp_': {wid}")
                    elif wid in zone_warps:
                        prev = zone_warps[wid]
                        report.error(
                            f"Warp {wid!r} declared by multiple zones: {prev[2]} and {zid}"
                        )
                    else:
                        zone_warps[wid] = (filename, oid, zid)

    # Connections.
    connections = data["connections.json"]

    if not isinstance(connections, list):
        report.error("connections.json: expected a top-level array")
        connections = []

    conn_by_id: dict[str, dict] = {}

    for conn in connections:
        if not isinstance(conn, dict):
            report.error("connections.json: every connection must be an object")
            continue
        cid = conn.get("id")
        if not isinstance(cid, str) or not ID_RE.fullmatch(cid):
            report.error(f"connections.json: invalid connection id {cid!r}")
            continue
        if not cid.startswith("conn_"):
            report.error(f"connections.json: connection id must start with 'conn_': {cid}")
        if cid in conn_by_id:
            report.error(f"connections.json: duplicate connection id {cid!r}")
        conn_by_id[cid] = conn

        ctype = conn.get("type")
        if not isinstance(ctype, str) or ctype not in CONNECTION_TYPES:
            report.warning(f"connections.json:{cid}: unknown connection type {ctype!r}")

        endpoints = conn.get("zones")
        if not isinstance(endpoints, list) or len(endpoints) != 2:
            report.error(f"connections.json:{cid}: zones must contain exactly two zone ids")
            continue
        if endpoints[0] == endpoints[1]:
            report.error(f"connections.json:{cid}: endpoints must be distinct")
        if any(not isinstance(zid, str) or not ID_RE.fullmatch(zid) for zid in endpoints):
            report.error(f"connections.json:{cid}: endpoints must be valid zone ids")

        requires = conn.get("requires")
        if requires is not None:
            if not isinstance(requires, str) or not ID_RE.fullmatch(requires):
                report.error(f"connections.json:{cid}: invalid requirement {requires!r}")
            elif not requires.startswith("state_"):
                report.error(f"connections.json:{cid}: requirement must be null or a state_* id: {requires}")

    # Every zone connection ref exists; every authored endpoint declares the connection.
    for zid, refs in zone_connections.items():
        for cid in refs:
            if cid not in conn_by_id:
                report.error(f"{zid}: references undefined connection {cid}")

    for cid, conn in conn_by_id.items():
        endpoints = conn.get("zones", [])
        if not isinstance(endpoints, list):
            continue
        for zid in endpoints:
            if not isinstance(zid, str):
                continue
            if zid not in zone_owners:
                report.warning(
                    f"connections.json:{cid}: endpoint zone not authored yet: {zid}",
                    incomplete=True,
                )
            elif cid not in zone_connections[zid]:
                report.error(f"{zid}: is endpoint of {cid} but does not declare it")

    # Direction comes from the link type. Destinations may repeat; departures may not.
    warp_departures: dict[str, tuple[str, int]] = {}
    portals = data["portals.json"]

    if not isinstance(portals, list):
        report.error("portals.json: expected a top-level array")
        portals = []

    for index, link in enumerate(portals):
        if not isinstance(link, dict):
            report.error(f"portals.json[{index}]: Warp link must be an object with type and warps")
            continue
        link_type = link.get("type")
        if not isinstance(link_type, str) or link_type not in WARP_LINK_TYPES:
            report.error(f"portals.json[{index}]: unknown Warp link type {link_type!r}")
            continue
        pair = link.get("warps")
        if not isinstance(pair, list) or len(pair) != 2:
            report.error(f"portals.json[{index}]: warps must contain exactly two warp ids")
            continue
        if pair[0] == pair[1]:
            report.error(f"portals.json[{index}]: Warp link endpoints must be distinct")
            continue
        valid = True
        for wid in pair:
            if not isinstance(wid, str) or not ID_RE.fullmatch(wid) or not wid.startswith("warp_"):
                report.error(f"portals.json[{index}]: invalid warp id {wid!r}")
                valid = False
            else:
                if wid not in zone_warps:
                    report.warning(
                        f"portals.json[{index}]: warp not declared by an authored zone yet: {wid}",
                        incomplete=True,
                    )

        if not valid:
            continue
        departures = [pair] if link_type == "drop" else [pair, list(reversed(pair))]
        for source, destination in departures:
            if source in warp_departures:
                previous_destination, previous_index = warp_departures[source]
                report.error(
                    f"portals.json[{index}]: duplicate outgoing Warp {source}; "
                    f"already maps to {previous_destination} in portals.json[{previous_index}]"
                )
            else:
                warp_departures[source] = (destination, index)

    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "root",
        nargs="?",
        default=".",
        help="World data root containing connections.json, portals.json, and containers/",
    )
    parser.add_argument("--strict", action="store_true", help="Treat not-yet-authored references as errors")
    args = parser.parse_args()

    root = Path(args.root)
    report = validate(root, strict=args.strict)

    for message in report.errors:
        print(f"ERROR: {message}")
    for message in report.warnings:
        print(f"WARN:  {message}")

    print(f"\n{len(report.errors)} error(s), {len(report.warnings)} warning(s)")
    return 1 if report.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
