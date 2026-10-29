local Versions = require("logic.versions")

local Encounters = {}

local function copy_entry(entry)
    local copy = {pokemon = entry.pokemon, levels = {}, rate = entry.rate}
    for _, level in ipairs(entry.levels) do
        table.insert(copy.levels, level)
    end
    return copy
end

function Encounters.available(world, reachable, state, version)
    assert(version == "firered" or version == "leafgreen", "Unknown game version: " .. tostring(version))
    local result = {sources_by_id = {}, species_available = {}}

    -- The Zone list preserves file order; shared sources are evaluated only once.
    for _, zone in ipairs(world.zones) do
        if reachable[zone.id] == true then
            for _, source_id in ipairs(zone.encounter_sources or {}) do
                local source = assert(world.encounter_sources_by_id[source_id], "Unknown encounter source: " .. source_id)
                if source.requires == nil or state[source.requires] == true then
                    local available_source = result.sources_by_id[source_id]
                    if available_source == nil then
                        available_source = {id = source_id, method = source.method, zones = {}, encounters = {}}
                        for _, entry in ipairs(source.encounters) do
                            if Versions.includes(entry, version) then
                                table.insert(available_source.encounters, copy_entry(entry))
                                result.species_available[entry.pokemon] = true
                            end
                        end
                        result.sources_by_id[source_id] = available_source
                    end
                    table.insert(available_source.zones, zone.id)
                end
            end
        end
    end

    return result
end

return Encounters
