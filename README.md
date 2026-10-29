# FRLG Tracker

A logic-aware tracker for Pokémon FireRed and LeafGreen.

The project models the vanilla FRLG world, progression state, encounters, items, trainers,
and Pokémon availability independently from the presentation layer.

Planned modes include Professor Oak Challenge support and manual Warp Randomiser tracking.

The v1.0 target is a publication-ready tracker for the complete single-player FRLG world,
including the Sevii Islands and post-game, subject to the exclusions in `docs/PROJECT.md`.

## Project Status

World loading, runtime indexing, Connection traversal, and reachability are implemented
and tested against the authored early-Kanto graph. Cut and Surf capabilities are derived
from badge and HM acquisition facts. The next milestone is reviewing early-game story gates.

See:

- `docs/PROJECT.md`
- `docs/DESIGN.md`
- `docs/DECISIONS.md`
- `docs/STATUS.md`
- `docs/STATE.md`
- `docs/FRLG_VANILLA_LOGIC_REFERENCE.md`

## Development Tools

World data is authored in small arrays under `data/source/world/` and generated into
the existing runtime files under `data/world/`. After editing sources, build and validate:

```text
python tools/build_world.py
```

Before committing or packaging, check freshness without writing:

```text
python tools/build_world.py --check
```

The generated files remain tracked and must not be edited directly. See
`data/source/world/README.md` for the authoring and packaging workflow.

Warp links in `portals.json` are objects with `type` and `warps`: `normal` permits both
directions, while `drop` permits only the first-to-second direction. The loader derives
`warp_to_destination`; multiple departures may share a landing. Bare Warp pairs are no
longer supported.

Generated world data can also be checked independently with:

```text
python tools/validate_world.py data/world
```

Run the Lua checks from the project root:

```text
lua tools/test.lua
lua tools/load_world.lua
```

Run the Python builder tests with:

```text
python -m unittest discover -s tests -p "test_*.py"
```

The standalone loader uses dkjson 2.11, included in `lib/dkjson.lua` with its license.

`tools/test.lua` runs indexing, player-state evaluation, traversal, reachability, and authored-world progression
checks. Individual test files under `tests/` can also be run directly.

`Reachability.solve(world, starting_zone_id, state)` returns a fresh table mapping reachable
Zone IDs to `true`. Unmet requirements and reverse ledges block traversal. Unauthored
destinations are skipped so the draft map can be exercised; the Python validator reports
incomplete references. This does not imply that the full vanilla game logic is complete.

Use `State.evaluate(player)` before solving from player facts. It derives Cut and Surf
from the acquired HM and its matching badge, without Pokémon move or compatibility checks.
See `docs/STATE.md` for the supported input contract and a complete usage example.

Authoring helpers are located under `tools/`.
