-- small confirmation prompt for what tile to place
-- along with a selector of how many wilds to use
local Object = require("cloudless_sky.extern.classic")
local PlacePrompt = Object:extend()

local flux = require("luis.3rdparty.flux")

local PROMPT_WIDTH = 100
local PROMPT_HEIGHT = 100
-- max scale the border box will be drawn at during transitionTween
local MAX_SCALE = 1.5

--- @param tileWorldX integer World X coordinate of the center of the tile the prompt is in relation to
---@param tileWorldY integer World Y coordinate of the center of the tile the prompt is in relation tofs
---@
function PlacePrompt:new(tileWorldX, tileWorldY, starIdx, slotIdx)
    self.starIdx = starIdx
    self.slotIdx = slotIdx
    self.tileWorldX = tileWorldX
    self.tileWorldY = tileWorldY
    self.scale = 0.1
    self.transitionTween = flux.to(self, 0.5, { scale = MAX_SCALE }):after(self, 0.25, { scale = 1.0 })
end

function PlacePrompt:mousePressed(worldX, worldY, button, istouch) end

function PlacePrompt:update(dt)
    flux.update(dt)
end

function PlacePrompt:draw()
    love.graphics.push()
    do
        local winHeight = love.graphics.getPixelHeight()
        local _, promptWindowY = camera:cameraCoords(self.tileWorldX, self.tileWorldY)

        -- TODO: need to know the HUD margin for this decision
        if promptWindowY + (MAX_SCALE * PROMPT_HEIGHT) > winHeight - 100 then
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

return PlacePrompt
