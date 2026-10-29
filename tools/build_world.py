#!/usr/bin/env python3
"""Build runtime world collections from small authored JSON arrays.

Run from any directory. Defaults are relative to this project's root.
Use --check before committing to validate sources and detect stale runtime data.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from validate_world import BUILD_FILES, CONTAINER_FILES, ID_RE, Report, validate_data

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOT = PROJECT_ROOT / "data" / "source"
OUTPUT_ROOT = PROJECT_ROOT / "data"


def assemble(source_root: Path) -> tuple[dict, Report]:
    """Load every configured category and report source errors with filenames."""
    data = {}
    report = Report()
    identities = {}

    # Share the category configuration with the existing world validator.
    for name, relative_path in BUILD_FILES.items():
        directory = source_root / relative_path.with_suffix("")
        paths = sorted(directory.rglob("*.json"))
        records = []
        data[name] = records

        if not paths:
            report.error(f"No source JSON files found for {relative_path}: {directory}")
            continue

        for path in paths:
            try:
                content = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, UnicodeError, ValueError) as exc:
                report.error(f"{path}: {exc}")
                continue

            if not isinstance(content, list):
                report.error(f"{path}: expected a top-level array")
                continue

            for index, record in enumerate(content):
                location = f"{path}[{index}]"
                if name == "portals.json":
                    if not isinstance(record, dict):
                        report.error(f"{location}: expected a typed Warp link object")
                        continue
                else:
                    if not isinstance(record, dict):
                        report.error(f"{location}: expected an object")
                        continue
                    record_id = record.get("id")
                    if not isinstance(record_id, str) or not ID_RE.fullmatch(record_id):
                        report.error(f"{location}: invalid id {record_id!r}")
                        continue
                    kind = "container" if name in CONTAINER_FILES else name
                    identity = (kind, record_id)
                    if identity in identities:
                        report.error(
                            f"{location}: duplicate {record_id!r}; first authored at {identities[identity]}"
                        )
                    else:
                        identities[identity] = location
                records.append(record)

        # Only sort the top-level collection. Never reorder endpoints or nested data.
        if name != "portals.json":
            records.sort(key=lambda record: record["id"])

    return data, report


def build(
    source_root: Path = SOURCE_ROOT,
    output_root: Path = OUTPUT_ROOT,
    *,
    check: bool = False,
    strict: bool = False,
) -> Report:
    """Validate the assembled world, then write or compare its runtime collections."""
    report = Report(strict=strict)
    source_root = source_root.resolve()
    output_root = output_root.resolve()
    destinations = [output_root / path for path in BUILD_FILES.values()]
    if (source_root == output_root or source_root in output_root.parents
            or any(source_root == path or source_root in path.parents for path in destinations)):
        report.error("Source and output directories must be separate; generated files must not be inside source")
        return report

    try:
        data, source_report = assemble(source_root)
        report.errors.extend(source_report.errors)
        report.warnings.extend(source_report.warnings)
        if report.errors:
            return report

        # Sort well-shaped links first so validation indices match generated output.
        # Malformed links are left for the validator to diagnose without a sort error.
        links = data["portals.json"]
        if all(
            isinstance(link.get("type"), str)
            and isinstance(link.get("warps"), list)
            and all(isinstance(warp, str) for warp in link["warps"])
            for link in links
        ):
            links.sort(key=lambda link: (link["type"], *link["warps"]))

        validation = validate_data(data, strict=strict)
        report.errors.extend(validation.errors)
        report.warnings.extend(validation.warnings)
        if report.errors:
            return report

        # Validate every collection before touching any runtime output.
        outputs = {
            output_root / relative_path: (
                json.dumps(data[name], indent=2, ensure_ascii=False) + "\n"
            ).encode("utf-8")
            for name, relative_path in BUILD_FILES.items()
        }

        for path, content in outputs.items():
            if check:
                if not path.is_file() or path.read_bytes() != content:
                    report.error(f"Generated file is missing or stale: {path}")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                if not path.is_file() or path.read_bytes() != content:
                    path.write_bytes(content)
    except (OSError, UnicodeError, ValueError) as exc:
        report.error(str(exc))

    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE_ROOT, help="Authored data root (contains world/ and encounters/)")
    parser.add_argument("--output", type=Path, default=OUTPUT_ROOT, help="Runtime data root (contains world/ and encounters/)")
    parser.add_argument("--check", action="store_true", help="Check without writing any files")
    parser.add_argument("--strict", action="store_true", help="Reject incomplete world references")
    args = parser.parse_args()
    report = build(args.source, args.output, check=args.check, strict=args.strict)

    for message in report.errors:
        print(f"ERROR: {message}")
    for message in report.warnings:
        print(f"WARN:  {message}")
    print(f"\n{len(report.errors)} error(s), {len(report.warnings)} warning(s)")
    if not report.errors:
        print("World data is current." if args.check else "World data built and validated.")
    elif args.check:
        print("Fix source errors, then run: python tools/build_world.py")
    return 1 if report.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
