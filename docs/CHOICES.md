# Exclusive acquisition choices

Accepted 30 October 2026 as D049, superseding D028's custom starter-state representation.
The choice milestone is implemented: authored sources/groups, validation, normalized
manual player state, starter availability, and metadata-only fossil selection.

## Sources and choice groups

Each physical selectable object has its own source ID. Group membership expresses
mutual exclusion separately from the source's reward, location, or progression conditions.
This preserves individual locations for future randomisers and completion tracking.

The accepted starter gift example is:

```json
{
  "id": "pokemon_gift_oaks_lab_starter_ball_1",
  "pokemon": "species_bulbasaur",
  "levels": [5],
  "repeatable": false
}
```

Balls 2 and 3 similarly yield Squirtle and Charmander at level 5. These numbers identify
the original selection slots, not coordinates or a sorting order. Original-slot identity
must survive replacement of a reward species.

```json
{
  "id": "choice_oaks_lab_starter",
  "option_type": "pokemon_gift",
  "options": [
    "pokemon_gift_oaks_lab_starter_ball_1",
    "pokemon_gift_oaks_lab_starter_ball_2",
    "pokemon_gift_oaks_lab_starter_ball_3"
  ],
  "max_selections": 1,
  "requires": "state_event_oak_ready_for_starter"
}
```

The corresponding fossil group is:

```json
{
  "id": "choice_mt_moon_fossil",
  "option_type": "item_pickup",
  "options": [
    "item_pickup_mt_moon_b2f_fossil_west",
    "item_pickup_mt_moon_b2f_fossil_east"
  ],
  "max_selections": 1,
  "requires": "state_event_mt_moon_miguel_defeated"
}
```

