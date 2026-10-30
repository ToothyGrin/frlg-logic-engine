local Choices = {}

local function add_unique(index, id, value)
    assert(index[id] == nil, "Duplicate choice index entry: " .. tostring(id))
    index[id] = value
end

function Choices.build_indexes(world, data)
    world.choices = data.choices or {}
    world.choices_by_id = {}
    world.choice_by_source = {}
    world.choice_source_zones = {}
    world.pokemon_gifts = data.pokemon_gifts or {}
    world.pokemon_gifts_by_id = {}
    for _, gift in ipairs(world.pokemon_gifts) do
        add_unique(world.pokemon_gifts_by_id, gift.id, gift)
    end
    for _, zone in ipairs(world.zones) do
        for _, field in ipairs({"pokemon_gifts", "item_pickups", "item_sources"}) do
            for _, id in ipairs(zone[field] or {}) do
                if field == "pokemon_gifts" then
                    assert(world.pokemon_gifts_by_id[id], "Unknown Pokémon gift: " .. id)
                end
                local owners = world.choice_source_zones[id]
                if owners == nil then
                    owners = {}
                    world.choice_source_zones[id] = owners
                end
                -- A shared source may have several access Zones, each listed once.
                local present = false
                for _, owner in ipairs(owners) do
                    if owner == zone.id then present = true end
                end
                if not present then table.insert(owners, zone.id) end
            end
        end
    end
    for _, group in ipairs(world.choices) do
        assert(group.option_type == "pokemon_gift" or group.option_type == "item_pickup", "Unknown choice option type")
        assert(group.max_selections == 1, "Choice must allow exactly one selection")
        assert(type(group.options) == "table" and #group.options >= 2, "Choice requires at least two options")
        add_unique(world.choices_by_id, group.id, group)
        for _, id in ipairs(group.options) do
            assert(type(id) == "string" and world.choice_source_zones[id], "Choice option is not a declared source: " .. tostring(id))
            if group.option_type == "pokemon_gift" then
                assert(world.pokemon_gifts_by_id[id], "Choice option is not a Pokémon gift: " .. id)
            else
                assert(string.find(id, "item_pickup_", 1, true) == 1, "Choice option is not an item pickup: " .. id)
            end
            add_unique(world.choice_by_source, id, group)
        end
    end
end

function Choices.normalize(world, input)
    assert(input == nil or type(input) == "table", "Player choices must be a table")
    assert(input == nil or world ~= nil, "Choice input requires the indexed world")
    local normalized = {}
    -- As with supported boolean facts, only authored choice IDs are read.
    for _, group in ipairs(world and world.choices or {}) do
        local choice = input and input[group.id]
        if choice == nil then
            normalized[group.id] = {status = "unknown"}
        else
            assert(type(choice) == "table", "Choice state must be an object: " .. group.id)
            local status = choice.status
            assert(status == "unknown" or status == "unselected" or status == "selected", "Invalid choice status: " .. group.id)
            if status == "selected" then
                assert(type(choice.source) == "string" and world.choice_by_source[choice.source] == group,
                    "Selected source does not belong to choice: " .. group.id)
                normalized[group.id] = {status = status, source = choice.source}
            else
                assert(choice.source == nil, "Unresolved choice cannot carry a selected source: " .. group.id)
                normalized[group.id] = {status = status}
            end
        end
    end
    return normalized
end

function Choices.starter_identity(choices)
    local choice = choices.choice_oaks_lab_starter
    if choice == nil or choice.status ~= "selected" then return nil end
    -- Original slot identity, independent of reward contents and ROM memory addresses.
    local identities = {
        pokemon_gift_oaks_lab_starter_ball_1 = "bulbasaur",
        pokemon_gift_oaks_lab_starter_ball_2 = "squirtle",
        pokemon_gift_oaks_lab_starter_ball_3 = "charmander",
    }
    return identities[choice.source]
end

local function requirement_met(object, state)
    return object.requires == nil or state[object.requires] == true
end

local function access_zones(world, id, reachable)
    local zones = {}
    for _, zone_id in ipairs(world.choice_source_zones[id] or {}) do
        if reachable[zone_id] == true then table.insert(zones, zone_id) end
    end
    return zones
end

local function add_gift(result, gift, zones, obtained)
    local entry = {id = gift.id, pokemon = gift.pokemon, levels = {}, repeatable = gift.repeatable, zones = zones, obtained = obtained}
    for _, level in ipairs(gift.levels) do table.insert(entry.levels, level) end
    result.pokemon_gifts_by_id[gift.id] = entry
    result.species_available[gift.pokemon] = true
end

function Choices.apply(world, reachable, state, result)
    local choices = Choices.normalize(world, state.choices)
    result.choices_by_id = {}
    result.pokemon_gifts_by_id = {}
    result.starter_choice = Choices.starter_identity(choices)
    for _, group in ipairs(world.choices) do
        local choice = choices[group.id]
        local summary = {status = choice.status, source = choice.source, alternatives = {}, excluded = {}}
        result.choices_by_id[group.id] = summary
        for _, id in ipairs(group.options) do
            local gift = world.pokemon_gifts_by_id[id]
            local zones = access_zones(world, id, reachable)
            if choice.status == "selected" then
                if id == choice.source then
                    -- A confirmed selection is an acquired fact, even after leaving.
                    if group.option_type == "pokemon_gift" then add_gift(result, gift, zones, true) end
                else
                    table.insert(summary.excluded, id)
                end
            elseif choice.status == "unselected" and #zones > 0
                and requirement_met(group, state) and (gift == nil or requirement_met(gift, state)) then
                table.insert(summary.alternatives, id)
            end
        end
    end
    for _, gift in ipairs(world.pokemon_gifts) do
        if world.choice_by_source[gift.id] == nil then
            local zones = access_zones(world, gift.id, reachable)
            if #zones > 0 and requirement_met(gift, state) then add_gift(result, gift, zones, false) end
        end
    end
end

return Choices
