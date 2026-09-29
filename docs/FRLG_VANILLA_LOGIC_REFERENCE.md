# FRLG Vanilla Logic Reference

> **Status:** Living research document **Research baseline:** 2026-09-25 **Primary source:**
> [`pret/pokefirered`][source-001], the matching decompilation of English Pokémon FireRed
> and LeafGreen.

## Purpose

This document is the research reference for assumptions made by the FRLG Tracker engine.

When the tracker assigns a requirement to a Connection, derives a progression state, or
otherwise makes an assumption about vanilla game logic, the relevant behaviour should be
verified here first or added as a new researched entry.

Entry IDs such as `FRLG-L001` are stable project citation keys. They may be referenced in:

- design discussions;
- tests;
- implementation comments;
- decision records;
- bug reports;
- future documentation.

They are **not** part of the runtime JSON schema unless the project later chooses to make
them so.

The goal is to describe **vanilla FRLG behaviour as implemented**, rather than infer logic
from dialogue, item descriptions, or the player's normal sequence of events.

---

## Source Policy

Use sources in this order:

1. **`pret/pokefirered` script or C implementation** that actually performs the check.
2. **`pret/pokefirered` constants, map data, and related scripts** as supporting evidence.
3. External technical documentation only when the decompilation does not answer the question
   directly.

Do not assume that possessing an item, receiving an item, defeating a trainer, or seeing a
cutscene is the condition another game system checks merely because those events normally
occur together.

### Classification Used in This Document

| Classification | Meaning |
| --- | --- |
| **Flag-based** | The relevant script tests a persistent event/system flag. |
| **Item-based** | The relevant script or C code checks current Bag inventory. |
| **Scene/object-state** | Access is controlled through a map scene variable, object hide/show state, or similar map state. |
| **Field-move rule** | The game checks a badge and/or whether a party Pokémon knows a move. |
| **Composite** | More than one independent kind of state is checked. |
| **Derived tracker state** | A tracker abstraction representing lower-level vanilla conditions. |
| **Partial** | Relevant behaviour is verified, but the exact final predicate has not yet been located. |

---

## Verified Logic Summary

| ID | Mechanic / Barrier | Vanilla predicate | Classification | Status |
| --- | --- | --- | --- | --- |
| `FRLG-L001` | S.S. Anne boarding | `FLAG_GOT_SS_TICKET` | Flag-based | Verified |
| `FRLG-L002` | Bill / Cerulean exits | `FLAG_GOT_SS_TICKET` for exit unblocking; separate `FLAG_HELPED_BILL_IN_SEA_COTTAGE` | Flag-based | Verified |
| `FRLG-L003` | Saffron gate Tea event | `FLAG_GOT_TEA`, then shared gate scene variable | Flag + scene state | Verified |
| `FRLG-L004` | Route 12/16 Snorlax | `FLAG_GOT_POKE_FLUTE` | Flag-based | Verified |
| `FRLG-L005` | Pokémon Tower ghosts / Marowak | Current Bag contains `ITEM_SILPH_SCOPE` | Item-based | Verified |
| `FRLG-L006` | Brock victory state | Separate `FLAG_DEFEATED_BROCK` and `FLAG_BADGE01_GET`; Pewter scene/object state also changes | Flag + scene/object state | Verified |
| `FRLG-L007` | Badge identity | Badge flags are permanent system flags distinct from boss-defeat flags | Flag-based | Verified |
| `FRLG-L008` | Cut | Cascade Badge flag + a party Pokémon knows `MOVE_CUT` | Field-move rule | Verified |
| `FRLG-L009` | Rock Smash | Marsh Badge flag + a party Pokémon knows `MOVE_ROCK_SMASH` | Field-move rule | Verified |
| `FRLG-L010` | Strength | Rainbow Badge flag + a party Pokémon knows `MOVE_STRENGTH` | Field-move rule | Verified |
| `FRLG-L011` | Cycling Road entry | `FLAG_GOT_BICYCLE` | Flag-based | Verified |
| `FRLG-L012` | Rocket Hideout lift | `FLAG_CAN_USE_ROCKET_HIDEOUT_LIFT` | Flag-based | Verified |
| `FRLG-L013` | Cinnabar Gym unlock | Secret Key item's hide/pickup flag | Flag-based | Verified |
| `FRLG-L014` | Mystic/Aurora ferry destinations | enable flag **and** current ticket item | Composite | Verified |
| `FRLG-L015` | Silph Co. Card Key doors | Individual persistent door flags verified; exact Card Key predicate still to be traced | Partial | Partial |
| `FRLG-L016` | Cerulean Cave guard | Guard/hide state exists; exact unlock script still to be traced | Partial | Partial |
| `FRLG-L017` | Fishing access/table selection | Shore or Surf; current map fishing table | Encounter rule | Verified |

