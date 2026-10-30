"""Choice group, gift schema, and metadata-only fossil validation."""
import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from validate_choices import validate_choices
from validate_world import Report, validate


class ChoiceValidationTests(unittest.TestCase):
    def setUp(self):
        self.gifts = [{"id": f"pokemon_gift_ball_{n}", "pokemon": "species_bulbasaur", "levels": [5], "repeatable": False} for n in (1, 2)]
        self.groups = [dict(id="choice_starter", option_type="pokemon_gift", options=[g["id"] for g in self.gifts], max_selections=1)]
        self.data = {"pokemon_gifts.json": self.gifts, "choices.json": self.groups}
        self.zones = [{"id": "zone_lab", "pokemon_gifts": [g["id"] for g in self.gifts]},
                      {"id": "zone_cave", "item_sources": ["item_pickup_west", "item_pickup_east", "item_gift_draft"]}]

    def errors(self, data=None, zones=None):
        report = Report()
        validate_choices(self.data if data is None else data, self.zones if zones is None else zones, report)
        return report.errors

    def test_valid_groups_and_reference_only_fossils(self):
        self.groups.append(dict(id="choice_fossil", option_type="item_pickup", options=["item_pickup_west", "item_pickup_east"], max_selections=1, requires="state_ready"))
        self.assertEqual(self.errors(), [])
        self.zones[1]["item_pickups"] = self.zones[1].pop("item_sources")[:2]
        self.assertEqual(self.errors(), [])

    def test_group_fields_and_option_resolution(self):
        cases = [("id", "invalid"), ("option_type", "pokemon_vendor"), ("option_type", []),
                 ("max_selections", True), ("max_selections", 2), ("options", []),
                 ("options", ["pokemon_gift_ball_1"]), ("options", ["pokemon_gift_ball_1", "pokemon_gift_ball_1"]),
                 ("options", [None, "pokemon_gift_ball_1"]), ("options", ["pokemon_gift_missing", "pokemon_gift_ball_1"]),
                 ("requires", True)]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                data = copy.deepcopy(self.data)
                data["choices.json"][0][field] = value
                self.assertTrue(self.errors(data))
        self.assertTrue(self.errors(zones=[]), "Options must be placed sources")

    def test_duplicate_groups_and_cross_group_members(self):
        self.groups.append(copy.deepcopy(self.groups[0]))
        self.assertTrue(self.errors())
        self.groups[1]["id"] = "choice_other"
        self.assertTrue(any("multiple options/groups" in error for error in self.errors()))

    def test_gift_fields(self):
        for field, value in [("id", "pokemon_vendor_bad"), ("pokemon", "item_potion"), ("levels", []),
                             ("levels", [True]), ("levels", [101]), ("levels", [5, 5]),
                             ("repeatable", 0), ("requires", {})]:
            with self.subTest(field=field, value=value):
                data = copy.deepcopy(self.data)
                data["pokemon_gifts.json"][0][field] = value
                self.assertTrue(self.errors(data))
        self.gifts.append(copy.deepcopy(self.gifts[0]))
        self.assertTrue(self.errors())

    def test_malformed_collections_and_references(self):
        for name in self.data:
            for value in ({}, None, [42], [None]):
                data = copy.deepcopy(self.data)
                data[name] = value
                self.assertTrue(self.errors(data))
        for refs in ("bad", [None], ["pokemon_gift_missing"], ["pokemon_gift_ball_1"] * 2):
            self.assertTrue(self.errors(zones=[{"id": "zone_lab", "pokemon_gifts": refs}]))

    def test_authored_data_and_slot_identity(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(validate(root / "data/world").errors, [])
        groups = json.loads((root / "data/acquisitions/choices.json").read_text())
        fossil = next(g for g in groups if g["id"] == "choice_mt_moon_fossil")
        self.assertEqual(fossil["options"], ["item_pickup_mt_moon_b2f_fossil_west", "item_pickup_mt_moon_b2f_fossil_east"])
        gifts = json.loads((root / "data/acquisitions/pokemon_gifts.json").read_text())
        self.assertEqual([g["pokemon"] for g in gifts], ["species_bulbasaur", "species_squirtle", "species_charmander"])

    def test_choice_generator_uses_runtime_shape(self):
        generator = Path(__file__).resolve().parents[1] / "tools/generate_entry.py"
        for kind in ("pokemon_gift", "item_pickup"):
            output = subprocess.run([sys.executable, str(generator), "choice", "--id", "choice_test",
                "--option-type", kind, "--options", kind + "_a", kind + "_b", "--requires", "state_ready"],
                capture_output=True, text=True, check=True)
            payload = json.loads(output.stdout)
            self.assertEqual(payload["option_type"], kind)
            self.assertEqual(payload["requires"], "state_ready")
            self.assertEqual(payload["max_selections"], 1)
        interactive = subprocess.run([sys.executable, str(generator)],
            input="choice\nchoice_test\n\nitem_pickup_a,item_pickup_b\n\n", capture_output=True, text=True, check=True)
        payload = json.loads(interactive.stdout[interactive.stdout.index("{"):])
        self.assertEqual(payload["option_type"], "item_pickup")
        self.assertIsNone(payload["requires"])
        invalid = subprocess.run([sys.executable, str(generator), "choice", "--id", "choice_test", "--option-type",
            "pokemon_source", "--options", "a", "b"], capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0)


if __name__ == "__main__":
    unittest.main()
