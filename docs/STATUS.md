# Project Status

Last verified: 30 October 2026.

## Completed

- World JSON loading through an injectable file reader.
- Standalone JSON file reading with dkjson decoding.
- Runtime indexes for Zones, Connections, Warp ownership, and Warp destinations.
- Duplicate rejection for all four indexes.
- Automated tests for indexing and duplicate rejection.
- Sample lookup checks against the authored world data.
- Connection traversal with boolean state requirements and one-way ledges.
- Queue-based reachability through Connections, bidirectional normal links, and one-way drops.
- Fresh reachability results on every calculation, without changing earlier results.
- Tests for parallel paths, isolated Zones, unpaired Warps, incomplete destinations,
  and invalid starting Zone or Connection references.
- Authored-world checks for parcel delivery, Brock, Cut, Surf, the Pewter museum ledge,
  Mt. Moon Portals, and Route 4's one-way return restriction.
- A single command to run all Lua tests.
- Player-state evaluation for Cut and Surf, derived from badge and HM acquisition facts (D031).
- Tests for all badge/HM combinations, missing and nonboolean facts, supplied capability
  overrides, independent story flags, input preservation, and capability removal.
- End-to-end state evaluation and reachability checks against the authored world.
- A documented supported-input contract in `docs/STATE.md` and a verified Surf research entry.
- D045's initial authoring workflow: 41 small source files generate the same six runtime
  world collections. All 131 migrated records preserve their fields and nested-array order.
- A shared Python builder with in-memory world validation and a non-writing stale-output
  check. Existing draft-reference warnings and runtime paths are preserved.
- Python regression tests for generation, stale sources/outputs, duplicates, malformed
  data, reference errors, deterministic ordering, and draft/strict validation.
- D044's typed Warp links across source/generated data, generator, template, validation,
  Lua indexes, and solver. All 53 existing pairs are migrated to normal links.
- Tests for drop direction, shared landings, explicit onward routes from a landing,
  unpaired Warps, invalid link shapes/types, and duplicate outgoing routes.
- Verified early story gates against vanilla scripts: completed parcel/Pokédex scene
  moves the old man aside; Brock victory updates Pewter's scene and guide visibility.
- Standardized the parcel input as `state_event_oaks_parcel_delivered`, with regression
  checks for inventory/badge non-substitution, independent gates, and the Cut alternative.
- Preserved 11 user-supplied Bulbapedia encounter screenshots with source links and
  authoring notes under `assets/reference/encounters/`.
- Wild encounter schema validation (D042–D043), optional Zone encounter references,
  encounter-source indexing, and version-filtered runtime availability.
- Forty-four wild tables in 13 area files, covering all supplied screenshot tables and
  supplementing existing Mt. Moon/Route 25 references from primary game data.
- All 72 effective screenshot/game tables cross-checked against game slots. Pallet's
  Old Rod levels 5–10 confirmed for both games (FRLG-L020).
- Old, Good, and Super Rod input facts; independent method gating and shore fishing
  through authored Zone references. Shared sources report their reachable Zones once.
- A single builder validates all seven runtime collections, including encounter
  references and 100% rates/unique species per game, before writing any outputs.
- Tests for version differences, exact level gaps, rods, Surf, unreachable/unplaced
  sources, shared access, fresh results, malformed tables, and invalid-reference failures.

## Verification

The nine-source trade/vendor milestone adds two NPC trades, the Route 4 salesman,
three Poké Marts, and three unplaced Game Corner windows. The shared builder validates
all ten collections. Runtime availability combines wild/vendor sources with trade
dependency closure; it preserves held-item and cost metadata. Draft gifts are not evaluated.

Run from the project root:

- `lua tools/test.lua`
- `lua tools/load_world.lua`
- `python tools/build_world.py --check`
- `python -m unittest discover -s tests -p "test_*.py"`
- `python tools/validate_world.py data/world`

