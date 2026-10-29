local World = require("logic.world")
local State = require("logic.state")
local Reachability = require("logic.reachability")
local Encounters = require("logic.encounters")
local Versions = require("logic.versions")
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

local function find_entry(source, pokemon)
    for _, entry in ipairs(source.encounters) do
        if entry.pokemon == pokemon then
            return entry
        end
    end
    error("Missing encounter: " .. pokemon)
end

local function test_version_filter()
    assert(Versions.includes({}, "firered"), "Omitted versions should apply to FireRed")
    assert(Versions.includes({}, "leafgreen"), "Omitted versions should apply to LeafGreen")
    assert(Versions.includes({versions = {"leafgreen"}}, "leafgreen"))
    assert(not Versions.includes({versions = {"leafgreen"}}, "firered"))
    assert(Versions.includes({versions = {"firered", "leafgreen"}}, "firered"))
    assert(not pcall(Versions.includes, {}, "emerald"), "Unknown versions should be rejected")
end

local function test_authored_availability(world)
    local initial_state = State.evaluate({})
    local initial_reachable = Reachability.solve(world, "zone_players_house", initial_state)
    local initial = Encounters.available(world, initial_reachable, initial_state, "firered")
    assert(initial.species_available.species_pidgey, "Route 1 grass should be available initially")
    assert(initial.species_available.species_mankey, "Route 22 grass should be available initially")
    assert(initial.species_available.species_magikarp == nil, "Fishing needs a rod")
    assert(initial.sources_by_id.enc_route_2_grass == nil, "Unreachable sources must stay unavailable")
    assert(initial.sources_by_id.enc_route_23_grass == nil, "Unplaced Route 23 data must not become available")

    local player = {state_has_old_rod = true}
    local state = State.evaluate(player)
    local reachable = Reachability.solve(world, "zone_players_house", state)
    local old_rod = Encounters.available(world, reachable, state, "firered")
    assert(old_rod.species_available.species_magikarp, "Old Rod should allow shore fishing without Surf")
    local pallet = old_rod.sources_by_id.enc_pallet_town_old_rod
    local entry = find_entry(pallet, "species_magikarp")
    assert(#entry.levels == 6 and entry.levels[1] == 5 and entry.levels[6] == 10, "Pallet Old Rod levels are 5–10")
    assert(#old_rod.sources_by_id.enc_viridian_city_old_rod.encounters[1].levels == 1, "Viridian Old Rod level is 5")
    assert(old_rod.sources_by_id.enc_pallet_town_good_rod == nil, "Old Rod must not grant Good Rod fishing")
    assert(old_rod.sources_by_id.enc_pallet_town_surf == nil, "A rod must not grant Surf encounters")

    player.state_event_oaks_parcel_delivered = true
    player.state_event_brock_defeated = true
    player.state_has_good_rod = true
    player.state_has_super_rod = true
    player.state_has_soul_badge = true
    player.state_has_hm03_surf = true
    state = State.evaluate(player)
    reachable = Reachability.solve(world, "zone_players_house", state)
    local fr = Encounters.available(world, reachable, state, "firered")
    local lg = Encounters.available(world, reachable, state, "leafgreen")
    assert(fr.species_available.species_ekans and not fr.species_available.species_sandshrew)
    assert(lg.species_available.species_sandshrew and not lg.species_available.species_ekans)
    assert(fr.species_available.species_psyduck and not fr.species_available.species_slowpoke)
    assert(lg.species_available.species_slowpoke and not lg.species_available.species_psyduck)
    assert(not fr.species_available.species_mr_mime and not fr.species_available.species_jynx, "Trades are separate from wild encounters")

    local route_3 = fr.sources_by_id.enc_route_3_grass
    local jigglypuff = find_entry(route_3, "species_jigglypuff")
    assert(#jigglypuff.levels == 3 and jigglypuff.levels[2] == 5, "Exact level gaps must be preserved")
    assert(find_entry(route_3, "species_nidoran_f").rate == 1)
    assert(find_entry(lg.sources_by_id.enc_route_3_grass, "species_nidoran_f").rate == 14)
    assert(find_entry(fr.sources_by_id.enc_viridian_forest_grass, "species_metapod").rate == 5)
    assert(find_entry(lg.sources_by_id.enc_viridian_forest_grass, "species_metapod").rate == 10)

    local shared = fr.sources_by_id.enc_pallet_town_old_rod
    assert(#shared.zones == 2 and #shared.encounters == 1, "Land/water references must merge source access without duplicating entries")
    assert(shared.encounters[1].rate == 100, "Access from two Zones must not add encounter rates")

    player.state_has_old_rod = false
    player.state_has_hm03_surf = false
    state = State.evaluate(player)
    local removed = Encounters.available(world, Reachability.solve(world, "zone_players_house", state), state, "firered")
    assert(removed.sources_by_id.enc_pallet_town_old_rod == nil)
    assert(removed.sources_by_id.enc_pallet_town_surf == nil)
    assert(removed.sources_by_id.enc_pallet_town_good_rod, "Rods are independent acquisition facts")
    assert(fr.sources_by_id.enc_pallet_town_surf, "Recalculation must preserve earlier results")
    entry.levels[1] = 99
    assert(shared.encounters[1].levels[1] == 5, "Results must not share nested level arrays")
    assert(world.encounter_sources_by_id.enc_pallet_town_old_rod.encounters[1].levels[1] == 5, "Results must not mutate authored data")
    assert(not pcall(Encounters.available, world, {}, {}, "emerald"), "Unknown versions fail even without reachable Zones")
    local nonboolean = Encounters.available(world, {zone_pallet_town = true}, {state_has_old_rod = "true"}, "firered")
    assert(nonboolean.sources_by_id.enc_pallet_town_old_rod == nil, "Method requirements need boolean true")
    assert(Encounters.available(world, {zone_pallet_town = 1}, state, "firered").sources_by_id.enc_pallet_town_good_rod == nil)
end

local function test_source_index_errors()
    local data = {containers = {}, connections = {}, portals = {}, encounters = {{id = "enc_test"}, {id = "enc_test"}}}
    assert(not pcall(World.build_indexes, data), "Duplicate encounter IDs should fail during indexing")
    data.encounters = {}
    data.containers = {{zones = {{id = "zone_test", warps = {}, encounter_sources = {"enc_missing"}}}}}
    assert(not pcall(World.build_indexes, data), "Unknown encounter references should fail during indexing")
    data.containers[1].zones[1].encounter_sources = nil
    local world = World.build_indexes(data)
    local result = Encounters.available(world, {zone_test = true}, {}, "firered")
    assert(result.sources_by_id.enc_missing == nil, "An omitted array should behave as empty")
end

test_version_filter()
test_authored_availability(World.load(read_world_json))
test_source_index_errors()
print("Wild encounter availability tests passed.")
