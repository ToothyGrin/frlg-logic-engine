# Player State and Capability Evaluation

`State.evaluate(player, world)` in `logic/state.lua` turns supported player facts into
evaluated state for reachability and acquisitions. Supply the indexed world with choice
input; existing boolean-only callers can omit it.

## Supported Inputs

| Input | Meaning |
| --- | --- |
| `state_has_cascade_badge` | Cascade Badge acquired |
| `state_has_soul_badge` | Soul Badge acquired |
| `state_has_hm01_cut` | HM01 Cut acquired |
| `state_has_hm03_surf` | HM03 Surf acquired |
| `state_has_old_rod` | Old Rod acquired |
| `state_has_good_rod` | Good Rod acquired |
| `state_has_super_rod` | Super Rod acquired |
| `state_has_coin_case` | Coin Case acquired; enables reachable Game Corner prize windows |
| `state_event_oak_ready_for_starter` | Oak's lab is ready for starter selection |
| `state_event_mt_moon_miguel_defeated` | Miguel defeated; fossil selection unlocked |
| `state_event_oaks_parcel_delivered` | Oak's parcel-delivery/Pokédex scene completed; old man moved aside |
| `state_event_brock_defeated` | Brock victory progression completed; Pewter's Route 3 guide removed |

Only the boolean value `true` enables a fact. Missing, false, and nonboolean values become
false. Unsupported keys are ignored. This is a small supported-input list, not a complete
player-state schema or typo validator.

## Story Event Mapping

These are manually supplied semantic events, representing the vanilla scene/object
changes verified in FRLG-L019 and FRLG-L006 in `FRLG_VANILLA_LOGIC_REFERENCE.md`.

Oak's completed scene sets `VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN` to 1. Viridian's
transition script then places the old man beside the road; completing the catching
tutorial (scene 2) is not required to pass. Holding Oak's Parcel does not satisfy this
event. The input was renamed from `state_delivered_oaks_parcel` to
`state_event_oaks_parcel_delivered`; callers must use the new name, with no legacy alias.

Brock's victory sets his defeat flag and Boulder Badge flag separately, advances Pewter's
map scene to 1, and hides the guide. The Route 3 guide triggers use scene 0. Our event
represents this completed victory progression; the Connection does not model a direct
check of the defeat flag or badge. No story event is inferred from badge ownership.

The existing Cut alternative around the old man remains available under D031's policy.
Unsupported inventory/badge facts used in regression cases remain ignored by the current
evaluator; those cases guard against introducing an automatic substitute for these events.

## Derived Outputs

The returned table contains the twelve normalized boolean inputs plus:

```text
state_can_cut = state_has_cascade_badge AND state_has_hm01_cut
state_can_surf = state_has_soul_badge AND state_has_hm03_surf
```

These predicates implement accepted decision D031: an acquired HM plus its corresponding
badge is sufficient. Pokémon move knowledge and compatibility are not checked.
FRLG-L008 and FRLG-L018 in `FRLG_VANILLA_LOGIC_REFERENCE.md` document the different vanilla
field-use checks; the tracker deliberately simplifies those checks.

Each rod remains an independent acquisition fact. Owning the Super Rod does not imply
owning the Old Rod or Good Rod. Rod facts gate their respective encounter sources;
Surf capability separately gates Surf encounters and water Connections.

Inputs named `state_can_cut` or `state_can_surf` are ignored; both outputs are recalculated
from their authoritative facts. Party-related inputs are unsupported and have no effect.

The state also contains fresh `choices` and derived `starter_choice`. Authored groups
default to `unknown`; selected sources must belong to their group. Unsupported group
IDs are ignored like unsupported boolean keys; malformed known group states fail.
Supplied `player.starter_choice` cannot override the original identity derived from a
selected slot. Supply the world when `player.choices` is present. See `CHOICES.md`.

## Usage

```lua
local State = require("logic.state")
local Reachability = require("logic.reachability")

local player = {
    state_has_cascade_badge = true,
    state_has_hm01_cut = true,
    state_event_brock_defeated = true,
}

local state = State.evaluate(player)
local reachable = Reachability.solve(world, "zone_players_house", state)
```

`world` must already be loaded. Evaluation returns a fresh table without modifying
`player` or any previous result. Re-evaluate and solve again after player facts change.

The solver remains independently usable with explicit evaluated flags for unit tests and
other callers. Player-state callers should use the evaluation step shown above.

## Current Scope

HM and badge acquisition facts are supplied manually. HM usability does not depend on
party composition, learned moves, Pokémon compatibility, or teaching the move. Those
checks are intentionally excluded by D031, rather than deferred requirements for these
capabilities. Automatic acquisition tracking is not implemented.

Other field moves and special water restrictions are outside this milestone.
