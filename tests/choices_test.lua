local World = require("logic.world")
local State = require("logic.state")
local Reachability = require("logic.reachability")
local Acquisitions = require("logic.acquisitions")
local read_json = require("logic.json_file")
local json = require("lib.dkjson")

local starter = "choice_oaks_lab_starter"
local fossil = "choice_mt_moon_fossil"
local ball_1 = "pokemon_gift_oaks_lab_starter_ball_1"
local ball_2 = "pokemon_gift_oaks_lab_starter_ball_2"
local ball_3 = "pokemon_gift_oaks_lab_starter_ball_3"
local west = "item_pickup_mt_moon_b2f_fossil_west"

local function reader(path)
    return read_json(path, function(contents)
        local value, _, message = json.decode(contents)
        assert(not message, message)
        return value
    end)
end

local function evaluate(world, player)
    local state = State.evaluate(player, world)
    return Acquisitions.available(world, Reachability.solve(world, "zone_players_house", state), state, "firered"), state
end

local function test_starter_choices(world)
    local initial, initial_state = evaluate(world, {})
    assert(initial_state.choices[starter].status == "unknown", "Missing is unknown, not a chosen starter")
    assert(initial.starter_choice == nil and not initial.species_available.species_bulbasaur)
    assert(#initial.choices_by_id[starter].alternatives == 0)
    local player = {choices = {[starter] = {status = "unselected"}}}
    assert(#evaluate(world, player).choices_by_id[starter].alternatives == 0, "The lab scene is not ready")
    player.state_event_oak_ready_for_starter = true
    local alternatives = evaluate(world, player)
    assert(#alternatives.choices_by_id[starter].alternatives == 3)
    assert(not alternatives.species_available.species_bulbasaur and not alternatives.species_available.species_squirtle)
    assert(not alternatives.species_available.species_charmander, "Alternatives cannot seed trade availability")
    for _, case in ipairs({{ball_1, "bulbasaur"}, {ball_2, "squirtle"}, {ball_3, "charmander"}}) do
        player.choices[starter] = {status = "selected", source = case[1]}
        local selected, state = evaluate(world, player)
        assert(state.starter_choice == case[2] and selected.starter_choice == case[2])
        assert(selected.species_available["species_" .. case[2]])
        assert(selected.pokemon_gifts_by_id[case[1]].obtained == true)
        assert(#selected.choices_by_id[starter].excluded == 2 and #selected.choices_by_id[starter].alternatives == 0)
        for _, other in ipairs({ball_1, ball_2, ball_3}) do
            if other ~= case[1] then assert(selected.pokemon_gifts_by_id[other] == nil) end
        end
    end
    player.choices[starter] = {status = "selected", source = ball_1}
    local first, state = evaluate(world, player)
    state.choices[starter].source = ball_2
    assert(player.choices[starter].source == ball_1, "State must not alias player choices")
    player.choices[starter] = {status = "selected", source = ball_2}
    local corrected = evaluate(world, player)
    assert(corrected.species_available.species_squirtle and not corrected.species_available.species_bulbasaur)
    assert(first.species_available.species_bulbasaur and first.choices_by_id[starter].source == ball_1)
    first.pokemon_gifts_by_id[ball_1].levels[1] = 99
    assert(world.pokemon_gifts_by_id[ball_1].levels[1] == 5)
    player.choices[starter] = nil
    assert(evaluate(world, player).starter_choice == nil, "Removing a choice must clear derived identity")
    local away = Acquisitions.available(world, {}, State.evaluate({choices = {[starter] = {status = "selected", source = ball_1}}}, world), "firered")
    assert(away.species_available.species_bulbasaur and #away.pokemon_gifts_by_id[ball_1].zones == 0,
        "An acquired selection survives leaving the location and its readiness scene")
    assert(#alternatives.choices_by_id[starter].alternatives == 3, "Later results must not mutate alternatives")
end

local function test_fossil_metadata(world)
    local player = {state_event_oaks_parcel_delivered = true, state_event_brock_defeated = true,
        choices = {[fossil] = {status = "unselected"}}}
    assert(#evaluate(world, player).choices_by_id[fossil].alternatives == 0, "Miguel must be defeated first")
    player.state_event_mt_moon_miguel_defeated = true
    local alternatives = evaluate(world, player)
    assert(#alternatives.choices_by_id[fossil].alternatives == 2)
    local isolated = Acquisitions.available(world, {}, State.evaluate(player, world), "firered")
    assert(#isolated.choices_by_id[fossil].alternatives == 0, "Readiness does not grant Zone access")
    player.choices[fossil] = {status = "selected", source = west}
    local result = evaluate(world, player)
    assert(result.choices_by_id[fossil].source == west and #result.choices_by_id[fossil].excluded == 1)
    assert(not result.items_available.item_dome_fossil and not result.items_available.item_helix_fossil)
    assert(not result.species_available.species_kabuto and not result.species_available.species_omanyte)
end

local function test_bad_state(world)
    for _, bad in ipairs({true, "selected", {}, {status = "invalid"}, {status = "selected"},
        {status = "selected", source = west}, {status = "selected", source = "missing"},
        {status = "unselected", source = ball_1}, {status = "unknown", source = ball_1}}) do
        assert(not pcall(State.evaluate, {choices = {[starter] = bad}}, world), "Invalid known choice input must fail")
    end
    assert(not pcall(State.evaluate, {choices = "bad"}, world))
    assert(not pcall(State.evaluate, {choices = {[starter] = {status = "selected", source = ball_1}}}), "Choice inputs require world membership")
    local state = State.evaluate({choices = {unsupported = {status = "selected"}}}, world)
    assert(state.choices[starter].status == "unknown", "Unsupported keys follow the existing state input policy")
    assert(State.evaluate({state_event_oak_ready_for_starter = "true"}, world).state_event_oak_ready_for_starter == false)
end

local function test_reward_identity_and_trade_seed()
    local data = {containers = {{zones = {{id = "zone_test", warps = {}, pokemon_gifts = {ball_1, ball_2},
        pokemon_trades = {"pokemon_trade_test"}, pokemon_vendors = {"pokemon_vendor_independent"}}}}}, connections = {}, portals = {},
        pokemon_gifts = {{id = ball_1, pokemon = "species_lapras", levels = {5}, repeatable = false},
            {id = ball_2, pokemon = "species_squirtle", levels = {5}, repeatable = false}},
        choices = {{id = starter, option_type = "pokemon_gift", options = {ball_1, ball_2}, max_selections = 1}},
        pokemon_trades = {{id = "pokemon_trade_test", exchanges = {{requested_pokemon = "species_lapras", pokemon = "species_jynx"}}}},
        pokemon_vendors = {{id = "pokemon_vendor_independent", offers = {{pokemon = "species_squirtle", levels = {5}}}}},
    }
    local world = World.build_indexes(data)
    local state = State.evaluate({choices = {[starter] = {status = "selected", source = ball_1}}}, world)
    local result = Acquisitions.available(world, {zone_test = true}, state, "firered")
    assert(state.starter_choice == "bulbasaur" and result.species_available.species_lapras)
    assert(result.species_available.species_jynx, "Chosen gifts must seed downstream trades")
    assert(result.species_available.species_squirtle and not result.pokemon_gifts_by_id[ball_2], "Other sources can still provide an excluded reward")
    local unresolved = Acquisitions.available(world, {zone_test = true}, State.evaluate({}, world), "firered")
    assert(not unresolved.species_available.species_jynx, "Unknown choices cannot seed trades")
    data.choices[1].options[2] = ball_1
    assert(not pcall(World.build_indexes, data), "Duplicate options must fail indexing")
    data.choices[1].options[2] = "pokemon_gift_missing"
    assert(not pcall(World.build_indexes, data), "Unplaced options must fail indexing")
end

local world = World.load(reader)
test_starter_choices(world)
test_fossil_metadata(world)
test_bad_state(world)
test_reward_identity_and_trade_seed()
print("Exclusive choice tests passed.")
