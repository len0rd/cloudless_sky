-- available tile types
local TileType = {
    RED = "red",
    ORANGE = "orange",
    YELLOW = "yellow",
    GREEN = "green",
    BLUE = "blue",
    PURPLE = "purple",
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
