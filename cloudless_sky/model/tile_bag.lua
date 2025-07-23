-- Represents a bag of tiles.
-- For instance the draw bag or the discard
local TileType = require("cloudless_sky.model.tile_type")
local Object = require("cloudless_sky.extern.classic")
local TileBag = Object:extend()

--- @param gameRng RandomGenerator random generator being used by the game
--- @param startValue integer optional. Value to start the count of all TileTypes at. Default is 0
function TileBag:new(gameRng, startValue)
    -- tracks how many of each tile type is present in the bag. Start with all 0's
    local defaultValue = 0
    if startValue ~= nil then
        defaultValue = startValue
    end
    self.tileCounts = {}
    self.gameRng = gameRng
    for _, tileType in pairs(TileType.ORDERED) do
        self.tileCounts[tileType] = defaultValue
    end
end

--- Get the number of tiles in this bag for the given TileType
function TileBag:num(tileType)
    if self.tileCounts[tileType] ~= nil then
        return self.tileCounts[tileType]
    end

    -- bad type if here
    TileType.emitBadTileTypeError(type)
end

--- Get the total number of all tiles in this bag
function TileBag:total()
    local total = 0
    for _, count in pairs(self.tileCounts) do
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
--- @return TileType - Type of the tile taken from the bag. Or nil if the bag is empty
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
    -- use TileType.ORDERED for repeatable randomness
    local count = 0
    for _, tileType in pairs(TileType.ORDERED) do
        count = count + self.tileCounts[tileType]
        if count >= idx then
            self.tileCounts[tileType] = self.tileCounts[tileType] - 1
            return tileType
        end
    end
    -- this shouldnt happen
    error("Somehow made it to the end of the takeRandomTile function?? " .. idx .. " " .. count)
    return nil
end

--- Take \p count random tiles from the bag, or until its empty
function TileBag:takeRandomTiles(count)
    tiles = {}
    for ii = 1, count do
        local tile = self:takeRandomTile()
        if tile == nil then
            break
        end
        table.insert(tiles, tile)
    end
    return tiles
end

--- Take a tile of the given type from the bag (remove). Does nothing if there are
--- no tiles of that type
function TileBag:takeTile(tileType)
    if self.tileCounts[tileType] ~= nil then
        return self.tileCounts[tileType]
    end
end

--- Add \p count number of \p tileType tiles to this bag
function TileBag:addTiles(tileType, count)
    if self.tileCounts[tileType] ~= nil then
        self.tileCounts[tileType] = self.tileCounts[tileType] + count
        return
    end
    -- shouldnt get here
    TileType.emitBadTileTypeError(type)
end

--- Add the list of tileTypes to this bag
function TileBag:addTileList(tileTypes)
    for _, tile in pairs(tileTypes) do
        self:addTile(tile)
    end
end

--- Add single tile of given TileType to this bag
function TileBag:addTile(tileType)
    self:addTiles(tileType, 1)
end

--- Set number of tiles of type \p tileType in this bag
--- @param tileType string The type of tile to set the count of. Must be one of TileType
--- @param count integer Number of tiles to set the tileType to in this bag
function TileBag:setCountForTileType(tileType, count)
    if self.tileCounts[tileType] ~= nil then
        self.tileCounts[tileType] = count
        return
    end

    -- shouldnt get here
    TileType.emitBadTileTypeError(type)
end

return TileBag
