-- small confirmation prompt for what tile to place
-- along with a selector of how many wilds to use
local Object = require("cloudless_sky.extern.classic")
local PlacePromptView = Object:extend()
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

local PROMPT_WIDTH = 100
local PROMPT_HEIGHT = 100
-- max scale the border box will be drawn at during transitionTween
local MAX_SCALE = 1.5

--- triangle vertices
---      1
---  3 <|
---     2
local leftArrowDraw = function(text, opt, x, y, w, h)
    local size = math.min(w, h)
    local wOffset = (w - size) / 2
    local hOffset = (h - size) / 2

    -- stylua: ignore start
    local vertices = {
        w - wOffset, hOffset,
        w - wOffset, h - hOffset,
        wOffset,     h / 2,
    }
    -- stylua: ignore end
    ViewUtil.shiftVerticies(vertices, x, y)
    love.graphics.setColor(love.math.colorFromBytes(30, 30, 30))
    love.graphics.polygon("fill", vertices)
end

--- @param tileWorldX integer World X coordinate of the center of the tile the prompt is in relation to
---@param tileWorldY integer World Y coordinate of the center of the tile the prompt is in relation tofs
---@
function PlacePromptView:new(tileWorldX, tileWorldY, tileCost)
    self.tileWorldX = tileWorldX
    self.tileWorldY = tileWorldY
    self.tileCost = tileCost

    self.scale = 0.1
    self.transitionTween = flux.to(self, 0.25, { scale = MAX_SCALE }):after(self, 0.25, { scale = 1.0 })
    self.ui = suit.new()
    self.ui.theme.color = {
        normal = { bg = { 94, 94, 94 }, fg = { 0, 0, 0 } },
        hovered = { bg = { 94, 94, 94 }, fg = { 0, 0, 0 } },
        active = { bg = { 94, 94, 94 }, fg = { 0, 0, 0 } },
    }
    self:resize(love.graphics.getWidth(), love.graphics.getHeight(), tileWorldX, tileWorldY)
end

function PlacePromptView:close() end

function PlacePromptView:update(dt, tileColor, wildColor)
    flux.update(dt)

    local promptW = PROMPT_WIDTH * self.scale
    local NUM_ROWS = 3

    self.ui.layout:reset(self.tileWorldX, self.tileWorldY, promptW, PROMPT_HEIGHT * self.scale)
    self.ui.layout:padding(10, 10)
    self.ui:Label(
        "Cost: " .. self.tileCost,
        { font = fonts.ithaca["16"] },
        self.ui.layout:row(promptW, PROMPT_HEIGHT / NUM_ROWS)
    )
    -- spacing
    self.ui.layout:row()
    self.ui:Button(nil, { draw = leftArrowDraw }, self.ui.layout:row(promptW, PROMPT_HEIGHT / NUM_ROWS))
end

function PlacePromptView:draw()
    love.graphics.push()
    do
        local width = PROMPT_WIDTH * self.scale
        local height = PROMPT_HEIGHT * self.scale
        local rx = width / 10
        local ry = height / 10

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", self.tileWorldX, self.tileWorldY, width, height, rx, ry)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.rectangle("line", self.tileWorldX, self.tileWorldY, width, height, rx, ry)

        self.ui:draw()
    end
    love.graphics.pop()
end

--- events

--- Call when the window is resized
--- TODO: need to know the HUD margin for this decision
function PlacePromptView:resize(w, h, tileWorldX, tileWorldY)
    self.tileWorldX = tileWorldX
    self.tileWorldY = tileWorldY
    local promptWindowX, promptWindowY = camera:cameraCoords(self.tileWorldX, self.tileWorldY)
    if promptWindowY + PROMPT_HEIGHT > h - 100 then
        self.tileWorldY = self.tileWorldY - PROMPT_HEIGHT
    end
    if promptWindowX + PROMPT_WIDTH > w - 100 then
        self.tileWorldX = self.tileWorldX - PROMPT_WIDTH
    end
end

return PlacePromptView