---

## Detailed Findings

### FRLG-L001 — S.S. Anne Boarding Checks a Flag, Not the Bag

**Classification:** Flag-based **Status:** Verified

The Vermilion City ticket-check script does not call `checkitem ITEM_SS_TICKET`. It branches
on:

```text
FLAG_GOT_SS_TICKET
```

If the flag is unset, the sailor rejects the player. If it is set, the boarding sequence
continues.

#### Tracker implication

For exact vanilla logic, the S.S. Anne boarding condition should correspond to the
persistent ticket-acquisition state, not merely the existence of `item_ss_ticket` in the
Bag.

A future randomiser that relocates the physical S.S. Ticket would need to patch the
underlying event logic or explicitly map the randomised reward to the equivalent state if it
wants item possession to govern boarding.

#### Source

- [`VermilionCity/scripts.inc`, ticket check][source-002]

---

### FRLG-L002 — Helping Bill and Receiving the S.S. Ticket Are Separate States

**Classification:** Flag-based **Status:** Verified

Bill's cottage uses at least two distinct progression concepts:

```text
FLAG_HELPED_BILL_IN_SEA_COTTAGE
FLAG_GOT_SS_TICKET
```

Running the cell-separation sequence sets `FLAG_HELPED_BILL_IN_SEA_COTTAGE`.

On a later interaction, Bill attempts to give `ITEM_SS_TICKET`; that reward script then sets
`FLAG_GOT_SS_TICKET`.

This distinction matters because Cerulean City's transition script blocks its relevant exits
while `FLAG_GOT_SS_TICKET` is unset. It does **not** use `FLAG_HELPED_BILL_IN_SEA_COTTAGE`
for that check.

#### Tracker implication

The earlier project assumption that "Bill rescued" is itself the Cerulean progression
condition is too coarse.

The vanilla-equivalent state for the Cerulean exit unblock should be based on the S.S.
Ticket acquisition flag.

Possible tracker states include:

```text
state_event_bill_rescued
state_got_ss_ticket
```

They should remain semantically distinct even if the normal player obtains them in quick
succession.

#### Sources

- [`Route25_SeaCottage/scripts.inc`, Bill state flow][source-003]
- [`Route25_SeaCottage/scripts.inc`, S.S. Ticket reward][source-004]
- [`Route25_SeaCottage/scripts.inc`, helping Bill flag][source-005]
- [`CeruleanCity/scripts.inc`, exit blocking][source-006]

---

### FRLG-L003 — Saffron Guards Use the Tea Acquisition Flag and Shared Scene State

**Classification:** Flag + scene state **Status:** Verified

The Saffron gate scripts do **not** directly test current Bag possession with
`checkitem ITEM_TEA`.

At a closed gate, the guard trigger branches on:

```text
FLAG_GOT_TEA
```

When that flag is set, the script removes `ITEM_TEA`, plays the handoff event, and sets:

```text
VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES = 1
```

The shared map-scene variable represents the permanently opened gate state across the four
entrances.

The symbol `FLAG_GAVE_TEA_TO_GUARD` does not exist in the current `pret/pokefirered` flag
constants.

The Celadon Tea-giver script itself sets `FLAG_GOT_TEA` and gives `ITEM_TEA` during the same
reward sequence.

#### Tracker implication

