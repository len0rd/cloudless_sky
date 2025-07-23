-- StarType extends TileType with a few additional values
local TileType = require("cloudless_sky.model.tile_type")

local StarType = {}

-- Copy all key-value pairs from TileType
for k, v in pairs(TileType) do
    StarType[k] = v
end

-- Add the additional value

-- multi-colored stars require each tile to be a different color
StarType.MULTI = "MULTI"
-- monochrome stars dont have a color assigned until the user places their first and second tiles.
-- At which point it can become any of the other star types
StarType.MONO = "MONO"
-- for the multi-colored star in Glazed Pavillion where each slot has a defined color
StarType.MULTI_STATIC = "MULTI_STATIC"

-- Ordered list of star types (deterministic iteration)
StarType.ORDERED = {}
for _, v in ipairs(TileType.ORDERED) do
    table.insert(StarType.ORDERED, v)
end
table.insert(StarType.ORDERED, StarType.MULTI)
table.insert(StarType.ORDERED, StarType.MONO)
table.insert(StarType.ORDERED, StarType.MULTI_STATIC)

function StarType.emitBadStarTypeError(invalidType)
    error(
        "Invalid star type: " .. tostring(invalidType) .. ". Must be one of: " .. table.concat(StarType.ORDERED, ", ")
    )
end

return StarType
