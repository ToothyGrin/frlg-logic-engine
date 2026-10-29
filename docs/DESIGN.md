# FRLG Tracker — Design

## Overview

The project is organised conceptually into four layers:

```text
Canonical FRLG Game Data
          ↓
      Core Engine
          ↓
     Optional Modes
          ↓
 EmoTracker Adapter/UI
```

The vanilla game data and core engine are the foundation. Professor Oak Challenge, Warp
Randomiser, autotracking, and other specialised behaviour are later layers rather than
assumptions built into the world model.

## Design Principles

The design follows several recurring principles:

- represent FRLG facts as data where practical;
- keep canonical behaviour defined once;
- keep relationships locally discoverable for authors;
- prefer descriptive stable IDs over terse opaque IDs;
- keep reference arrays homogeneous;
- derive reachability rather than storing it as authoritative state;
- validate deliberate referential redundancy automatically;
- model vanilla FRLG first and patch behaviour only when a selected mode requires it.

## World Model

### Map Containers

Every traversable map container contains `1..*` Zones.

The major container categories are:

- **Route**: an overworld Route;
- **Settlement**: an overworld town or city;
- **Instance**: a separately loaded non-overworld space.

Instances include concepts such as:

- houses and other Buildings;
- Gyms;
- caves;
- forests;
- dungeons;
- ships;
- other separately loaded interiors or map spaces.

A container with no useful internal reachability division still contains one Zone.

Examples:

```text
Route 1
└── zone_route_1

Viridian Forest
└── zone_viridian_forest

Route 2
├── zone_route_2_southwest
├── zone_route_2_southeast
├── zone_route_2_northwest
└── zone_route_2_northeast
```

The extra Zone wrapper for simple maps is intentional. It allows the solver to operate on
one universal reachability type rather than special-casing simple and complex maps.

### Zones

A Zone is the unit of world reachability.

A Zone represents a portion of map space that is meaningful to treat as reachable or
unreachable independently from another portion.

Zones do not have intrinsic accessibility requirements in v1.0. A Zone becomes reachable
because the engine can traverse a Connection or Portal leading to it.

A Zone locally declares references to the world objects and content associated with it. For
example:

```json
{
  "id": "zone_route_2_southwest",
  "connections": [
    "conn_viridian_city_route_2_border",
    "conn_route_2_southwest_southeast_tree"
  ],
  "warps": ["warp_route_2_viridian_forest_south_gate_south_entrance"],
  "encounter_sources": ["enc_route_2_grass"],
  "item_sources": [],
  "trainers": []
}
```

The exact names of some source arrays remain subject to later acquisition-model design, but
each array is homogeneous.

### Connections

A Connection represents continuous movement between two Zones without a game-engine map
warp.

Examples include:

- borders between Routes or Settlements;
- boundaries between Zones inside one Route;
- Cut-tree passages;
- Surf passages where the water itself is ordinary continuous movement;
- ledges;
- other continuous terrain boundaries.

Connections are first-class authoritative objects. Neither endpoint Zone owns the
Connection.

A Zone declares the Connection IDs that touch it, while the Connection definition stores the
authoritative endpoints, type, and requirement.

Example:

```json
{
  "id": "conn_route_2_southwest_southeast_tree",
  "type": "cut_tree",
  "zones": ["zone_route_2_southwest", "zone_route_2_southeast"],
  "requires": "state_can_cut"
}
```

This deliberate duplicated reference is validated in both directions.

#### Multiple Connections Between the Same Zones

The world graph is a multigraph. Two Zones may be joined by more than one physical
Connection.

For example, Viridian City's Dream Eater tutor island can be reached by two physically
distinct paths:

```text
zone_viridian_city
    ├── Cut-tree Connection ──┐
    └── Surf Connection ──────┤
                              ▼
              zone_viridian_city_move_tutor_island
```

These are represented as two Connection objects rather than one Connection containing an
`OR` requirement.

An `OR` would describe multiple logical ways of opening the same physical path. Distinct
physical paths remain distinct Connections.

#### Directionality

Connections are bidirectional by default.

Directional Connection types may define special traversal semantics. In v1.0 the known
example is a ledge that actually separates reachability Zones.

