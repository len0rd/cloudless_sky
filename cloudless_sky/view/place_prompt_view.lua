-- small confirmation prompt for what tile to place
-- along with a selector of how many wilds to use
local Object = require("cloudless_sky.extern.classic")
local PlacePromptView = Object:extend()

local flux = require("cloudless_sky.extern.flux")

local PROMPT_WIDTH = 100
local PROMPT_HEIGHT = 100
-- max scale the border box will be drawn at during transitionTween
local MAX_SCALE = 1.5

--- @param tileWorldX integer World X coordinate of the center of the tile the prompt is in relation to
---@param tileWorldY integer World Y coordinate of the center of the tile the prompt is in relation tofs
---@
function PlacePromptView:new(tileWorldX, tileWorldY)
    self.tileWorldX = tileWorldX
    self.tileWorldY = tileWorldY
    self.scale = 0.1
    self.transitionTween = flux.to(self, 0.25, { scale = MAX_SCALE }):after(self, 0.25, { scale = 1.0 })
end

function PlacePromptView:close() end

function PlacePromptView:mousePressed(worldX, worldY, button, istouch) end

function PlacePromptView:update(dt)
    flux.update(dt)
end

function PlacePromptView:draw()
    love.graphics.push()
    do
        local winHeight = love.graphics.getPixelHeight()
        local _, promptWindowY = camera:cameraCoords(self.tileWorldX, self.tileWorldY)

        -- TODO: need to know the HUD margin for this decision
        if promptWindowY + PROMPT_HEIGHT > winHeight - 100 then
            self.tileWorldY = self.tileWorldY - PROMPT_HEIGHT
        end

        local width = PROMPT_WIDTH * self.scale
        local height = PROMPT_HEIGHT * self.scale
        local rx = PROMPT_WIDTH * self.scale / 10
        local ry = PROMPT_HEIGHT * self.scale / 10

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", self.tileWorldX, self.tileWorldY, width, height, rx, ry)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.rectangle("line", self.tileWorldX, self.tileWorldY, width, height, rx, ry)
    end
    love.graphics.pop()
end

return PlacePromptView
