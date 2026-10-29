# Project Status

Last verified: 29 October 2026.

## Completed

- World JSON loading through an injectable file reader.
- Standalone JSON file reading with dkjson decoding.
- Runtime indexes for Zones, Connections, Warp ownership, and Portal siblings.
- Duplicate rejection for all four indexes.
- Automated tests for indexing and duplicate rejection.
- Sample lookup checks against the authored world data.
- Connection traversal with boolean state requirements and one-way ledges.
- Queue-based reachability through Connections and bidirectional Portals.
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

## Verification

Run from the project root:

- `lua tools/test.lua`
- `lua tools/load_world.lua`
- `python tools/validate_world.py data/world`

Both Lua commands passed. World validation reported 0 errors and 6 warnings for
not-yet-authored destinations: Route 21 water, Route 5, Route 5 center, Route 9,
the Route 2 Diglett's Cave exit, and the Victory Road gate's north entrance.

## Known Limitations

- World data remains incomplete.
- The Python validator handles schema and reference validation.
- The Lua loader does not yet perform comprehensive validation.
- State evaluation currently covers Cut, Surf, and the graph's existing parcel/Brock
  inputs. HM and badge facts are supplied manually. Move knowledge and Pokémon
  compatibility are intentionally excluded by D031. This is not a complete vanilla
  progression model.
- Existing story input names and their exact scene/object mapping still need review.
- Reachability skips Connection destinations and Portal endpoints whose Zones are not
  authored yet. It rejects unknown starting Zones and missing referenced Connections.
- Encounters, item availability, and trainer logic are not evaluated.

## Next Task

Work through open decisions with the user, one at a time. O001's non-item-source
prefixes are accepted as D032; item-source naming is deferred to O004. O002's descriptive
Warp naming is accepted as D033. O003's source-ID conventions are accepted as D034;
multi-offer vendors including Game Corner prizes are accepted as D035. Optional direct
Zone acquisition arrays are accepted as D036. Single-player v1.0 acquisition is accepted
as D037, retaining NPC trades and excluding external acquisition. D038 records release-based
roaming availability with detailed rules deferred. O003's current design is resolved;
O004's pickup/gift/vendor grouping and prefixes are accepted as D039, including multi-offer
item vendors. Optional direct `item_pickups`, `item_gifts`, and `item_vendors` arrays are
accepted as D040. D041 settles held-item data ownership, connects Thief/Covet to wild
held items, defers Pickup beyond v1.0, and confirms external item trading/Mystery Gift
exclusions. O004's current design is resolved. O005 is resolved by D042's optional
entry-level version filters, with the earlier encounter-table schema recovered as D043.
O006 is resolved by D044: typed Warp links with normal/drop direction rules and a
destination index. The existing bare Portal pairs, sibling index, validator, and solver
still require a coordinated migration. O007 is resolved by D045's small authored-source
files and generated runtime category collections, following the MobiusFFTool pattern.
The builder, stale-output check, and source-data migration remain implementation work.
O008 is resolved by D046: publication-ready complete single-player FRLG coverage,
including Sevii and post-game, subject to agreed exclusions and the needs of the majority
of players. All O001–O008 discussions are resolved for the current design, with detailed
schemas and deferred mechanics still requiring implementation work. These decisions
do not change current runtime behaviour.
These documentation changes are not yet committed.

Review the early-game story gates against the researched vanilla behaviour, especially
the parcel/old-man and Brock/Route 3 transitions. Settle their semantic input names and
document any scene/object abstractions before changing the canonical graph.

The initial Cut/Surf capability milestone is complete. The loader, supported state
evaluation, and solver now work together; complete vanilla progression and game data
remain separate work.
