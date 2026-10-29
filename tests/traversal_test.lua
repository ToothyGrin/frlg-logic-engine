local Traversal = require("logic.traversal")

local function test_connection_destination()
    local cases = {
        {
            name = "border forward",
            type = "border",
            from = "zone_a",
            state = {},
            expected = "zone_b",
        },
        {
            name = "border backward",
            type = "border",
            from = "zone_b",
            state = {},
            expected = "zone_a",
        },
        {
            name = "unrelated starting Zone",
            type = "border",
            from = "zone_elsewhere",
            state = {},
            expected = nil,
        },
        {
            name = "ledge forward",
            type = "ledge",
            from = "zone_a",
            state = {},
            expected = "zone_b",
        },
        {
            name = "ledge backward",
            type = "ledge",
            from = "zone_b",
            state = {},
            expected = nil,
        },
        {
            name = "Cut requirement missing",
            type = "cut_tree",
            requires = "state_can_cut",
            from = "zone_a",
            state = {},
            expected = nil,
        },
        {
            name = "Cut requirement false",
            type = "cut_tree",
            requires = "state_can_cut",
            from = "zone_a",
            state = { state_can_cut = false },
            expected = nil,
        },
        {
            name = "Cut requirement met forward",
            type = "cut_tree",
            requires = "state_can_cut",
            from = "zone_a",
            state = { state_can_cut = true },
            expected = "zone_b",
        },
        {
            name = "Cut requirement met backward",
            type = "cut_tree",
            requires = "state_can_cut",
            from = "zone_b",
            state = { state_can_cut = true },
            expected = "zone_a",
        },
        {
            name = "Surf requirement unmet",
            type = "water",
            requires = "state_can_surf",
            from = "zone_a",
            state = {},
            expected = nil,
        },
        {
            name = "Surf requirement met",
            type = "water",
            requires = "state_can_surf",
            from = "zone_a",
            state = { state_can_surf = true },
            expected = "zone_b",
        },
    }

    table.insert(cases, {
        name = "Surf requirement met backward",
        type = "water",
        requires = "state_can_surf",
        from = "zone_b",
        state = {state_can_surf = true},
        expected = "zone_a",
    })
    table.insert(cases, {
        name = "truthy values are not boolean capabilities",
        type = "cut_tree",
        requires = "state_can_cut",
        from = "zone_a",
        state = {state_can_cut = "true"},
        expected = nil,
    })

    for _, case in ipairs(cases) do
        local connection = {
            id = "conn_test",
            type = case.type,
            zones = { "zone_a", "zone_b" },
            requires = case.requires,
        }

        local actual = Traversal.connection_destination(
            connection,
            case.from,
            case.state
        )

        assert(
            actual == case.expected,
            case.name
            .. ": expected " .. tostring(case.expected)
            .. ", got " .. tostring(actual)
        )
    end
end

local function test_unknown_connection_type()
    local connection = {
        id = "conn_unknown",
        type = "unknown",
        zones = { "zone_a", "zone_b" },
    }

    local ok, message = pcall(
        Traversal.connection_destination,
        connection,
        "zone_a",
        {}
    )

    assert(not ok, "Unknown Connection type should have failed")
    assert(
        type(message) == "string",
        "Unknown Connection type should produce a string error"
    )
    assert(
        string.find(message, "Unknown Connection type: unknown", 1, true),
        "Unexpected error: " .. message
    )
end

test_connection_destination()
test_unknown_connection_type()

print("Connection traversal tests passed.")
