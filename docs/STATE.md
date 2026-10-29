# Player State and Capability Evaluation

`State.evaluate(player)` in `logic/state.lua` turns supported player facts into the
boolean state table consumed by `Reachability.solve`.

## Supported Inputs

| Input | Meaning |
| --- | --- |
| `state_has_cascade_badge` | Cascade Badge acquired |
| `state_has_soul_badge` | Soul Badge acquired |
| `state_has_hm01_cut` | HM01 Cut acquired |
| `state_has_hm03_surf` | HM03 Surf acquired |
| `state_delivered_oaks_parcel` | Existing parcel-delivery input used by the authored graph |
| `state_event_brock_defeated` | Existing Brock-event input used by the authored graph |

Only the boolean value `true` enables a fact. Missing, false, and nonboolean values become
false. Unsupported keys are ignored. This is a small supported-input list, not a complete
player-state schema or typo validator.

The two existing story input names are preserved for compatibility with world data.
Their naming and exact scene/object mapping remain to be reviewed separately; the
evaluator does not infer story events from badges or change the graph's requirements.

## Derived Outputs

The returned table contains the six normalized inputs plus:

```text
state_can_cut = state_has_cascade_badge AND state_has_hm01_cut
state_can_surf = state_has_soul_badge AND state_has_hm03_surf
```

These predicates implement accepted decision D031: an acquired HM plus its corresponding
badge is sufficient. Pokémon move knowledge and compatibility are not checked.
FRLG-L008 and FRLG-L018 in `FRLG_VANILLA_LOGIC_REFERENCE.md` document the different vanilla
field-use checks; the tracker deliberately simplifies those checks.

Inputs named `state_can_cut` or `state_can_surf` are ignored; both outputs are recalculated
from their authoritative facts. Party-related inputs are unsupported and have no effect.

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
