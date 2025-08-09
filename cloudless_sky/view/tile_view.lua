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

--- @param mirror boolean OPTIONAL. if true, mirror the vertices before rotation
--- @return table tileVerticies. The 4 x,y vertices for a tile-shaped polygon constrained to the given size and rotated by rot radians
---     0 deg rotation looks like this:
---       X ______   <- X is 0,0 in the vertices
---        /____/
function TileView.tilePolyVerticies(size, rot)
    local height = math.tan(math.rad(60)) * (size / 3)

    -- stylua: ignore start
    local vertices = {
        0,              height,
        size/3,         0,
        size,           0,
        size - size/3,  height
    }
    -- stylua: ignore end

    for ii = 1, #vertices, 2 do
        local x, y = vertices[ii], vertices[ii + 1]
        vertices[ii] = x * math.cos(rot) - y * math.sin(rot)
        vertices[ii + 1] = y * math.cos(rot) + x * math.sin(rot)
    end
    return vertices
end
--- A draw tile method that can be integrated into SUIT layout management/widgets
function TileView.suitDrawTile(ignored, opt, x, y, w, h)
    local PAD = opt["pad"] or 2
    local ROT = opt["rot"] or (-math.pi / 6)
    local TILE_SIZE = opt["size"] or h - (2 * PAD)

    local tileVertices = TileView.tilePolyVerticies(TILE_SIZE, ROT)
    local _, _, tileW, tileH = ViewUtil.boundingBoxOfVerticies(tileVertices)

    ViewUtil.shiftVerticies(tileVertices, x + ((w - tileW) / 2) - tileW / 2, y + ((h - tileH) / 2) + (tileH / 2))
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
