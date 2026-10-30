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

**Status:** Superseded in authored representation by D044; normal links remain bidirectional

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

**Status:** Derivation principle retained; sibling index superseded by D044's destination index

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

Vanilla uses the canonical typed Warp links by default (D044).

A later Warp Randomiser mode may replace the active mapping with manually tracked or
otherwise supplied links without changing the vanilla dataset.

Reachability is recalculated when the active mapping changes.

---

### D020 — Not Every Warp Must Belong to a Normal Portal

**Status:** Accepted

Normal links cover bidirectional Warp pairs. D044 also represents drops in the same
collection using a directional type. A landing-only or unpaired Warp need not have an
outgoing link; declaring a Warp in a Zone does not itself make it a traversable departure.

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

**Status:** Superseded in representation by D049 (30 October 2026); mutual exclusivity retained

The initial starter choice is represented as dedicated mutually exclusive player state
rather than a generic Pokémon-choice source object.

Conceptually:

```text
starter_choice = bulbasaur | charmander | squirtle
```

A reusable choice abstraction may be introduced later only if concrete game or mod data
justifies it.

D049 accepts that abstraction for the concrete lab-starter and Mt. Moon fossil choices.
Their selected source is authoritative; starter-dependent state is derived from its
original slot, separately from the reward species.

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

### D032 — Adopt Type Prefixes Except Item-Source Naming

**Status:** Accepted (29 October 2026)

Use `zone_`, `conn_`, `warp_`, `enc_`, `trainer_`, and `state_` for their existing
object types. Use `species_` for Pokémon species definitions and `item_` for item
definitions. Map containers retain descriptive unprefixed IDs such as `pallet_town`.

Item-source prefixes are deferred to O004 alongside item acquisition object types.
Keep existing `item_pickup_` and `item_gift_` references in the meantime; do not migrate
them to `item_source_` or `itemsrc_` as part of this decision.

---

### D033 — Warp IDs Describe Physical Endpoints in Full

**Status:** Accepted (29 October 2026)

Prefer descriptive Warp IDs over brevity. Include enough physical context to identify
the endpoint clearly: landmark, floor, local section, doorway side, movement mechanism,
and endpoint role as applicable. There is no need to shorten a useful identifier simply
because it is long.

Examples:

```text
warp_viridian_forest_south_gate_north_entrance
warp_mt_moon_b1f_east_corner_ladder_up
warp_cerulean_city_burgled_house_south_entrance
```

These are descriptive examples, not a fixed-length naming template requiring every
qualifier on every Warp. Use the physical context needed by the location. Zone declarations
and Portal pairs remain authoritative for ownership and destination; IDs do not encode
the currently paired destination.

---

### D034 — Name Pokémon Acquisition Sources Independently of Their Rewards

**Status:** Accepted (29 October 2026)

Apply D026 to Pokémon acquisition sources. Identify the location, NPC, or acquisition
mechanism rather than the current species, received nickname, or other changeable contents.
Use additional physical qualifiers when needed to distinguish sources at the same location.

Accepted examples and prefixes:

```text
static_encounter_seafoam_islands_b4f
pokemon_gift_silph_co_7f_employee
pokemon_trade_route_2_traders_house
pokemon_vendor_route_4_pokecenter_salesman
fossil_revival_helix_fossil
```

The fossil name identifies a revival input option, not its output species. Keep the
yielded species, requested trade species, nickname, price, and other contents in data.
The source's Zone association records its location even when its ID names a mechanism.

Research evidence: `pret/pokefirered` uses both location/NPC and species-based script
labels, while Universal Pokémon Randomizer ZX can replace the species associated with
these sources and modify in-game trade contents. The tracker therefore keeps stable source
IDs rather than copying all vanilla script-label conventions.