Do not model the initial Saffron gate as a direct `item_tea` inventory check merely because
the player normally carries Tea into the gate.

A useful vanilla abstraction may distinguish:

```text
state_got_tea
state_event_saffron_gates_open
```

Whether the tracker needs both states depends on what later logic actually references.

#### Sources

- [`Route5_SouthEntrance/scripts.inc`, Tea trigger][source-007]
- [`Route6_NorthEntrance/scripts.inc`][source-008]
- [`Route7_EastEntrance/scripts.inc`][source-009]
- [`Route8_WestEntrance/scripts.inc`][source-010]
- [`CeladonCity_Condominiums_1F/scripts.inc`, Tea reward][source-011]
- [`flags.h`, `FLAG_GOT_TEA`][source-012]

---

### FRLG-L004 — Snorlax Checks the Poké Flute Acquisition Flag

**Classification:** Flag-based **Status:** Verified

Both Route 12 and Route 16 Snorlax scripts branch on:

```text
FLAG_GOT_POKE_FLUTE
```

The scripts do not perform a direct `checkitem ITEM_POKE_FLUTE` before awakening Snorlax.

#### Tracker implication

The exact vanilla blocker is a persistent state, not current Bag contents.

This is another case where a physical Key Item and the state used by game logic should not
automatically be treated as the same concept.

#### Sources

- [`Route12/scripts.inc`, Snorlax][source-013]
- [`Route16/scripts.inc`, Snorlax][source-014]

---

### FRLG-L005 — Silph Scope Is a Genuine Current-Inventory Check

**Classification:** Item-based **Status:** Verified

Pokémon Tower provides an important counterexample to the flag-heavy progression cases.

The battle setup code calls:

```text
CheckBagHasItem(ITEM_SILPH_SCOPE, 1)
```

for Pokémon Tower ghost handling.

`StartMarowakBattle()` also directly checks the Bag for `ITEM_SILPH_SCOPE` to decide whether
the Marowak ghost is unveiled.

#### Tracker implication

A vanilla tracker should treat Silph Scope possession as actual item-dependent logic.

This validates keeping physical inventory objects distinct from event flags instead of
reducing all Key Items to generic progression booleans.

#### Source

- [`src/battle_setup.c`, Pokémon Tower and Marowak checks][source-015]
- [`src/battle_setup.c`, `StartMarowakBattle`][source-016]

---

### FRLG-L006 — Brock Victory Changes Several Distinct States

**Classification:** Flag + scene/object state **Status:** Verified

The Brock victory script independently performs all of the following:

```text
set FLAG_DEFEATED_BROCK
set FLAG_BADGE01_GET
set VAR_MAP_SCENE_PEWTER_CITY = 1
hide the Pewter City Gym guide
reveal the Running Shoes NPC
```

This proves that "Brock defeated" and "Boulder Badge obtained" are distinct engine flags
even though vanilla sets them together.

The Pewter City route-blocking behaviour is implemented through the guide/scene/object
state. The researched Pewter City script does not contain a simple "Route 3 guard checks
`FLAG_DEFEATED_BROCK`" predicate.

#### Tracker implication

It is reasonable for the tracker to expose a semantic state such as:

```text
state_event_brock_defeated
```

for a Connection whose vanilla accessibility is caused by Brock's defeat.

However, documentation should not claim that the border script itself directly checks
`FLAG_DEFEATED_BROCK` unless that specific check exists.

Likewise, `state_has_boulder_badge` should remain a separate concept.

#### Sources

- [`PewterCity_Gym/scripts.inc`, Brock victory][source-017]
- [`PewterCity/scripts.inc`, Gym guide logic][source-018]
- [`flags.h`, boss clear flags][source-019]

---

### FRLG-L007 — Badge Flags Are Distinct Permanent System State

**Classification:** Flag-based **Status:** Verified

FRLG defines the eight Badge states separately as permanent system flags:

```text
FLAG_BADGE01_GET
...
FLAG_BADGE08_GET
```

Boss-defeat states are defined separately:

```text
FLAG_DEFEATED_BROCK
FLAG_DEFEATED_MISTY
...
FLAG_DEFEATED_LEADER_GIOVANNI
```

