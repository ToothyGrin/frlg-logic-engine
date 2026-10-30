local World = require("logic.world")
local State = require("logic.state")
local Reachability = require("logic.reachability")
local Traversal = require("logic.traversal")
local read_json = require("logic.json_file")
local json = require("lib.dkjson")

local function reader(path)
    return read_json(path, function(contents)
        local value, _, message = json.decode(contents)
        assert(not message, message)
        return value
    end)
end

local function test_settlement_snapshots(world)
    local cases = {
        {name = "No flags", player = {}},
        {name = "Cut cannot bypass NPCs", player = {state_has_hm01_cut = true, state_has_cascade_badge = true}},
        {name = "Ticket opens both NPC approaches", ticket = true, player = {state_event_ss_ticket_acquired = true}},
        {name = "Surf opens bank but not guard", water = true, player = {state_has_hm03_surf = true, state_has_soul_badge = true}},
        {name = "Guard event does not grant bank access", player = {state_event_cerulean_cave_guard_cleared = true}},
        {name = "Surf and cleared guard", water = true, cave = true, player = {state_has_hm03_surf = true, state_has_soul_badge = true, state_event_cerulean_cave_guard_cleared = true}},
        {name = "All approaches open", water = true, cave = true, ticket = true, player = {
            state_event_ss_ticket_acquired = true, state_has_hm01_cut = true, state_has_cascade_badge = true,
            state_has_hm03_surf = true, state_has_soul_badge = true, state_event_cerulean_cave_guard_cleared = true,
        }},
    }
    local settlements = reader("data/world/containers/settlements.json")
    for _, case in ipairs(cases) do
        local reachable = Reachability.solve(world, "zone_cerulean_city", State.evaluate(case.player))
        local expected = {
            zone_cerulean_city = true,
            zone_cerulean_city_backyard = true,
            zone_cerulean_city_southeast = case.ticket == true,
            zone_cerulean_city_south_tree_approach = case.ticket == true,
            zone_cerulean_city_burgled_house_south_entrance = case.ticket == true,
            zone_cerulean_city_water = case.water == true,
            zone_cerulean_city_northwest_riverbank = case.water == true,
            zone_cerulean_city_cave_entrance = case.cave == true,
        }
        for _, settlement in ipairs(settlements) do
            if settlement.id == "cerulean_city" then
                for _, zone in ipairs(settlement.zones) do
                    assert(expected[zone.id] ~= nil, "Snapshot must account for every Cerulean settlement Zone: " .. zone.id)
                    assert((reachable[zone.id] == true) == expected[zone.id], case.name .. ": " .. zone.id)
                end
            end
        end
        assert((reachable.zone_cerulean_city_burgled_house == true) == (case.ticket == true), case.name .. ": house access")
    end
end

local function test_sequential_barriers(world)
    local tree = world.connections_by_id.conn_cerulean_city_southeast_cut_tree
    local npc = world.connections_by_id.conn_cerulean_city_south_tree_approach_event
    local approach = "zone_cerulean_city_south_tree_approach"
    assert(tree.zones[1] == approach, "The tree must start beyond the NPC barrier")
    for _, ticket in ipairs({false, true}) do
        for _, cut in ipairs({false, true}) do
            local state = State.evaluate({state_event_ss_ticket_acquired = ticket, state_has_hm01_cut = cut, state_has_cascade_badge = cut})
            local past_npc = Traversal.connection_destination(npc, "zone_cerulean_city", state)
            local past_tree = past_npc and Traversal.connection_destination(tree, past_npc, state)
            assert((past_tree == "zone_cerulean_city_southeast") == (ticket and cut), "The direct tree route requires ticket and usable Cut")
            assert((Traversal.connection_destination(tree, "zone_cerulean_city_southeast", state) == approach) == cut)
        end
    end
    assert(world.warp_to_zone.warp_cerulean_city_burgled_house_south_entrance.id == "zone_cerulean_city_burgled_house_south_entrance")
    assert(world.warp_to_zone.warp_cerulean_city_cave_entrance.id == "zone_cerulean_city_cave_entrance")
    assert(world.warp_to_destination.warp_cerulean_city_cave_entrance == nil, "Cave interior remains outside the authored slice")
end

local function test_recalculation_and_alternative_approach(world)
    local opened = Reachability.solve(world, "zone_cerulean_city", State.evaluate({state_event_ss_ticket_acquired = true}))
    local closed = Reachability.solve(world, "zone_cerulean_city", State.evaluate({}))
    assert(opened.zone_cerulean_city_burgled_house and not closed.zone_cerulean_city_burgled_house)
    assert(opened.zone_cerulean_city_southeast and not closed.zone_cerulean_city_southeast)
    assert(not closed.zone_cerulean_city_south_tree_approach)
    local bank = Reachability.solve(world, "zone_route_4_top", {})
    assert(bank.zone_cerulean_city_northwest_riverbank and not bank.zone_cerulean_city_cave_entrance)
    local cave = Reachability.solve(world, "zone_route_4_top", State.evaluate({state_event_cerulean_cave_guard_cleared = true}))
    assert(cave.zone_cerulean_city_cave_entrance, "Route 4's existing approach must remain usable without adding a Surf requirement")
    assert(not bank.zone_cerulean_city_cave_entrance, "Later calculations must preserve earlier results")
    for _, value in ipairs({"true", 1, {}}) do
        local state = State.evaluate({state_event_ss_ticket_acquired = value, state_event_cerulean_cave_guard_cleared = value})
        assert(state.state_event_ss_ticket_acquired == false and state.state_event_cerulean_cave_guard_cleared == false)
    end
    assert(State.evaluate({state_has_ss_ticket = true, state_has_boulder_badge = true}).state_event_ss_ticket_acquired == false,
        "Inventory and unrelated badges must not infer the ticket event")
    assert(State.evaluate({state_event_indigo_league_defeated = true}).state_event_cerulean_cave_guard_cleared == false,
        "Guard removal is supplied explicitly until its derivation is verified")
end

local world = World.load(reader)
test_settlement_snapshots(world)
test_sequential_barriers(world)
test_recalculation_and_alternative_approach(world)
print("Cerulean NPC gate tests passed.")