For a directional `ledge`, the ordered `zones` array defines traversal direction:

```text
zones[0] → zones[1]
```

Example:

```json
{
  "id": "conn_route_4_east_eastmost_ledge",
  "type": "ledge",
  "zones": ["zone_route_4_east", "zone_route_4_eastmost"],
  "requires": null
}
```

For ordinary Connection types, array ordering carries no traversal meaning.

Topology may include a ledge or shortcut even when it is redundant to vanilla reachability.
Faithful topology is useful for later modes such as Warp Randomiser.

### Requirements

World-topology requirements are intentionally simple in v1.0.

A Connection has:

```text
requires = null | state_id
```

For example:

```json
{
  "id": "conn_pewter_city_route_3_border",
  "type": "border",
  "zones": ["zone_pewter_city", "zone_route_3"],
  "requires": "state_event_brock_defeated"
}
```

The old recursive `AND` and `OR` requirement expressions are not part of the v1.0 world
schema.

Compound game logic belongs in state derivation. For example:

```text
state_can_cut =
    state_has_cascade_badge
    AND state_has_hm01_cut
```

The Connection only needs to ask whether `state_can_cut` is true.

Accepted decision D031 considers HM ownership plus the corresponding badge sufficient.
The tracker does not check move knowledge or Pokémon compatibility. This intentionally
simplifies the vanilla party-move checks documented in `FRLG_VANILLA_LOGIC_REFERENCE.md`.

Zones, Warps, and Portals do not carry accessibility requirements in v1.0.

If an NPC, story event, or obstacle blocks access to a Warp, the world should normally be
zoned so that the Connection leading to the Warp's Zone carries the requirement.

### Warps

A Warp represents one game-engine displacement point, such as:

- a building entrance or exit;
- a cave entrance or exit;
- a forest gate;
- a staircase;
- a ladder;
- a ship entrance;
- another tile or trigger that moves the player to another map coordinate or loaded map.

A Warp is a globally unique reference ID declared by exactly one Zone.

A Warp is not a standalone data object in v1.0. There is no canonical `warps.json` whose
entries merely repeat the IDs.

The meaningful facts about a normal Warp are derived from:

1. the Zone that declares the Warp ID; and
2. the Portal that pairs it with its sibling Warp.

A Cut tree, ledge, or ordinary continuous map border is not a Warp.

### Portals

A Portal represents the normal vanilla case in which two Warps are linked bidirectionally.

The canonical vanilla representation is an unordered pair of Warp IDs:

```json
["warp_pallet_town_rival_house_entrance", "warp_rivals_house_exit"]
```

A Portal collection is therefore an array of two-element arrays:

```json
[
  ["warp_pallet_town_rival_house_entrance", "warp_rivals_house_exit"],
  ["warp_pallet_town_player_house_entrance", "warp_players_house_exit"],
  ["warp_pallet_town_oaks_lab_entrance", "warp_oaks_lab_exit"]
]
```

For normal vanilla Portals:

```text
Warp A ↔ Warp B
```

Array order has no traversal meaning.

The loader derives runtime indexes such as:

```text
warp_to_zone[Warp A] = Zone A
warp_to_zone[Warp B] = Zone B

warp_to_sibling[Warp A] = Warp B
warp_to_sibling[Warp B] = Warp A
```

The authored data therefore stores each Portal relationship only once while the runtime
engine receives efficient reciprocal lookup tables.

#### Warps That Are Not Portals

Not every discrete movement mechanic must be represented as a Portal.

For example, one-way drops in Pokémon Mansion behave like game-engine warps but do not form
a normal bidirectional door pair.

The exact representation of one-way Warp mechanics is deferred until the vanilla data
requires it. The common Portal model should not be made more complicated to anticipate rare
exceptions.

## State

State describes facts relevant to progression and logic.

The exact type-prefix list remains to be formally frozen, but the current state naming
direction is:

```text
state_has_*      acquired state
state_can_*      derived capability
state_event_*    story or world state
```

Examples:

```text
state_has_boulder_badge
state_has_hm01_cut
state_can_cut
state_event_bill_rescued
```