- [Vanilla trade data](https://github.com/pret/pokefirered/blob/master/src/data/ingame_trades.h)
- [ZX FRLG static, gift, vendor, and fossil slots](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/master/src/com/dabomstew/pkrandom/config/gen3_offsets.ini#L459-L484)
- [ZX trade options](https://github.com/Ajarmar/universal-pokemon-randomizer-zx/blob/master/src/com/dabomstew/pkrandom/newgui/Bundle.properties#L117-L131)

This settles the listed source-ID conventions. Exact schemas, Zone reference-array
names, Game Corner grouping, roaming Pokémon, and external connectivity remain under O003.
No existing source references are renamed as part of this documentation decision.

---

### D035 — Pokémon Vendors Contain Multiple Offers

**Status:** Accepted (29 October 2026)

One Pokémon vendor object may contain several offers. Each offer records its species,
price, and currency. A Zone references the vendor object once rather than referencing
a separate acquisition-source object for each offer.

Use the same vendor type for the single Route 4 salesman purchase and the Game Corner's
multiple Pokémon prize offers. Exact offer fields and version-specific representation
will be settled when implemented.

---

### D036 — Pokémon Acquisition References Are Optional Zone Arrays

**Status:** Accepted (29 October 2026)

Replace the draft mixed `pokemon_sources` array with direct homogeneous arrays on a Zone:

```text
static_encounters
pokemon_gifts
pokemon_trades
pokemon_vendors
fossil_revivals
```

These arrays are optional in authored JSON. Omission means no references of that type,
equivalent to an empty array. Authors need not add empty categories to every Zone.
When present, each property must contain an array of IDs of its corresponding object type.

Acquisition readers must handle absent arrays as empty when these mechanics are
implemented. Keep the existing topology-array requirements for `connections` and `warps`;
this decision does not change those or the current `encounter_sources` convention.

No nesting under a `pokemon_sources` object is required. Detailed acquisition schemas,
runtime readers, validation, and migration of draft references remain implementation work.

---

### D037 — Version 1.0 Assumes Single-Player Acquisition

**Status:** Accepted (29 October 2026)

Version 1.0 evaluates acquisition within a single FRLG game. Do not assume access to
external player trades, another game's Pokémon or held items, or external connectivity
rewards. External trading must not make the entire Pokédex available early.

NPC in-game trades remain ordinary single-player acquisition sources under D034.
Evolution through trading with another player is not assumed possible in v1.0.
External acquisition may be designed as a later explicit mode or policy.

---

### D038 — Roamers Use Release Availability, With Implementation Deferred

**Status:** Accepted direction; detailed rules and implementation deferred

For an availability tracker, the eligible roaming Pokémon may become available when
its verified release/progression conditions are satisfied. Tracking its current map or
requiring a current sighting is not part of this intended availability model.

Before implementation, verify the actual release predicate, species-selection rules,
and any relevant encounter or removal conditions. Do not assume that one generic flag
releases every roaming species or attach the roamer to a single fixed Zone.

The exact state IDs, schema, and evaluation remain deferred until roaming acquisition
is implemented. This is distinct from external connectivity, which D037 excludes from v1.0.

---

### D039 — Item Pickups, Gifts, and Multi-Offer Vendors

**Status:** Accepted (29 October 2026)

Retain `item_pickup_` and `item_gift_` for item acquisition sources and use `item_vendor_`
for shops and item prize exchanges. Item definitions continue to use `item_` (D032).
Do not replace these source prefixes with a generic `item_source_` or `itemsrc_` prefix.

One item vendor object may contain several offers, following the Pokémon vendor model
in D035. Offers record their item, price, and currency. A single vendor can therefore
represent either one offer or a catalogue.

Visible and hidden items use the pickup type, with visibility represented as a property.
Regeneration or repeatability is a property of the pickup rather than requiring another
source type. Detailed fields and renewal conditions will be defined when implemented.

This settles the initial pickup/gift/vendor grouping and source prefixes under O004.
Zone reference-array names and other acquisition mechanics remain for discussion.

---

### D040 — Item Acquisition References Are Optional Zone Arrays

**Status:** Accepted (29 October 2026)

Replace the draft mixed `item_sources` array with direct homogeneous arrays on a Zone:

```text
item_pickups
item_gifts
item_vendors
```

These properties follow the optional-array convention in D036. Omitted and empty arrays
both mean no sources of that type. When present, an array contains IDs of its corresponding
source type. Unused categories need not appear on every Zone.

Detailed acquisition schemas, runtime readers, validation, and migration of existing
draft references remain implementation work. Topology-array requirements are unchanged.

---

### D041 — Held Items Share Their Pokémon Acquisition Data; Defer Pickup

**Status:** Accepted (29 October 2026)

NPC trade held items belong to the corresponding Pokémon trade data. Wild Pokémon held
items belong with the relevant encounter data. Do not duplicate those held-item facts
as independent Zone pickup or gift sources.

Thief and Covet are methods of obtaining a Pokémon's held item and must use the same
wild held-item data. Their detailed eligibility and availability rules will be verified
when implemented, rather than inventing a separate source inventory for each move.

Pickup is deferred beyond v1.0 (F007). External item trading and Mystery Gift are
excluded from v1.0 under the single-player scope in D037.

Together, D039–D041 settle O004's current object grouping, source prefixes, Zone
reference arrays, and remaining acquisition-mechanic scope. Detailed schemas remain
implementation work.

---

### D042 — Version Applicability Uses Optional Entry Filters

**Status:** Accepted (29 October 2026), aligned with the supplied earlier conversation

Use one shared dataset and a selected game version (`firered` or `leafgreen`). Entries
may carry a `versions` array listing their applicable games. Omit it when the entry applies
to both. Write identical entries once; split an entry only when its actual data differs.

Apply this convention to encounter records, trade exchanges, vendor offers, and other
acquisition entries at the boundary where content differs. Keep source IDs stable.
Do not duplicate entire shared sources or use a general `by_version` override/merge system.

Readers filter entries for the selected game. Validation requires non-empty recognized
version lists when supplied. Validate the filtered result according to its collection:
wild rates total 100% per game; a fixed trade has one applicable exchange per applicable
game; a vendor may have multiple applicable offers. Encounter-specific uniqueness rules
must not be applied indiscriminately to vendor offers or other collections.

Exact source payload field names, including the illustrative trade `exchanges` collection,
remain to be finalized with each concrete mechanic. The applicability convention is settled.

---

### D043 — Wild Encounters Use Species-Aggregated Table Entries

**Status:** Accepted; recovered from the supplied Project Plan Documentation extract

For v1.0, an encounter source has `id`, `method`, `requires`, and `encounters`.
Each encounter record has `pokemon`, `levels`, numeric `rate`, and optional `versions`.
The `pokemon` reference uses the accepted `species_` ID prefix (D032), replacing the
older extract's `pokemon_` prefix without changing the field's meaning.

`levels` is a non-empty array of the exact possible positive integer levels, including
non-contiguous possibilities. It does not imply equal probabilities. `rate` is the total
percentage for that species within the applicable version's source, greater than zero
and no greater than 100. Do not use min/max ranges or per-level weights in v1.0.

After D042 filtering, each supported version's encounter rates must total 100%, and
each species has at most one applicable aggregated record in a source. Different
records for the same species are valid when their version applicability does not overlap.

The supplied Route 3 and Route 4 screenshots illustrate these rules. Their data is
reference material for later authoring, not encounter data already loaded by the engine.
Detailed encounter validation and runtime acquisition remain implementation work.

---

### D044 — Standardize Warp Links With Type-Based Direction

**Status:** Accepted (29 October 2026); implemented

Use one collection of typed Warp links, following Connections' type-based direction
convention. Each object has `type` and a two-element `warps` array:

```json
{"type": "normal", "warps": ["warp_a", "warp_b"]}
```

```json
{"type": "drop", "warps": ["warp_departure", "warp_landing"]}
```

Normal links allow both directions and array order has no traversal meaning. Drop links
allow only first endpoint to second endpoint. Do not introduce a separate drop collection.
Warp IDs are still declared by Zones, with no standalone objects repeating those IDs.

Derive `warp_to_destination` rather than `warp_to_sibling`: a normal link produces two
entries and a drop produces one. Multiple incoming links may share a destination, while
each departure has at most one active outgoing destination. A destination's occurrence
in a drop does not create a reverse departure. Validate outgoing mappings, rather than
requiring every endpoint to occur in only one link.

The distinction follows the map records and activation code in `pret/pokefirered`:
destination records and usable departure triggers are separate facts. Verify Mansion's
actual tile behaviours before authoring its drop endpoints; reciprocal map references
alone do not establish a traversable return route.

- [Mansion 3F Warp records](https://github.com/pret/pokefirered/blob/master/data/maps/PokemonMansion_3F/map.json#L74-L130)
- [Mansion 1F arrival records](https://github.com/pret/pokefirered/blob/master/data/maps/PokemonMansion_1F/map.json#L138-L158)
- [Warp activation checks](https://github.com/pret/pokefirered/blob/master/src/field_control_avatar.c#L806-L869)

This revises D017's bare-pair representation and D018's sibling lookup. The existing
53 Portal pairs have been migrated to normal links, together with the source builder,
generator, validator, indexes, solver, and tests. Typed links remain in `portals.json`.
Drop mechanics are tested with fixtures; Mansion-specific records await world authoring.

---

### D045 — Build Runtime Collections From Small Authored Source Files

**Status:** Accepted (29 October 2026); initial world source/build workflow implemented

Adopt the authored-source/generated-aggregate pattern inspected in the supplied
MobiusFFTool project. Retain category-based runtime collections while partitioning
large authored categories into smaller files grouped by area or natural entity.

For example:

```text
data/source/world/containers/buildings/pallet_town.json
data/source/world/containers/buildings/viridian_city.json
    -> data/world/containers/buildings.json

data/source/world/connections/pallet_town.json
data/source/world/connections/viridian_city.json
    -> data/world/connections.json
```

Use the same approach for other large categories, including typed Warp links. Authored
files contain arrays of their category's records, combined into the runtime category
array. Each object is authored once, including cross-area Connections and Warp links.
File grouping does not alter object identity, graph relationships, or reference ownership.

The source files are authoritative. Generated aggregates are never edited manually.
Use a shared configurable builder with deterministic collection ordering, duplicate-ID
and reference validation, and a non-writing check mode that fails on stale outputs.
Preserve meaningful array order, especially directional endpoints and versioned content.

Implement using existing Python tooling. The Lua runtime continues loading a small
set of category files and building its indexes; generated compact indexes are not needed
at this stage. Small reference categories may remain single authored files until splitting
is useful. Detailed partitions and cross-area authoring conventions will be documented
with migration.

The initial world categories are implemented through `tools/build_world.py`: small source
arrays, generated aggregates, shared validation, stale-output checking, and documented
packaging. This migration retains the existing Portal and content schemas; their separate
accepted changes remain pending. Future acquisition categories can extend this workflow.

---

### D046 — Version 1.0 Is a Publication-Ready Single-Player FRLG Tracker

**Status:** Accepted (29 October 2026)

Version 1.0 covers the complete single-player FireRed and LeafGreen world, including
mainland Kanto, the Sevii Islands, and post-game content, subject to the agreed exclusions.

Version 1.0 means publication-ready: a reliable, usable, documented tracker that includes
most functionality needed by the majority of players. A working engine or partial-world
prototype alone does not meet that release standard. Earlier usable development milestones
may be released without being called v1.0.

The existing exclusions and simplifications remain in force, including single-player
acquisition (no external trading or Mystery Gift), Pickup deferred beyond v1.0, HM usability
based on acquired HM and badge, and later challenge/randomiser/autotracking enhancements.
Full-world scope does not imply that every Pokémon is obtainable in either selected game.

Deferring the detailed design of an in-scope mechanic until implementation does not remove
it from the v1.0 content boundary. Roaming acquisition details remain deferred under D038,
but relevant single-player roaming availability belongs to complete-world coverage.

---

### D047 — NPC Trades Use Version-Filtered Exchanges

**Status:** Accepted (30 October 2026); nine-source milestone implemented

An NPC trade source contains `id`, `requires`, and `exchanges`. Each exchange contains
`requested_pokemon`, received `pokemon`, `level_rule`, `held_item`, `repeatable`, and
optional `versions`. Species references use `species_*`; `held_item` is an `item_*`
reference or `null`. `level_rule: "match_requested_pokemon"` represents the received
Pokémon matching the submitted Pokémon's level without inventing a fixed level list.

After version filtering, a fixed trade has exactly one exchange per applicable game.
Availability requires the reachable trader, its source requirement, and availability
of the requested species. The tracker does not simulate consuming a Pokémon from the
player's collection. Held items remain part of the received Pokémon's trade data (D041).

The accepted Route 2 example is `pokemon_trade_route_2_traders_house`: Abra for Mr. Mime,
matching the submitted level, no held item, and not repeatable. See `ACQUISITIONS.md`
for the approved shapes and implementation boundaries.

---

### D048 — Pokémon and Item Vendors Share Offer Fields

**Status:** Accepted (30 October 2026); nine-source milestone implemented

Both vendor source types contain `id`, `requires`, and `offers`. Every offer has numeric
`price`, `currency` (`money` or `coins`), `repeatable`, and optional `versions` (D042).
Pokémon offers contain `pokemon` and exact possible `levels`; item offers contain `item`
and `quantity`. Prices are canonical metadata, not balance checks for v1.0 availability.
`repeatable` records transaction renewal and does not remove previously obtained species
from availability. Source requirements are additional progression gates; Zone references
supply location access. No encounter-rate or per-species uniqueness rule applies to vendors.

Route 4's salesman is one Pokémon vendor with one non-repeatable level-5 Magikarp offer
for 500 money. Game Corner prizes use one object per physical window: left and right
item vendors and a middle Pokémon vendor. Each window requires Coin Case acquisition
(`state_has_coin_case`), and offers are repeatable. Version differences belong on offers,
including differing levels and prices for the same species.

Use the stable IDs, complete example catalogues, and optional Zone reference arrays
recorded in `ACQUISITIONS.md`. Author area arrays and build separate trade, Pokémon-vendor,
and item-vendor collections using D045's workflow. Runtime code, validation, player-state
support, and draft-reference migration are implemented for the nine-source milestone.
Game Corner catalogues remain unplaced until Celadon world authoring. Bike Voucher exchange
and gift availability were explicitly excluded. The Powder Jar man and Running Shoes
aide have Zone references only, like existing draft gifts; rewards remain unspecified
and gift references stay unevaluated for now.

---

### D049 — Individual Sources Share Explicit Exclusive Choice Groups

**Status:** Accepted (30 October 2026); manual engine milestone implemented

Represent each physical starter ball and fossil pickup as an independent, stable source.
Group alternatives in a separate object containing `id`, `option_type`, `options` (source
IDs), `max_selections: 1`, and optional readiness `requires`. The lab uses `pokemon_gift` options; Mt. Moon uses
`item_pickup` options. Source identity follows the original selectable slot, not a reward
that a randomiser might replace. Preserve existing homogeneous Zone source arrays.

Use `player.choices[choice_id]` with `status` equal to `unknown`, `unselected`, or
`selected`. Only selected state carries a `source` ID, which must belong to the group.
Manual controls and future autotracking populate this same authoritative representation.
Derive starter-dependent facts from the selected original slot and received Pokémon from
its reward data. Do not maintain independently editable starter flags.

Show unresolved eligible options as alternatives, without adding all rewards to the
simultaneously obtainable set. Preserve the selected acquisition after selection; exclude
unchosen options through this choice mechanism. Other independent sources remain valid.

Keep memory addresses, ROM mappings, decoding, and connection handling in a separate
adapter. Gate starter-variable decoding on confirmed starter acquisition. Use persistent
fossil acquisition flags rather than current inventory or object visibility. Rebuild
state from coherent snapshots after save changes/rewinds instead of accumulating stale
choices. Unknown observations must not silently become a concrete selection.

Implementation reuses existing west/east fossil references in place of the draft's
numbered placeholders. Only known-unselected ready/reachable options are alternatives;
confirmed selected gifts remain acquired after leaving. See `CHOICES.md` for the API,
original-object mapping, examples, and evidence. Fossil reward payloads, item
definitions, revival availability, and Professor Oak evolution logic remain deferred;
this decision records source references and choice relationships without implementing
those domains. General gift payloads outside the starter example still need definition.

---

## Open Decisions

### O001 — Final Type-Prefix Vocabulary

**Status:** Resolved by D032 and D039

The non-item-source prefix vocabulary is accepted as D032. Item-source naming was deferred
to O004 and is now accepted as D039.

---

### O002 — Final Warp Naming Grammar

**Status:** Resolved by D033

Descriptive physical-endpoint names are accepted. Include all useful location and
transition qualifiers, favoring clarity over short identifiers. Existing names follow
this approach; no renaming is required by this decision.

---

### O003 — Remaining Pokémon Acquisition Object Types

**Status:** Resolved for current design by D034–D038; detailed schemas deferred to implementation

D034 settles prefixes and stable-source naming for static encounters, gifts, trades,
vendors, and fossil revival. D035 settles multi-offer vendors and Game Corner grouping.
D036 settles optional direct Zone reference arrays. D037 excludes external acquisition
from v1.0 while retaining NPC trades. D038 records release-based roaming availability
and defers its detailed rules and implementation.

Wild encounter tables are settled. Detailed schemas for these accepted categories will
be designed when each mechanic is implemented:

- static Pokémon battles;
- NPC gifts;
- in-game Pokémon trades;
- Pokémon vendors;
- Game Corner prize Pokémon;
- fossil revival;

Roaming details will be researched when implemented. External connectivity is outside
v1.0 under D037.

These should be designed as each concrete mechanic is implemented rather than forced into
one generic source type.

---

### O004 — Item Acquisition Object Types

**Status:** Resolved for current design by D039–D041; detailed schemas deferred to implementation

Item-source prefix naming deferred from O001 is resolved by D039: use `item_pickup_`,
`item_gift_`, and `item_vendor_`. Item vendors support multiple offers. Pickup visibility
and regeneration are properties rather than separate source types.

D040 settles optional direct `item_pickups`, `item_gifts`, and `item_vendors` Zone arrays.
D041 attaches held items to their Pokémon acquisition data, links Thief/Covet to wild
held items, defers Pickup, and confirms the external acquisition exclusions.

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

**Status:** Resolved by D042; encounter representation recovered as D043

The world topology is largely shared, but encounters and other content differ between
versions.

Use optional per-entry `versions` filters with a single shared dataset. Shared entries
are authored once; differing entries are split by applicability. See D042–D043.

---

### O006 — One-Way Warp and Drop Representation

**Status:** Resolved by D044; typed-link implementation complete

Pokémon Mansion and similar mechanics include one-way discrete movement that fits the Warp
concept but not the normal bidirectional Portal pairing.

Use one typed-link collection with `normal` and `drop` types, mirroring Connection
direction semantics. D044 records the schema and required migration.

---

### O007 — Physical File Organisation

**Status:** Resolved by D045; initial world workflow implemented

Author small category-based source files grouped by area or natural entity, and build
the broad runtime category collections. D045 records the accepted source/aggregate split
and stale-output checks, based on the MobiusFFTool workflow.

---

### O008 — Exact Version 1.0 Content Boundary

**Status:** Resolved by D046

Version 1.0 covers the complete single-player FRLG world, including the Sevii Islands
and post-game, subject to agreed exclusions. It must be publication-ready and meet most
needs of the majority of players. Earlier development milestones may have smaller scope.

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

### F007 — Pickup Ability Item Acquisition

**Status:** Deferred beyond v1.0

Do not implement Pickup-derived item availability for v1.0. Research the FRLG-specific
item selection and eligibility rules when this feature is resumed; do not assume that
another game's level-based Pickup behaviour applies.

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