#### Tracker implication

The current project direction is supported by the game's own representation:

- badges should be represented primarily as persistent state;
- Gym defeat should be represented independently where it matters;
- badges do not need to be treated as ordinary `item_*` inventory objects in the vanilla
  model.

A future randomiser mode may introduce addressable Badge rewards without changing the
vanilla ontology.

#### Sources

- [`flags.h`, boss clear flags][source-019]
- [`flags.h`, permanent Badge flags][source-020]

---

### FRLG-L008 — Cut Checks Badge State and a Party Move, Not HM Inventory

**Classification:** Field-move rule **Status:** Verified

The Cut-tree script checks:

1. `FLAG_BADGE02_GET`;
2. whether a party Pokémon knows `MOVE_CUT`.

It does not check whether `ITEM_HM01` is currently in the Bag.

#### Tracker implication

The exact vanilla meaning of:

```text
state_can_cut
```

is closer to:

```text
Cascade Badge obtained
AND
a current party Pokémon knows Cut
```

than:

```text
HM01 obtained
AND
Cascade Badge obtained
```

If v1 deliberately uses HM ownership as a convenience proxy for "can teach/has taught the
move", that is a tracker simplification and should be documented as such rather than
described as exact game logic.

#### Source

- [`data/scripts/field_moves.inc`, Cut][source-021]

---

### FRLG-L009 — Rock Smash Checks Badge State and a Party Move

**Classification:** Field-move rule **Status:** Verified

Rock Smash checks:

1. `FLAG_BADGE06_GET`;
2. whether a party Pokémon knows `MOVE_ROCK_SMASH`.

#### Tracker implication

As with Cut, an exact `state_can_rock_smash` is a derived capability rather than simple HM
inventory ownership.

#### Source

- [`data/scripts/field_moves.inc`, Rock Smash][source-022]

---

### FRLG-L010 — Strength Checks Badge State and a Party Move

**Classification:** Field-move rule **Status:** Verified

Strength checks:

1. `FLAG_BADGE04_GET`;
2. whether Strength is already active for the current context;
3. otherwise, whether a party Pokémon knows `MOVE_STRENGTH`.

Using Strength sets `FLAG_SYS_USE_STRENGTH`.

#### Tracker implication

For static world reachability, the important durable capability is whether the player can
activate Strength when required. The temporary "Strength is currently active" state is
probably below the granularity needed by v1 unless a concrete topology case proves
otherwise.

#### Source

- [`data/scripts/field_moves.inc`, Strength][source-023]

---

### FRLG-L011 — Cycling Road Uses the Bicycle Acquisition Flag

**Classification:** Flag-based **Status:** Verified

The Route 16 Cycling Road gate transition checks:

```text
FLAG_GOT_BICYCLE
```

and disables the "need bike" trigger when that flag is set.

The researched gate script does not use a direct current-Bag check for `ITEM_BICYCLE`.

#### Tracker implication

Like the S.S. Ticket and Poké Flute, Bicycle-related access demonstrates that possessing a
Key Item and the flag used by a gate are not universally interchangeable concepts.

#### Source

- [`Route16_NorthEntrance_1F/scripts.inc`][source-024]

---

### FRLG-L012 — Rocket Hideout Lift Uses a Dedicated Access Flag

**Classification:** Flag-based **Status:** Verified

Picking up the Lift Key executes both:

```text
set FLAG_CAN_USE_ROCKET_HIDEOUT_LIFT
give ITEM_LIFT_KEY
```

The elevator floor-selection script checks:

```text
FLAG_CAN_USE_ROCKET_HIDEOUT_LIFT
```

rather than checking current possession of `ITEM_LIFT_KEY`.

#### Tracker implication

For vanilla elevator access, the dedicated flag is the authoritative predicate.

A future item randomiser that relocates `ITEM_LIFT_KEY` without changing the corresponding
logic would not automatically reproduce vanilla lift access.

#### Sources

- [`RocketHideout_B4F/scripts.inc`, Lift Key pickup][source-025]
- [`RocketHideout_Elevator/scripts.inc`, lift access][source-026]

