--- HUD element for displaying a players current hand during their turn
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

---@class PlayerHandHudEntity
local PlayerHandHudEntity = {}
PlayerHandHudEntity.__index = PlayerHandHudEntity

function PlayerHandHudEntity.new()
    local entity = Concord.entity()

    entity:give(Components.names.drawable, Constants.drawPriority.hudPlayerHand):give(Components.names.cameraPos, 0, 0)

    EUtil.extendEntity(entity, PlayerHandHudEntity)

    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    entity:resize(screenWidth, screenHeight, nil)

    entity.ui = suit.new()

    return entity
end

function PlayerHandHudEntity:update(dt, gameState)
    self.ui:Button(
        nil,
        { id = "OpenPlayerHand", cornerRadius = self._openHandBtnRadius },
        self.cameraPos.x,
        self.cameraPos.y,
        self._openHandBtnRadius * 2,
        self._openHandBtnRadius * 2
    )
end

function PlayerHandHudEntity:draw(gameState)
    self.ui:draw()
end

function PlayerHandHudEntity:resize(w, h, _)
    self._openHandBtnRadius = math.max(h / 10, 20)
    self.cameraPos.x = 0
    self.cameraPos.y = h - self._openHandBtnRadius
end

return PlayerHandHudEntity
