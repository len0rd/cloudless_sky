--- The bonus pool on the table: a circular cluster of tiles (RingLayout) on a backing disc, one slot
--- per tile the pool holds (GameRules.bonusSurrounds.numBonusTiles). Empty slots show as faint
--- outlines, so it's clear how many are missing.
---
--- It has the same tile container interface as TileGroupView (addTile, receiveTile, removeTiles,
--- counts, tileAt, drawTiles) so the table's model sync and fly-in animation work for both.
---
--- The cluster can be drawn at any size: setPlacement moves its center and sets its scale (1 = tiles
--- at tileSize). Tiles in their slot follow; tiles flying in (targetX set) keep their tweened position
--- until they land.
local Object = require("cloudless_sky.extern.classic")
local RingLayout = require("cloudless_sky.view.ring_layout")
local TileGroupView = require("cloudless_sky.view.tile_group_view")
local TileType = require("cloudless_sky.model.tile_type")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class BonusPoolView : Object
---@field x number world x of the cluster's center
---@field y number world y of the cluster's center
---@field scale number draw scale of the tiles (1 = tileSize)
---@field tileSize number tile size at scale 1
---@field slots table[] RingLayout slots {x, y, rot}, in tile sizes from the center
---@field tiles VisualTile[] tiles in the pool. Each has .slot, its index in slots
local BonusPoolView = Object:extend()

-- disc around the tiles, in tile sizes
local DISC_PAD = 0.25
local DISC_COLOR = { 0.86, 0.83, 0.75, 1 }
local DISC_OUTLINE_COLOR = { 0.35, 0.3, 0.25, 1 }
local EMPTY_SLOT_COLOR = { 0.35, 0.3, 0.25, 0.35 }

--- @param numSlots integer how many tiles the pool holds
--- @param tileSize number tile size at scale 1
function BonusPoolView:new(numSlots, tileSize)
    self.slots, self.layoutRadius = RingLayout.slots(numSlots)
    self.tileSize = tileSize
    self.tiles = {}
    self.x, self.y, self.scale = 0, 0, 1
end

--- @return number world radius of the disc drawn at \p scale (default: the current scale)
function BonusPoolView:radiusAt(scale)
    return (self.layoutRadius + DISC_PAD) * self.tileSize * (scale or self.scale)
end

--- @return number world radius of the disc as drawn now
function BonusPoolView:radius()
    return self:radiusAt(self.scale)
end

--- Move the cluster's center to (x, y) and draw its tiles at \p scale
function BonusPoolView:setPlacement(x, y, scale)
    self.x, self.y, self.scale = x, y, scale
    for _, tile in ipairs(self.tiles) do
        if tile.targetX == nil then
            self:_moveToSlot(tile)
        end
    end
end

--- @return number x, number y, number rot. World position and rotation of slot \p idx
function BonusPoolView:slotPosition(idx)
    local slot = self.slots[idx]
    local unit = self.tileSize * self.scale
    return self.x + slot.x * unit, self.y + slot.y * unit, slot.rot
end

function BonusPoolView:_moveToSlot(tile)
    tile.x, tile.y, tile.rot = self:slotPosition(tile.slot)
end

--- @return integer|nil the first slot without a tile
function BonusPoolView:_freeSlot()
    local used = {}
    for _, tile in ipairs(self.tiles) do
        used[tile.slot] = true
    end
    for ii = 1, #self.slots do
        if not used[ii] then
            return ii
        end
    end
    return nil
end

--- Add a tile in the first free slot
--- @return VisualTile tile the tile added
function BonusPoolView:addTile(tileType)
    local tile = { tileType = tileType, slot = self:_freeSlot(), scale = 1, alpha = 1 }
    -- more tiles than slots shouldn't happen (the model fills to the slot count). Stack them on the
    -- last slot rather than lose them
    tile.slot = tile.slot or #self.slots
    self:_moveToSlot(tile)
    table.insert(self.tiles, tile)
    return tile
end

