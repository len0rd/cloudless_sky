--- Dialog to display when a slot is clicked during place phase but player has insufficient tiles
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

local PlaceTileLackingDialogEntity = {}
PlaceTileLackingDialogEntity.__index = PlaceTileLackingDialogEntity

-- dialog dimensions in screen pixels
local PROMPT_WIDTH = 190 -- wide enough for "Need More Tiles!" at 32px
local PROMPT_HEIGHT = 100
local CORNER_RADIUS_SCALER = 1 / 10

-- max scale the border box will be drawn at during transitionTween
local MAX_SCALE = 1.5

function PlaceTileLackingDialogEntity.new(playerIdx, starIdx, slotIdx, tileCost)
    local entity = Concord.entity()

    entity
        :give(Components.names.playerMatTileAnchor, starIdx, slotIdx)
        :give(Components.names.playerEntity, playerIdx)
        :give(Components.names.boundingBox, PROMPT_WIDTH, PROMPT_HEIGHT)
        :give(Components.names.drawable, Constants.drawPriority.tilePlacePrompt)
        :give(Components.names.worldPos, 0, 0)
        :give(Components.names.killOffCamera) -- in the event state machine doesnt remove the prompt, ensure its removed once off camera
        :give(Components.names.uniqueGroup, "tilePlacementDialogs")

    EUtil.extendEntity(entity, PlaceTileLackingDialogEntity)

    entity.scale = 0.1
    entity.transitionTween = flux.group()
    entity.transitionTween:to(entity, 0.25, { scale = MAX_SCALE }):after(entity, 0.25, { scale = 1.0 })

    entity.tileCost = tileCost

    entity.ui = suit.new()
    entity.ui.theme.color.normal.fg = { 0, 0, 0 }

    return entity
end

--- @return integer screenX, integer screenY. Top-left of the dialog in screen coordinates,
---     snapped to whole pixels
function PlaceTileLackingDialogEntity:screenOrigin()
    local x, y = camera:cameraCoords(self.worldPos.x, self.worldPos.y)
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

function PlaceTileLackingDialogEntity:update(dt, gameState)
    self.transitionTween:update(dt)

    local promptW = math.floor(self.boundingBox.w * self.scale)
    local promptH = math.floor(self.boundingBox.h * self.scale)
    local NUM_ROWS = 3
    local cellHeight = math.floor(promptH / NUM_ROWS)

    local LAYOUT_PAD = 1
    local originX, originY = self:screenOrigin()
    self.ui.layout:reset(originX, originY, LAYOUT_PAD, LAYOUT_PAD)
    self.ui:Label("Cost: " .. self.tileCost, { draw = ViewUtil.suitLabelDraw }, self.ui.layout:row(promptW, cellHeight))
    self.ui:Label("Need More Tiles!", { draw = ViewUtil.suitLabelDraw }, self.ui.layout:row(promptW, cellHeight))
end

--- drawn in screen space (see DrawSys)
function PlaceTileLackingDialogEntity:drawScreen(gameState)
    love.graphics.push()
    do
        local width = math.floor(self.boundingBox.w * self.scale)
        local height = math.floor(self.boundingBox.h * self.scale)
        local cornerR = width * CORNER_RADIUS_SCALER
        local originX, originY = self:screenOrigin()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", originX, originY, width, height, cornerR, cornerR)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", originX, originY, width, height, cornerR, cornerR)

        self.ui:draw()
    end
    love.graphics.pop()
end

return PlaceTileLackingDialogEntity
