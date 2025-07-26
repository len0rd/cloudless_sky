--- Heads-up display for the player
local Object = require("cloudless_sky.extern.classic")
local PlayerHUD = Object:extend()
local TileType = require("cloudless_sky.model.tile_type")
local ViewUtil = require("cloudless_sky.view.view_util")

local PlayerHandView = require("cloudless_sky.view.player_hand_view")

function PlayerHUD:new()
    self.shouldDraw = false

    -- HUD top bar
    self.playerScore = 0
    self.currentRound = 1
    self.wildColor = TileType.PURPLE
    self._openHandBtnBaseRadius = love.graphics.getPixelHeight() / 10

    local handOriginY = love.graphics.getPixelHeight() - self._openHandBtnBaseRadius
    local handEndX = love.graphics.getPixelWidth() - self._openHandBtnBaseRadius - 10
    local handAnimStartX = love.graphics.getPixelWidth() - (self._openHandBtnBaseRadius / 2)
    self.handView = PlayerHandView(0, handOriginY, handEndX, love.graphics.getPixelHeight(), handAnimStartX)
end

function PlayerHUD:show()
    self.shouldDraw = true
end

function PlayerHUD:hide()
    self.shouldDraw = false
end

-- TODO: on screen resize, upgrade the limits in PlayerHandView

function PlayerHUD:update(dt, playerScore, currentRound, wildColor)
    self.playerScore = playerScore
    self.currentRound = currentRound
    self.wildColor = wildColor
    self._openHandBtnBaseRadius = love.graphics.getPixelHeight() / 10
    self.handView:update(dt)
end

function PlayerHUD:_openHandHoveredRadius()
    return self._openHandBtnBaseRadius + 10
end

--- @return boolean pressHandled. True if the HUD handled the mouse press, otherwise false
function PlayerHUD:mousePressed()
    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    if
        ViewUtil.euclidianDistance(screenWidth, screenHeight, love.mouse.getPosition())
        < self._openHandBtnBaseRadius
    then
        if self.handView.drawHand then
            self.handView:hide()
        else
            self.handView:show()
        end
        return true
    end
    return false
end

--- Draw the HUD. SHOULD BE DONE OUTSIDE OF CAMERA CONTEXT
function PlayerHUD:draw()
    if self.shouldDraw then
        local origR, origG, origB, origA = love.graphics.getColor()

        local screenWidth, screenHeight = love.graphics.getPixelDimensions()
        local topBarHeight = math.max(10, screenHeight * 0.05)

        -- score box
        love.graphics.setColor(love.math.colorFromBytes(138, 138, 240))
        local scoreBoxOriginX = screenWidth - 100
        love.graphics.rectangle("fill", scoreBoxOriginX, 0, 100, topBarHeight, 10, 10)
        local fontHeight = fonts.ithaca["16"]:getHeight()
        local yOffset = (topBarHeight - fontHeight) / 2
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.print("Score: " .. self.playerScore, fonts.ithaca["16"], scoreBoxOriginX + 2, yOffset)

        -- tile hand button
        -- check if mouse is hovering in tile hand area
        if
            ViewUtil.euclidianDistance(screenWidth, screenHeight, love.mouse.getPosition())
            < self._openHandBtnBaseRadius
        then
            -- mouse hovering in tile hand button area
            love.graphics.setColor(love.math.colorFromBytes(236, 240, 137))
            love.graphics.circle("fill", screenWidth, screenHeight, self:_openHandHoveredRadius(), 100)
        else
            love.graphics.setColor(love.math.colorFromBytes(138, 138, 240))
            love.graphics.circle("fill", screenWidth, screenHeight, self._openHandBtnBaseRadius, 100)
        end

        love.graphics.setColor(origR, origG, origB, origA)
    end

    self.handView:draw()
end

return PlayerHUD
