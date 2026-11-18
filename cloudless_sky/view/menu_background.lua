--- The look shared by the main menu and the New Game menu: a sky of blues drifting up the whole window
--- and a big pixel-font title with a drop shadow
local ViewUtil = require("cloudless_sky.view.view_util")

local MenuBackground = {}

-- the blues the sky cycles through, bottom to top (and back round to the first)
local SKY_COLORS = {
    { 0.07, 0.24, 0.58 },
    { 0.16, 0.42, 0.78 },
    { 0.36, 0.64, 0.92 },
    { 0.56, 0.8, 0.97 },
    { 0.3, 0.55, 0.88 },
}
-- how many screen heights the full cycle of colors spans
local CYCLE_HEIGHTS = 2
-- seconds for the colors to drift up through one full cycle
local CYCLE_S = 24
-- horizontal strips in the gradient mesh
local BANDS = 32

local TITLE_COLOR = { 1, 1, 1, 1 }
local SHADOW_COLOR = { 0.04, 0.12, 0.35, 0.55 }

-- the gradient mesh (its colors change every frame), rebuilt when the window size changes
local mesh, meshW, meshH = nil, nil, nil

--- @param pos number position along the cycle, any value (wraps every 1)
--- @return number r, number g, number b. The sky color at \p pos, blended between SKY_COLORS
function MenuBackground.colorAt(pos)
    local n = #SKY_COLORS
    local f = (pos % 1) * n
    local i = math.floor(f)
    local t = f - i
    -- smooth the blend so bands don't show
    t = t * t * (3 - 2 * t)
    local a, b = SKY_COLORS[i + 1], SKY_COLORS[(i + 1) % n + 1]
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

--- Fill the \p w x \p h window with the sky. Its colors drift from the bottom of the screen to the top
--- over time
function MenuBackground.draw(w, h)
    if not mesh or meshW ~= w or meshH ~= h then
        local vertices = {}
        for row = 0, BANDS do
            local y = h * row / BANDS
            table.insert(vertices, { 0, y, 0, 0, 1, 1, 1, 1 })
            table.insert(vertices, { w, y, 1, 0, 1, 1, 1, 1 })
        end
        local map = {}
        for row = 0, BANDS - 1 do
            local a, b = row * 2 + 1, row * 2 + 2
            for _, v in ipairs({ a, b, a + 2, b, b + 2, a + 2 }) do
                table.insert(map, v)
            end
        end
        mesh = love.graphics.newMesh(vertices, "triangles", "dynamic")
        mesh:setVertexMap(map)
        meshW, meshH = w, h
    end
    -- distance up from the bottom, in cycles, plus how far the colors have drifted up
    local drift = love.timer.getTime() / CYCLE_S
    for row = 0, BANDS do
        local fromBottom = (BANDS - row) / BANDS / CYCLE_HEIGHTS
        local r, g, b = MenuBackground.colorAt(fromBottom - drift)
        mesh:setVertexAttribute(row * 2 + 1, 3, r, g, b, 1)
        mesh:setVertexAttribute(row * 2 + 2, 3, r, g, b, 1)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)
end

--- \p text as large as fits centered in the rect (x, y, w, h), with a drop shadow
--- @param scale number|nil extra scale about the rect's center (eg: a breathing title). Default 1
function MenuBackground.drawTitle(text, x, y, w, h, scale)
    scale = scale or 1
    love.graphics.push()
    if scale ~= 1 then
        local cx, cy = x + w / 2, y + h / 2
        love.graphics.translate(cx, cy)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-cx, -cy)
    end
    local offset = math.max(2, math.floor(h * 0.04))
    love.graphics.setColor(SHADOW_COLOR)
    ViewUtil.printScaledPixelText(text, x + offset, y + offset, w, h)
    love.graphics.setColor(TITLE_COLOR)
    ViewUtil.printScaledPixelText(text, x, y, w, h)
    love.graphics.pop()
end

return MenuBackground
