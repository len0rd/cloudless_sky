--- Describes a combination of tiles in the players hand that could be used to place a tile in a particular slot
--- Just exists as a type for better documentation
local Object = require("cloudless_sky.extern.classic")
local PlacementPossibility = Object:extend()

function PlacementPossibility:new(tileType, tileCount, wildType, wildCount)
    --- type of tile to use for the slot
    self.tileType = tileType
    --- how many of @ref tileType are needed
    self.tileCount = tileCount
    --- The current wildType
    self.wildType = wildType
    --- How many wilds would be needed to make this placement valid
    self.wildCount = wildCount or 0
end

function PlacementPossibility:toTable()
    return {
        tileType = self.tileType,
        tileCount = self.tileCount,
        wildType = self.wildType,
        wildCount = self.wildCount,
    }
end

--- Override equality operator
function PlacementPossibility:__eq(other)
    return self.tileType == other.tileType
        and self.tileCount == other.tileCount
        and self.wildType == other.wildType
        and self.wildCount == other.wildCount
end

return PlacementPossibility
