# FRLG Tracker

A logic-aware tracker for Pokémon FireRed and LeafGreen.

The project models the vanilla FRLG world, progression state, encounters, items, trainers,
and Pokémon availability independently from the presentation layer.

Planned modes include Professor Oak Challenge support and manual Warp Randomiser tracking.

## Project Status

The project is entering Phase 1 of development: world loading, indexing, state evaluation,
and reachability.

See:

- `docs/PROJECT.md`
- `docs/DESIGN.md`
- `docs/DECISIONS.md`
- `docs/STATUS.md`
- `docs/FRLG_VANILLA_LOGIC_REFERENCE.md`

## Development Tools

World data can be checked with:

```text
python tools/validate_world.py data
```

Authoring helpers are located under `tools/`.
