# Phase 2 reachability snapshots

Phase 2 is complete under the agreed topology and progression-state model. The solver
has 23 hand-authored complete expected-Zone snapshots across 71 Zones in the ten areas
listed in `PROJECT.md`. The task is reachability from supplied progression facts;
acquisition, UI, evolution, and automatic game-state observation are separate work.

## Files and execution

- `tests/fixtures/phase2_expected.lua`: explicit area/container scope, disjoint Zone
  groups, player facts, starting Zones, and expected groups for every snapshot.
- `tests/phase2_snapshots_test.lua`: scope/inventory checks and full set comparisons.
- `tools/test.lua`: includes the snapshot suite alongside the existing Lua tests.

Run from the project root:

```text
lua tests/phase2_snapshots_test.lua
lua tools/test.lua
```

Expected sets are not recorded from `Reachability.solve`. They are manually specified
using named lists of Zone IDs. Grouping avoids repeating long identical lists; the
fixture contains no traversal, Warp lookup, or algorithm to discover expected Zones.
Every in-scope Zone not included in a snapshot's expected set must be unreachable.

## Coverage

The scope includes all authored buildings, routes, settlements, and instance subdivisions
for Pallet Town, Route 1, Viridian City, Route 2, Viridian Forest, Pewter City, Route 3,
Mt. Moon, Route 4, and Cerulean City. Gatehouses are included with Route 2.
Every expected container must exist, every declared in-scope Zone must have an explicit
expectation group, and every Zone must be both reachable in at least one snapshot and
unreachable in at least one other snapshot.

| Representative scenario | Expected in-scope reachable Zones |
| --- | ---: |
| Initial state from the player's house | 11 |
| Parcel delivered, before Brock | 27 |
| Parcel delivered and Brock defeated | 52 |
| Above plus S.S. Ticket event | 56 |
| Usable Cut, without parcel delivery or Brock | 35 |
| Usable Surf, without parcel delivery | 14 |
| All progression gates and capabilities enabled | 71 |
| Start in Cerulean, no flags | 12 |
| Start in Pewter museum backyard, no flags | 18 |
| Start in Route 2's northeast corridor, no flags | 5 |

The 23 scenarios also cover distant event flags without physical access, Cut/Surf
alternatives, Cerulean NPC restrictions, guard clearance, badges without HMs, HMs
without badges, the wrong HM/badge combination, removal of facts, and starting on
the far side of Route 4's ledges. Surf provides a legitimate alternative route to
upper Route 4, contrasting with attempting to walk backward over the ledges.

## Comparison and preservation

The runner evaluates player facts with `State.evaluate`, calls the production solver,
and compares every Zone in scope. Failures list missing and unexpected reachable Zones.
After all calculations, it checks every earlier result again to detect mutations.
The comparator itself is checked with deliberately damaged local results: one missing
Zone and one unexpected extra Zone. Neither mutation changes production data.

The actual world graph is used. Already-authored neighbouring areas can participate in
travel, but their Zones are outside this Phase 2 result comparison. We do not remove
valid paths or require outside Zones to be unreachable. No additional neighbouring
areas or cave interiors were authored for this test task.

## Maintaining expectations

When an in-scope Zone changes, review the fixture against the intended topology and
progression rules. Do not automatically replace expectations with solver output. New
Zones in scoped containers fail the inventory check until explicitly assigned. New
containers must be deliberately classified in the area manifest.

These are complete Zone sets for representative states, not an enumeration of every
possible player-state table. Existing focused traversal/state tests complement them.
The six unfinished destination warnings are outside the slice boundary; they do not
prevent its reachable Zones from being calculated. The cave guard remains an explicit
input, with post-game derivation deferred as agreed.
