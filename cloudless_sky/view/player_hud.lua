--- Heads-up display for the player
local Object = require("cloudless_sky.extern.classic")
local PlayerHUD = Object:extend()
local TileType = require("cloudless_sky.model.tile_type")
local ViewUtil = require("cloudless_sky.view.view_util")

function PlayerHUD:new()
    self.shouldDraw = false

    -- HUD top bar
    self.playerScore = 0
    self.currentRound = 1
    self.wildColor = TileType.PURPLE
end

function PlayerHUD:show()
    self.shouldDraw = true
end

function PlayerHUD:hide()
    self.shouldDraw = false
end

function PlayerHUD:update(playerScore, currentRound, wildColor)
    self.playerScore = playerScore
    self.currentRound = currentRound
    self.wildColor = wildColor
end

--- Draw the HUD. SHOULD BE DONE OUTSIDE OF CAMERA CONTEXT
function PlayerHUD:draw()
    if self.shouldDraw then
        local origR, origG, origB, origA = love.graphics.getColor()
        -- local origFont = love.graphics.getFont()

        local screenWidth, screenHeight = love.graphics.getPixelDimensions()
        local topBarHeight = math.max(10, screenHeight * 0.05)

        love.graphics.setColor(love.math.colorFromBytes(138, 138, 240))
        local scoreBoxOriginX = screenWidth - 100
        love.graphics.rectangle("fill", scoreBoxOriginX, 0, 100, topBarHeight, 10, 10)

        -- if fonts.pixelatedElegance:getHeight() < topBarHeight / 2 then
        --     fonts.pixelatedElegance:setLineHeight(20)
        -- end
        local fontHeight = fonts.pixelatedElegance["16"]:getHeight()
        local yOffset = (topBarHeight - fontHeight) / 2

        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.print("Score: " .. self.playerScore, fonts.pixelatedElegance["16"], scoreBoxOriginX + 2, yOffset)

        -- love.graphics.setFont(origFont)
        -- fonts.pixelatedElegance:setLineHeight(1)
        love.graphics.setColor(origR, origG, origB, origA)
    end
end

return PlayerHUD