Implementation reuses the existing descriptive west/east fossil references rather than
the numbered placeholders from the draft. The [map objects](https://github.com/pret/pokefirered/blob/master/data/maps/MtMoon_B2F/map.json)
place the original Dome slot at x=13 (west), and Helix at x=14 (east), both y=7. This
documents original-object identity only; no fossil item reward payloads are stored.

Starter sources are authored in `data/source/acquisitions/pokemon_gifts/oaks_lab.json`
and referenced through `zone_oaks_lab.pokemon_gifts`. Groups are area arrays under
`data/source/acquisitions/choices/`. The shared builder produces
`data/acquisitions/pokemon_gifts.json` and `data/acquisitions/choices.json`, bringing the
runtime collection count to twelve. It validates all collections before writing any.

Group `requires` is an optional state ID or `null`, following our existing convention.
Readiness facts describe the lab's starter-selection scene and Miguel's defeat. They
gate unselected alternatives; confirmed selections remain acquired facts after leaving
a Zone or ending its selection scene. The lab script allows selection in scene 2;
Miguel's script enables fossil choice after his battle. The opening cutscene itself is
not simulated by the topology engine.

## Authoritative player state

```lua
player.choices = {
    choice_oaks_lab_starter = {
        status = "selected",
        source = "pokemon_gift_oaks_lab_starter_ball_1",
    },
    choice_mt_moon_fossil = {
        status = "unselected",
    },
}
```

| Status | Meaning |
| --- | --- |
| `unknown` | Reliable choice information is unavailable |
| `unselected` | The player is known not to have selected an option yet |
| `selected` | The named source was chosen |

Selected state must name an option in its group. Unknown/unselected state carries no
selected source. Manual controls and later autotracking write the same representation;
the acquisition engine must not depend on which input mechanism supplied it. Missing
known groups normalize to `unknown`. Unsupported group IDs are ignored, consistent with
the supported-input policy for boolean facts; malformed known group states fail.

With known `unselected` state, expose eligible alternatives without treating rewards as jointly
obtainable. `unknown` reports no alternatives because the selection is unresolved.
After selection, preserve the selected acquisition and exclude other options
through that choice. Exclusion does not prohibit obtaining the same species elsewhere.
Changing or clearing the choice must recalculate fresh results without modifying earlier
results or source data.

Starter-dependent gameplay facts are derived from the selected original slot; the actual
received species is read from its reward payload. Separate editable booleans for the
three starters are unnecessary and could contradict the authoritative choice.

## Autotracking evidence and boundary

The [lab script](https://github.com/pret/pokefirered/blob/master/data/maps/PalletTown_ProfessorOaksLab/scripts.inc#L989-L1038)
records the selected starter in `VAR_STARTER_MON` (0 Bulbasaur, 1 Squirtle, 2 Charmander)
and sets `FLAG_SYS_POKEMON_GET`. Only decode the variable as a choice after confirming
starter acquisition; its initial zero must not imply Bulbasaur was selected.

The [Mt. Moon script](https://github.com/pret/pokefirered/blob/master/data/maps/MtMoon_B2F/scripts.inc)
sets `FLAG_GOT_DOME_FOSSIL` or `FLAG_GOT_HELIX_FOSSIL`, plus
`FLAG_GOT_FOSSIL_FROM_MT_MOON`. Both objects disappear after selection. Decode persistent
acquisition flags rather than inferring the chosen fossil from disappearing objects or
current Bag contents, which can change after revival. Contradictory or incomplete
observations must not be guessed into a selected option.

[EmoTracker's Lua memory watches](https://github.com/EmoTracker-Community/EmoTracker/wiki/Authoring-Lua-Autotracking)
can supply observations. A separate adapter must translate coherent memory snapshots
into player state. ROM-version mappings, memory addresses, provider support, allowed
memory regions, and connection handling need verification when implemented. Rebuild
choice state on save changes and rewinds rather than accumulating selections forever.

## Runtime functions and usage

`World.build_indexes` calls `Choices.build_indexes(world, data)` to index gifts, groups,
source membership, and source access Zones. Duplicate IDs, repeated/group-shared options,
and unresolved options fail. `World.load` reads the two new collections; small fixtures
may omit them.

`State.evaluate(player, world)` normalizes booleans and choices, returning fresh `choices`
and derived `starter_choice` (original identity, or `nil`). Supply the indexed world when
`player.choices` is present for membership checks. Existing boolean-only callers can
omit the world. Supplied `player.starter_choice` is ignored.

`Choices.normalize(world, input)` checks supported groups and copies their states.
`Choices.starter_identity(choices)` maps the original chosen lab slot to `bulbasaur`,
`squirtle`, or `charmander`, independently of reward contents.

`Acquisitions.available` calls `Choices.apply(world, reachable, state, result)` before
trade evaluation, so the confirmed starter can seed trades. The result adds:

- `choices_by_id`: normalized status/source, eligible `alternatives` (source IDs), and
  `excluded` (the other source IDs after selection).
- `pokemon_gifts_by_id`: applicable gifts with copied `id`, `pokemon`, `levels`,
  `repeatable`, reachable `zones`, and `obtained`. A chosen starter has `obtained=true`;
  `zones` can be empty if its location is not currently reachable.
- `starter_choice`: original starter identity, derived from the selected slot.

Only the chosen grouped gift enters `species_available`. Ungrouped gifts can contribute
when reachable with their optional requirements satisfied, with `obtained=false` because
access alone does not prove collection. Fossils contribute metadata only, with no item
or revived Pokémon output. Results do not alias player state or source level arrays.

```lua
local player = {
    choices = {
        choice_oaks_lab_starter = {
            status = "selected",
            source = "pokemon_gift_oaks_lab_starter_ball_1",
        },
    },
}
local state = State.evaluate(player, world)
local reachable = Reachability.solve(world, "zone_players_house", state)
local available = Acquisitions.available(world, reachable, state, "firered")
assert(state.starter_choice == "bulbasaur")
assert(available.species_available.species_bulbasaur)
```

For pre-selection options, set status to `unselected` and the readiness fact to `true`.
Clear the group entry to return to `unknown`. Re-evaluate and solve after edits; earlier
results remain unchanged. Tests cover all states, membership errors, prerequisites,
location access, correction/removal, alternatives, changed rewards, independent sources,
trade seeding, copied results, malformed schemas, generator output, and build integrity.

## Milestone boundary

The manual engine milestone is complete. UI controls and memory observation are deferred.

Actual memory tracking, item definitions, item-dependent evolution, and general
item-gift rewards remain outside this milestone. The previous vendor milestone remains
complete; existing metadata-only item-gift references remain unevaluated.
