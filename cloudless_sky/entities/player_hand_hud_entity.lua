--- HUD element for displaying a players current hand during their turn
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")

local PlayerHandStarView = require("cloudless_sky.view.player_hand_star")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

---@class PlayerHandHudEntity
---@field ui table Suit UI instance
local PlayerHandHudEntity = {}
PlayerHandHudEntity.__index = PlayerHandHudEntity

function PlayerHandHudEntity.new()
    local entity = Concord.entity()

    entity:give(Components.names.drawable, Constants.drawPriority.hudPlayerHand):give(Components.names.cameraPos, 0, 0)

    EUtil.extendEntity(entity, PlayerHandHudEntity)

    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    entity:resize(screenWidth, screenHeight, nil)

    entity.openHandBtnScale = 1.0

    entity.ui = suit.new()

    return entity
end

function PlayerHandHudEntity:_btnHoverTween(tween)
    tween:to(self, 0.5, { openHandBtnScale = 1.05 }):after(self, 0.5, { openHandBtnScale = 1.0 }):oncomplete(function()
        self:_btnHoverTween(tween)
    end)
end

function PlayerHandHudEntity:update(dt, gameState)
    self.ui:enterFrame()
    local openHandBtn = self.ui:Button("", {
        id = "openPlayerHand",
        cornerRadius = self._openHandBtnRadius - 1,
        outline = 2,
        scale = self.openHandBtnScale,
    }, self.cameraPos.x, self.cameraPos.y, self._openHandBtnRadius * 2, self._openHandBtnRadius * 2)

    -- handle tweening animation
    if openHandBtn.entered then
        -- start new animation
        Log.debug("open hand entered")
        self.openHandHoverTween = nil
        self.openHandHoverTween = flux.group()
        self:_btnHoverTween(self.openHandHoverTween)
    end
    if openHandBtn.hovered then
        self.openHandHoverTween:update(dt)
    elseif openHandBtn.left then
        Log.debug("open hand left")
        self.openHandBtnScale = 1.0
        self.openHandHoverTween = nil
    end

    self.star:update(dt)
end

function PlayerHandHudEntity:draw(gameState)
    self.ui:draw()
    self.star:draw()
end

function PlayerHandHudEntity:resize(w, h, _)
    self._openHandBtnRadius = math.max(h / 8, 20)
    self.cameraPos.x = 0 - self._openHandBtnRadius
    self.cameraPos.y = h - self._openHandBtnRadius

    local hRadius = math.floor(self._openHandBtnRadius / 2)
    local qRadius = math.floor(self._openHandBtnRadius / 6)
    local STAR_PAD = 5
    self.star = PlayerHandStarView(
        self.cameraPos.x + self._openHandBtnRadius + STAR_PAD,
        self.cameraPos.y + self._openHandBtnRadius - hRadius - STAR_PAD,
        hRadius
    )
end

return PlayerHandHudEntity
