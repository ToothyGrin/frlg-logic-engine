local Traversal = require("logic.traversal")

local Reachability = {}

function Reachability.solve(world, starting_zone_id, state)
    assert(
        world.zones_by_id[starting_zone_id],
        "Unknown starting Zone: " .. tostring(starting_zone_id)
    )

    local reachable = {}
    local queue = {}
    local head = 1

    local function enqueue(zone_id)
        if zone_id == nil
            or world.zones_by_id[zone_id] == nil
            or reachable[zone_id] then
            return
        end

        reachable[zone_id] = true
        table.insert(queue, zone_id)
    end

    enqueue(starting_zone_id)

    while head <= #queue do
        local zone_id = queue[head]
        head = head + 1

        local zone = world.zones_by_id[zone_id]

        for _, connection_id in ipairs(zone.connections) do
            local connection = assert(
                world.connections_by_id[connection_id],
                "Unknown Connection: " .. connection_id
            )

            local destination_id = Traversal.connection_destination(
                connection,
                zone_id,
                state
            )

            enqueue(destination_id)
        end

        for _, warp_id in ipairs(zone.warps) do
            local destination_warp_id = world.warp_to_destination[warp_id]

            if destination_warp_id ~= nil then
                local destination_zone = world.warp_to_zone[destination_warp_id]

                if destination_zone ~= nil then
                    enqueue(destination_zone.id)
                end
            end
        end
    end

    return reachable
end

return Reachability
