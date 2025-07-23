-- available tile types
local TileType = {
    RED = "RED",
    ORANGE = "ORANGE",
    YELLOW = "YELLOW",
    GREEN = "GREEN",
    BLUE = "BLUE",
    PURPLE = "PURPLE",
}

-- Ordered list of tile types (useful for deterministic iteration)
TileType.ORDERED = {
    TileType.RED,
    TileType.ORANGE,
    TileType.YELLOW,
    TileType.GREEN,
    TileType.BLUE,
    TileType.PURPLE,
}

function TileType.emitBadTileTypeError(invalidType)
    error(
        "Invalid tile type: " .. tostring(invalidType) .. ". Must be one of: " .. table.concat(TileType.ORDERED, ", ")
    )
end

return TileType
