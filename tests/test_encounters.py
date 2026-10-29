"""Schema checks for the shared wild-encounter representation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from validate_encounters import validate_encounters
from validate_world import Report, validate


class EncounterValidationTests(unittest.TestCase):
    def setUp(self):
        self.source = {"id": "enc_test_grass", "method": "grass", "requires": None, "encounters": [
            {"pokemon": "species_nidoran_f", "levels": [6], "rate": 1, "versions": ["firered"]},
            {"pokemon": "species_nidoran_f", "levels": [6, 7], "rate": 14, "versions": ["leafgreen"]},
            {"pokemon": "species_nidoran_m", "levels": [6, 7], "rate": 14, "versions": ["firered"]},
            {"pokemon": "species_nidoran_m", "levels": [6], "rate": 1, "versions": ["leafgreen"]},
            {"pokemon": "species_pidgey", "levels": [3, 5, 7], "rate": 85},
        ]}
        self.zones = [{"id": "zone_a", "encounter_sources": ["enc_test_grass"]}, {"id": "zone_b"}]

    def report(self, source=None, zones=None):
        report = Report()
        validate_encounters([self.source if source is None else source], self.zones if zones is None else zones, report)
        return report

    def test_split_versions_and_exact_levels_are_valid(self):
        self.assertEqual(self.report().errors, [])

    def test_rates_and_species_are_checked_per_version(self):
        source = copy.deepcopy(self.source)
        source["encounters"][0]["rate"] = 2
        errors = self.report(source).errors
        self.assertTrue(any("firered rates total 101" in error for error in errors))
        self.assertFalse(any("leafgreen rates total" in error for error in errors))
        source = copy.deepcopy(self.source)
        source["encounters"][0].pop("versions")
        self.assertTrue(any("duplicate species" in error for error in self.report(source).errors))

    def test_invalid_entry_fields(self):
        mutations = [
            ("pokemon", "pokemon_pidgey"), ("pokemon", []),
            ("levels", []), ("levels", [0]), ("levels", [101]),
            ("levels", [True]), ("levels", [5.5]), ("levels", [5, 5]), ("levels", "5"),
            ("rate", True), ("rate", 0), ("rate", -1), ("rate", 101),
            ("rate", float("nan")), ("rate", float("inf")), ("rate", "100"),
            ("versions", []), ("versions", ["emerald"]), ("versions", "firered"),
            ("versions", [None]), ("versions", ["firered", "firered"]),
        ]
        for key, value in mutations:
            with self.subTest(key=key, value=value):
                source = copy.deepcopy(self.source)
                source["encounters"][0][key] = value
                self.assertTrue(self.report(source).errors)

    def test_invalid_source_shapes_and_method_requirements(self):
        sources = [None, [], {}, {"id": "enc_test", "method": [], "encounters": [42]},
                   {**self.source, "encounters": []}, {**self.source, "method": "unknown"},
                   {**self.source, "method": "surf", "requires": None},
                   {**self.source, "method": "good_rod", "requires": "state_has_old_rod"}]
        for source in sources:
            with self.subTest(source=source):
                report = Report()
                validate_encounters([source], [], report)
                self.assertTrue(report.errors)
        for method, requirement in (("surf", "state_can_surf"), ("old_rod", "state_has_old_rod"),
                                    ("good_rod", "state_has_good_rod"), ("super_rod", "state_has_super_rod")):
            self.assertEqual(self.report({**self.source, "method": method, "requires": requirement}).errors, [])
        missing = copy.deepcopy(self.source)
        missing.pop("requires")
        self.assertTrue(self.report(missing).errors)

    def test_source_and_reference_uniqueness(self):
        report = Report()
        validate_encounters([self.source, self.source], [], report)
        self.assertTrue(any("duplicate encounter source id" in error for error in report.errors))
        for refs in (["enc_missing"], ["enc_test_grass", "enc_test_grass"], [42], "enc_test_grass"):
            with self.subTest(refs=refs):
                self.assertTrue(self.report(zones=[{"id": "zone_a", "encounter_sources": refs}]).errors)
        shared = [{"id": "zone_a", "encounter_sources": ["enc_test_grass"]},
                  {"id": "zone_b", "encounter_sources": ["enc_test_grass"]}]
        self.assertEqual(self.report(zones=shared).errors, [])

    def test_authored_data_validates(self):
        root = Path(__file__).resolve().parents[1] / "data" / "world"
        report = validate(root)
        self.assertEqual(report.errors, [])


if __name__ == "__main__":
    unittest.main()
