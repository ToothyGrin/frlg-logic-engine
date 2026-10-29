local World = require("logic.world")
local State = require("logic.state")
local Reachability = require("logic.reachability")
local Acquisitions = require("logic.acquisitions")
local read_json = require("logic.json_file")
local json = require("lib.dkjson")

local function reader(path)
    return read_json(path, function(contents)
        local value, _, message = json.decode(contents)
        assert(not message, message)
        return value
    end)
end

local function evaluate(world, player, version)
    local state = State.evaluate(player)
    return Acquisitions.available(world, Reachability.solve(world, "zone_players_house", state), state, version)
end

local function test_authored_sources()
    local world = World.load(reader)
    local initial = evaluate(world, {}, "firered")
    assert(initial.item_vendors_by_id.item_vendor_viridian_city_pokemart == nil, "The parcel scene must gate Viridian shopping")
    assert(initial.species_available.species_magikarp == nil)

    local parcel = evaluate(world, {state_event_oaks_parcel_delivered = true}, "firered")
    assert(parcel.items_available.item_poke_ball and parcel.items_available.item_repel)
    assert(parcel.items_available.item_super_potion == nil, "Cerulean is still unreachable")
    assert(#parcel.item_vendors_by_id.item_vendor_viridian_city_pokemart.offers == 4)
    assert(#parcel.item_vendors_by_id.item_vendor_pewter_city_pokemart.offers == 8)

    local player = {state_event_oaks_parcel_delivered = true, state_event_brock_defeated = true}
    local before_cut = evaluate(world, player, "firered")
    assert(before_cut.species_available.species_abra and not before_cut.species_available.species_mr_mime,
        "Finding Abra does not bypass the Cut-gated trader's location")
    player.state_has_hm01_cut = true
    player.state_has_cascade_badge = true
    local full = evaluate(world, player, "firered")
    assert(full.species_available.species_magikarp, "Salesman should provide Magikarp without a rod")
    assert(full.species_available.species_mr_mime, "Route 24 Abra should enable the reachable Route 2 trade")
    assert(full.species_available.species_jynx == nil, "Jynx still needs Poliwhirl")
    assert(full.items_available.item_super_potion)
    assert(#full.item_vendors_by_id.item_vendor_cerulean_city_pokemart.offers == 9)
    local salesman = full.pokemon_vendors_by_id.pokemon_vendor_route_4_pokecenter_salesman
    assert(salesman.offers[1].price == 500 and salesman.offers[1].repeatable == false)
    assert(full.pokemon_trades_by_id.pokemon_trade_route_2_traders_house.exchanges[1].level_rule == "match_requested_pokemon")
    player.state_has_super_rod = true
    local fished = evaluate(world, player, "leafgreen")
    assert(fished.species_available.species_jynx and fished.items_available.item_fab_mail)
    assert(fished.pokemon_trades_by_id.pokemon_trade_cerulean_city_traders_house.exchanges[1].held_item == "item_fab_mail")

    local middle = "pokemon_vendor_celadon_game_corner_prize_room_middle_window"
    player.state_has_coin_case = true
    assert(evaluate(world, player, "firered").pokemon_vendors_by_id[middle] == nil, "Coin Case alone cannot reach Celadon")
    -- Attach the real catalogues to a fixture Zone only, without changing authored topology.
    local zone = world.zones_by_id.zone_players_house
    zone.pokemon_vendors = {middle}
    zone.item_vendors = {"item_vendor_celadon_game_corner_prize_room_left_window", "item_vendor_celadon_game_corner_prize_room_right_window"}
    assert(evaluate(world, {}, "firered").pokemon_vendors_by_id[middle] == nil, "Prize windows require the Coin Case")
    assert(State.evaluate({state_has_coin_case = "true"}).state_has_coin_case == false)
    local fr = evaluate(world, {state_has_coin_case = true}, "firered")
    local lg = evaluate(world, {state_has_coin_case = true}, "leafgreen")
    assert(#fr.pokemon_vendors_by_id[middle].offers == 5 and #lg.pokemon_vendors_by_id[middle].offers == 5)
    assert(fr.species_available.species_scyther and not fr.species_available.species_pinsir)
    assert(lg.species_available.species_pinsir and not lg.species_available.species_scyther)
    assert(fr.items_available.item_tm13_ice_beam and lg.items_available.item_smoke_ball)
    assert(fr.pokemon_vendors_by_id[middle].offers[1].levels[1] == 9)
    assert(lg.pokemon_vendors_by_id[middle].offers[1].levels[1] == 7)
    fr.pokemon_vendors_by_id[middle].offers[1].levels[1] = 99
    assert(world.pokemon_vendors_by_id[middle].offers[1].levels[1] == 9, "Results must not mutate data")
    assert(evaluate(world, {state_has_coin_case = true}, "firered").pokemon_vendors_by_id[middle].offers[1].levels[1] == 9)
    assert(full.species_available.species_jynx == nil, "Earlier results must remain unchanged")
    assert(full.items_available.item_town_map == nil, "Draft gift references are not evaluated")
end

local function trade(id, requested, received)
    return {id = id, exchanges = {{requested_pokemon = requested, pokemon = received, level_rule = "match_requested_pokemon", repeatable = false}}}
end

local function test_trade_chains_and_shared_access()
    local data = {
        containers = {{zones = {
            {id = "zone_a", warps = {}, pokemon_vendors = {"pokemon_vendor_seed"}, pokemon_trades = {"pokemon_trade_second", "pokemon_trade_first", "pokemon_trade_cycle_a", "pokemon_trade_cycle_b", "pokemon_trade_blocked"}},
            {id = "zone_b", warps = {}, pokemon_vendors = {"pokemon_vendor_seed"}},
            {id = "zone_isolated", warps = {}, pokemon_trades = {"pokemon_trade_isolated"}},
        }}},
        connections = {}, portals = {},
        pokemon_vendors = {{id = "pokemon_vendor_seed", offers = {{pokemon = "species_abra", levels = {5}, price = 1, currency = "money", repeatable = true}}}},
        pokemon_trades = {
            trade("pokemon_trade_second", "species_mr_mime", "species_jynx"),
            trade("pokemon_trade_first", "species_abra", "species_mr_mime"),
            trade("pokemon_trade_cycle_a", "species_ekans", "species_sandshrew"),
            trade("pokemon_trade_cycle_b", "species_sandshrew", "species_ekans"),
            trade("pokemon_trade_isolated", "species_abra", "species_porygon"),
            trade("pokemon_trade_blocked", "species_abra", "species_dratini"),
        },
    }
    data.pokemon_trades[6].requires = "state_test"
    local world = World.build_indexes(data)
    local result = Acquisitions.available(world, {zone_a = true, zone_b = true}, {}, "firered")
    assert(result.species_available.species_jynx, "Reverse-ordered chains must reach a fixed point")
    assert(result.species_available.species_abra, "An exchange must not consume an available species")
    assert(not result.species_available.species_ekans and not result.species_available.species_sandshrew, "Unseeded cycles cannot create Pokémon")
    assert(not result.species_available.species_porygon and not result.species_available.species_dratini)
    assert(#result.pokemon_vendors_by_id.pokemon_vendor_seed.zones == 2)
    assert(#result.pokemon_vendors_by_id.pokemon_vendor_seed.offers == 1)
    assert(Acquisitions.available(world, {zone_a = true}, {state_test = true}, "firered").species_available.species_dratini)
    assert(not pcall(Acquisitions.available, world, {}, {}, "emerald"))
    data.pokemon_trades[1].id = data.pokemon_trades[2].id
    assert(not pcall(World.build_indexes, data), "Duplicate acquisition IDs must fail")
    data.pokemon_trades[1].id = "pokemon_trade_second"
    data.containers[1].zones[1].item_vendors = {"item_vendor_missing"}
    assert(not pcall(World.build_indexes, data), "Unknown typed references must fail")
end

test_authored_sources()
test_trade_chains_and_shared_access()
print("Trade and vendor availability tests passed.")
