local Encounters = require("logic.encounters")
local Versions = require("logic.versions")
local Choices = require("logic.choices")

local Acquisitions = {}

local function copy_entry(entry)
    local copy = {
        pokemon = entry.pokemon,
        requested_pokemon = entry.requested_pokemon,
        level_rule = entry.level_rule,
        held_item = entry.held_item,
        item = entry.item,
        quantity = entry.quantity,
        price = entry.price,
        currency = entry.currency,
        repeatable = entry.repeatable,
    }
    if entry.levels ~= nil then
        copy.levels = {}
        for _, level in ipairs(entry.levels) do
            table.insert(copy.levels, level)
        end
    end
    return copy
end

local function collect_sources(world, reachable, state, version, kind)
    local by_id = {}
    local ordered = {}
    local field = "offers"
    if kind == "pokemon_trades" then
        field = "exchanges"
    end

    for _, zone in ipairs(world.zones) do
        if reachable[zone.id] == true then
            for _, id in ipairs(zone[kind] or {}) do
                local source = assert(world[kind .. "_by_id"][id], "Unknown acquisition source: " .. id)
                if source.requires == nil or state[source.requires] == true then
                    local available = by_id[id]
                    if available == nil then
                        available = {id = id, zones = {}}
                        available[field] = {}
                        for _, entry in ipairs(source[field]) do
                            if Versions.includes(entry, version) then
                                table.insert(available[field], copy_entry(entry))
                            end
                        end
                        by_id[id] = available
                        table.insert(ordered, available)
                    end
                    table.insert(available.zones, zone.id)
                end
            end
        end
    end
    return ordered
end

function Acquisitions.available(world, reachable, state, version)
    -- The wild result is already fresh and validates the selected game.
    local result = Encounters.available(world, reachable, state, version)
    result.pokemon_vendors_by_id = {}
    result.item_vendors_by_id = {}
    result.pokemon_trades_by_id = {}
    result.items_available = {}

    for _, source in ipairs(collect_sources(world, reachable, state, version, "pokemon_vendors")) do
        if #source.offers > 0 then
            result.pokemon_vendors_by_id[source.id] = source
            for _, offer in ipairs(source.offers) do
                result.species_available[offer.pokemon] = true
            end
        end
    end
    for _, source in ipairs(collect_sources(world, reachable, state, version, "item_vendors")) do
        if #source.offers > 0 then
            result.item_vendors_by_id[source.id] = source
            for _, offer in ipairs(source.offers) do
                result.items_available[offer.item] = true
            end
        end
    end

    Choices.apply(world, reachable, state, result)

    local trades = collect_sources(world, reachable, state, version, "pokemon_trades")
    local changed = true
    while changed do
        changed = false
        for _, source in ipairs(trades) do
            if result.pokemon_trades_by_id[source.id] == nil then
                for _, exchange in ipairs(source.exchanges) do
                    if result.species_available[exchange.requested_pokemon] == true then
                        result.pokemon_trades_by_id[source.id] = source
                        if result.species_available[exchange.pokemon] ~= true then
                            result.species_available[exchange.pokemon] = true
                            changed = true
                        end
                        if exchange.held_item ~= nil then
                            result.items_available[exchange.held_item] = true
                        end
                    end
                end
            end
        end
    end
    return result
end

return Acquisitions
