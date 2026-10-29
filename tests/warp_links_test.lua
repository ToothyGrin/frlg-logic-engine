local World = require("logic.world")
local Reachability = require("logic.reachability")

local function test_drop_direction_and_shared_landings()
    local data = {
        containers = {{zones = {
            {id = "zone_a", connections = {}, warps = {"warp_a"}},
            {id = "zone_b", connections = {}, warps = {"warp_b"}},
            {id = "zone_c", connections = {}, warps = {"warp_c"}},
            {id = "zone_d", connections = {}, warps = {"warp_d", "warp_unpaired"}},
        }}},
        connections = {},
        portals = {
            {type = "drop", warps = {"warp_a", "warp_b"}},
            {type = "drop", warps = {"warp_c", "warp_b"}},
        },
    }
    local world = World.build_indexes(data)
    assert(world.warp_to_destination.warp_a == "warp_b")
    assert(world.warp_to_destination.warp_c == "warp_b")
    assert(world.warp_to_destination.warp_b == nil, "A landing must not gain a reverse departure")

    local from_a = Reachability.solve(world, "zone_a", {})
    assert(from_a.zone_b, "A drop must lead to its landing Zone")
    assert(from_a.zone_c == nil, "A shared landing must not connect back to another departure")
    local from_b = Reachability.solve(world, "zone_b", {})
    assert(from_b.zone_a == nil and from_b.zone_c == nil, "A drop must not be reversible")
    local from_d = Reachability.solve(world, "zone_d", {})
    assert(from_d.zone_b == nil, "Unpaired Warps must not create a route")

    -- A landing may also have an explicitly authored normal departure.
    table.insert(data.portals, {type = "normal", warps = {"warp_b", "warp_d"}})
    local connected_world = World.build_indexes(data)
    local connected = Reachability.solve(connected_world, "zone_a", {})
    assert(connected.zone_b and connected.zone_d, "An explicit onward route must remain usable")
    assert(connected.zone_c == nil, "An onward route must not invent a reverse drop")
    local reverse_normal = Reachability.solve(connected_world, "zone_d", {})
    assert(reverse_normal.zone_b, "Normal links still work in both directions")
    assert(reverse_normal.zone_a == nil, "A normal link into a landing must not reverse the drop")
end

local function test_invalid_links()
    local cases = {
        {link = 42, expected = "Warp link must be an object"},
        {link = {"warp_a", "warp_b"}, expected = "Unknown Warp link type"},
        {link = {type = "unknown", warps = {"warp_a", "warp_b"}}, expected = "Unknown Warp link type"},
        {link = {type = "normal"}, expected = "exactly two Warp IDs"},
        {link = {type = "drop", warps = {"warp_a"}}, expected = "exactly two Warp IDs"},
        {link = {type = "drop", warps = {"warp_a", "warp_b", "warp_c"}}, expected = "exactly two Warp IDs"},
        {link = {type = "normal", warps = {"", "warp_b"}}, expected = "non-empty strings"},
        {link = {type = "drop", warps = {42, "warp_b"}}, expected = "non-empty strings"},
        {link = {type = "drop", warps = {"warp_a", "warp_a"}}, expected = "must be distinct"},
    }
    for _, case in ipairs(cases) do
        local ok, message = pcall(World.build_indexes, {
            containers = {}, connections = {}, portals = {case.link},
        })
        assert(not ok, "Invalid Warp links must be rejected")
        assert(type(message) == "string", "Invalid links must produce a string error")
        assert(string.find(message, case.expected, 1, true), "Unexpected error: " .. message)
    end
end

local function test_conflicting_departures()
    local cases = {
        {
            {type = "drop", warps = {"warp_a", "warp_b"}},
            {type = "drop", warps = {"warp_a", "warp_c"}},
        },
        {
            {type = "normal", warps = {"warp_a", "warp_b"}},
            {type = "drop", warps = {"warp_b", "warp_c"}},
        },
        {
            {type = "normal", warps = {"warp_a", "warp_b"}},
            {type = "normal", warps = {"warp_b", "warp_a"}},
        },
    }
    for _, links in ipairs(cases) do
        local ok, message = pcall(World.build_indexes, {
            containers = {}, connections = {}, portals = links,
        })
        assert(not ok, "A Warp may not have duplicate or conflicting outgoing links")
        assert(type(message) == "string", "Conflicts must produce a string error")
        assert(string.find(message, "Duplicate index entry:", 1, true), "Unexpected error: " .. message)
    end
end

test_drop_direction_and_shared_landings()
test_invalid_links()
test_conflicting_departures()

print("Typed Warp link tests passed.")
