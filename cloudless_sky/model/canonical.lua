--- Order-independent encoding and comparison of plain Lua data (eg: serialized game state).
--- Table keys are sorted, so two tables with the same contents always encode the same way
local Canonical = {}

local function sortedKeys(value)
    local keys = {}
    for k in pairs(value) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function encodeInto(value, parts)
    local kind = type(value)
    if kind ~= "table" then
        table.insert(parts, kind:sub(1, 1) .. tostring(value))
        return
    end
    table.insert(parts, "{")
    for _, k in ipairs(sortedKeys(value)) do
        table.insert(parts, tostring(k) .. "=")
        encodeInto(value[k], parts)
        table.insert(parts, ",")
    end
    table.insert(parts, "}")
end

--- @param value any plain data: tables, strings, numbers, booleans
--- @return string canonical encoding of \p value
function Canonical.encode(value)
    local parts = {}
    encodeInto(value, parts)
    return table.concat(parts)
end

--- @return string 8 hex digit hash (djb2) of \p str
function Canonical.hash(str)
    local hash = 5381
    for ii = 1, #str do
        hash = (hash * 33 + str:byte(ii)) % 4294967296
    end
    return string.format("%08x", hash)
end

--- Find the first difference between \p a and \p b. Keys are visited in sorted order, so the result
--- is the same every time.
--- Table keys are compared as strings (tostring), so { [1] = x } matches { ["1"] = x }. JSON
--- turns some number keys into strings, and that shouldn't count as a difference
--- @param path string|nil prefix for the reported path (default "")
--- @return string|nil difference eg: "players.1.score: 7 ~= 6". nil if \p a and \p b are the same
function Canonical.diff(a, b, path)
    path = path or ""
    if type(a) ~= "table" or type(b) ~= "table" then
        if type(a) == type(b) and a == b then
            return nil
        end
        return string.format("%s: %s ~= %s", path == "" and "(root)" or path, tostring(a), tostring(b))
    end

    local byName = {}
    for k, v in pairs(a) do
        byName[tostring(k)] = { a = v }
    end
    for k, v in pairs(b) do
        local name = tostring(k)
        byName[name] = byName[name] or {}
        byName[name].b = v
    end
    for _, name in ipairs(sortedKeys(byName)) do
        local pair = byName[name]
        local diff = Canonical.diff(pair.a, pair.b, path == "" and name or (path .. "." .. name))
        if diff then
            return diff
        end
    end
    return nil
end

return Canonical
