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
- Progression-state evaluation is not implemented. Callers currently supply boolean
  capability and story flags directly; this is not a complete vanilla progression model.
- Reachability skips Connection destinations and Portal endpoints whose Zones are not
  authored yet. It rejects unknown starting Zones and missing referenced Connections.
- Encounters, item availability, and trainer logic are not evaluated.

## Next Task

Define the authoritative player-state inputs and implement capability derivation,
starting with Cut and Surf. Confirm badge/HM requirements and settle the naming of
story flags before wiring derived state into the solver.

The reachability milestone is complete for the authored graph using supplied state flags.
This completes the graph solver portion of the vertical slice; state derivation and
complete vanilla game data remain separate work.
