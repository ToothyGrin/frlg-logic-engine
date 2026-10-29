"""Run with: python -m unittest discover -s tests -p 'test_*.py'."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_world import build
from validate_world import BUILD_FILES, validate


class WorldBuildTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.output = self.root / "runtime"
        self.data = {
            "buildings.json": [{"id": "house", "zones": [{
                "id": "zone_a", "connections": ["conn_b_a"], "warps": ["warp_a"],
            }]}],
            "settlements.json": [{"id": "town", "zones": [{
                "id": "zone_b", "connections": ["conn_b_a"], "warps": ["warp_b"],
            }]}],
            "instances.json": [],
            "routes.json": [],
            "connections.json": [{
                "id": "conn_b_a", "type": "ledge", "zones": ["zone_b", "zone_a"],
                "requires": None,
            }],
            "portals.json": [{"type": "normal", "warps": ["warp_b", "warp_a"]}],
            "wild.json": [],
        }
        for name, records in self.data.items():
            self.write_source(name, records)

    def write_source(self, name, records, filename="part.json"):
        path = self.source / BUILD_FILES[name].with_suffix("") / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(records), encoding="utf-8")
        return path

    def snapshot(self):
        return {path.relative_to(self.output): path.read_bytes() for path in self.output.rglob("*.json")}

    def test_build_preserves_records_and_direction(self):
        report = build(self.source, self.output)
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])
        for name, relative_path in BUILD_FILES.items():
            self.assertEqual(json.loads((self.output / relative_path).read_text()), self.data[name])
        self.assertEqual(validate(self.output / "world", strict=True).errors, [])
        self.assertEqual(build(self.source, self.output, check=True).errors, [])

    def test_check_reports_stale_files_without_writing(self):
        self.assertEqual(build(self.source, self.output).errors, [])
        path = self.output / "world" / "connections.json"
        path.write_bytes(b"[]\n")
        before = self.snapshot()
        report = build(self.source, self.output, check=True)
        self.assertTrue(any("connections.json" in error for error in report.errors))
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(build(self.source, self.output).errors, [])
        self.assertEqual(build(self.source, self.output, check=True).errors, [])

    def test_check_does_not_create_output_directory(self):
        report = build(self.source, self.output, check=True)
        self.assertEqual(len(report.errors), len(BUILD_FILES))
        self.assertFalse(self.output.exists())

    def test_source_edits_require_rebuilding(self):
        self.assertEqual(build(self.source, self.output).errors, [])
        before = self.snapshot()
        self.data["buildings.json"][0]["name"] = "Updated display name"
        self.write_source("buildings.json", self.data["buildings.json"])
        report = build(self.source, self.output, check=True)
        self.assertTrue(any("buildings.json" in error for error in report.errors))
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(build(self.source, self.output).errors, [])
        self.assertNotEqual(self.snapshot(), before)
        self.assertEqual(build(self.source, self.output, check=True).errors, [])

    def test_duplicate_ids_include_both_source_locations(self):
        self.assertEqual(build(self.source, self.output).errors, [])
        before = self.snapshot()
        self.write_source("buildings.json", self.data["buildings.json"], "duplicate.json")
        report = build(self.source, self.output)
        self.assertTrue(any("duplicate" in error and "part.json" in error for error in report.errors))
        self.assertEqual(self.snapshot(), before)

    def test_duplicate_connection_ids_are_rejected(self):
        self.write_source("connections.json", self.data["connections.json"], "duplicate.json")
        self.assertTrue(any("duplicate" in error for error in build(self.source, self.output).errors))
        self.assertFalse(self.output.exists())

    def test_invalid_reference_leaves_previous_outputs_untouched(self):
        self.assertEqual(build(self.source, self.output).errors, [])
        before = self.snapshot()
        self.data["buildings.json"][0]["zones"][0]["connections"].append("conn_missing")
        self.write_source("buildings.json", self.data["buildings.json"])
        report = build(self.source, self.output)
        self.assertTrue(any("conn_missing" in error for error in report.errors))
        self.assertEqual(self.snapshot(), before)

    def test_invalid_encounters_prevent_all_runtime_writes(self):
        self.assertEqual(build(self.source, self.output).errors, [])
        before = self.snapshot()
        self.data["buildings.json"][0]["name"] = "Must not be written"
        self.write_source("buildings.json", self.data["buildings.json"])
        self.write_source("wild.json", [{"id": "enc_test", "method": "grass", "requires": None,
            "encounters": [{"pokemon": "species_pidgey", "levels": [3, 5, 7], "rate": 99}]}])
        self.assertTrue(any("rates total 99" in error for error in build(self.source, self.output).errors))
        self.assertEqual(self.snapshot(), before)

    def test_encounter_references_are_required_even_in_draft_mode(self):
        self.data["buildings.json"][0]["zones"][0]["encounter_sources"] = ["enc_missing"]
        self.write_source("buildings.json", self.data["buildings.json"])
        self.assertTrue(any("unknown encounter source" in error for error in build(self.source, self.output).errors))
        self.assertFalse(self.output.exists())

    def test_draft_and_strict_incomplete_references(self):
        self.data["connections.json"].append({
            "id": "conn_a_missing", "type": "border", "zones": ["zone_a", "zone_missing"],
        })
        self.data["buildings.json"][0]["zones"][0]["connections"].append("conn_a_missing")
        self.write_source("connections.json", self.data["connections.json"])
        self.write_source("buildings.json", self.data["buildings.json"])
        draft = build(self.source, self.output)
        self.assertEqual(draft.errors, [])
        self.assertEqual(len(draft.warnings), 1)
        before = self.snapshot()
        strict = build(self.source, self.output, strict=True)
        self.assertTrue(any("zone_missing" in error for error in strict.errors))
        self.assertEqual(self.snapshot(), before)

    def test_malformed_sources_report_errors_instead_of_crashing(self):
        cases = [
            ("buildings.json", {}),
            ("buildings.json", [42]),
            ("buildings.json", [{"id": "house", "zones": [42]}]),
            ("buildings.json", [{"id": "house", "zones": [{
                "id": "zone_a", "connections": {}, "warps": 42,
            }]}]),
            ("connections.json", [None]),
            ("connections.json", [{"id": "conn_bad", "type": [], "zones": [[], "zone_a"]}]),
            ("portals.json", [{"warps": ["warp_a", "warp_b"]}]),
            ("portals.json", [["warp_a", "warp_b"]]),
            ("portals.json", [{"type": "drop", "warps": [[], "warp_a"]}]),
            ("portals.json", [{"type": [], "warps": ["warp_a", "warp_b"]}]),
        ]
        for name, records in cases:
            with self.subTest(name=name, records=records):
                self.write_source(name, records)
                report = build(self.source, self.output)
                self.assertTrue(report.errors)
                self.assertFalse(self.output.exists())
                self.write_source(name, self.data[name])

    def test_invalid_json_names_source_file(self):
        path = self.write_source("buildings.json", [])
        path.write_text("[broken", encoding="utf-8")
        report = build(self.source, self.output)
        self.assertTrue(any(str(path.resolve()) in error for error in report.errors), report.errors)
        self.assertFalse(self.output.exists())

    def test_missing_category_is_not_silently_dropped(self):
        path = self.source / "world" / "portals" / "part.json"
        path.unlink()
        report = build(self.source, self.output)
        self.assertTrue(any("No source JSON files" in error for error in report.errors))
        self.assertFalse(self.output.exists())

    def test_source_order_does_not_change_generated_content(self):
        second = {"id": "another_house", "zones": [{
            "id": "zone_isolated", "connections": [], "warps": [],
        }]}
        first = self.data["buildings.json"][0]
        self.write_source("buildings.json", [first, second])
        self.assertEqual(build(self.source, self.output).errors, [])
        before = self.snapshot()
        self.write_source("buildings.json", [second])
        self.write_source("buildings.json", [first], "nested/other.json")
        self.assertEqual(build(self.source, self.output, check=True).errors, [])
        self.assertEqual(self.snapshot(), before)

    def test_overlapping_source_and_output_are_rejected(self):
        for output in (self.source, self.source / "generated"):
            with self.subTest(output=output):
                report = build(self.source, output)
                self.assertTrue(any("must be separate" in error for error in report.errors))
        report = build(self.root / "world", self.root)
        self.assertTrue(any("must be separate" in error for error in report.errors))

    def test_parent_output_root_preserves_authored_files(self):
        before = {path: path.read_bytes() for path in self.source.rglob("*.json")}
        self.assertEqual(build(self.source, self.root).errors, [])
        self.assertEqual(build(self.source, self.root, check=True).errors, [])
        self.assertEqual({path: path.read_bytes() for path in self.source.rglob("*.json")}, before)

    def add_warp(self, warp):
        self.data["buildings.json"][0]["zones"][0]["warps"].append(warp)
        self.write_source("buildings.json", self.data["buildings.json"])

    def test_drop_order_and_shared_destination_are_preserved(self):
        self.add_warp("warp_c")
        self.add_warp("warp_unpaired")
        self.write_source("portals.json", [
            {"type": "drop", "warps": ["warp_c", "warp_a"]},
            {"type": "drop", "warps": ["warp_b", "warp_a"]},
        ])
        report = build(self.source, self.output, strict=True)
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])
        links = json.loads((self.output / "world" / "portals.json").read_text())
        self.assertEqual(links, [
            {"type": "drop", "warps": ["warp_b", "warp_a"]},
            {"type": "drop", "warps": ["warp_c", "warp_a"]},
        ])
        self.assertEqual(build(self.source, self.output, check=True, strict=True).errors, [])
        self.assertEqual(validate(self.output / "world", strict=True).errors, [])

    def test_explicit_departure_from_a_shared_landing(self):
        self.add_warp("warp_c")
        self.write_source("portals.json", [
            {"type": "normal", "warps": ["warp_b", "warp_a"]},
            {"type": "drop", "warps": ["warp_c", "warp_a"]},
        ])
        self.assertEqual(build(self.source, self.output, strict=True).errors, [])

    def test_warp_link_errors_prevent_generation(self):
        self.assertEqual(build(self.source, self.output).errors, [])
        before = self.snapshot()
        cases = [
            [{"type": "unknown", "warps": ["warp_a", "warp_b"]}],
            [{"type": "drop", "warps": ["warp_a", "warp_a"]}],
            [{"type": "drop", "warps": ["warp_a"]}],
            [{"type": "normal", "warps": ["bad_id", "warp_b"]}],
            [
                {"type": "normal", "warps": ["warp_a", "warp_b"]},
                {"type": "drop", "warps": ["warp_b", "warp_a"]},
            ],
            [
                {"type": "drop", "warps": ["warp_a", "warp_b"]},
                {"type": "drop", "warps": ["warp_a", "warp_b"]},
            ],
        ]
        for links in cases:
            with self.subTest(links=links):
                self.write_source("portals.json", links)
                self.assertTrue(build(self.source, self.output).errors)
                self.assertEqual(self.snapshot(), before)

    def test_missing_link_destination_draft_and_strict(self):
        self.write_source("portals.json", [{"type": "drop", "warps": ["warp_a", "warp_missing"]}])
        report = build(self.source, self.output)
        self.assertEqual(report.errors, [])
        self.assertEqual(len(report.warnings), 1)
        self.assertTrue(build(self.source, self.output, strict=True).errors)

    def test_generator_emits_typed_links(self):
        generator = Path(__file__).resolve().parents[1] / "tools" / "generate_entry.py"
        for kind in ("normal", "drop"):
            result = subprocess.run([
                sys.executable, str(generator), "portal", "--type", kind,
                "--warp-a", "warp_b", "--warp-b", "warp_a",
            ], capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(result.stdout), {"type": kind, "warps": ["warp_b", "warp_a"]})
        default = subprocess.run([
            sys.executable, str(generator), "portal", "--warp-a", "warp_a", "--warp-b", "warp_b",
        ], capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(default.stdout)["type"], "normal")
        interactive = subprocess.run([
            sys.executable, str(generator),
        ], input="portal\ndrop\nwarp_b\nwarp_a\n", capture_output=True, text=True, check=True)
        payload = interactive.stdout[interactive.stdout.index("{"):]
        self.assertEqual(json.loads(payload), {"type": "drop", "warps": ["warp_b", "warp_a"]})
        invalid = subprocess.run([
            sys.executable, str(generator), "portal", "--type", "unknown",
            "--warp-a", "warp_a", "--warp-b", "warp_b",
        ], capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0)


if __name__ == "__main__":
    unittest.main()