### Acquired State

Acquired state records things the player directly possesses, chose, or completed.

Examples include:

- badges;
- HMs and key items;
- story flags;
- the starter choice.

Starter selection is a custom mutually exclusive state rather than a general-purpose
Pokémon-choice source object.

Conceptually:

```text
starter_choice = bulbasaur | charmander | squirtle
```

The exact storage representation may be adapted to EmoTracker later.

### Derived Capability State

Derived capability state is calculated from acquired state and other authoritative facts.

Examples include:

```text
state_can_cut
state_can_surf
```

Derived capabilities should normally not be independently toggled by the user.

The initial implementation is `State.evaluate(player)` in `logic/state.lua`.
It derives Cut and Surf from badge and HM acquisition facts, returns a fresh boolean state
table, and preserves the existing parcel-delivery and Brock-event inputs. See `STATE.md`
for supported inputs, examples, and the accepted HM-usability policy.

### Reachability State

Zone reachability is derived output, not authoritative player state.

The engine should not maintain independent `canAccess*` values that can drift away from the
actual graph.

## Reachability Solver

The world solver operates on Zones.

At a high level:

```text
reachable = { starting_zone }
queue = { starting_zone }

while queue is not empty:
    current = remove one Zone from queue

    inspect current Zone's Connections
    traverse any valid Connection to an unreached Zone

    inspect current Zone's Warps
    traverse any active Portal pairing to an unreached Zone

    add newly reached Zones to reachable and queue
```

Connection traversal checks:

- whether the current Zone is one endpoint;
- whether the Connection permits traversal in that direction;
- whether its `requires` state is true, if present.

Portal traversal checks:

- whether the Warp has an active sibling pairing;
- which Zone declares the sibling Warp.

The solver continues until no new Zones become reachable.

When relevant player state or the active Portal mapping changes, reachability is
recalculated from authoritative state rather than depending on a long-lived chain of
incremental mutations.

FRLG is small enough that correctness and simple reasoning are more valuable than
micro-optimising this calculation.

## Acquisition Model

Acquisition logic is separate from world topology.

The engine distinguishes three broad scopes:

- **location-bound acquisition**, associated with a reachable Zone;
- **derived acquisition**, calculated from other data and state;
- **external acquisition**, supplied by connectivity or other games rather than the
  currently reachable FRLG world.

### Homogeneous Reference Arrays

Reference arrays contain one domain-object type only.

For example:

```json
"encounter_sources": [
  "enc_route_1_grass"
]
```

Every reference in `encounter_sources` resolves to an encounter table.

NPC trades, Pokémon vendors, gifts, static encounters, fossil revival, and other mechanics
should not be mixed into that array merely because they all yield Pokémon.

Their exact object types and array names will be defined as each mechanic is implemented.

### Encounter Sources

Encounter sources represent wild encounter tables.

Examples include:

```text
enc_route_1_grass
enc_viridian_city_old_rod
enc_viridian_city_surfing
```

Different encounter methods may share the encounter-table abstraction when their schema and
behaviour remain coherent.

### Stable Source Identity

Source IDs describe the stable source or mechanism rather than its current payload.

Prefer:

```text
enc_route_1_grass
itemsrc_route_3_floor_between_two_ledges
```

over names based on the Pokémon or item currently obtained there.

This keeps references stable when:

- FireRed and LeafGreen differ;
- a mod changes the reward;
- game data is corrected;
- a source's contents vary by state.

### Evolution

Evolution is derived acquisition rather than a Zone source.

Evolution data should eventually record concepts such as:

- source species;
- target species;
- method;
- level or item parameters;
- trade requirements;
- other restrictions.

The exact evolution schema is deferred until Pokémon availability work begins.

### Currency and Consumable Resources

Version 1.0 does not track quantities of renewable or expendable resources such as:

- Poké Dollars;
- Game Corner Coins;
- Poké Balls.

Canonical prices and costs may still be stored.

The vanilla availability engine determines whether an acquisition mechanism is accessible,
not whether the player's current wallet or consumable inventory can pay for it.

