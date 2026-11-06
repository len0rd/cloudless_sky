--- The look shared by the main menu and the New Game menu: a blue sky gradient over the whole window
--- and a big pixel-font title with a drop shadow
local ViewUtil = require("cloudless_sky.view.view_util")

local MenuBackground = {}

local SKY_TOP = { 0.56, 0.8, 0.97, 1 }
local SKY_BOTTOM = { 0.07, 0.24, 0.58, 1 }
local TITLE_COLOR = { 1, 1, 1, 1 }
local SHADOW_COLOR = { 0.04, 0.12, 0.35, 0.55 }

-- the gradient mesh, rebuilt when the window size changes
local mesh, meshW, meshH = nil, nil, nil

--- Fill the \p w x \p h window with the gradient
function MenuBackground.draw(w, h)
    if not mesh or meshW ~= w or meshH ~= h then
        local t, b = SKY_TOP, SKY_BOTTOM
        mesh = love.graphics.newMesh({
            { 0, 0, 0, 0, t[1], t[2], t[3], t[4] },
            { w, 0, 1, 0, t[1], t[2], t[3], t[4] },
            { w, h, 1, 1, b[1], b[2], b[3], b[4] },
            { 0, h, 0, 1, b[1], b[2], b[3], b[4] },
        }, "fan", "static")
        meshW, meshH = w, h
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh)
end

--- \p text as large as fits centered in the rect (x, y, w, h), with a drop shadow
function MenuBackground.drawTitle(text, x, y, w, h)
    local offset = math.max(2, math.floor(h * 0.04))
    love.graphics.setColor(SHADOW_COLOR)
    ViewUtil.printScaledPixelText(text, x + offset, y + offset, w, h)
    love.graphics.setColor(TITLE_COLOR)
    ViewUtil.printScaledPixelText(text, x, y, w, h)
end

return MenuBackground
