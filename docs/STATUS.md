# Project Status

Last verified: 29 October 2026.

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

## Verification

Run from the project root:

- `lua tools/test.lua`
- `lua tools/load_world.lua`
- `python tools/build_world.py --check`
- `python -m unittest discover -s tests -p "test_*.py"`
- `python tools/validate_world.py data/world`

Both Lua commands and all 18 Python builder/generator tests passed. The generated files match
their sources. World validation reported 0 errors and 6 warnings for
not-yet-authored destinations: Route 21 water, Route 5, Route 5 center, Route 9,
the Route 2 Diglett's Cave exit, and the Victory Road gate's north entrance.

## Known Limitations

- World data remains incomplete.
- The Python validator handles topology/reference validation, including assembled sources
  before generation. Acquisition schema validation remains future work.
- The Lua loader does not yet perform comprehensive validation.
- State evaluation currently covers Cut, Surf, and the graph's existing parcel/Brock
  inputs. HM and badge facts are supplied manually. Move knowledge and Pokémon
  compatibility are intentionally excluded by D031. This is not a complete vanilla
  progression model.
- Existing story input names and their exact scene/object mapping still need review.
- Reachability skips Connection destinations and Portal endpoints whose Zones are not
  authored yet. It rejects unknown starting Zones and missing referenced Connections.
- Encounters, item availability, and trainer logic are not evaluated.
- Drop mechanics are covered by fixtures; Mansion's actual drop records and tile
  activation behaviour still need verification during world authoring.

## Next Task

All O001–O008 design discussions are resolved in D032–D046. D044's typed Warp links
and D045's source/build workflow are implemented and verified. The decision-review
baseline was committed as `016b449`; use Git history for subsequent implementation commits.

Author future world changes under `data/source/world/`, then run the builder; do not edit
generated runtime JSON directly.

Review the early-game story gates against the researched vanilla behaviour, especially
the parcel/old-man and Brock/Route 3 transitions. Settle their semantic input names and
document any scene/object abstractions before changing the canonical graph.

Then implement the accepted acquisition schemas, optional Zone content arrays,
entry-level version filtering, and species-aggregated encounters through small working
examples. The current Zone content arrays are still the pre-migration draft form.

The release target remains publication-ready complete single-player FRLG coverage,
including Sevii and post-game, subject to the agreed exclusions. Detailed acquisition
fields, roaming rules, complete data, and the UI remain future work.

The initial Cut/Surf capability milestone is complete. The loader, supported state
evaluation, and solver now work together; complete vanilla progression and game data
remain separate work.
