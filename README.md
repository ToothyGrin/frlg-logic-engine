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
from badge and HM acquisition facts. Early story gates are verified. Wild encounter data
and availability now combine reachable Zones, rod/Surf requirements, and game version.

See:

- `docs/PROJECT.md`
- `docs/DESIGN.md`
- `docs/DECISIONS.md`
- `docs/STATUS.md`
- `docs/STATE.md`
- `docs/ENCOUNTERS.md`
- `docs/ACQUISITIONS.md`
- `docs/CHOICES.md`
- `docs/FRLG_VANILLA_LOGIC_REFERENCE.md`

## Development Tools

World data is authored in small arrays under `data/source/world/` and generated into
the existing runtime files under `data/world/`. Wild tables are authored under
`data/source/encounters/wild/` and generated into `data/encounters/wild.json` by the same
builder. After editing sources, build and validate:

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

`tools/test.lua` runs indexing, player-state evaluation, traversal, reachability,
authored-world progression, and encounter availability checks. Individual test files
under `tests/` can also be run directly.

`Reachability.solve(world, starting_zone_id, state)` returns a fresh table mapping reachable
Zone IDs to `true`. Unmet requirements and reverse ledges block traversal. Unauthored
destinations are skipped so the draft map can be exercised; the Python validator reports
incomplete references. This does not imply that the full vanilla game logic is complete.

Use `State.evaluate(player)` before solving from player facts. It derives Cut and Surf
from the acquired HM and its matching badge, without Pokémon move or compatibility checks.
See `docs/STATE.md` for the supported input contract and a complete usage example.

Authoring helpers are located under `tools/`.

`Acquisitions.available(world, reachable, state, version)` combines wild encounters,
reachable Pokémon/item vendors, and eligible NPC trade chains. Its generated sources live
under `data/acquisitions/`; author area arrays under `data/source/acquisitions/` and use
the same builder. Nine initial sources are loaded; the three Game Corner windows remain
unplaced until Celadon is authored. Item-gift references remain unevaluated draft metadata.

Exclusive choice groups now handle three starter gift sources and the existing fossil
pickup references. Use `State.evaluate(player, world)` with `player.choices` to validate
manual selection. Results report alternatives separately from obtainable species, keep
original starter identity independent of rewards, and preserve confirmed choices after
leaving their location. Fossil reward payloads and actual autotracking remain deferred.
See `docs/CHOICES.md` for the state contract, readiness facts, and examples.