This simplification can produce false positives in specialised challenge situations. For
example, a Professor Oak Challenge can theoretically become unwinnable before Brock if the
player exhausts finite early money and Poké Balls.

Finite-resource feasibility is explicitly deferred beyond v1.0 and may later be a mode-level
feature.

## Naming and IDs

Every significant cross-referenced object uses a stable machine ID separate from its display
name.

IDs should be descriptive enough to locate and understand without requiring detailed game
knowledge.

IDs should not encode mutable behaviour such as the current reward or requirement, and must
never depend on authoring order.

The current direction is to use type prefixes for heavily cross-referenced leaf objects, for
example:

```text
zone_route_2_southwest
conn_route_2_southwest_southeast_tree
warp_route_2_gate_north_entrance
enc_route_1_grass
itemsrc_route_1_pokemart_employee
trainer_route_3_lass_janice
state_can_cut
```

Map-container IDs may remain concise when their natural names are already clear:

```text
route_2
viridian_city
viridian_forest
oaks_lab
```

Single-Zone containers omit an unnecessary `_main` qualifier:

```text
zone_route_1
zone_pallet_town
zone_viridian_forest
```

Partitioned containers use descriptive local qualifiers:

```text
zone_route_2_southwest
zone_viridian_city_north
```

The exact final prefix vocabulary and Warp naming grammar remain open and are recorded in
`DECISIONS.md`.

## Modes

### Vanilla

Vanilla mode uses the canonical FRLG state rules, Connections, and Portal pairings.

### Warp Randomiser

Warp Randomiser is a later mode.

Instead of using the canonical vanilla Portal mapping as the active mapping, the mode can
supply a player-tracked set of discovered Warp pairs.

Conceptually:

```text
unknown pairing
      ↓
player discovers Warp A ↔ Warp X
      ↓
record pair
      ↓
recalculate reachability
      ↓
new Zones may become reachable
```

The vanilla Portal data remains unchanged.

### Professor Oak Challenge

Professor Oak Challenge is a later mode that interprets vanilla reachability and acquisition
availability according to challenge-specific completion rules.

It should not redefine canonical FRLG topology merely to express challenge rules.

## Validation

Validation is part of normal development rather than a final clean-up step.

At minimum, the validator should eventually verify:

- globally unique IDs where uniqueness is required;
- every Zone Connection reference resolves to a Connection;
- every Connection endpoint resolves to a Zone;
- every Connection endpoint Zone declares that Connection;
- directional Connection types obey their ordering rules;
- every Connection requirement resolves to valid state;
- every Warp ID is globally unique;
- every Warp is declared by exactly one Zone;
- every vanilla Portal contains exactly two distinct Warp IDs;
- every Warp referenced by a Portal exists;
- no Warp participates in more than one vanilla Portal;
- source arrays contain only the correct source-object type;
- referenced encounters, Pokémon, items, trainers, and evolution data exist as those domains
  are implemented.

## Testing

Logic should be tested using known progression snapshots and focused topology cases.

Useful early tests include:

### New Game

Only Zones reachable through the starting vanilla state should be discovered.

### Brock Defeated

The Pewter City to Route 3 Connection should become traversable when
`state_event_brock_defeated` becomes true. Badge acquisition remains a separate fact.

### Cut Available

Cut-tree Connections should become traversable when `state_can_cut` becomes true without
altering unrelated Connections.

### Directional Ledge

The Route 4 ledge should be traversable only in its declared direction.

### Portal Traversal

A Zone containing one side of a vanilla Portal should reach the Zone containing its sibling
Warp.

### Parallel Connections

Viridian City's Cut and Surf routes to the move-tutor island should behave as two
independent physical Connections.

Tests should assert externally meaningful outputs rather than implementation details.

## Deferred Mechanics

The following mechanics are intentionally deferred until they are required:

- one-way Warp/drop representation;
- Teleport, Fly, Dig, Escape Rope, and other dynamic movement;
- finite-resource feasibility;
- exact mod-overlay and patch semantics;
- Warp Randomiser UI and manual pairing state;
- Professor Oak Challenge completion rules;
- emulator autotracking.

These deferred features should not make the vanilla v1.0 data model more complicated without
a concrete requirement.
