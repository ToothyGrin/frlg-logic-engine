# Wild encounter data and availability

## Data

Author area arrays under `data/source/encounters/wild/`, then run
`python tools/build_world.py`. The same builder validates topology, encounter tables,
and their references before writing any of the ten generated collections. Lua reads
`data/encounters/wild.json`; Python is not required at runtime.

The initial dataset has 44 sources in 13 area files. It covers all 11 supplied Bulbapedia
screenshots, plus Mt. Moon and Route 25 from the game data to fill existing Zone references.
Route 23's five tables are ready for later world authoring; they have no Zone references
and therefore are unavailable. Screenshot links and verification notes are in
`assets/reference/encounters/README.md`.

Example source:

```json
{
  "id": "enc_route_1_grass",
  "method": "grass",
  "requires": null,
  "encounters": [
    {"pokemon": "species_pidgey", "levels": [2, 3, 4, 5], "rate": 50},
    {"pokemon": "species_rattata", "levels": [2, 3, 4], "rate": 50}
  ]
}
```

Zone `encounter_sources` arrays contain these source IDs. Missing arrays mean no sources.
Several Zones can refer to the same table, including a shore and its adjacent water.
References to missing encounter sources are errors even in draft mode.

| Method | Required state |
| --- | --- |
| `grass`, `cave` | `null` |
| `surf` | `state_can_surf` |
| `old_rod` | `state_has_old_rod` |
| `good_rod` | `state_has_good_rod` |
| `super_rod` | `state_has_super_rod` |

Each entry's `pokemon` uses a `species_*` ID. `levels` lists exact possibilities; gaps
are meaningful and level probabilities are not stored. `rate` is the aggregate species
percentage within this source, not the probability of triggering an encounter or catching
the Pokémon. Missing `versions` means both games. Differing entries specify
`["firered"]` or `["leafgreen"]`. Validate totals of 100% per game and at most one
applicable record per species. Non-empty recognized version lists, unique integer levels
1–100, numeric rates, method requirements, and references are checked at build time.

## Runtime functions

`Versions.includes(entry, version)` takes an acquisition entry and `firered` or
`leafgreen`. It accepts shared entries or finds the selected game in `entry.versions`,
then returns a boolean. Unknown game versions fail explicitly. This filter can be reused
when other acquisition types are implemented.

`World.build_indexes(data)` now also keeps an ordered `zones` list and builds
`encounter_sources_by_id` from `data.encounters`. It rejects duplicate source IDs and
missing Zone references. `World.load` loads the generated encounter collection alongside
the six world collections. Small fixtures can omit `data.encounters` when they have no
encounter references.

`Encounters.available(world, reachable, state, version)` takes the indexed world,
the reachable-Zone map from `Reachability.solve`, evaluated state from `State.evaluate`,
and the selected game. It visits reachable Zones, checks source requirements, filters
entries by game, and records each source once. Shared sources collect all reachable
access Zones without duplicating entries or adding their rates.

It returns a fresh table containing:

- `sources_by_id`: available sources keyed by ID. Each result has `id`, `method`,
  `zones` (reachable Zone IDs), and `encounters` (filtered `pokemon`, `levels`, `rate`).
- `species_available`: species IDs mapped to `true` when available from at least one
  wild source. Missing species are absent.

Filtered entries and their level arrays are copied. Changing a result cannot change
authored entries or another result. Re-evaluate state, solve, and calculate availability
again after player facts change. Earlier results are preserved.

```lua
local State = require("logic.state")
local Reachability = require("logic.reachability")
local Encounters = require("logic.encounters")

local state = State.evaluate({state_has_old_rod = true})
local reachable = Reachability.solve(world, "zone_players_house", state)
local available = Encounters.available(world, reachable, state, "firered")

assert(available.species_available.species_pidgey)
assert(available.species_available.species_magikarp)
assert(available.sources_by_id.enc_pallet_town_old_rod)
```

## Scope

Availability follows authored Zone access and source requirements. The engine does not
infer missing shore references from an area name. Full world/shore authoring remains
unfinished. Species-ID spelling is validated; a species catalogue for resolving those
references is not implemented yet.

These results concern direct wild encounters. They do not calculate evolutions, trades,
gifts, vendors, fossil revival, roamers, or held-item availability. Poké Balls and money
are not consumed or simulated. Other acquisition schemas and the UI remain separate work.
