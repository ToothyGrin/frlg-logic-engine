local function read_json(path, decode_json)
    local file, open_error = io.open(path, "r")
    assert(file, open_error)

    local contents, read_error = file:read("*a")
    file:close()
    assert(contents, read_error)

    return decode_json(contents)
end

return read_json
