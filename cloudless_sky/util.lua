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
