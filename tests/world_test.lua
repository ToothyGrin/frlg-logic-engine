local World = require("logic.world")

local function test_build_indexes()
    local zone_a = {
        id = "zone_a",
        warps = { "warp_a", "warp_unpaired" },
    }

    local zone_b = {
        id = "zone_b",
        warps = { "warp_b" },
    }

    local connection = {
        id = "conn_a_b",
        type = "border",
        zones = { "zone_a", "zone_b" },
        requires = nil,
    }

    local data = {
        containers = {
            { id = "container_a", zones = { zone_a } },
            { id = "container_b", zones = { zone_b } },
        },
        connections = { connection },
        portals = {
            { "warp_a", "warp_b" },
        },
    }

    local world = World.build_indexes(data)

    assert(world.zones_by_id.zone_a == zone_a)
    assert(world.zones_by_id.zone_b == zone_b)
    assert(world.connections_by_id.conn_a_b == connection)

    assert(world.warp_to_zone.warp_a == zone_a)
    assert(world.warp_to_zone.warp_b == zone_b)
    assert(world.warp_to_zone.warp_unpaired == zone_a)

    assert(world.warp_to_sibling.warp_a == "warp_b")
    assert(world.warp_to_sibling.warp_b == "warp_a")
    assert(world.warp_to_sibling.warp_unpaired == nil)
end

local function test_duplicate_rejection()
    local cases = {
        {
            name = "duplicate Zone ID",
            duplicate_id = "zone_a",
            data = {
                containers = {
                    {
                        zones = {
                            { id = "zone_a", warps = {} },
                            { id = "zone_a", warps = {} },
                        },
                    },
                },
                connections = {},
                portals = {},
            },
        },
        {
            name = "duplicate Connection ID",
            duplicate_id = "conn_a",
            data = {
                containers = {},
                connections = {
                    { id = "conn_a" },
                    { id = "conn_a" },
                },
                portals = {},
            },
        },
        {
            name = "duplicate Warp ownership",
            duplicate_id = "warp_a",
            data = {
                containers = {
                    {
                        zones = {
                            { id = "zone_a", warps = { "warp_a" } },
                            { id = "zone_b", warps = { "warp_a" } },
                        },
                    },
                },
                connections = {},
                portals = {},
            },
        },
        {
            name = "duplicate Portal membership",
            duplicate_id = "warp_a",
            data = {
                containers = {},
                connections = {},
                portals = {
                    { "warp_a", "warp_b" },
                    { "warp_a", "warp_c" },
                },
            },
        },
    }

    for _, case in ipairs(cases) do
        local ok, message = pcall(World.build_indexes, case.data)

        assert(not ok, case.name .. " should have failed")
        assert(
            type(message) == "string",
            case.name .. " should have produced a string error"
        )

        local expected = "Duplicate index entry: " .. case.duplicate_id
        assert(
            string.find(message, expected, 1, true),
            case.name .. " produced an unexpected error: " .. message
        )
    end
end

test_build_indexes()
test_duplicate_rejection()

print("World indexing tests passed.")