---

### FRLG-L013 — Cinnabar Gym Unlock Uses the Secret Key Pickup/Hide Flag

**Classification:** Flag-based **Status:** Verified

Cinnabar Island's Gym-unlock check tests:

```text
FLAG_HIDE_POKEMON_MANSION_B1F_SECRET_KEY
```

That is the object/pickup flag associated with collecting the vanilla Secret Key item ball.

The Cinnabar unlock script does not directly check current possession of `ITEM_SECRET_KEY`.

#### Tracker implication

This is an especially important randomiser edge case.

The vanilla game is effectively checking whether the original Secret Key pickup has been
collected, not whether a Secret Key object currently exists in the Bag.

The vanilla tracker should model the vanilla predicate. A future randomiser mode must patch
the behaviour appropriate to that randomiser rather than assuming item identity controls the
door.

#### Source

- [`CinnabarIsland/scripts.inc`, Gym unlock][source-027]

---

### FRLG-L014 — Mystic and Aurora Tickets Use Composite Logic

**Classification:** Composite **Status:** Verified

Vermilion City's Seagallop Ferry logic demonstrates that FRLG does sometimes check both
persistent state and current item possession.

For the Mystic Ticket destination, the script requires:

```text
FLAG_ENABLE_SHIP_NAVEL_ROCK
AND
ITEM_MYSTIC_TICKET present in Bag
```

For the Aurora Ticket destination, it requires:

```text
FLAG_ENABLE_SHIP_BIRTH_ISLAND
AND
ITEM_AURORA_TICKET present in Bag
```

#### Tracker implication

There is no safe global rule such as "Key Items are always flags" or "Key Items are always
Bag checks".

Each progression mechanic should be researched independently.

This is also evidence that the tracker's v1 Connection requirement may legitimately point to
a **derived state** whose internal calculation combines lower-level conditions, even if the
Connection JSON itself retains the simple:

```json
"requires": "state_some_capability"
```

shape.

#### Source

- [`VermilionCity/scripts.inc`, event-ticket checks][source-028]

---

### FRLG-L015 — Silph Co. Card Key Doors

**Classification:** Partial **Status:** Partially verified

The source defines individual persistent flags for Silph Co. doors, for example:

```text
FLAG_SILPH_2F_DOOR_1
FLAG_SILPH_2F_DOOR_2
...
FLAG_SILPH_11F_DOOR
```

Floor scripts use these flags to maintain door-open state.

The Card Key itself is a real Bag item and its vanilla pickup is defined as `ITEM_CARD_KEY`.

However, this research pass has **not yet located the common interaction routine that proves
exactly how possession of the Card Key is checked before a door flag is set**.

#### Tracker implication

Do not yet encode the statement:

> "Silph doors directly check `ITEM_CARD_KEY`."

as a verified engine assumption.

The likely model is straightforward, but this document exists precisely to distinguish
likely behaviour from source-confirmed behaviour.

#### Sources

- [`flags.h`, Silph door flags][source-012]
- [`item_ball_scripts.inc`, Card Key pickup][source-029]
- [`SilphCo_2F/scripts.inc`][source-030]

---

### FRLG-L016 — Cerulean Cave Guard

**Classification:** Partial **Status:** Research required

The source defines a hide/show state for the Cerulean Cave guard, and Cerulean City contains
the guard NPC/script.

This research pass has not yet traced the exact script that changes the guard's state or
proved the full condition that removes access blocking.

#### Tracker implication

Do not encode "beat the League" or any other simplified condition as source-verified yet.

When Cerulean Cave is added to the world graph, trace the state transition first and
reference the completed entry here.

#### Sources

- [`flags.h`][source-012]
- [`CeruleanCity/scripts.inc`][source-031]

---

### FRLG-L017 — Fishing Works From Shore or While Surfing

**Classification:** Encounter rule **Status:** Verified

The field-item routine allows fishing in both of the situations relevant to the tracker:

- while standing on land and facing surfable, fishable water;
- while already Surfing and facing a valid surfable tile or bridge-over-water tile.

