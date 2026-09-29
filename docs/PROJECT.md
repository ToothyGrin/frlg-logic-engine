# FRLG Tracker — Project Plan

## Purpose

Build a logic-aware tracker for *Pokémon FireRed* and *Pokémon LeafGreen* using EmoTracker
as the initial user interface.

The project is a general FRLG tracker first. Its core engine should model the vanilla game
world, progression state, reachability, and acquisition opportunities without assuming a
particular challenge format.

Specialised modes may be added later. Planned examples include:

- Professor Oak Challenge support;
- Warp Randomiser support;
- emulator autotracking.

The project is inspired by logic-aware randomiser trackers, particularly trackers used for
*The Legend of Zelda: A Link to the Past*. The long-term aim is similar: represent the game
world as data, derive what is logically reachable, and let different modes interpret or
modify that world without rewriting the core engine.

## Project Goals

The tracker should eventually:

- model the traversable world of FireRed and LeafGreen;
- represent Routes, Settlements, Instances, Zones, Connections, Warps, and Portals;
- understand progression state such as badges, HMs, key items, and story events;
- calculate which Zones are currently reachable;
- associate encounters, items, trainers, and other game content with reachable Zones;
- model Pokémon acquisition and evolution methods;
- expose the resulting state through EmoTracker;
- support optional modes without contaminating the canonical vanilla FRLG data;
- remain maintainable enough that future fixes and mods do not require reconstructing the
  entire world model from unrelated files.

The underlying game data and core logic should remain sufficiently independent from
EmoTracker that they can be validated and tested outside the UI.

## Version 1.0 Scope

Version 1.0 focuses on vanilla FRLG functionality.

It should provide a reliable base-game world and logic engine before specialised modes are
implemented.

Version 1.0 does not require:

- Professor Oak Challenge rules;
- Warp Randomiser tracking;
- emulator autotracking or memory inspection;
- exact currency or consumable-resource accounting;
- dynamic movement mechanics such as Teleport, Fly, Dig, or Escape Rope;
- a general mod-overlay or patch system;
- sophisticated animation or presentation;
- online services.

Canonical data such as prices may still be stored even when the corresponding resource
quantity is not tracked.

## Current State

The recovered March 2026 project contained an early data-driven world prototype and a Lua
sandbox for experimenting with reachability requirements.

The recovered design used:

- area-level `reqToEnter` rules;
- `borders` arrays;
- `canAccess*` state flags;
- recursive `AND` and `OR` requirement expressions.

That model has now been superseded by the Zone, Connection, Warp, and Portal model
documented in `DESIGN.md` and `DECISIONS.md`.

Current working drafts now include separate JSON data for concepts such as:

- Routes;
- Settlements;
- Buildings and other Instances;
- Connections.

The project remains pre-production. The canonical schema, validator, reachability solver,
complete game data, and EmoTracker UI still need to be implemented.

## Development Principles

### 1. Vanilla FRLG Comes First

The base data describes vanilla FireRed and LeafGreen.

Challenge rules, randomised Portal mappings, and other specialised behaviour belong to modes
layered over the base game.

### 2. Game Data Is Separate From Logic

Facts about FRLG belong in data files wherever practical.

Examples include:

- map containers and Zones;
- Connections;
- Warp declarations and Portal pairings;
- encounters;
- Pokémon species and evolution data;
- items and acquisition sources;
- trainers;
- badges and story events.

Lua code should interpret those facts rather than contain large quantities of
location-specific game data.

### 3. Canonical Behaviour, Locally Discoverable Relationships

Authoritative behaviour should be defined once, but related objects should still be easy to
discover from the object being edited.

For example, a Zone declares the Connection IDs that touch it, while the Connection object
contains the authoritative endpoints, type, and requirement.

This deliberate referential redundancy favours authoring and maintenance over maximal data
normalisation. Automated validation protects the duplicated references.

### 4. Reference Arrays Are Homogeneous

An array should contain references to one kind of domain object.

For example, `encounter_sources` contains encounter-table IDs only. NPC trades, Pokémon
vendors, gifts, static encounters, and other acquisition mechanics receive their own object
types and arrays if they are needed.

### 5. EmoTracker Is an Adapter and Presentation Layer

The core reachability and availability model should not depend unnecessarily on UI layout or
EmoTracker-specific state.

EmoTracker should display and manipulate the results of the engine rather than define the
domain model.

### 6. Data Must Be Validated

As the amount of FRLG data grows, manual inspection will become unreliable.

Validation should begin early and eventually detect at least:

- duplicate identifiers;
- unresolved Zone, Connection, Warp, state, and source references;
- Connection references that disagree with their endpoint Zones;
- invalid directional Connection definitions;
- invalid Portal pairs;
- Warps declared by more than one Zone;
- references to the wrong source-object type;
- malformed or missing required properties;
- invalid Pokémon, item, trainer, or evolution references.

### 7. Current Status Must Remain Documented

