# FRLG World Data Tools

## Validator

Draft mode permits references to zones/warps that have not been authored yet, but reports
those references as warnings:

```bash
python validate_world.py ../revised_world
```

Strict mode promotes incomplete references to errors:

```bash
python validate_world.py ../revised_world --strict
```

The validator currently checks topology and reference integrity: JSON validity, ID shape,
duplicate IDs, Zone and Connection references, Connection endpoint declarations, Portal pair
shape, Warp uniqueness, empty-string placeholders, and `state_*` requirements.

## Generator

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
can be reviewed before copy/paste.
