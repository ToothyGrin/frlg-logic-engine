local World = require("logic.world")
local State = require("logic.state")
local Reachability = require("logic.reachability")
local read_json = require("logic.json_file")
local json = require("lib.dkjson")
local specification = require("tests.fixtures.phase2_expected")

local areas = {"pallet_town", "route_1", "viridian_city", "route_2", "viridian_forest", "pewter_city", "route_3", "mt_moon", "route_4", "cerulean_city"}
local group_names = {"southern_land", "north_of_old_man", "route_2_east", "museum_back", "tutor_island", "southern_water",
    "route_3_and_west_route_4", "mt_moon", "route_4_middle", "cerulean_land", "ticket_access", "eastern_water",
    "riverbank_and_upper_route_4", "cave_doorway"}

local function reader(path)
    return read_json(path, function(contents)
        local value, _, message = json.decode(contents)
        assert(not message, message)
        return value
    end)
end

local function build_scope(world)
    local containers_in_scope = {}
    local expected_containers = {}
    for _, area in ipairs(areas) do
        for _, id in ipairs(specification.areas[area]) do
            assert(containers_in_scope[id] == nil, "Container listed twice in slice: " .. id)
            containers_in_scope[id] = true
            table.insert(expected_containers, id)
        end
    end
    local found = {}
    local scope = {}
    local scope_by_id = {}
    for _, kind in ipairs({"buildings", "instances", "routes", "settlements"}) do
        for _, container in ipairs(reader("data/world/containers/" .. kind .. ".json")) do
            if containers_in_scope[container.id] then
                found[container.id] = true
                for _, zone in ipairs(container.zones) do
                    assert(world.zones_by_id[zone.id], "Scope Zone is absent from world: " .. zone.id)
                    scope_by_id[zone.id] = true
                    table.insert(scope, zone.id)
                end
            end
        end
    end
    for _, id in ipairs(expected_containers) do assert(found[id], "Slice container is missing: " .. id) end

    -- Every in-scope Zone must have a manually assigned expectation group.
    local inventory = {}
    for _, name in ipairs(group_names) do
        for _, id in ipairs(specification.groups[name]) do
            assert(scope_by_id[id], "Snapshot contains an unknown or out-of-scope Zone: " .. id)
            assert(inventory[id] == nil, "Snapshot inventory repeats Zone: " .. id)
            inventory[id] = true
        end
    end
    for _, id in ipairs(scope) do assert(inventory[id], "New slice Zone needs explicit snapshot expectations: " .. id) end
    return scope
end

local function expected_set(case)
    local expected = {}
    for _, name in ipairs(case.groups) do
        local group = assert(specification.groups[name], "Unknown expected group: " .. name)
        for _, id in ipairs(group) do
            assert(expected[id] == nil, "Case repeats expected Zone: " .. id)
            expected[id] = true
        end
    end
    -- Every in-scope Zone absent here is explicitly expected to be unreachable.
    return expected
end

local function differences(scope, expected, actual)
    local problems = {}
    for _, id in ipairs(scope) do
        if expected[id] == true and actual[id] ~= true then
            table.insert(problems, "Missing reachable Zone: " .. id)
        elseif expected[id] ~= true and actual[id] == true then
            table.insert(problems, "Unexpected reachable Zone: " .. id)
        end
    end
    return problems
end

local function assert_snapshot(scope, expected, actual, name)
    local problems = differences(scope, expected, actual)
    assert(#problems == 0, name .. "\n" .. table.concat(problems, "\n"))
end

local function player_facts(case)
    local player = {}
    for _, flag in ipairs(case.flags or {}) do
        for _, id in ipairs(assert(specification.flag_facts[flag], "Unknown fixture flag: " .. flag)) do
            player[id] = true
        end
    end
    for _, id in ipairs(case.facts or {}) do player[id] = true end
    return player
end

local function test_phase2_snapshots()
    local world = World.load(reader)
    local scope = build_scope(world)
    local results = {}
    local observed = {}
    local blocked = {}
    for _, case in ipairs(specification.snapshots) do
        local player = player_facts(case)
        local state = State.evaluate(player)
        local actual = Reachability.solve(world, case.start or "zone_players_house", state)
        local expected = expected_set(case)
        assert_snapshot(scope, expected, actual, case.name)
        table.insert(results, {case = case, expected = expected, actual = actual})
        for _, id in ipairs(scope) do
            if actual[id] == true then observed[id] = true else blocked[id] = true end
        end
    end
    for _, id in ipairs(scope) do assert(observed[id], "No positive snapshot covers Zone: " .. id) end
    for _, id in ipairs(scope) do assert(blocked[id], "No negative snapshot covers Zone: " .. id) end
    for _, result in ipairs(results) do
        assert_snapshot(scope, result.expected, result.actual, "Preserved result: " .. result.case.name)
    end

    -- Prove that the comparator catches omissions and false positives, rather than
    -- merely checking a few selected landmarks. These are local test mutations only.
    local initial = results[1]
    local damaged = {}
    for _, id in ipairs(scope) do damaged[id] = initial.actual[id] end
    damaged.zone_players_house = nil
    assert(#differences(scope, initial.expected, damaged) == 1, "A missing Zone must fail comparison")
    damaged.zone_players_house = true
    damaged.zone_route_3 = true
    assert(#differences(scope, initial.expected, damaged) == 1, "An unexpected Zone must fail comparison")

    print("Phase 2 snapshots passed: " .. #specification.snapshots .. " complete sets across " .. #scope .. " Zones in 10 areas.")
end

test_phase2_snapshots()
