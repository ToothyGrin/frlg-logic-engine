local Traversal = {}

local connection_types = {
    border = true,
    cut_tree = true,
    water = true,
    ledge = true,
}

function Traversal.connection_destination(connection, from_zone_id, state)
    assert(
        connection_types[connection.type],
        "Unknown Connection type: " .. tostring(connection.type)
    )

    if connection.requires ~= nil
        and state[connection.requires] ~= true then
        return nil
    end

    local zone_a = connection.zones[1]
    local zone_b = connection.zones[2]

    if from_zone_id == zone_a then
        return zone_b
    elseif from_zone_id == zone_b and connection.type ~= "ledge" then
        return zone_a
    end

    return nil
end

return Traversal
