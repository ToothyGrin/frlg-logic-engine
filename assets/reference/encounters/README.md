# Initial encounter references

These are the user's supplied Bulbapedia Generation III screenshots. They are reference
material for authoring encounter data, not runtime data. The coloured FR/LG backgrounds
indicate availability; a white background indicates absence in that version.

Keep these screenshots and this README in Git. The repository's `.gitattributes` excludes
`assets/reference/` from Git archive exports; these files are development references and
are not part of the runtime package. See `tools/README.md` for the export command.

| Screenshot | Source section |
| --- | --- |
| `route_1_gen3.png` | [Route 1](https://bulbapedia.bulbagarden.net/wiki/Kanto_Route_1#Generation_III) |
| `route_2_gen3.png` | [Route 2](https://bulbapedia.bulbagarden.net/wiki/Kanto_Route_2#Generation_III) |
| `pallet_town_gen3.png` | [Pallet Town](https://bulbapedia.bulbagarden.net/wiki/Pallet_Town#Generation_III) |
| `viridian_city_gen3.png` | [Viridian City](https://bulbapedia.bulbagarden.net/wiki/Viridian_City#Generation_III) |
| `viridian_forest_gen3.png` | [Viridian Forest](https://bulbapedia.bulbagarden.net/wiki/Viridian_Forest#Generation_III) |
| `route_22_gen3.png` | [Route 22](https://bulbapedia.bulbagarden.net/wiki/Kanto_Route_22#Generation_III) |
| `route_3_gen3.png` | [Route 3](https://bulbapedia.bulbagarden.net/wiki/Kanto_Route_3#Generation_III) |
| `route_4_gen3.png` | [Route 4](https://bulbapedia.bulbagarden.net/wiki/Kanto_Route_4#Generation_III) |
| `route_23_gen3.png` | [Route 23](https://bulbapedia.bulbagarden.net/wiki/Kanto_Route_23#Generation_III) |
| `route_24_gen3.png` | [Route 24](https://bulbapedia.bulbagarden.net/wiki/Kanto_Route_24#Generation_III) |
| `cerulean_city_gen3.png` | [Cerulean City](https://bulbapedia.bulbagarden.net/wiki/Cerulean_City#Generation_III) |

## Authoring rules

- Follow the accepted encounter schema: source `id`, `method`, `requires`, and
  `encounters`; entries contain `pokemon`, exact `levels`, aggregate species `rate`,
  and optional `versions`.
- Preserve noncontiguous levels, such as `3, 5, 7`, without filling their gaps.
- Share entries across versions when identical, and split them when rates or levels
  differ. Effective rates must total 100% separately for each version and method.
- Preserve each location's values. Pallet Town's Old Rod screenshot lists levels 5–10,
  while the other supplied Old Rod tables list level 5. Verified against both games'
  tables on 29 October 2026: this is an actual location difference, retained in the data.
- Route 2's Mr. Mime trade, Cerulean's Jynx trade, and Route 4's purchased Magikarp
  belong to their respective trade/vendor sources, separate from wild tables.
- Assign encounters to the relevant authored Zone rather than copying a whole area's
  tables into every Zone. Route 23's graph is not authored yet; retain its reference
  for later work. Mt. Moon and Route 25 tables were not supplied in this batch.

## Implementation and cross-check

All 36 supplied wild sources were transcribed with exact levels, rates, and versions.
The resulting 72 effective game/source tables matched the slot-aggregated
[pret/pokefirered game data](https://github.com/pret/pokefirered/blob/master/src/data/wild_encounters.json)
on 29 October 2026. Pallet's first two fishing slots both use Magikarp at levels 5–10
in FireRed and LeafGreen; Viridian's corresponding slots use level 5.

Mt. Moon's three floor tables and Route 25's five tables were supplemented from that
primary source to resolve existing authored Zone references. These areas have no supplied
screenshots in this batch. Runtime data stores aggregated species entries, without
retaining raw slots or introducing per-level weights. See `docs/ENCOUNTERS.md`.