When fishing starts, `FishingWildEncounter()` selects from the current map's
`fishingMonsInfo`. The wild-encounter data defines one fishing table for the map, with
separate Old Rod, Good Rod, and Super Rod slot groups.

#### Tracker implication

A fishing encounter source belongs to every Zone from which the player can legally fish
using that map's table. The same source may therefore be referenced by a shoreline land Zone
and by the corresponding water Zone.

For tracker availability, separate source IDs such as `enc_route_24_old_rod`,
`enc_route_24_good_rod`, and `enc_route_24_super_rod` remain useful because each requires a
different Key Item, even though vanilla stores their encounter slots under one map-level
fishing table.

Do not attach a fishing source to a Zone merely because it is graph-adjacent to a water
Zone. The Zone must contain at least one legal position from which the player can fish.

#### Sources

- [`src/item_use.c`, `FieldUseFunc_Rod` and `CanFish`][source-035]
- [`src/data/wild_encounters.json`, fishing rod groups][source-036]

---

## Research Corrections to Earlier Assumptions

The research changed several assumptions that looked reasonable from normal gameplay.

| Earlier assumption | Source-backed finding |
| --- | --- |
| Helping Bill itself opens Cerulean progression. | Cerulean's transition uses `FLAG_GOT_SS_TICKET`; helping Bill is a separate earlier flag. |
| Saffron guards directly check `ITEM_TEA`, then set `FLAG_GAVE_TEA_TO_GUARD`. | Gate scripts check `FLAG_GOT_TEA`, remove the item, then set a shared map-scene variable. No `FLAG_GAVE_TEA_TO_GUARD` symbol was found. |
| Snorlax directly checks `ITEM_POKE_FLUTE`. | Both Snorlax scripts check `FLAG_GOT_POKE_FLUTE`. |
| Route 3's blocker simply checks `FLAG_DEFEATED_BROCK`. | Brock's victory script changes defeat, badge, scene, and NPC visibility state; Pewter's blocking behaviour is implemented through scene/object state. |
| Owning HM01 + Cascade Badge is exactly what Cut checks. | The game checks Cascade Badge + whether a current party Pokémon knows `MOVE_CUT`. |
| Cinnabar Gym checks current `ITEM_SECRET_KEY` possession. | Its unlock script checks the Secret Key pickup/hide flag. |

These are examples of why the tracker should not infer engine predicates solely from the
normal causal sequence visible to the player.

---

## Engine Design Consequences

## 1. Do Not Derive Every Gate From Inventory

The physical item object and the state a game script checks are separate concerns.

Examples:

```text
ITEM_SS_TICKET          != FLAG_GOT_SS_TICKET
ITEM_POKE_FLUTE         != FLAG_GOT_POKE_FLUTE
ITEM_LIFT_KEY           != FLAG_CAN_USE_ROCKET_HIDEOUT_LIFT
ITEM_BICYCLE            != FLAG_GOT_BICYCLE
```

Vanilla normally keeps the corresponding pairs coherent, but the engine should model the
predicate the game actually uses.

---

## 2. Badges and Gym-Defeat Events Should Remain Separate States

The source explicitly defines both:

```text
FLAG_DEFEATED_BROCK
FLAG_BADGE01_GET
```

and Brock's victory script sets them separately.

This supports tracker state along the lines of:

```text
state_event_brock_defeated
state_has_boulder_badge
```

rather than treating the Boulder Badge as an ordinary Bag item.

---

## 3. Derived Capabilities Are Useful

A Connection should not need to reproduce low-level mechanics.

For example:

```json
{
  "id": "conn_route_2_south_cut_tree",
  "requires": "state_can_cut"
}
```

can remain simple while `state_can_cut` encapsulates whatever fidelity the current tracker
version chooses to support.

For exact vanilla behaviour, Cut requires Badge 02 plus a party Pokémon knowing Cut.

For a simpler manual v1 tracker, the project may deliberately use a proxy such as HM
acquired + badge acquired. If it does, that simplification should be recorded in
`DECISIONS.md`.

---

