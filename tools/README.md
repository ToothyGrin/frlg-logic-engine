# FRLG World Data Tools

## World Builder

Edit the authoritative JSON arrays under `data/source/world/`. Generate and validate the
runtime collections from the project root:

```text
python tools/build_world.py
```

Check source validation and generated-file freshness without writing:

```text
python tools/build_world.py --check
```

Use `--strict` to reject unfinished references, or `--source PATH --output PATH` for an
isolated build. Source and output directories must be separate. The six generated JSON
files stay at their existing paths under `data/world/`; do not edit them directly.

Run the builder regression tests:

```text
python -m unittest discover -s tests -p "test_*.py"
```

See `data/source/world/README.md` for authoring conventions and the pre-commit workflow.

## Validator

Draft mode permits references to zones/warps that have not been authored yet, but reports
those references as warnings:

```bash
python tools/validate_world.py data/world
```

Strict mode promotes incomplete references to errors:

```bash
python tools/validate_world.py data/world --strict
```

The validator currently checks topology and reference integrity: JSON validity, ID shape,
duplicate IDs, Zone and Connection references, Connection endpoint declarations, typed Warp
links, unique Warp ownership, conflicting outgoing routes, empty-string placeholders, and
`state_*` requirements. Normal links are bidirectional; drops follow endpoint order. Shared
landings and unpaired Warps are allowed; unfinished referenced endpoints remain draft warnings.

## Generator

Generate a normal Warp link (the default) or a one-way drop:

```text
python tools/generate_entry.py portal --warp-a warp_a --warp-b warp_b
python tools/generate_entry.py portal --type drop --warp-a warp_departure --warp-b warp_landing
```

The drop runs from `--warp-a` to `--warp-b` only. Both forms output typed objects for
the Portal source arrays, using the same format as `templates/portal.template.json`.

Run without arguments for an interactive prompt:

```bash
python generate_entry.py
```

Or generate snippets directly:

```bash
python generate_entry.py connection \
  --id conn_route_24_land_water \
  --type water \
  --zone-a zone_route_24 \
  --zone-b zone_route_24_water \
  --requires state_can_surf
```

```bash
python generate_entry.py container \
  --id mt_moon \
  --name "Mt. Moon" \
  --zones zone_mt_moon_1f zone_mt_moon_b1f_east_corner zone_mt_moon_b2f
```

The generator only prints JSON. It does not modify project data files, so generated output
can be reviewed before copy/paste into the authoritative source arrays. Then run the world
builder. Do not paste snippets into generated runtime collections.
