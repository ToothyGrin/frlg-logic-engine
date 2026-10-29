local World = {}

local function add_unique(index, id, value)
    assert(index[id] == nil, "Duplicate index entry: " .. id)

    index[id] = value
end

function World.build_indexes(data)
    local world = {
        zones_by_id = {},
        connections_by_id = {},
        warp_to_zone = {},
        warp_to_sibling = {},
    }

    for _, container in ipairs(data.containers) do
        for _, zone in ipairs(container.zones) do
            -- Zone lookup:
            add_unique(world.zones_by_id, zone.id, zone)
            for _, warp_id in ipairs(zone.warps) do
                -- Warp ownership:
                add_unique(world.warp_to_zone, warp_id, zone)
            end
        end
    end

    for _, connection in ipairs(data.connections) do
        -- Connection lookup:
        add_unique(world.connections_by_id, connection.id, connection)
    end

    for _, portal in ipairs(data.portals) do
        local warp_a = portal[1]
        local warp_b = portal[2]

        -- Both Portal directions:
        add_unique(world.warp_to_sibling, warp_a, warp_b)
        add_unique(world.warp_to_sibling, warp_b, warp_a)
    end

    return world
end

function World.load(read_json)
    local container_paths = {
        "data/world/containers/buildings.json",
        "data/world/containers/instances.json",
        "data/world/containers/routes.json",
        "data/world/containers/settlements.json",
    }

    local data = {
        containers = {},
        connections = read_json("data/world/connections.json"),
        portals = read_json("data/world/portals.json"),
    }

    for _, path in ipairs(container_paths) do
        local containers = read_json(path)

        for _, container in ipairs(containers) do
            table.insert(data.containers, container)
        end
    end

    return World.build_indexes(data)
end

return World
