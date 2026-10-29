# Accepted NPC trade and vendor shapes

Approved 30 October 2026 as D047–D048. The nine-source trade/vendor milestone is
implemented: two trades, two Pokémon vendors, and five item vendors. Examples below
document the payloads used by the runtime collections.

## NPC trades

```json
{
  "id": "pokemon_trade_route_2_traders_house",
  "requires": null,
  "exchanges": [
    {
      "requested_pokemon": "species_abra",
      "pokemon": "species_mr_mime",
      "level_rule": "match_requested_pokemon",
      "held_item": null,
      "repeatable": false
    }
  ]
}
```

`pokemon` is the received species. `held_item` is its held item (`item_*` or `null`).
`level_rule` expresses a variable level; it does not enumerate possible submitted levels.
Optional exchange `versions` follows D042: omitted means both games; supplied lists
must be non-empty and recognized. Each applicable game resolves to exactly one exchange.

Availability requires access to the trader, its `requires` state when present, and
availability of `requested_pokemon`. Pokémon are not consumed from a simulated collection.
Dependent acquisition chains must be evaluated without allowing circular trades to
create an initial obtainable species. The runtime starts with wild/vendor species and
repeats eligible trades until no further species are added.

The Route 2 Zone references the source through:

```json
"pokemon_trades": ["pokemon_trade_route_2_traders_house"]
```

