local EUtil = {}

function EUtil.extendEntity(base, child)
    -- Preserve the original metatable and add PlayerMatEntity methods
    local originalMT = getmetatable(base)
    local newMT = {}

    -- Copy original metatable
    for k, v in pairs(originalMT) do
        newMT[k] = v
    end

    -- Add child methods to the __index
    local originalIndex = newMT.__index
    newMT.__index = function(t, k)
        -- First check child methods
        if child[k] then
            return child[k]
        end
        -- Then check original base methods
        if type(originalIndex) == "function" then
            return originalIndex(t, k)
        elseif originalIndex then
            return originalIndex[k]
        end
    end

    setmetatable(base, newMT)
end

return EUtil