## 4. Semantic Tracker State Must Map Back to Verified Vanilla State

The tracker does not need to expose raw engine symbols everywhere.

For example:

```text
state_got_ss_ticket
```

may be preferable to leaking `FLAG_GOT_SS_TICKET` into public data.

But the mapping should be documented:

```text
state_got_ss_ticket
    ↔ vanilla FLAG_GOT_SS_TICKET
    ↔ FRLG-L001 / FRLG-L002
```

This gives the project readable IDs without losing traceability.

---

## 5. Connection Requirements Should Describe the Actual Blocker

When a map is inaccessible because a scene/NPC blocks continuous movement, represent that as
a Connection requirement between Zones rather than pretending the destination Zone or Warp
itself is disabled.

This remains consistent with the current topology design.

---

## 6. Vanilla Data Remains Vanilla

Randomiser and challenge modes should patch or reinterpret vanilla behaviour rather than
forcing the base FRLG data model to anticipate every possible modification.

The source-backed distinction between flags, items, map scenes, and field-move rules is
especially important if a future randomiser changes rewards without changing all of the
scripts that normally accompany those rewards.

---

## Suggested Research Workflow for New Logic

Before assigning a new Connection requirement:

1. Identify the physical blocker in the game.
2. Locate the relevant map script, C routine, or field-move implementation.
3. Identify the **exact predicate** the game checks.
4. Identify the event that changes that predicate.
5. Check whether the apparent item/event and the tested state are distinct.
6. Add or update an `FRLG-Lxxx` entry in this document.
7. Map the raw predicate to an appropriately named tracker state.
8. Only then add the requirement to world data.

Example:

```text
Question:
"What opens this path?"

Do not stop at:
"The player normally has the S.S. Ticket by then."

Trace:
Cerulean transition
    → FLAG_GOT_SS_TICKET
    → Bill's reward script
    → FRLG-L002

Then encode:
requires: state_got_ss_ticket
```

---

## Open Research Queue

These topics should be traced before their exact tracker predicates are finalised.

## High Priority

- **Silph Co. Card Key doors:** locate the common door interaction routine and prove the
  exact Card Key possession check that sets the per-door flags.
- **Cerulean Cave:** trace the exact condition that removes/hides the entrance guard.
- **Surf:** trace the precise badge/party-move logic used in FRLG.
- **Flash:** trace the precise gating and what world-access assumptions the tracker actually
  needs.
- **Fly:** trace field-use conditions separately from map reachability.
- **Route 23 badge gates:** document whether each guard checks Badge flags directly and how
  the map blocks movement.

## Medium Priority

- Victory Road Strength/boulder state where it affects Zone modelling.
- Seafoam Islands boulder/water-current interactions.
- Pokémon Mansion one-way drops and landing behaviour.
- Escape Rope and Dig.
- Teleport and last-heal-location behaviour.
- Whiteout/respawn movement.
- Event-ferry progression beyond the ticket checks already documented.
- Sevii Island progression gates and National Dex prerequisites.

---

## Research Notes

## Waterfall

The shared field-move script checks whether a party Pokémon knows `MOVE_WATERFALL` and does
not show a Badge check in that script. This is recorded as an observation, but Waterfall has
not yet been promoted to a tracker requirement because its broader FRLG progression context
has not been researched here.

Source:

- [`data/scripts/field_moves.inc`, Waterfall][source-032]

## Why Constants Alone Are Not Enough

A flag existing in `flags.h` proves that the game has that state. It does **not** prove that
a particular barrier checks it.

For example, `FLAG_DEFEATED_BROCK` exists, but the exact Pewter/Route 3 blocking behaviour
also involves map-scene and NPC hide/show state.

Always prefer the script performing the actual access check.

---

## Primary Repository

- [`pret/pokefirered`][source-001]
- [`include/constants/flags.h`][source-012]
- [`include/constants/items.h`][source-033]
- [`data/scripts/field_moves.inc`][source-034]
- [`data/scripts/item_ball_scripts.inc`][source-029]

---

## Maintenance Rule

Treat this file as a living source-of-truth document.