`docs/STATUS.md` should be maintained once active development resumes.

It should record:

- what currently works;
- what was being worked on;
- known broken behaviour;
- unresolved design questions relevant to the current task;
- the next intended task.

## Development Roadmap

### Phase 0 — Project Recovery and Design

Goal: establish a trustworthy baseline and replace the recovered prototype architecture with
a documented world model.

Tasks:

- preserve the recovered project and Git history;
- document the recovered intent;
- define Routes, Settlements, Instances, and Zones;
- define Connections, Warps, and Portals;
- define the initial state model;
- document accepted decisions and deferred questions;
- update the early-game JSON drafts to the new schema.

Exit condition:

The core world-topology design is documented well enough that implementation can proceed
without rediscovering architectural intent.

### Phase 1 — Schema and Validation Foundation

Goal: make the data model mechanically trustworthy before entering large amounts of game
data.

Tasks:

- finalise the near-term ID naming conventions;
- define the canonical JSON shapes used by the first vertical slice;
- implement reference indexing;
- implement validation for Zones, Connections, Warps, Portals, and state references;
- validate the Pallet Town through Cerulean City draft data;
- add tests for intentionally invalid data.

Exit condition:

The vertical-slice data loads successfully, and common authoring mistakes fail with clear
validation errors.

### Phase 2 — World Reachability Vertical Slice

Goal: prove the world solver on early Kanto.

Initial scope:

- Pallet Town;
- Route 1;
- Viridian City;
- Route 2;
- Viridian Forest;
- Pewter City;
- Route 3;
- Mt. Moon;
- Route 4;
- Cerulean City.

Tasks:

- implement state lookup and derived capabilities;
- implement Connection traversal;
- implement directional Connection types such as ledges;
- implement vanilla Portal lookup;
- implement queue-based reachability propagation;
- recalculate reachability from authoritative state when relevant state changes;
- add progression snapshots and reachability tests.

Exit condition:

Given a progression-state object, the engine correctly calculates every reachable Zone in
the vertical slice.

### Phase 3 — Vanilla Acquisition Vertical Slice

Goal: attach useful FRLG content to reachable Zones without introducing challenge-mode
rules.

Tasks:

- define Pokémon species data;
- define wild encounter-table data;
- implement `encounter_sources`;
- define additional Pokémon acquisition object types as concrete mechanics require them;
- define item acquisition object types as concrete mechanics require them;
- model evolution relationships;
- retain prices and other canonical facts without tracking renewable resource balances;
- calculate logically available Pokémon and items for the vertical slice.

Exit condition:

The engine can answer which relevant Pokémon and items are logically available from the
currently reachable vanilla world.

### Phase 4 — Expand the Vanilla World

Goal: expand the proven topology and acquisition model across FRLG without redesigning the
architecture for every new area.

Tasks include:

- complete mainland Kanto topology;
- add remaining Settlements, Routes, Buildings, caves, forests, ships, and dungeons;
- add vanilla Portal mappings;
- add story progression state;
- add encounters, trainers, items, gifts, trades, vendors, static encounters, and other
  acquisition mechanics as their schemas are settled;
- add FireRed and LeafGreen differences;
- add Sevii Islands and post-game content according to the eventual v1.0 completion
  boundary.

Exit condition:

The chosen v1.0 vanilla FRLG scope is represented and validated by the core engine.

### Phase 5 — Minimal EmoTracker Integration

Goal: expose the working vanilla engine through EmoTracker.

Tasks:

- create valid package metadata;
- create tracker controls for relevant player state;
- create a minimal map and layout;
- integrate the Lua world engine;
- display Zone and content accessibility;
- ensure the tracker can be used manually without autotracking.

Exit condition:

A user can track a vanilla FRLG playthrough through EmoTracker using the core engine.

### Phase 6 — Vanilla FRLG 1.0

Goal: complete, test, document, and polish the first stable vanilla tracker.

Potential work includes:

- complete UI coverage;
- FRLG map artwork;
- Pokémon sprites;
- accessibility indicators;
- filters and counters;
- version selection;
- useful tooltips;
- regression tests;
- documentation for adding and fixing data.

### Later Modes and Enhancements

After the vanilla tracker is reliable, later work may include:

- Professor Oak Challenge mode;
- Warp Randomiser mode with manually tracked Portal pairings;
- emulator autotracking;
- dynamic movement mechanics such as Teleport and Fly;
- optional finite-resource modelling for challenge modes;
- mod overlays and patch systems;
- import and export utilities;
- alternative front ends.

## Immediate Next Milestone

Do not attempt to complete Kanto yet.

The next milestone is:

> **Validate and solve the early-Kanto world graph using the new Zone, Connection, Warp, and
> Portal model.**

The practical next steps are:

1. settle only the remaining naming details needed by the schema;
2. update the Pallet Town through Cerulean City data to the new conventions;
3. implement validation and runtime indexes;
4. implement the reachability solver;
5. prove the model with tests before expanding the dataset.
