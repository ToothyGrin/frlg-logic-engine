# FRLG Tracker — Design Decisions

This file records significant architectural decisions and the questions that remain open.

## Decision Statuses

- **Recovered**: directly evidenced by the recovered March 2026 project.
- **Accepted**: explicitly adopted for the resumed project.
- **Open**: still requires a design decision.
- **Deferred**: intentionally postponed because it does not block current work.
- **Superseded**: retained for historical context but replaced by the current design.

## Accepted Decisions

### D001 — Use Data-Driven World Definitions

**Status:** Recovered

World structure and game facts should be represented primarily as data rather than
hard-coded location-specific Lua.

#### Rationale

FRLG contains enough repeated world, encounter, item, trainer, and progression data that
declarative data is easier to maintain, validate, and extend.

---

### D002 — Vanilla FRLG Is the Foundation

**Status:** Accepted

The core engine and canonical data model vanilla FireRed and LeafGreen first.

Professor Oak Challenge, Warp Randomiser, autotracking, and other specialised behaviour are
later modes or adapters.

#### Rationale

Mode-specific rules should not contaminate the canonical representation of the base game.

---

### D003 — Story Events Are Progression State

**Status:** Recovered

Progression is not represented solely by badges, HMs, and inventory.

Story and world events may also be state.

#### Rationale

The tracker should represent the actual game conditions that govern progression rather than
approximate them through unrelated items or badges.

---

### D004 — Keep Experimental Logic Separate From Production Logic

**Status:** Recovered

Exploratory logic may be developed in a sandbox before integration into the production
engine.

#### Evidence

The recovered project contains `logic/sandbox.lua`, which was used for the prototype
requirement evaluator.

---

### D005 — Use Stable Machine IDs

**Status:** Accepted

Significant cross-referenced domain objects use stable machine IDs separate from display
names.

IDs favour clarity over brevity, should not depend on authoring order, and should not encode
mutable facts such as the current reward or requirement.

#### Rationale

Stable descriptive IDs improve validation, debugging, searching, modding, and long-term
maintainability.

---

### D006 — Every Traversable Map Container Contains Zones

**Status:** Accepted

Every Route, Settlement, and separately loaded Instance contains `1..*` Zones.

Simple containers still explicitly contain one Zone.

#### Rationale

The solver can operate on one universal reachability type without special-casing simple
houses, large dungeons, Routes, Settlements, forests, caves, or ships.

---

### D007 — Zones Are the Reachability Unit

**Status:** Accepted

A Zone represents a portion of map space whose reachability matters independently from
another portion.

Zones themselves have no intrinsic accessibility requirement in v1.0.

A Zone becomes reachable through a traversable Connection or Portal.

---

### D008 — Connections Represent Continuous Movement

**Status:** Accepted

A Connection represents continuous movement between two Zones without a game-engine map
warp.

Examples include borders, Cut-tree passages, Surf passages, and ledges.

Connections are authoritative objects and do not conceptually belong to either endpoint
Zone.

---

### D009 — Zones Declare Their Connection References

**Status:** Accepted

Each Zone locally declares the IDs of the Connections that touch it.

The Connection object contains the authoritative endpoints, type, and requirement.

#### Rationale

This is deliberate referential redundancy. It makes a Route or Zone easier to understand and
edit without reconstructing the world graph from several unrelated files.

Validation ensures both sides remain consistent.

---

### D010 — Prefer Canonical Behaviour and Locally Discoverable Relationships

**Status:** Accepted

Behaviour should have one authoritative definition, but references may be repeated where
that substantially improves authoring and maintenance.

#### Rationale

Human navigation is more valuable here than maximal data normalisation, provided the
redundancy is validated automatically.

---

### D011 — Multiple Physical Paths Are Multiple Connections

**Status:** Accepted

Two Zones may be joined by multiple distinct Connection objects.

For example, Viridian City's Cut-tree path and Surf path to the Dream Eater tutor island are
separate Connections even though they share endpoint Zones.

#### Rationale

A Connection represents a physical path, not merely a logical relationship between two
Zones.

---

### D012 — Connection Requirements Are Simple State References in v1.0

**Status:** Accepted

A world Connection uses:

```text
requires = null | state_id
```

Compound `AND` and `OR` trees are not part of the v1.0 world-topology schema.

Compound logic is represented by derived state when needed.

---

### D013 — Connections Are Bidirectional Unless Their Type Says Otherwise

**Status:** Accepted

Ordinary Connections are bidirectional.

Directional Connection types may define special semantics. For the known v1.0 `ledge` case,
the ordered Zone array means:

```text
zones[0] → zones[1]
```

#### Rationale

This keeps the common case terse while supporting the rare one-way continuous path.

---

### D014 — Faithful Topology May Include Vanilla-Redundant Connections

**Status:** Accepted

A real Connection may be represented even when it does not change normal vanilla
reachability.

#### Example

A shortcut ledge on Route 10 may be redundant in vanilla because the player reaches its
upper side through the Power Plant. It may still matter under a future Warp Randomiser.

---

### D015 — Warps Are Discrete Game-Engine Movement Endpoints

**Status:** Accepted

A Warp is a point that transports the player to another coordinate or loaded map space, such
as a door, cave entrance, staircase, ladder, forest gate, or ship entrance.

Cut trees, ledges, and ordinary continuous borders are not Warps.

---

### D016 — Warps Are References, Not Standalone Objects

**Status:** Accepted

A Warp is represented by a globally unique Warp ID declared by exactly one Zone.

There is no standalone Warp object merely repeating that ID in v1.0.

Its containing Zone is derived from the Zone declaration.

---

### D017 — A Vanilla Portal Is an Unordered Pair of Warps

**Status:** Accepted

A normal vanilla Portal is represented as exactly two Warp IDs:

```json
["warp_a", "warp_b"]
```

The relationship is bidirectional:

```text
Warp A ↔ Warp B
```

Array order carries no traversal meaning.

---

### D018 — Portal Runtime Lookups Are Derived

**Status:** Accepted

Each vanilla Portal pairing is authored once.

The loader derives reciprocal runtime indexes such as:

```text
warp_to_sibling[A] = B
warp_to_sibling[B] = A
```

and derives each Warp's containing Zone from Zone declarations.

---

### D019 — Modes May Replace the Active Portal Mapping

**Status:** Accepted

Vanilla uses the canonical Portal pairings by default.

A later Warp Randomiser mode may replace the active mapping with manually tracked or
otherwise supplied pairs without changing the vanilla dataset.

Reachability is recalculated when the active mapping changes.

---

### D020 — Not Every Warp Must Belong to a Normal Portal

**Status:** Accepted

The common Portal model covers bidirectional Warp pairs.

Rare discrete movement mechanics such as one-way drops may use Warp references without being
forced into the normal Portal representation.

Their exact schema is deferred until required by vanilla FRLG data.

---

### D021 — Reachability Is Derived State

**Status:** Accepted

Zone reachability is calculated from authoritative player state, Connections, and the active
Portal mapping.

`canAccess*` values are not independently maintained as authoritative progression state.

---

### D022 — Reachability Is Recalculated From Authoritative State

**Status:** Accepted

When relevant state or Portal mappings change, the engine recalculates reachability from
known starting Zones.

A queue-based graph traversal may be used to discover Zones until no new Zone becomes
reachable.

#### Rationale

FRLG is computationally small. Recalculation is simple, deterministic, and avoids stale
incremental state.

---

### D023 — Keep the Core Engine Independent of EmoTracker

**Status:** Accepted

World loading, validation, state evaluation, reachability, and later availability logic
should be testable without starting EmoTracker.

EmoTracker is an adapter and presentation layer.

---

### D024 — Reference Arrays Are Homogeneous

**Status:** Accepted

A declaration array contains references to one specific domain-object type.

For example, `encounter_sources` contains encounter-table IDs only.

NPC trades, Pokémon vendors, gifts, static encounters, and other mechanics should use their
own object types and arrays when implemented.

---

### D025 — Encounter Sources Are Wild Encounter Tables

**Status:** Accepted

`encounter_sources` refers only to wild encounter tables such as grass, cave, Surf, or
fishing encounter tables.

Other ways of obtaining Pokémon are not mixed into the same array merely because they all
yield Pokémon.

---