A statement should be marked **Verified** only when the relevant vanilla implementation has
been found. If only surrounding evidence is available, leave it **Partial** or **Open**
rather than filling the gap from memory.

The purpose is not merely to know *what normally happens in a playthrough*, but to know
*what piece of state the game actually evaluates*.

[source-001]: https://github.com/pret/pokefirered
[source-002]:
  https://github.com/pret/pokefirered/blob/master/data/maps/VermilionCity/scripts.inc#L174-L185
[source-003]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route25_SeaCottage/scripts.inc#L19-L27
[source-004]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route25_SeaCottage/scripts.inc#L85-L98
[source-005]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route25_SeaCottage/scripts.inc#L139-L145
[source-006]:
  https://github.com/pret/pokefirered/blob/master/data/maps/CeruleanCity/scripts.inc#L4-L13
[source-007]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route5_SouthEntrance/scripts.inc#L23-L46
[source-008]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route6_NorthEntrance/scripts.inc
[source-009]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route7_EastEntrance/scripts.inc
[source-010]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route8_WestEntrance/scripts.inc
[source-011]:
  https://github.com/pret/pokefirered/blob/master/data/maps/CeladonCity_Condominiums_1F/scripts.inc#L2-L14
[source-012]: https://github.com/pret/pokefirered/blob/master/include/constants/flags.h
[source-013]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route12/scripts.inc#L11-L25
[source-014]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route16/scripts.inc#L28-L42
[source-015]: https://github.com/pret/pokefirered/blob/master/src/battle_setup.c#L204-L225
[source-016]: https://github.com/pret/pokefirered/blob/master/src/battle_setup.c#L295-L312
[source-017]:
  https://github.com/pret/pokefirered/blob/master/data/maps/PewterCity_Gym/scripts.inc#L10-L18
[source-018]:
  https://github.com/pret/pokefirered/blob/master/data/maps/PewterCity/scripts.inc
[source-019]:
  https://github.com/pret/pokefirered/blob/master/include/constants/flags.h#L1219-L1232
[source-020]:
  https://github.com/pret/pokefirered/blob/master/include/constants/flags.h#L1339-L1349
[source-021]:
  https://github.com/pret/pokefirered/blob/master/data/scripts/field_moves.inc#L0-L15
[source-022]:
  https://github.com/pret/pokefirered/blob/master/data/scripts/field_moves.inc#L55-L70
[source-023]:
  https://github.com/pret/pokefirered/blob/master/data/scripts/field_moves.inc#L112-L149
[source-024]:
  https://github.com/pret/pokefirered/blob/master/data/maps/Route16_NorthEntrance_1F/scripts.inc#L0-L11
[source-025]:
  https://github.com/pret/pokefirered/blob/master/data/maps/RocketHideout_B4F/scripts.inc#L56-L64
[source-026]:
  https://github.com/pret/pokefirered/blob/master/data/maps/RocketHideout_Elevator/scripts.inc#L2-L14
[source-027]:
  https://github.com/pret/pokefirered/blob/master/data/maps/CinnabarIsland/scripts.inc#L35-L41
[source-028]:
  https://github.com/pret/pokefirered/blob/master/data/maps/VermilionCity/scripts.inc#L53-L63
[source-029]:
  https://github.com/pret/pokefirered/blob/master/data/scripts/item_ball_scripts.inc
[source-030]:
  https://github.com/pret/pokefirered/blob/master/data/maps/SilphCo_2F/scripts.inc
[source-031]:
  https://github.com/pret/pokefirered/blob/master/data/maps/CeruleanCity/scripts.inc
[source-032]:
  https://github.com/pret/pokefirered/blob/master/data/scripts/field_moves.inc#L167-L196
[source-033]: https://github.com/pret/pokefirered/blob/master/include/constants/items.h
[source-034]: https://github.com/pret/pokefirered/blob/master/data/scripts/field_moves.inc
[source-035]: https://github.com/pret/pokefirered/blob/master/src/item_use.c
[source-036]: https://github.com/pret/pokefirered/blob/master/src/data/wild_encounters.json