Both Lua commands and all 41 Python builder/generator/schema tests passed. The generated
files match their sources. World validation reported 0 errors and 6 warnings for
not-yet-authored destinations: Route 21 water, Route 5, Route 5 center, Route 9,
the Route 2 Diglett's Cave exit, and the Victory Road gate's north entrance.

## Known Limitations

- World data remains incomplete.
- The Python validator handles topology, wild schemas, and references before generation.
  Other acquisition schemas and species-catalogue reference resolution remain future work.
- The Lua loader does not yet perform comprehensive validation.
- State evaluation currently covers Cut, Surf, rods, Coin Case, choices, readiness, and parcel/Brock
  inputs. HM and badge facts are supplied manually. Move knowledge and Pokémon
  compatibility are intentionally excluded by D031. This is not a complete vanilla
  progression model.
- Parcel and Brock events abstract verified scene/object changes; automatic game-state
  reading and other progression events remain future work.
- Reachability skips Connection destinations and Portal endpoints whose Zones are not
  authored yet. It rejects unknown starting Zones and missing referenced Connections.
- Wild availability follows authored Zone references; complete shore and world authoring
  remains unfinished. Route 23's tables are present but not placed in the graph.
- Vendor items, eligible trade-held items, and chosen starter gifts are evaluated.
  Fossils have choice metadata only. Wild held items, other Pokémon acquisition,
  evolution, item gifts/pickups, and trainer logic are not evaluated.
- Drop mechanics are covered by fixtures; Mansion's actual drop records and tile
  activation behaviour still need verification during world authoring.

## Next Task

Phase 2's reachability exit condition is satisfied under the agreed topology/state model.
All 71 Zones across the ten listed areas have hand-authored expected sets in 23 progression
and alternate-start snapshots. Comparisons reject missing and unexpected Zones, validate
scope coverage, and preserve previous results. The Cerulean NPC barrier correction and
its focused tests remain in place. See `PHASE2_SNAPSHOTS.md` for scope and coverage.
Review the completed slice before selecting more work; no acquisition/UI expansion is
needed to close Phase 2.

All O001–O008 design discussions are resolved in D032–D046. D044's typed Warp links
and D045's source/build workflow are implemented and verified. The decision-review
baseline was committed as `016b449`; use Git history for subsequent implementation commits.

Author future world changes under `data/source/world/`, then run the builder; do not edit
generated runtime JSON directly.

The early story-gate and wild encounter milestones are complete. NPC trade and shared
Pokémon/item vendor shapes were approved on 30 October 2026 (D047–D048), including
one source per Game Corner window. See `ACQUISITIONS.md` for accepted fields and examples.
The nine-source implementation milestone is complete, including build collections,
validation, acquisition availability, and typed Zone-reference migration for current
slice sources. Review the runtime API before selecting the next milestone. Bike Voucher
exchange and gift availability were explicitly excluded. The Powder Jar man and Running
Shoes aide now have draft Zone references, alongside the existing gift references.
These remain metadata without rewards or a runtime reader, preserving NPC locations for
future item-randomiser support. The milestone has no remaining implementation work.
Detailed item definitions and item-dependent evolution checks are deferred beyond v1
for later Professor Oak mode work.

The exclusive acquisition choice milestone (D049) is complete: three starter sources,
lab/fossil groups, normalized manual state, readiness/access checks, mutual exclusion,
and original starter identity separated from rewards. Existing fossil references are
reused without payloads. The builder validates twelve collections. Tests cover changes,
removal, unknown state, alternatives, trade seeding, malformed data, and fresh results.
See `CHOICES.md` for the API and evidence. Return to the Phase 2 goal above;
UI controls and actual autotracking remain deferred.

The release target remains publication-ready complete single-player FRLG coverage,
including Sevii and post-game, subject to the agreed exclusions. Detailed acquisition
fields, roaming rules, complete data, and the UI remain future work.

The initial Cut/Surf capability milestone is complete. The loader, supported state
evaluation, and solver now work together; complete vanilla progression and game data
remain separate work.
