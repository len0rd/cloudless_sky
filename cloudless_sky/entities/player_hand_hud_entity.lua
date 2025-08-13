--- HUD element for displaying a players current hand during their turn
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local ViewUtil = require("cloudless_sky.view.view_util")
local TileType = require("cloudless_sky.model.tile_type")
local TileView = require("cloudless_sky.view.tile_view")

local PlayerHandStarView = require("cloudless_sky.view.player_hand_star")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

---@class PlayerHandHudEntity
---@field ui table Suit UI instance
local PlayerHandHudEntity = {}
PlayerHandHudEntity.__index = PlayerHandHudEntity

PlayerHandHudEntity.STATES = {
    UNOPENED = 1,
    OPENED = 2,
}

function PlayerHandHudEntity.new()
    local entity = Concord.entity()

    entity
        :give(Components.names.drawable, Constants.drawPriority.hudPlayerHand)
        :give(Components.names.cameraPos, 0, 0)
        :give(Components.names.mouseHandler, Constants.drawPriority.hudPlayerHand)

    EUtil.extendEntity(entity, PlayerHandHudEntity)

    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    entity:resize(screenWidth, screenHeight, nil)

    entity.openHandBtnScale = 1.0
    entity.state = PlayerHandHudEntity.STATES.UNOPENED

    entity.openHandTween = flux.group()

    entity.ui = suit.new()

    return entity
end

function PlayerHandHudEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    if button == 1 then
        if ViewUtil.ptInCircle(cameraX, cameraY, self.circleCenter.x, self.circleCenter.y, self._openHandBtnRadius) then
            if self.state == self.STATES.UNOPENED then
                self.state = PlayerHandHudEntity.STATES.OPENED
                self.openHandTween = flux.group()
                self.openHandTween
                    :to(self, 0.25, { _handBackgroundRadius = self._handBackgroundTargetRadius })
                    :after(self.handTiles[1], 0.25, { x = self.handTiles[1].destX, y = self.handTiles[1].destY })
                self.openHandHoverTween = nil
            else
                self.openHandTween = flux.group()
                self.openHandTween
                    :to(self.handTiles[1], 0.25, { x = self.star.starOriginX, y = self.star.starOriginY })
                    :after(self, 0.25, { _handBackgroundRadius = self._openHandBtnRadius * 0.9 })
                    :oncomplete(function()
                        self.state = PlayerHandHudEntity.STATES.UNOPENED
                    end)
            end
            return true
        end
    end
    return false
end

function PlayerHandHudEntity:_btnHoverTween(tween)
    tween:to(self, 0.5, { openHandBtnScale = 1.05 }):after(self, 0.5, { openHandBtnScale = 0.95 }):oncomplete(function()
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
        self.openHandHoverTween = flux.group()
        self:_btnHoverTween(self.openHandHoverTween)
        self.handStarRotation = flux.group()
        self.handStarRotation:to(self.star.super, 0.25, { rotation = math.pi / 6 })
    end
    if openHandBtn.hovered then
        if self.openHandHoverTween then
            self.openHandHoverTween:update(dt)
        end
    elseif openHandBtn.left then
        Log.debug("open hand left")
        self.openHandBtnScale = 1.0
        self.openHandHoverTween = nil
        self.handStarRotation:to(self.star.super, 0.25, { rotation = 0 })
    end

    if self.handStarRotation then
        self.handStarRotation:update(dt)
    end
    self.openHandTween:update(dt)

    self.star:update(dt)
end

function PlayerHandHudEntity:draw(gameState)
    if self.state == self.STATES.OPENED then
        love.graphics.circle("fill", self.circleCenter.x, self.circleCenter.y, self._handBackgroundRadius)
    end
    self.ui:draw()
    if self.state == self.STATES.OPENED then
        TileView.drawTileAt(
            self.handTiles[1].type,
            self.handTiles[1].size,
            math.pi / 4,
            self.handTiles[1].x,
            self.handTiles[1].y
        )
    end
    self.star:draw()
end

function PlayerHandHudEntity:resize(w, h, _)
    self._openHandBtnRadius = math.max(h / 8, 20)
    self._handBackgroundRadius = self._openHandBtnRadius * 0.9
    self._handBackgroundTargetRadius = self._openHandBtnRadius + 50
    self.circleCenter = {
        x = 0,
        y = h,
    }
    self.cameraPos.x = 0 - self._openHandBtnRadius
    self.cameraPos.y = h - self._openHandBtnRadius

    local hRadius = math.floor(self._openHandBtnRadius / 2)
    local STAR_PAD = 5
    self.star = PlayerHandStarView(self.circleCenter.x + STAR_PAD, self.circleCenter.y - hRadius - STAR_PAD, hRadius)

    local tileDistFromCenter = ((self._handBackgroundRadius - self._openHandBtnRadius) / 2) + self._openHandBtnRadius
    local destX, destY = ViewUtil.pointFromDistanceAndAngle(
        self.star.starOriginX,
        self.star.starOriginY,
        tileDistFromCenter,
        -math.pi / 4
    )
    self.handTiles = {
        {
            type = TileType.RED,
            destX = destX,
            destY = destY,
            x = self.star.starOriginX,
            y = self.star.starOriginY,
            size = math.floor(self._openHandBtnRadius / 2),
        },
    }
end

return PlayerHandHudEntity
