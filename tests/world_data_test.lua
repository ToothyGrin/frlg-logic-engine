local World = require("logic.world")
local Reachability = require("logic.reachability")
local State = require("logic.state")
local read_json = require("logic.json_file")
local json = require("lib.dkjson")

local function decode_json(contents)
    local value, _, message = json.decode(contents)
    assert(not message, message)
    return value
end

local function read_world_json(path)
    return read_json(path, decode_json)
end

local function test_evaluated_player_state(world)
    local player = {
        state_delivered_oaks_parcel = true,
        state_event_brock_defeated = true,
        state_has_cascade_badge = true,
        state_has_soul_badge = true,
    }

    local before = Reachability.solve(world, "zone_players_house", State.evaluate(player))
    assert(before.zone_cerulean_city, "Evaluated story flags should preserve the early-Kanto path")
    assert(before.zone_pewter_city_museum_backyard == nil, "A badge without HM01 must not open Cut paths")
    assert(before.zone_pallet_town_water == nil, "A badge without HM03 must not open water")

    player.state_has_hm01_cut = true
    player.state_has_hm03_surf = true
    local with_hms = Reachability.solve(world, "zone_players_house", State.evaluate(player))
    assert(with_hms.zone_pewter_city_museum_backyard, "Derived Cut should open the museum backyard without party checks")
    assert(with_hms.zone_pallet_town_water, "Derived Surf should open Pallet's water without party checks")

    player.state_has_hm01_cut = false
    player.state_has_soul_badge = false
    local removed = Reachability.solve(world, "zone_players_house", State.evaluate(player))
    assert(removed.zone_pewter_city_museum_backyard == nil, "Removing HM01 must close Cut paths")
    assert(removed.zone_pallet_town_water == nil, "Removing Surf's badge must close water paths")
    assert(with_hms.zone_pewter_city_museum_backyard, "Recalculation must preserve earlier reachability")
    assert(player.state_can_cut == nil, "The full pipeline must not write capabilities into player facts")
end

local function test_authored_world()
    local world = World.load(read_world_json)
    test_evaluated_player_state(world)

    local early = Reachability.solve(world, "zone_players_house", {})
    assert(early.zone_pallet_town, "The player's house Portal should lead to Pallet Town")
    assert(early.zone_route_1, "Route 1 should be reachable at the start")
    assert(early.zone_viridian_city, "Viridian City should be reachable at the start")
    assert(early.zone_viridian_city_north == nil, "The old man should block northern Viridian")
    assert(early.zone_pewter_city == nil, "Pewter should remain beyond the old man")
    assert(early.zone_pallet_town_water == nil, "Water should require Surf")

    local parcel = Reachability.solve(world, "zone_players_house", {
        state_delivered_oaks_parcel = true,
    })
    assert(parcel.zone_viridian_forest, "Parcel delivery should open the path through Viridian Forest")
    assert(parcel.zone_pewter_city, "Parcel delivery should allow reaching Pewter")
    assert(parcel.zone_route_3 == nil, "Brock should block Route 3")
    assert(parcel.zone_pewter_city_museum_backyard == nil, "The museum ledge must not allow entry uphill")

    local brock = Reachability.solve(world, "zone_players_house", {
        state_delivered_oaks_parcel = true,
        state_event_brock_defeated = true,
    })
    assert(brock.zone_route_3, "Defeating Brock should open Route 3")
    assert(brock.zone_mt_moon_1f, "The Mt. Moon entrance Portal should be traversable")
    assert(brock.zone_mt_moon_b2f, "Mt. Moon ladder Portals should connect the floors")
    assert(brock.zone_cerulean_city, "The authored path through Mt. Moon should reach Cerulean")
    assert(brock.zone_route_25, "The authored northern Cerulean path should reach Route 25")

    local cut = Reachability.solve(world, "zone_players_house", {
        state_can_cut = true,
        state_event_brock_defeated = true,
    })
    assert(cut.zone_viridian_city_north, "Cut should provide the alternative path past the old man")
    assert(cut.zone_pewter_city_museum_backyard, "Cut should open the museum backyard")
    assert(cut.zone_pewter_city_museum_side, "The backyard Portal should lead into the museum side room")
    assert(cut.zone_cerulean_city_southeast, "Cut should open southeastern Cerulean")
    assert(cut.zone_route_5 == nil, "Unfinished Route 5 must not become a reachable Zone")
    assert(cut.zone_route_9 == nil, "Unfinished Route 9 must not become a reachable Zone")

    local surf = Reachability.solve(world, "zone_players_house", {state_can_surf = true})
    assert(surf.zone_pallet_town_water, "Surf should open Pallet's water")
    assert(surf.zone_viridian_city_water, "Surf should open Viridian's water")
    assert(surf.zone_viridian_city_move_tutor_island, "Surf should provide an alternative to the island's Cut path")
    assert(surf.zone_viridian_city_north == nil, "Surf should not bypass the old man")
    assert(surf.zone_route_21_water == nil, "Unfinished Route 21 must remain outside the result")

    local backyard = Reachability.solve(world, "zone_pewter_city_museum_backyard", {})
    assert(backyard.zone_pewter_city, "The museum ledge should allow leaving without Cut")

    local cerulean = Reachability.solve(world, "zone_cerulean_city", {})
    assert(cerulean.zone_route_4_easternmost, "Cerulean should connect to the eastern end of Route 4")
    assert(cerulean.zone_route_4_east == nil, "Route 4's ledge must block the return toward Mt. Moon")
    assert(cerulean.zone_mt_moon_1f == nil, "Mt. Moon must not be reachable by reversing the ledges")

    local reset = Reachability.solve(world, "zone_players_house", {})
    assert(reset.zone_pewter_city == nil, "Removing progression flags must close the northern path again")
    assert(reset.zone_pallet_town_water == nil, "Removing Surf must close water access again")
    assert(brock.zone_cerulean_city, "Later calculations must preserve earlier results")
end

test_authored_world()

print("Authored world reachability tests passed.")
