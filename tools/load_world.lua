local World = require("logic.world")
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
    world.warp_to_sibling["warp_players_house_exit"]
    == "warp_players_house_entrance"
)

print("World loaded; sample lookups passed.")
