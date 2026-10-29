local Versions = {}

function Versions.includes(entry, version)
    assert(version == "firered" or version == "leafgreen", "Unknown game version: " .. tostring(version))

    if entry.versions == nil then
        return true
    end

    for _, entry_version in ipairs(entry.versions) do
        if entry_version == version then
            return true
        end
    end

    return false
end

return Versions
