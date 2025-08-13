--- Info for displaying tiles
local TileType = require("cloudless_sky.model.tile_type")
local ViewUtil = require("cloudless_sky.view.view_util")

local TileView = {}

TileView.TILE_COLOR = {
    [TileType.RED] = { 255, 15, 15 },
    [TileType.ORANGE] = { 255, 113, 66 },
    [TileType.YELLOW] = { 255, 210, 77 },
    [TileType.GREEN] = { 161, 215, 106 },
    [TileType.BLUE] = { 74, 161, 242 },
    [TileType.PURPLE] = { 153, 90, 181 },
}
TileView.TILE_COLOR = ViewUtil.normalizeColorTables(TileView.TILE_COLOR)

--- Draws the tile like this:
---  /\
---  \/
--- Cause this makes more sense to my brain
--- @param rot number rotation about the center of the tile in radians
function TileView.betterPolyVerticies(size, rot, x, y)
    x = x or 0
    y = y or 0
    -- stylua: ignore start
    local verticies = {
        1/2,  0,
        5/6,  1/2,
        1/2,  1,
        1/6,  1/2,
    }
    -- stylua: ignore end

    local tileVerticies = ViewUtil.transformVertexScalers(verticies, size, x, y)
    local centerX, centerY = ViewUtil.centerOfConvexPoly(tileVerticies)
    return ViewUtil.rotateVerticies(tileVerticies, centerX, centerY, rot)
end

--- TODO: remove usage!
--- @return table tileVerticies. The 4 x,y vertices for a tile-shaped polygon constrained to the given size and rotated by rot radians
---     0 deg rotation looks like this:
---       X ______   <- X is 0,0 in the vertices
---        /____/
function TileView.tilePolyVerticies(size, rot)
    local height = math.tan(math.rad(60)) * (size / 3)

    -- stylua: ignore start
    local verticies = {
        0,              height,
        size/3,         0,
        size,           0,
        size - size/3,  height
    }
    -- stylua: ignore end
    local centerX, centerY = ViewUtil.centerOfConvexPoly(verticies)
    return ViewUtil.rotateVerticies(verticies, centerX, centerY, rot)
end

function TileView.drawTileAt(type, size, rot, x, y)
    local tileVertices = TileView.betterPolyVerticies(size, rot, x, y)
    -- tileVertices = ViewUtil.shiftVerticies(tileVertices, x, y)
    local color = TileView.TILE_COLOR[type]

    love.graphics.push()
    do
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.polygon("fill", tileVertices)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", tileVertices)
    end
    love.graphics.pop()
end

--- A draw tile method that can be integrated into SUIT layout management/widgets
function TileView.suitDrawTile(ignored, opt, x, y, w, h)
    local PAD = opt["pad"] or 2
    local ROT = opt["rot"] or (-math.pi / 6)
    local TILE_SIZE = opt["size"] or h - (2 * PAD)

    local tileVertices = TileView.tilePolyVerticies(TILE_SIZE, ROT)
    local _, _, tileW, tileH = ViewUtil.boundingBoxOfVerticies(tileVertices)

    ViewUtil.shiftVerticies(tileVertices, x + ((w - tileW) / 2) - tileW / 4, y + (h - tileH))
    local color = TileView.TILE_COLOR[opt.tileType]
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.polygon("fill", tileVertices)
    love.graphics.setColor({ 0, 0, 0 })
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", tileVertices)

    if opt["boundingBox"] then
        love.graphics.setColor({ 0, 0.5, 0 })
        love.graphics.rectangle("line", x, y, w, h)
    end
end

return TileView
