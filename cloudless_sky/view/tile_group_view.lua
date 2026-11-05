--- A loose group of tiles scattered inside a circle. Used for each factory display and the center
--- of the table.
---
--- This is visual state only: tile positions/rotations are random, from a view-only generator
--- (never the game's rng, so visuals can't change game results). The owning entity keeps the group's tile counts in step
--- with the model (see TableAreaEntity:syncFromModel)
local Object = require("cloudless_sky.extern.classic")
local TileType = require("cloudless_sky.model.tile_type")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class VisualTile
---@field tileType TileType
---@field x number world x of the tile's center
---@field y number world y of the tile's center
---@field rot number rotation in radians
---@field scale number draw scale (1 = tileSize)
---@field alpha number opacity 0-1

---@class TileGroupView : Object
---@field x number world x of the group's center
---@field y number world y of the group's center
---@field radius number radius of the group's circle
---@field tileSize number size of each tile
---@field tiles VisualTile[] tiles in draw order (last is on top)
local TileGroupView = Object:extend()

-- tiles try to stay at least this many tileSizes apart (center to center)
local MIN_SPACING = 0.6
-- placement attempts before settling for an overlapping spot
local PLACE_ATTEMPTS = 40

local HIGHLIGHT_COLOR = { 1, 1, 1, 1 }
local HIGHLIGHT_OUTLINE_COLOR = { 0, 0, 0, 1 }
local HIGHLIGHT_WIDTH = 4
local HIGHLIGHT_SCALE = 1.15

--- @param rng table|nil view-only random generator (love RandomGenerator). Defaults to a new one
function TileGroupView:new(x, y, radius, tileSize, rng)
    self.rng = rng or love.math.newRandomGenerator()
    self.x = x
    self.y = y
    self.radius = radius
    self.tileSize = tileSize
    self.tiles = {}
end

--- @return number x, number y, number rot. A random spot (and rotation) inside the circle,
---     away from the other tiles if possible
function TileGroupView:randomSpot()
    local maxR = math.max(0, self.radius - self.tileSize * 0.45)
    local minDist = self.tileSize * MIN_SPACING
    local bestX, bestY, bestDist = self.x, self.y, -1
    for _ = 1, PLACE_ATTEMPTS do
        -- sqrt for an even spread over the circle's area
        local r = maxR * math.sqrt(self.rng:random())
        local angle = self.rng:random() * 2 * math.pi
        local x = self.x + r * math.cos(angle)
        local y = self.y + r * math.sin(angle)
        local nearest = math.huge
        for _, tile in ipairs(self.tiles) do
            nearest = math.min(nearest, ViewUtil.euclidianDistance(x, y, tile.targetX or tile.x, tile.targetY or tile.y))
        end
        if nearest >= minDist then
            bestX, bestY = x, y
            break
        end
        if nearest > bestDist then
            bestX, bestY, bestDist = x, y, nearest
        end
    end
    return bestX, bestY, self.rng:random() * 2 * math.pi
end

--- Add a tile at a random spot
--- @return VisualTile tile the tile added
function TileGroupView:addTile(tileType)
    local x, y, rot = self:randomSpot()
    local tile = { tileType = tileType, x = x, y = y, rot = rot, scale = 1, alpha = 1 }
    table.insert(self.tiles, tile)
    return tile
end

--- Add an existing tile (eg: one moving here from another group). It is given a target spot
--- (tile.targetX, tile.targetY) but its current position is left alone so the caller can tween it
--- @return VisualTile tile
function TileGroupView:receiveTile(tile)
    tile.targetX, tile.targetY = self:randomSpot()
    table.insert(self.tiles, tile)
    return tile
end

--- Remove a specific tile
function TileGroupView:removeTile(tile)
    for ii, t in ipairs(self.tiles) do
        if t == tile then
            table.remove(self.tiles, ii)
            return tile
        end
    end
    return nil
end

--- Remove up to \p count tiles of \p tileType, topmost first
--- @param prefer VisualTile|nil remove this tile first if it matches
--- @return VisualTile[] removed
function TileGroupView:removeTiles(tileType, count, prefer)
    local removed = {}
    if prefer and prefer.tileType == tileType and count > 0 and self:removeTile(prefer) then
        table.insert(removed, prefer)
    end
    for ii = #self.tiles, 1, -1 do
        if #removed >= count then
            break
        end
        if self.tiles[ii].tileType == tileType then
            table.insert(removed, table.remove(self.tiles, ii))
        end
    end
    return removed
end

--- @return table TileType -> count of tiles in the group (every TileType present, possibly 0)
function TileGroupView:counts()
    local counts = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        counts[tileType] = 0
    end
    for _, tile in ipairs(self.tiles) do
        counts[tile.tileType] = counts[tile.tileType] + 1
    end
    return counts
end

--- @return table polygon vertices of \p tile in world coordinates
function TileGroupView:tilePoly(tile)
    local size = self.tileSize * tile.scale
    return TileView.betterPolyVerticies(size, tile.rot, tile.x - size / 2, tile.y - size / 2)
end

--- @return VisualTile|nil tile The topmost tile under (worldX, worldY)
function TileGroupView:tileAt(worldX, worldY)
    if not ViewUtil.ptInCircle(worldX, worldY, self.x, self.y, self.radius + self.tileSize) then
        return nil
    end
    for ii = #self.tiles, 1, -1 do
        local tile = self.tiles[ii]
        if ViewUtil.ptInConvexPoly(self:tilePoly(tile), worldX, worldY) then
            return tile
        end
    end
    return nil
end

--- Draw a single tile at its current position. Highlighted tiles are drawn a little larger with a
--- bold outline
function TileGroupView.drawTile(tile, tileSize, highlighted)
    local size = tileSize * tile.scale * (highlighted and HIGHLIGHT_SCALE or 1)
    local left, top = tile.x - size / 2, tile.y - size / 2
    TileView.drawTileAt(tile.tileType, size, tile.rot, left, top, tile.alpha)
    if highlighted then
        local poly = TileView.betterPolyVerticies(size, tile.rot, left, top)
        love.graphics.setLineJoin("bevel")
        love.graphics.setColor(HIGHLIGHT_OUTLINE_COLOR)
        love.graphics.setLineWidth(HIGHLIGHT_WIDTH + 3)
        love.graphics.polygon("line", poly)
        love.graphics.setColor(HIGHLIGHT_COLOR)
        love.graphics.setLineWidth(HIGHLIGHT_WIDTH)
        love.graphics.polygon("line", poly)
        love.graphics.setLineJoin("miter")
    end
end

--- @param highlight table|nil set of VisualTile -> true to outline. Highlighted tiles are drawn on top
function TileGroupView:drawTiles(highlight)
    for _, tile in ipairs(self.tiles) do
        if not (highlight and highlight[tile]) then
            TileGroupView.drawTile(tile, self.tileSize, false)
        end
    end
    if highlight then
        for _, tile in ipairs(self.tiles) do
            if highlight[tile] then
                TileGroupView.drawTile(tile, self.tileSize, true)
            end
        end
    end
end

return TileGroupView