The [vanilla trade data](https://github.com/pret/pokefirered/blob/master/src/data/ingame_trades.h)
confirms the Abra/Mr. Mime exchange and no held item. Other trades can carry items in
this same field; those facts must not be duplicated as independent pickup sources.

## Pokémon vendors

```json
{
  "id": "pokemon_vendor_route_4_pokecenter_salesman",
  "requires": null,
  "offers": [
    {
      "pokemon": "species_magikarp",
      "levels": [5],
      "price": 500,
      "currency": "money",
      "repeatable": false
    }
  ]
}
```

The [salesman's script](https://github.com/pret/pokefirered/blob/master/data/maps/Route4_PokemonCenter_1F/scripts.inc)
confirms the price, level, and one-time purchase. His Zone uses:

```json
"pokemon_vendors": ["pokemon_vendor_route_4_pokecenter_salesman"]
```

## Item vendors

```json
{
  "id": "item_vendor_celadon_game_corner_prize_room_left_window",
  "requires": "state_has_coin_case",
  "offers": [
    {"item": "item_smoke_ball", "quantity": 1, "price": 800, "currency": "coins", "repeatable": true},
    {"item": "item_miracle_seed", "quantity": 1, "price": 1000, "currency": "coins", "repeatable": true},
    {"item": "item_charcoal", "quantity": 1, "price": 1000, "currency": "coins", "repeatable": true},
    {"item": "item_mystic_water", "quantity": 1, "price": 1000, "currency": "coins", "repeatable": true},
    {"item": "item_yellow_flute", "quantity": 1, "price": 1600, "currency": "coins", "repeatable": true}
  ]
}
```

Both vendor types use `offers`, `price`, `currency`, `repeatable`, and optional `versions`.
Their reward fields distinguish Pokémon (`pokemon`, `levels`) and items (`item`, `quantity`).
Vendor entries are not subject to wild encounter rate totals or per-species uniqueness.

## Game Corner windows

One source per physical window:

| Window | Source ID | Type |
| --- | --- | --- |
| Left | `item_vendor_celadon_game_corner_prize_room_left_window` | Item vendor |
| Middle | `pokemon_vendor_celadon_game_corner_prize_room_middle_window` | Pokémon vendor |
| Right | `item_vendor_celadon_game_corner_prize_room_right_window` | Item vendor |

All three sources use `requires: "state_has_coin_case"` (Coin Case acquired).
All prize offers use `currency: "coins"` and `repeatable: true`.
The middle window's approved offers are:

| `pokemon` | `levels` | `price` | `versions` |
| --- | --- | --- | --- |
| `species_abra` | `[9]` | 180 | `["firered"]` |
| `species_abra` | `[7]` | 120 | `["leafgreen"]` |
| `species_clefairy` | `[8]` | 500 | `["firered"]` |
| `species_clefairy` | `[12]` | 750 | `["leafgreen"]` |
| `species_dratini` | `[18]` | 2800 | `["firered"]` |
| `species_dratini` | `[24]` | 4600 | `["leafgreen"]` |
| `species_scyther` | `[25]` | 5500 | `["firered"]` |
| `species_pinsir` | `[18]` | 2500 | `["leafgreen"]` |
| `species_porygon` | `[26]` | 9999 | `["firered"]` |
| `species_porygon` | `[18]` | 6500 | `["leafgreen"]` |

The right window uses the item-vendor shape, with `quantity: 1` and no `versions` field
on each offer:

| `item` | `price` |
| --- | --- |
| `item_tm13_ice_beam` | 4000 |
| `item_tm23_iron_tail` | 3500 |
| `item_tm24_thunderbolt` | 4000 |
| `item_tm30_shadow_ball` | 4500 |
| `item_tm35_flamethrower` | 4000 |

The supplied Bulbapedia screenshot records the catalogues. The
[prize-room script](https://github.com/pret/pokefirered/blob/master/data/maps/CeladonCity_GameCorner_PrizeRoom/scripts.inc)
also supplies the Coin Case acquisition gate and version-specific Pokémon rewards.

The proposed prize-room Zone references each window once:

```json
"pokemon_vendors": [
  "pokemon_vendor_celadon_game_corner_prize_room_middle_window"
],
"item_vendors": [
  "item_vendor_celadon_game_corner_prize_room_left_window",
  "item_vendor_celadon_game_corner_prize_room_right_window"
]
```

## Shared interpretation and implementation boundary

- Source `requires` is a state ID or `null`; Zone reachability supplies location access.
- Missing Zone content arrays mean empty. Migrate the relevant draft `pokemon_sources`
  and `item_sources` references when their typed readers and validation are implemented.
- Prices and currencies preserve canonical facts. v1.0 does not check money/coin balances.
- `repeatable` describes further transactions; completing a source must not erase a
  previously obtained species from availability.
- Version differences belong to exchanges or offers; shared entries are authored once.
- Keep source IDs independent of rewards. Author area-based arrays and generate separate
  trade, Pokémon-vendor, and item-vendor collections using the shared build workflow.
- Validation, runtime readers, acquisition-chain evaluation, and manual Coin Case state
  support are implemented. Species/item catalogue resolution and completion tracking
  remain future work.

## Current runtime and authoring workflow

Area arrays under `data/source/acquisitions/{pokemon_trades,pokemon_vendors,item_vendors}/`
build into matching `data/acquisitions/*.json` collections. The common builder validates
all ten runtime collections before writing any output. Typed Zone references must resolve
even in draft mode; missing arrays mean no sources. Shared sources can have several access
Zones. Unplaced source catalogues are allowed but cannot become available.

The two trades are Route 2's Abra/Mr. Mime and Cerulean's Poliwhirl/Jynx (with Fab Mail).
The Pokémon vendors are the Route 4 salesman and Game Corner middle window. The item
vendors are the Viridian/Pewter/Cerulean marts and Game Corner left/right windows.
The six slice sources have authored Zone references. Game Corner windows remain unplaced
until Celadon world authoring; tests attach the real catalogues to a fixture Zone.

Viridian shopping requires `state_event_oaks_parcel_delivered`, representing completion
of the parcel/Pokédex scene. Its Mart script blocks normal shopping while delivery is
outstanding. [Viridian's clerk script](https://github.com/pret/pokefirered/blob/master/data/maps/ViridianCity_Mart/scripts.inc)
performs the scene check; the tracker uses the existing completed-delivery semantic event.
[Pewter](https://github.com/pret/pokefirered/blob/master/data/maps/PewterCity_Mart/scripts.inc)
and [Cerulean](https://github.com/pret/pokefirered/blob/master/data/maps/CeruleanCity_Mart/scripts.inc)
provide their respective shop catalogues. Mart prices were checked against the
[canonical item definitions](https://github.com/pret/pokefirered/blob/master/src/data/items.json).
The initial mart offers are shared across FireRed and LeafGreen:

| Item | Price (money) | Viridian | Pewter | Cerulean |
| --- | --- | --- | --- | --- |
| Poké Ball | 200 | Yes | Yes | Yes |
| Potion | 300 | Yes | Yes | Yes |
| Antidote | 100 | Yes | Yes | Yes |
| Paralyze Heal | 200 | Yes | Yes | Yes |
| Awakening | 250 | — | Yes | Yes |
| Burn Heal | 250 | — | Yes | Yes |
| Escape Rope | 550 | — | Yes | Yes |
| Repel | 350 | — | Yes | Yes |
| Super Potion | 700 | — | — | Yes |

### API

`Acquisitions.available(world, reachable, state, version)` takes the indexed world,
the reachable Zone map, evaluated player facts, and `firered` or `leafgreen`.
It calculates wild availability, collects reachable/version-applicable vendor offers,
then applies reachable trades until the available species set stops changing. Prices,
collection ownership, party capacity, and resource consumption are not simulated.

It returns fresh tables:

- `sources_by_id`: wild sources, preserving the existing encounter result contract.
- `species_available`: species obtainable through wild encounters, vendors, or trades.
- `pokemon_vendors_by_id`, `item_vendors_by_id`: available source results with `id`,
  reachable `zones`, and filtered `offers`.
- `pokemon_trades_by_id`: eligible trade results with `id`, reachable `zones`, and
  filtered `exchanges`. A blocked trade is absent.
- `items_available`: vendor items and held items received through eligible trades.

Result entries retain price, quantity, repeatability, levels, level rule, and held-item
metadata where applicable. Level arrays are copied; modifying a result does not change
the source data or another result. A trade's variable level remains a rule, because
species availability does not track the exact level of a submitted individual Pokémon.

```lua
local State = require("logic.state")
local Reachability = require("logic.reachability")
local Acquisitions = require("logic.acquisitions")

local state = State.evaluate({state_event_oaks_parcel_delivered = true})
local reachable = Reachability.solve(world, "zone_players_house", state)
local available = Acquisitions.available(world, reachable, state, "firered")
assert(available.items_available.item_poke_ball)
```

Internal helpers copy entry payloads and collect reachable source access once per source.
The existing `Versions.includes` filter is shared with wild encounters. No acquisition
result automatically sets a progression fact or recalculates topology.

### Deliberate exclusions

The Bike Voucher exchange and gift availability are excluded from this implementation.
Berry Powder purchases remain deferred with multiplayer support. Detailed item definitions
and item-dependent evolution checks are deferred beyond the current slice and v1, for
later Professor Oak mode work. Gift rewards, pickups, and automatic item-derived
progression are not implemented.

Daisy, the Route 1 employee, and the Route 2 aide have draft `item_sources` references,
without gift payloads or readers. The following references preserve two additional NPC
locations for possible future item-randomiser support:

| Zone | Gift source reference |
| --- | --- |
| `zone_cerulean_city_berry_powder_house` | `item_gift_cerulean_city_berry_powder_house_man` |
| `zone_pewter_city` | `item_gift_pewter_city_east_exit_prof_aide` |

The latter identifies the aide on the way from Pewter to Route 3, separately from the
Gym's `item_gift_pewter_city_defeat_brock` reference. These entries identify sources only:
they do not store rewards or contribute to the runtime's item availability. Source IDs
remain independent of their vanilla rewards so future randomiser data can reuse them.
