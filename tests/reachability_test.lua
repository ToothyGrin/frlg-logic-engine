local World = require("logic.world")
local Reachability = require("logic.reachability")

local function test_reachability()
    local data = {
        containers = {
            {
                id = "container_test",
                zones = {
                    {
                        id = "zone_a",
                        connections = { "conn_a_b" },
                        warps = {},
                    },
                    {
                        id = "zone_b",
                        connections = { "conn_a_b", "conn_b_c" },
                        warps = {},
                    },
                    {
                        id = "zone_c",
                        connections = { "conn_b_c" },
                        warps = { "warp_c" },
                    },
                    {
                        id = "zone_d",
                        connections = {},
                        warps = { "warp_d" },
                    },
                },
            },
        },
        connections = {
            {
                id = "conn_a_b",
                type = "border",
                zones = { "zone_a", "zone_b" },
            },
            {
                id = "conn_b_c",
                type = "cut_tree",
                zones = { "zone_b", "zone_c" },
                requires = "state_can_cut",
            },
        },
        portals = {
            { "warp_c", "warp_d" },
        },
    }

    local world = World.build_indexes(data)

    local before_cut = Reachability.solve(world, "zone_a", {})

    assert(before_cut.zone_a, "Starting Zone should be reachable")
    assert(before_cut.zone_b, "Open border should be traversable")
    assert(before_cut.zone_c == nil, "Cut should block Zone C")
    assert(before_cut.zone_d == nil, "Blocked path should prevent reaching Portal")

    local after_cut = Reachability.solve(
        world,
        "zone_a",
        { state_can_cut = true }
    )

    assert(after_cut.zone_a, "Starting Zone should remain reachable")
    assert(after_cut.zone_b, "Zone B should remain reachable")
    assert(after_cut.zone_c, "Cut should allow reaching Zone C")
    assert(after_cut.zone_d, "Portal should allow reaching Zone D")

    local from_d = Reachability.solve(world, "zone_d", {})

    assert(from_d.zone_d, "Zone D should be reachable when starting there")
    assert(from_d.zone_c, "Portal should work in reverse")
    assert(from_d.zone_b == nil, "Cut should also block reverse traversal")
    assert(from_d.zone_a == nil, "Zone A should remain behind the Cut requirement")

    local cut_removed = Reachability.solve(world, "zone_a", {})

    assert(cut_removed.zone_c == nil, "Recalculation should remove access to Zone C")
    assert(cut_removed.zone_d == nil, "Recalculation should remove access to Zone D")
    assert(after_cut.zone_d, "Earlier results should remain unchanged")
end

local function test_ledge_and_parallel_paths()
    local world = World.build_indexes({
        containers = {{zones = {
            {id = "zone_a", connections = {"conn_cut", "conn_ledge"}, warps = {}},
            {id = "zone_b", connections = {"conn_cut", "conn_ledge"}, warps = {}},
        }}},
        connections = {
            {id = "conn_cut", type = "cut_tree", zones = {"zone_a", "zone_b"}, requires = "state_can_cut"},
            {id = "conn_ledge", type = "ledge", zones = {"zone_b", "zone_a"}},
        },
        portals = {},
    })

    local uphill = Reachability.solve(world, "zone_a", {})
    assert(uphill.zone_b == nil, "A reverse ledge must not bypass the Cut requirement")

    local downhill = Reachability.solve(world, "zone_b", {})
    assert(downhill.zone_a, "An open ledge must work even when the parallel Cut path is blocked")

    local with_cut = Reachability.solve(world, "zone_a", {state_can_cut = true})
    assert(with_cut.zone_b, "Cut must provide an alternative to the reverse ledge")
end

local function test_incomplete_destinations()
    local world = World.build_indexes({
        containers = {{zones = {
            {
                id = "zone_a",
                connections = {"conn_missing_destination"},
                warps = {"warp_unpaired", "warp_paired"},
            },
        }}},
        connections = {
            {id = "conn_missing_destination", type = "border", zones = {"zone_a", "zone_missing"}},
        },
        portals = {{"warp_paired", "warp_missing"}},
    })

    local reachable = Reachability.solve(world, "zone_a", {})
    assert(reachable.zone_a, "Incomplete exits must not prevent reaching the starting Zone")
    assert(reachable.zone_missing == nil, "Unauthored destinations must not be marked reachable")

    local isolated_world = World.build_indexes({
        containers = {{zones = {{id = "zone_alone", connections = {}, warps = {}}}}},
        connections = {},
        portals = {},
    })
    local isolated = Reachability.solve(isolated_world, "zone_alone", {})
    assert(isolated.zone_alone, "An isolated starting Zone must be reachable")
end

local function test_invalid_references()
    local world = World.build_indexes({
        containers = {{zones = {{id = "zone_a", connections = {"conn_missing"}, warps = {}}}}},
        connections = {},
        portals = {},
    })

    local cases = {
        {start = "zone_missing", expected = "Unknown starting Zone: zone_missing"},
        {start = "zone_a", expected = "Unknown Connection: conn_missing"},
    }

    for _, case in ipairs(cases) do
        local ok, message = pcall(Reachability.solve, world, case.start, {})
        assert(not ok, "Invalid references should fail")
        assert(type(message) == "string", "Invalid references should produce a string error")
        assert(string.find(message, case.expected, 1, true), "Unexpected error: " .. message)
    end
end

test_reachability()
test_ledge_and_parallel_paths()
test_incomplete_destinations()
test_invalid_references()

print("Reachability tests passed.")