--- Add a tile in slot \p slot (eg: to match another view of the same pool). Falls back to the first
--- free slot when \p slot is nil or taken
--- @return VisualTile tile the tile added
function BonusPoolView:addTileAt(tileType, slot)
    local taken = slot == nil or slot > #self.slots
    for _, tile in ipairs(self.tiles) do
        taken = taken or tile.slot == slot
    end
    if taken then
        return self:addTile(tileType)
    end
    local tile = { tileType = tileType, slot = slot, scale = 1, alpha = 1 }
    self:_moveToSlot(tile)
    table.insert(self.tiles, tile)
    return tile
end

--- Add an existing tile (eg: one flying in from the bag). It is given the first free slot as its
--- target (tile.targetX, tile.targetY) and that slot's rotation, but its position is left alone so
--- the caller can tween it. Once it lands (targetX cleared) it follows its slot
--- @return VisualTile tile
function BonusPoolView:receiveTile(tile)
    tile.slot = self:_freeSlot() or #self.slots
    local rot
    tile.targetX, tile.targetY, rot = self:slotPosition(tile.slot)
    tile.rot = rot
    table.insert(self.tiles, tile)
    return tile
end

--- Remove a specific tile
BonusPoolView.removeTile = TileGroupView.removeTile

--- Remove up to \p count tiles of \p tileType, most recently added first
--- @param prefer VisualTile|nil remove this tile first if it matches
--- @return VisualTile[] removed
function BonusPoolView:removeTiles(tileType, count, prefer)
    -- same rules as a tile group
    return TileGroupView.removeTiles(self, tileType, count, prefer)
end

--- @return table TileType -> count of tiles in the pool (every TileType present, possibly 0)
function BonusPoolView:counts()
    return TileGroupView.counts(self)
end

--- @return boolean True if the world point is on the pool's disc
function BonusPoolView:contains(worldX, worldY)
    return ViewUtil.ptInCircle(worldX, worldY, self.x, self.y, self:radius())
end

--- @return VisualTile|nil tile The topmost tile under (worldX, worldY)
function BonusPoolView:tileAt(worldX, worldY)
    for ii = #self.tiles, 1, -1 do
        local tile = self.tiles[ii]
        if ViewUtil.ptInConvexPoly(self:_tilePoly(tile), worldX, worldY) then
            return tile
        end
    end
    return nil
end

function BonusPoolView:_tilePoly(tile)
    local size = self.tileSize * self.scale * tile.scale
    return TileView.betterPolyVerticies(size, tile.rot, tile.x - size / 2, tile.y - size / 2)
end

--- The disc and the outlines of empty slots
function BonusPoolView:drawBase()
    local r = self:radius()
    love.graphics.setColor(DISC_COLOR)
    love.graphics.circle("fill", self.x, self.y, r)
    love.graphics.setColor(DISC_OUTLINE_COLOR)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", self.x, self.y, r)

    local filled = {}
    for _, tile in ipairs(self.tiles) do
        filled[tile.slot] = true
    end
    local size = self.tileSize * self.scale
    for ii = 1, #self.slots do
        if not filled[ii] then
            local x, y, rot = self:slotPosition(ii)
            TileView.drawDiamond(x - size / 2, y - size / 2, size, rot, nil, EMPTY_SLOT_COLOR, 2)
        end
    end
end

--- @param highlight table|nil set of VisualTile -> true to outline. Highlighted tiles are drawn on top
function BonusPoolView:drawTiles(highlight)
    local size = self.tileSize * self.scale
    for _, tile in ipairs(self.tiles) do
        if not (highlight and highlight[tile]) then
            TileGroupView.drawTile(tile, size, false)
        end
    end
    if highlight then
        for _, tile in ipairs(self.tiles) do
            if highlight[tile] then
                TileGroupView.drawTile(tile, size, true)
            end
        end
    end
end

--- @return TileType[] \p counts (TileType -> count) as a list grouped by color (TileType.ORDERED), so
---     tiles added in this order sit together around the ring
function BonusPoolView.orderedList(counts)
    local list = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        for _ = 1, counts[tileType] or 0 do
            table.insert(list, tileType)
        end
    end
    return list
end

return BonusPoolView
