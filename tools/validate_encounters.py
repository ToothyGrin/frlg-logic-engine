"""Validate species-aggregated wild tables and their Zone references (D042–D043)."""

import math
import re

VERSIONS = ("firered", "leafgreen")
METHOD_REQUIREMENTS = {
    "grass": None,
    "cave": None,
    "surf": "state_can_surf",
    "old_rod": "state_has_old_rod",
    "good_rod": "state_has_good_rod",
    "super_rod": "state_has_super_rod",
}
SPECIES_RE = re.compile(r"^species_[a-z0-9]+(?:_[a-z0-9]+)*$")
SOURCE_RE = re.compile(r"^enc_[a-z0-9]+(?:_[a-z0-9]+)*$")


def validate_encounters(sources, zones, report):
    """Append errors to the shared report; missing wild references are always errors."""
    if not isinstance(sources, list):
        report.error("wild.json: expected a top-level array")
        sources = []

    ids = set()
    for source in sources:
        if not isinstance(source, dict):
            report.error("wild.json: every source must be an object")
            continue
        sid = source.get("id")
        location = f"wild.json:{sid}"
        if not isinstance(sid, str) or not SOURCE_RE.fullmatch(sid):
            report.error(f"{location}: invalid encounter source id")
        elif sid in ids:
            report.error(f"{location}: duplicate encounter source id")
        else:
            ids.add(sid)

        method = source.get("method")
        if not isinstance(method, str) or method not in METHOD_REQUIREMENTS:
            report.error(f"{location}: unknown encounter method {method!r}")
        elif "requires" not in source or source["requires"] != METHOD_REQUIREMENTS[method]:
            report.error(f"{location}: {method} requires {METHOD_REQUIREMENTS[method]!r}")

        entries = source.get("encounters")
        if not isinstance(entries, list) or not entries:
            report.error(f"{location}: encounters must be a non-empty array")
            continue

        totals = {version: 0.0 for version in VERSIONS}
        species = {version: set() for version in VERSIONS}
        for index, entry in enumerate(entries):
            entry_location = f"{location}:encounters[{index}]"
            if not isinstance(entry, dict):
                report.error(f"{entry_location}: expected an object")
                continue
            pokemon = entry.get("pokemon")
            valid_pokemon = isinstance(pokemon, str) and SPECIES_RE.fullmatch(pokemon)
            if not valid_pokemon:
                report.error(f"{entry_location}: pokemon must be a species_* id")

            levels = entry.get("levels")
            if (not isinstance(levels, list) or not levels
                    or any(type(level) is not int or not 1 <= level <= 100 for level in levels)):
                report.error(f"{entry_location}: levels must contain integers from 1 to 100")
            elif len(set(levels)) != len(levels):
                report.error(f"{entry_location}: duplicate levels")

            rate = entry.get("rate")
            valid_rate = (type(rate) in (int, float) and 0 < rate <= 100 and math.isfinite(rate))
            if not valid_rate:
                report.error(f"{entry_location}: rate must be a finite number greater than 0 and at most 100")

            versions = entry.get("versions", list(VERSIONS))
            if (not isinstance(versions, list) or not versions
                    or any(not isinstance(version, str) or version not in VERSIONS for version in versions)):
                report.error(f"{entry_location}: versions must be a non-empty array of supported games")
                continue
            if len(set(versions)) != len(versions):
                report.error(f"{entry_location}: duplicate versions")
                continue
            for version in versions:
                if valid_rate:
                    totals[version] += rate
                if valid_pokemon:
                    if pokemon in species[version]:
                        report.error(f"{entry_location}: duplicate species {pokemon} for {version}")
                    species[version].add(pokemon)

        for version, total in totals.items():
            if not math.isclose(total, 100, rel_tol=0, abs_tol=1e-9):
                report.error(f"{location}: {version} rates total {total:g}, expected 100")

    for zone in zones:
        refs = zone.get("encounter_sources", [])
        if not isinstance(refs, list):
            report.error(f"{zone['id']}: encounter_sources must be an array")
            continue
        seen = set()
        for ref in refs:
            if not isinstance(ref, str) or not SOURCE_RE.fullmatch(ref):
                report.error(f"{zone['id']}: invalid encounter source reference {ref!r}")
            elif ref not in ids:
                report.error(f"{zone['id']}: unknown encounter source {ref}")
            elif ref in seen:
                report.error(f"{zone['id']}: duplicate encounter source reference {ref}")
            else:
                seen.add(ref)
