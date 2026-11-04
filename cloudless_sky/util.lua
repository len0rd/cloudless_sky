--- Global utility functions

--- create a copy of a table
--- https://github.com/nessan/lulu
function table.copy(obj)
    if type(obj) ~= "table" then
        return obj
    end

    -- Keep a cache of the tables we have already copied to avoid infinite recursion on cycles.
    cache = {}

    -- Workhorse function to copy a table. This is called recursively.
    local function process(tbl)
        -- If we have already copied this table, return the cached copy.
        if cache[tbl] then
            return cache[tbl]
        end

        -- Create a new table and store it in the cache under the `tbl` key.
        local retval = {}
        cache[tbl] = retval

        -- Copy the metatable if it exists.
        local mt = getmetatable(tbl)
        if mt then
            setmetatable(retval, mt)
        end

        -- Copy all the keys and values from `tbl` to `retval`. May recurse on the values.
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                retval[k] = process(v)
            else
                retval[k] = v
            end
        end

        return retval
    end

    -- Kick things off by processing the root table.
    return process(obj)
end

--- @return integer count. The number of key-value pairs in the given table
function table.count(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

--- Function that prints just the top-level strings, integers, and numbers in the given table
function table.shallowPrint(t)
    if type(t) ~= "table" then
        return "Error: Expected table, got " .. type(t)
    end

    local result = "table = {\n"

    for k, v in pairs(t) do
        local valueType = type(v)
        if valueType == "string" or valueType == "number" then
            local keyStr = type(k) == "string" and k or "[" .. tostring(k) .. "]"
            local valueStr = valueType == "string" and '"' .. v .. '"' or tostring(v)
            result = result .. "  " .. keyStr .. " = " .. valueStr .. "\n"
        end
    end

    result = result .. "}"
    return result
end