### D026 — Source IDs Describe Stable Sources, Not Payloads

**Status:** Accepted

Acquisition-source IDs describe the stable location or mechanism rather than the item or
Pokémon currently yielded.

Prefer names such as:

```text
enc_route_1_grass
itemsrc_route_3_floor_between_two_ledges
```

rather than IDs based on the current contents.

---

### D027 — Acquisition Logic Has Three Broad Scopes

**Status:** Accepted

Acquisition mechanisms are conceptually classified as:

- location-bound acquisition;
- derived acquisition;
- external acquisition.

Location-bound sources are associated with reachable Zones. Evolution is an example of
derived acquisition. Cross-game connectivity is an example of external acquisition.

---

### D028 — Starter Choice Is Custom Player State

**Status:** Accepted

The initial starter choice is represented as dedicated mutually exclusive player state
rather than a generic Pokémon-choice source object.

Conceptually:

```text
starter_choice = bulbasaur | charmander | squirtle
```

A reusable choice abstraction may be introduced later only if concrete game or mod data
justifies it.

---

### D029 — Currency and Consumable Quantities Are Not Tracked in v1.0

**Status:** Accepted

Version 1.0 does not track exact quantities of Poké Dollars, Game Corner Coins, Poké Balls,
or similar expendable resources.

Canonical prices may still be stored.

The vanilla engine determines whether an acquisition mechanism is logically accessible, not
whether the player currently has enough expendable resources to use it.

#### Known Limitation

A specialised challenge can become impossible through resource exhaustion even when the base
availability engine still reports the relevant species as available.

Finite-resource feasibility is deferred beyond v1.0.

---

### D030 — Validate References Automatically

**Status:** Accepted

Validation is required before substantial data expansion.

At minimum, validation should eventually cover:

- duplicate IDs;
- unresolved Zone, Connection, Warp, state, and source references;
- disagreement between Zone Connection references and Connection endpoints;
- invalid directional Connection definitions;
- invalid Portal pairs;
- Warps declared by more than one Zone;
- type errors in homogeneous reference arrays.

---

### D031 — HM Usability Uses Acquisition and Badge State

**Status:** Accepted (29 October 2026)

The tracker considers an HM usable once that HM and its corresponding badge have been
acquired. It does not check whether any Pokémon knows the move, whether the current
party contains a compatible Pokémon, or whether the player owns a compatible Pokémon.

The first implemented capabilities are:

```text
state_can_cut = state_has_hm01_cut AND state_has_cascade_badge
state_can_surf = state_has_hm03_surf AND state_has_soul_badge
```

This is an intentional tracker simplification. The vanilla field-use checks documented
in FRLG-L008 and FRLG-L018 remain accurate research, but do not define the tracker policy.
Other HM capabilities should follow this policy when their badge mappings are implemented.

---

## Open Decisions

### O001 — Final Type-Prefix Vocabulary

**Status:** Open

The project is moving towards descriptive type-prefixed IDs for heavily cross-referenced
objects, for example:

```text
zone_route_2_southwest
conn_route_2_southwest_southeast_tree
warp_route_2_gate_north_entrance
enc_route_1_grass
itemsrc_route_1_pokemart_employee
trainer_route_3_lass_janice
state_can_cut
```

The exact prefix spellings still need to be frozen.

Questions include whether prefixes such as `itemsrc_` are preferable to longer names such as
`item_source_`, and whether Pokémon and item entity IDs should also receive explicit type
prefixes.

---

### O002 — Final Warp Naming Grammar

**Status:** Open

Warp IDs need to remain understandable around structures with several entrances and exits,
such as the two gatehouses between Route 2 and Viridian Forest.

The current entrance/exit and compass-direction approach is workable but not yet formally
specified as a naming grammar.

---

### O003 — Remaining Pokémon Acquisition Object Types

**Status:** Open

Wild encounter tables are settled, but exact object types and array names remain open for:

- static Pokémon battles;
- NPC gifts;
- in-game Pokémon trades;
- Pokémon vendors;
- Game Corner prize Pokémon;
- fossil revival;
- roaming Pokémon;
- external connectivity.

These should be designed as each concrete mechanic is implemented rather than forced into
one generic source type.

---

