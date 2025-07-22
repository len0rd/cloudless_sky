-- Represents a bag of tiles.
-- For instance the draw bag or the discard
local TileType = require("cloudless_sky.model.tile_type")
local Object = require("cloudless_sky.extern.classic")
local TileBag = Object:extend()

-- @param gameRng The random generator being used by the game
function TileBag:new(gameRng)
    -- tracks how many of each tile type is present in the bag. Start with all 0's
    self.tileCounts = {}
    self.gameRng = gameRng
    for i = 1, #TileType.ORDERED do
        table.insert(self.tileCounts, 0)
    end
end

--- Get the number of tiles in this bag for the given TileType
function TileBag:num(tileType)
    for ii, validTileType in ipairs(TileType.ORDERED) do
        if tileType == validTileType then
            return self.tileCounts[ii]
        end
    end
    -- bad type if here
    TileType.emitBadTileTypeError(type)
end

--- Get the total number of all tiles in this bag
function TileBag:total()
    local total = 0
    for _, count in ipairs(self.tileCounts) do
        total = total + count
    end
    return total
end

--- Return true if total == 0
function TileBag:empty()
    return self:total() == 0
end

--- From the tiles currently in this bag, "take" a random one.
--- "Take" means the tile is removed from the bag when returned by this function
---
-- @return TileType - Type of the tile taken from the bag. Or nil if the bag is empty
function TileBag:takeRandomTile()
    if self:empty() then
        return nil
    end
    -- treat the tiles in the bag as one big list and choose an index within it
    -- this means that if there is more of a particular tile in the bag its more
    -- likely to be picked
    local idx = self.gameRng:random(1, self:total())
    -- now start counting up. once the totalCount is >= the random index,
    -- the type to remove has been found.
    local count = 0
    for tileTypeIdx, typeCount in ipairs(self.tileCounts) do
        count = count + typeCount
        if count >= idx then
            self.tileCounts[tileTypeIdx] = self.tileCounts[tileTypeIdx] - 1
            return TileType.ORDERED[tileTypeIdx]
        end
    end
    -- this shouldnt happen
    error("Somehow made it to the end of the takeRandomTile function?? " .. idx .. " " .. count)
    return nil
end

--- Add \p count number of \p tileType tiles to this bag
function TileBag:addTiles(tileType, count)
    for ii, validTileType in ipairs(TileType.ORDERED) do
        if tileType == validTileType then
            self.tileCounts[ii] = self.tileCounts[ii] + count
            return
        end
    end
    -- shouldnt get here
    TileType.emitBadTileTypeError(type)
end

--- Add single tile of given TileType to this bag
function TileBag:addTile(tileType)
    self:addTiles(tileType, 1)
end

--- Set number of tiles of type \p tileType in this bag
-- @param tileType string The type of tile to set the count of. Must be one of TileType
-- @param count integer Number of tiles to set the tileType to in this bag
function TileBag:setCountForTileType(tileType, count)
    for ii, validTileType in ipairs(TileType.ORDERED) do
        if tileType == validTileType then
            self.tileCounts[ii] = count
            return
        end
    end
    -- shouldnt get here
    TileType.emitBadTileTypeError(type)
end

return TileBag
