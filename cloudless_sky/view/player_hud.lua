--- Heads-up display for the player
local Object = require("cloudless_sky.extern.classic")
local luis = require("luis.init")("luis/widgets")
local flux = require("luis.3rdparty.flux")
local Gamestate = require("cloudless_sky.extern.hump.gamestate")
luis.flux = flux

local TileType = require("cloudless_sky.model.tile_type")
local ViewUtil = require("cloudless_sky.view.view_util")
local TileView = require("cloudless_sky.view.tile_view")
local PlayerHandView = require("cloudless_sky.view.player_hand_view")

local PlayerHUD = Object:extend()

function PlayerHUD:new()
    self.shouldDraw = false

    -- HUD top bar
    self.playerScore = 0
    self.currentRound = 1
    self.wildColor = TileType.PURPLE
    self._openHandBtnBaseRadius = 0
    self.topBarHeight = 0

    self.handView = PlayerHandView(0, 0, 0, 0, 0)

    self:resize(love.graphics.getPixelDimensions())

    luis.newLayer("hud")

    local saveButton = luis.createElement("hud", "Button", "Save", 4, 2, nil, function()
        local state = Gamestate.current()
        if state and type(state.onSave) == "function" then
            state:onSave()
        end
    end, 1, 1)
end

--- @return integer,integer,integer,integer HUDMargins. Top, Left, Bottom, and Right area in screen coordinates that this HUD will occupy in the game window.
function PlayerHUD:marginsNeeded()
    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    return self.topBarHeight, 0, screenHeight - self._openHandBtnBaseRadius, screenWidth
end

function PlayerHUD:show()
    self.shouldDraw = true
    luis.enableLayer("hud")
end

function PlayerHUD:hide()
    self.shouldDraw = false
    luis.disableLayer("hud")
end

-- TODO: on screen resize, upgrade the limits in PlayerHandView

function PlayerHUD:update(dt, playerScore, currentRound, wildColor)
    self.playerScore = playerScore
    self.currentRound = currentRound
    self.wildColor = wildColor
    self.handView:update(dt)
    luis.update(dt)
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
function PlayerHUD:draw(playerHand)
    self.handView:draw(playerHand)

    if self.shouldDraw then
        local origR, origG, origB, origA = love.graphics.getColor()
        local screenWidth, screenHeight = love.graphics.getPixelDimensions()

        -- score box
        love.graphics.setColor(love.math.colorFromBytes(138, 138, 240))
        local scoreBoxOriginX = screenWidth - 100
        love.graphics.rectangle("fill", scoreBoxOriginX, 0, 100, self.topBarHeight, 10, 10)
        local fontHeight = fonts.ithaca["16"]:getHeight()
        local yOffset = (self.topBarHeight - fontHeight) / 2
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
end

-- update all HUD element dimensions that are based on screen size
function PlayerHUD:resize(w, h)
    self._openHandBtnBaseRadius = math.max(h / 10, 20)
    self.topBarHeight = math.max(10, h * 0.05)
    self.handView:resize(
        0,
        h - self._openHandBtnBaseRadius,
        w - self._openHandBtnBaseRadius - 10,
        h,
        w - (self._openHandBtnBaseRadius / 2)
    )
end

return PlayerHUD
