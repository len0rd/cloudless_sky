--- Icons for end-game bonuses (see EndGameBonus), drawn in screen space:
---     - star bonus: a star filled with its color. Multicolor stars get a rainbow gradient
---     - number bonus: a tile with the number in its middle
--- Used by the end-game bonus reference dialog and the game end sequence
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local StarType = require("cloudless_sky.model.star_type")
local StarView = require("cloudless_sky.view.star_view")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

local BonusIconView = {}

local OUTLINE_COLOR = { 0, 0, 0, 1 }
-- number tiles: the color of an empty space on the board
local NUMBER_TILE_COLOR = { 0.96, 0.95, 0.89, 1 }
local NUMBER_COLOR = { 0, 0, 0, 1 }
-- the middle of the rainbow star fades to this
local RAINBOW_CENTER_COLOR = { 1, 1, 1, 1 }
-- rainbow saturation/value
local RAINBOW_S = 0.75
local RAINBOW_V = 1.0

--- @return number r, number g, number b for hue \p h (0..1, wraps), saturation \p s, value \p v
function BonusIconView.hsvToRgb(h, s, v)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    if i == 0 then
        return v, t, p
    elseif i == 1 then
        return q, v, p
    elseif i == 2 then
        return p, v, t
    elseif i == 3 then
        return p, q, v
    elseif i == 4 then
        return t, p, v
    end
    return v, p, q
end

--- @return table vertices the star's slot \p slotIdx polygon for a star with top-left (x, y), \p size
local function slotVertices(slotIdx, x, y, size)
    return ViewUtil.transformVertexScalers(StarView.SLOT_VERTEX_SCALARS[slotIdx], size, x, y)
end

--- Fill \p vertices with a rainbow: each vertex's hue comes from its angle around (cx, cy), and
--- vertices at the center take RAINBOW_CENTER_COLOR, so neighboring slots blend into one gradient
local function drawRainbowPoly(vertices, cx, cy, size)
    local meshVertices = {}
    for ii = 1, #vertices, 2 do
        local vx, vy = vertices[ii], vertices[ii + 1]
        local r, g, b
        if ViewUtil.euclidianDistance(vx, vy, cx, cy) < size * 0.01 then
            r, g, b = RAINBOW_CENTER_COLOR[1], RAINBOW_CENTER_COLOR[2], RAINBOW_CENTER_COLOR[3]
        else
            -- start red at the top, going clockwise
            local hue = (math.atan2(vy - cy, vx - cx) + math.pi / 2) / (2 * math.pi)
            r, g, b = BonusIconView.hsvToRgb(hue, RAINBOW_S, RAINBOW_V)
        end
        table.insert(meshVertices, { vx, vy, 0, 0, r, g, b, 1 })
    end
    local mesh = love.graphics.newMesh(meshVertices, "fan", "static")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)
end

--- Draw a star of \p starType, top-left at (x, y), \p size wide and tall
function BonusIconView.drawStar(starType, x, y, size)
    local cx, cy = x + size / 2, y + size / 2
    local color = TileView.TILE_COLOR[starType]
    love.graphics.setLineJoin("bevel")
    for slotIdx = 1, #StarView.SLOT_VERTEX_SCALARS do
        local vertices = slotVertices(slotIdx, x, y, size)
        if color then
            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.polygon("fill", vertices)
        else
            -- MULTI (and anything without a single color)
            drawRainbowPoly(vertices, cx, cy, size)
        end
        love.graphics.setColor(OUTLINE_COLOR)
        love.graphics.setLineWidth(math.max(1, size / 40))
        love.graphics.polygon("line", vertices)
    end
    love.graphics.setLineJoin("miter")
end

--- Draw a tile (upright diamond) with \p value in its middle, top-left at (x, y), \p size wide and tall
function BonusIconView.drawNumberTile(value, x, y, size)
    local vertices = TileView.betterPolyVerticies(size, 0, x, y)
    love.graphics.setColor(NUMBER_TILE_COLOR)
    love.graphics.polygon("fill", vertices)
    love.graphics.setColor(OUTLINE_COLOR)
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(math.max(1, size / 40))
    love.graphics.polygon("line", vertices)
    love.graphics.setLineJoin("miter")

    -- the diamond spans 1/6..5/6 of the width: fit the number inside its middle
    local text = tostring(value)
    local textX, textY, textW, textH = x + size * 0.3, y + size * 0.25, size * 0.4, size * 0.5
    love.graphics.setColor(NUMBER_COLOR)
    ViewUtil.printPixelText(text, ViewUtil.largestFontThatFits(text, textW, textH), textX, textY, textW, textH)
end

--- Draw the icon for \p bonus (EndGameBonus), top-left at (x, y), \p size wide and tall
function BonusIconView.drawIcon(bonus, x, y, size)
    if bonus.kind == EndGameBonus.KIND.STAR then
        BonusIconView.drawStar(bonus.starType or StarType.MULTI, x, y, size)
    else
        BonusIconView.drawNumberTile(bonus.value, x, y, size)
    end
end

--- Draw "<icon> = N" in the rect (x, y, w, h): the icon is h square on the left, the text fills the rest
--- @param textColor table|nil defaults to white
function BonusIconView.drawBonus(bonus, x, y, w, h, textColor)
    BonusIconView.drawIcon(bonus, x, y, h)
    local text = "= " .. tostring(bonus.points)
    local textX = x + h + h * 0.15
    local textW = math.max(1, w - (textX - x))
    love.graphics.setColor(textColor or { 1, 1, 1, 1 })
    ViewUtil.printPixelText(text, ViewUtil.largestFontThatFits(text, textW, h * 0.8), textX, y, textW, h, "left")
end

return BonusIconView