### O004 — Item Acquisition Object Types

**Status:** Open

The project has not yet decided whether the broad `item_sources` concept remains one
coherent object type or should be split into homogeneous arrays such as pickups, gifts, and
vendors.

Relevant mechanics include:

- visible pickups;
- hidden items;
- regenerating items;
- shops and specialist vendors;
- Game Corner prizes;
- NPC rewards;
- held items received through trades;
- Pickup;
- Thief and Covet;
- external held-item trading;
- Mystery Gift.

---

### O005 — FireRed and LeafGreen Differences

**Status:** Open

The world topology is largely shared, but encounters and other content differ between
versions.

The project still needs a consistent representation for version-specific data.

---

### O006 — One-Way Warp and Drop Representation

**Status:** Open, but not blocking current work

Pokémon Mansion and similar mechanics include one-way discrete movement that fits the Warp
concept but not the normal bidirectional Portal pairing.

The common Portal schema will remain simple until a concrete vanilla representation is
needed.

---

### O007 — Physical File Organisation

**Status:** Open

The logical model is clearer than the final filesystem layout.

The project still needs to decide when data belongs in broad files such as
`connections.json` and `portals.json` versus more granular per-area files.

The decision should favour local discoverability without creating unnecessarily large
monolithic documents.

---

### O008 — Exact Version 1.0 Content Boundary

**Status:** Open

The project has not yet frozen whether the first stable release must include all Sevii
Islands and post-game content or whether some post-game coverage may land after the first
usable vanilla release.

This does not block the early-Kanto vertical slice.

---

## Deferred Decisions

### F001 — Dynamic Non-Local Movement

**Status:** Deferred beyond the initial world solver

Teleport, Fly, Dig, Escape Rope, blackout behaviour, and similar mechanics can create
movement that depends on history or dynamic destinations rather than static topology.

They are outside the v1.0 static reachability model unless a concrete requirement changes
that scope.

---

### F002 — Mod Overlay and Patch Semantics

**Status:** Deferred

The base schema is intended to be mod-friendly, but the project has not designed a general
system for adding, replacing, or deleting vanilla data through mod overlays.

Future work may define how a mod changes Connections, Zones, sources, and Portal mappings.

---

### F003 — Professor Oak Challenge Rules

**Status:** Deferred

Professor Oak Challenge is a future mode, not the purpose of the base tracker.

Completion models, checkpoints, Living Dex rules, trade policy, finite-resource feasibility,
and other challenge-specific decisions will be designed after vanilla FRLG logic is
reliable.

---

### F004 — Warp Randomiser UI and Tracking Workflow

**Status:** Deferred

The architectural direction is accepted: Warp Randomiser may replace the active vanilla
Portal mapping with manually tracked pairs.

The exact UI, mode state, discovery workflow, and patch API are deferred until the vanilla
Portal system is working.

---

### F005 — Emulator Autotracking

**Status:** Deferred

The initial tracker is manual.

Autotracking must not constrain the core data model prematurely.

---

### F006 — Finite Resource Feasibility

**Status:** Deferred beyond v1.0

A future challenge mode may optionally model money, Poké Balls, or other consumables when
resource exhaustion can make an otherwise accessible acquisition impossible.

---

## Superseded Decisions

### S001 — Destination `reqToEnter` Defines Reachability

**Status:** Superseded

The recovered model stored area-level `reqToEnter` rules containing `canAccess*` state.

It is replaced by Zone reachability derived from Connections and Portals.

---

### S002 — `borders` Arrays Define Topology

**Status:** Superseded

The recovered area-level `borders` arrays are replaced by first-class Connection objects
referenced by their endpoint Zones.

---

### S003 — World Requirements Use Recursive `AND` and `OR`

**Status:** Superseded for v1.0 world topology

The recovered prototype supported recursive boolean requirement expressions.

The v1.0 world schema instead uses a single state reference or `null` on each Connection.
Compound logic is expressed through derived state when required.

---

### S004 — Zone-Level Accessibility Requirements

**Status:** Superseded

Zones do not carry their own requirements in v1.0.

Requirements belong to the Connection that gates access to the Zone. Warps and normal
Portals remain unconditional once their containing Zone is reachable.
