local World = require("logic.world")
local State = require("logic.state")
local Reachability = require("logic.reachability")
local Encounters = require("logic.encounters")
local read_json = require("logic.json_file")
local json = require("lib.dkjson")

local function decode_json(contents)
    local value, _, decode_error = json.decode(contents)
    assert(not decode_error, decode_error)

    return value
end

local function read_world_json(path)
    return read_json(path, decode_json)
end

local world = World.load(read_world_json)

assert(world.zones_by_id["zone_players_house"])
assert(
    world.warp_to_zone["warp_players_house_exit"]
    == world.zones_by_id["zone_players_house"]
)
assert(
    world.warp_to_destination["warp_players_house_exit"]
    == "warp_players_house_entrance"
)

local state = State.evaluate({})
local reachable = Reachability.solve(world, "zone_players_house", state)
assert(reachable.zone_pallet_town, "The player's house should connect to Pallet Town")
assert(reachable.zone_viridian_city, "The opening path should reach Viridian City")
assert(reachable.zone_pallet_town_water == nil, "Water should remain blocked without Surf")
local available = Encounters.available(world, reachable, state, "firered")
assert(available.species_available.species_pidgey, "Route 1 Pidgey should be available initially")
assert(available.species_available.species_magikarp == nil, "Initial fishing should require a rod")

print("World loaded; sample lookups, reachability, and encounter availability passed.")
