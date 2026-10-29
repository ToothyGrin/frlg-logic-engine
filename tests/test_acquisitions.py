"""Validate approved trade/vendor shapes and integration with the common builder."""
import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from validate_acquisitions import KINDS, validate_acquisitions
from validate_world import Report


class AcquisitionValidationTests(unittest.TestCase):
    def setUp(self):
        self.trade = {"id": "pokemon_trade_test", "requires": None, "exchanges": [{
            "requested_pokemon": "species_abra", "pokemon": "species_mr_mime",
            "level_rule": "match_requested_pokemon", "held_item": None, "repeatable": False}]}
        self.vendor = {"id": "pokemon_vendor_test", "requires": None, "offers": [{
            "pokemon": "species_magikarp", "levels": [5], "price": 500, "currency": "money", "repeatable": False}]}
        self.items = {"id": "item_vendor_test", "requires": None, "offers": [{
            "item": "item_potion", "quantity": 1, "price": 300, "currency": "money", "repeatable": True}]}
        self.data = {"pokemon_trades.json": [self.trade], "pokemon_vendors.json": [self.vendor], "item_vendors.json": [self.items]}

    def errors(self, data=None, zones=None):
        report = Report()
        validate_acquisitions(self.data if data is None else data, [] if zones is None else zones, report)
        return report.errors

    def test_valid_shapes_and_shared_references(self):
        zones = [{"id": "zone_a", "item_vendors": ["item_vendor_test"]},
                 {"id": "zone_b", "item_vendors": ["item_vendor_test"]}]
        self.assertEqual(self.errors(zones=zones), [])
        # Multiple vendor offers for the same species are valid, unlike wild entries.
        self.vendor["offers"].append(copy.deepcopy(self.vendor["offers"][0]))
        self.assertEqual(self.errors(), [])

    def test_trade_version_cardinality(self):
        fr = self.trade["exchanges"][0]
        fr["versions"] = ["firered"]
        self.assertTrue(self.errors())
        lg = copy.deepcopy(fr)
        lg["versions"] = ["leafgreen"]
        lg["requested_pokemon"] = "species_poliwhirl"
        self.trade["exchanges"].append(lg)
        self.assertEqual(self.errors(), [])
        lg.pop("versions")
        self.assertTrue(any("exactly one exchange" in error for error in self.errors()))

    def test_bad_entry_fields(self):
        changes = {
            "pokemon_trades.json": [("requested_pokemon", "item_potion"), ("held_item", []), ("level_rule", "fixed"), ("pokemon", None)],
            "pokemon_vendors.json": [("levels", []), ("levels", [True]), ("levels", [5, 5]), ("levels", [101]), ("price", True), ("price", 0), ("price", float("inf")), ("currency", "berry_powder")],
            "item_vendors.json": [("item", "species_abra"), ("quantity", True), ("quantity", 0)],
        }
        for name, mutations in changes.items():
            for field, value in mutations + [("repeatable", 1), ("versions", []), ("versions", ["emerald"]), ("versions", ["firered", "firered"]), ("versions", [None])]:
                with self.subTest(name=name, field=field, value=value):
                    data = copy.deepcopy(self.data)
                    entries = data[name][0]["exchanges" if name == "pokemon_trades.json" else "offers"]
                    entries[0][field] = value
                    self.assertTrue(self.errors(data))

    def test_missing_fields_shapes_and_references(self):
        for kind in KINDS:
            name = kind + ".json"
            for value in (None, {}, [None], [{"id": "invalid"}]):
                with self.subTest(kind=kind, value=value):
                    data = copy.deepcopy(self.data)
                    data[name] = value
                    self.assertTrue(self.errors(data))
            for refs in (None, "bad", [None], ["missing"], [self.data[name][0]["id"]] * 2):
                self.assertTrue(self.errors(zones=[{"id": "zone_a", kind: refs}]))
            duplicate = copy.deepcopy(self.data)
            duplicate[name].append(duplicate[name][0])
            self.assertTrue(self.errors(duplicate))
        self.trade.pop("requires")
        self.assertTrue(self.errors())

    def test_authored_source_counts(self):
        root = Path(__file__).resolve().parents[1] / "data" / "acquisitions"
        data = {kind + ".json": json.loads((root / (kind + ".json")).read_text()) for kind in KINDS}
        self.assertEqual([len(data[kind + ".json"]) for kind in KINDS], [2, 2, 5])
        self.assertEqual(self.errors(data), [])


if __name__ == "__main__":
    unittest.main()
