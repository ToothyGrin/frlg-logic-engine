# FRLG Tracker

A logic-aware tracker for Pokémon FireRed and LeafGreen.

The project models the vanilla FRLG world, progression state, encounters, items, trainers,
and Pokémon availability independently from the presentation layer.

Planned modes include Professor Oak Challenge support and manual Warp Randomiser tracking.

## Project Status

World loading and runtime indexing are implemented and tested. The next milestone is
Connection traversal, followed by state evaluation and reachability.

See:

- `docs/PROJECT.md`
- `docs/DESIGN.md`
- `docs/DECISIONS.md`
- `docs/STATUS.md`
- `docs/FRLG_VANILLA_LOGIC_REFERENCE.md`

## Development Tools

World data can be checked with:

```text
python tools/validate_world.py data/world
```

Run the Lua checks from the project root:

```text
lua tests/world_test.lua
lua tools/load_world.lua
```

The standalone loader uses dkjson 2.11, included in `lib/dkjson.lua` with its license.

Authoring helpers are located under `tools/`.
