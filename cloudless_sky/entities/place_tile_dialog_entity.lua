--- Pop-up dialog for spaces where the player can place a tile
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local StarView = require("cloudless_sky.view.star_view")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

---@class PlaceTileDialogEntity
---@field scale number Scale of the entire entity
---@field transitionTween table flux group for tweening the entity onto the screen
---@field ui suit Suit UI instance for drawing all the gui poritions of the entity
local PlaceTileDialogEntity = {}
PlaceTileDialogEntity.__index = PlaceTileDialogEntity

-- dialog dimensions in screen pixels
local PROMPT_WIDTH = 160
local PROMPT_HEIGHT = 120

-- max scale the border box will be drawn at during transitionTween
local MAX_SCALE = 1.5

-- stuff for drawing arrows
local MAX_ARROW_SIZE = PROMPT_HEIGHT / 10
local PAD = 2
local CORNER_RADIUS_SCALER = 1 / 10

-- for debug
local WIDGET_BOUNDING_BOXES = false

--- triangle vertices
---      1
---  3 <|
---     2
local leftArrowDraw = function(text, opt, x, y, w, h)
    local size = math.max(math.min(w, h), MAX_ARROW_SIZE)
    local wOffset = ((w - size) / 2) + PAD
    local hOffset = ((h - size) / 2) + PAD

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

    if WIDGET_BOUNDING_BOXES then
        love.graphics.setColor({ 0.5, 0, 0 })
        love.graphics.rectangle("line", x, y, w, h)
    end
end

--- triangle vertices
---  1
---  |> 2
---  3
local rightArrowDraw = function(text, opt, x, y, w, h)
    local size = math.max(math.min(w, h), MAX_ARROW_SIZE)
    local wOffset = ((w - size) / 2) + PAD
    local hOffset = ((h - size) / 2) + PAD

    -- stylua: ignore start
    local vertices = {
        wOffset, hOffset,
        w - wOffset, h / 2,
        wOffset,     h -hOffset,
    }
    -- stylua: ignore end
    ViewUtil.shiftVerticies(vertices, x, y)
    love.graphics.setColor(love.math.colorFromBytes(30, 30, 30))
    love.graphics.polygon("fill", vertices)

    if WIDGET_BOUNDING_BOXES then
        love.graphics.setColor({ 0.5, 0, 0 })
        love.graphics.rectangle("line", x, y, w, h)
    end
end

function PlaceTileDialogEntity.new(playerIdx, starIdx, slotIdx, tileCost, placementOptions, starType)
    local entity = Concord.entity()

    entity
        :give(Components.names.playerMatTileAnchor, starIdx, slotIdx)
        :give(Components.names.playerEntity, playerIdx)
        :give(Components.names.boundingBox, PROMPT_WIDTH, PROMPT_HEIGHT)
        :give(Components.names.mouseHandler, Constants.drawPriority.tilePlacePrompt)
        :give(Components.names.drawable, Constants.drawPriority.tilePlacePrompt)
        :give(Components.names.worldPos, 0, 0)
        :give(Components.names.killOffCamera) -- in the event state machine doesnt remove the prompt, ensure its removed once off camera
        :give(Components.names.uniqueGroup, "tilePlacementDialogs")
        :give(Components.names.ephemeral)
        :give(Components.names.dismissOnClickOutside)

    EUtil.extendEntity(entity, PlaceTileDialogEntity)

    entity.tileCost = tileCost
    entity.placementOptions = placementOptions
    entity.placementOptIdx = 1

    entity.placeBtnScale = 1.0

    entity.scale = 0.1
    entity.transitionTween = flux.group()
    entity.transitionTween:to(entity, 0.25, { scale = MAX_SCALE }):after(entity, 0.25, { scale = 1.0 })

    entity.placeHoverTween = nil

    local customTheme = table.copy(require("cloudless_sky.extern.suit.theme"))
    customTheme.color = {
        normal = { bg = StarView.UNPLACED_SLOT_COLOR[starType], fg = { 0, 0, 0 } },
        hovered = {
            bg = TileView.TILE_COLOR[entity.placementOptions[entity.placementOptIdx].tileType],
            fg = { 0, 0, 0 },
        },
        active = {
            bg = TileView.TILE_COLOR[entity.placementOptions[entity.placementOptIdx].tileType],
            fg = { 0, 0, 0 },
        },
    }
    entity.ui = suit.new(customTheme)

    return entity
end

function PlaceTileDialogEntity:_btnHoverTween(tween)
    tween:to(self, 0.5, { placeBtnScale = 1.1 }):after(self, 0.5, { placeBtnScale = 1.0 }):oncomplete(function()
        self:_btnHoverTween(tween)
    end)
end

--- @return integer screenX, integer screenY. Top-left of the dialog in screen coordinates,
---     snapped to whole pixels
function PlaceTileDialogEntity:screenOrigin()
    local x, y = camera:cameraCoords(self.worldPos.x, self.worldPos.y)
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

--- Claims any press inside the dialog. Presses outside it dismiss the dialog
--- (dismissOnClickOutside, see MousePressedSys)
function PlaceTileDialogEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    local originX, originY = self:screenOrigin()
    if not ViewUtil.ptInRect(cameraX, cameraY, originX, originY, self.boundingBox.w, self.boundingBox.h) then
        return false
    end

    local btn = self.placeButton
    if button == 1 and btn and ViewUtil.ptInRect(cameraX, cameraY, btn.x, btn.y, btn.w, btn.h) then
        -- place button was pressed. provide info to state machine
        self.mouseHandler.clickEvent = {
            type = Components.mouseHandler.eventTypes.placeTileClicked,
            starIdx = self.playerMatTileAnchor.starIdx,
            slotIdx = self.playerMatTileAnchor.slotIdx,
            placementOpt = self.placementOptions[self.placementOptIdx],
        }
    end
    return true
end

function PlaceTileDialogEntity:update(dt, gameState)
    self.transitionTween:update(dt)

    local promptW = math.floor(self.boundingBox.w * self.scale)
    local promptH = math.floor(self.boundingBox.h * self.scale)
    local NUM_ROWS = 3
    local cellHeight = math.floor(promptH / NUM_ROWS)

    -- dialog is laid out in screen space, so the default (screen) mouse position is correct
    self.ui:enterFrame()

    local LAYOUT_PAD = 1

    local originX, originY = self:screenOrigin()
    self.ui.layout:reset(originX, originY, LAYOUT_PAD, LAYOUT_PAD)
    self.ui:Label("Cost: " .. self.tileCost, { draw = ViewUtil.suitLabelDraw }, self.ui.layout:row(promptW, cellHeight))

    -- cost option row --
    local currentPromptCtx = self.placementOptions[self.placementOptIdx]
    currentPromptCtx["draw"] = TileView.suitDrawTile
    currentPromptCtx["boundingBox"] = WIDGET_BOUNDING_BOXES

    local displayOptionSelectBtns = #self.placementOptions > 1
    local displayWildTile = self.placementOptions[self.placementOptIdx].wildCount > 0

    -- L/R arrow buttons take up 1/6 each. Tile display takes up the other 2/3
    -- decide how much X-space each element gets based on the placement options
    local cellWidth = math.floor((promptW - 2 * LAYOUT_PAD) / 3)
    if not displayOptionSelectBtns then
        cellWidth = math.floor((promptW - 2 * LAYOUT_PAD) / 2)
    end
    local tileCellWidth = cellWidth
    if displayWildTile then
        tileCellWidth = math.floor(tileCellWidth / 2)
    end

    self.ui.layout:newRow()
    if displayOptionSelectBtns then
        local lArr =
            self.ui:Button("placeOptLArr", { draw = leftArrowDraw }, self.ui.layout:col(cellWidth / 2, cellHeight))
        if lArr.hit then
            self.placementOptIdx = self.placementOptIdx - 1
            if self.placementOptIdx <= 0 then
                self.placementOptIdx = #self.placementOptions
            end
        end
    end

    self.ui:Label(nil, currentPromptCtx, self.ui.layout:col(tileCellWidth, cellHeight))
    self.ui:Label(
        tostring(currentPromptCtx.tileCount),
        { draw = ViewUtil.suitLabelDraw },
        self.ui.layout:col(tileCellWidth, cellHeight)
    )
    if displayWildTile then
        self.ui:Label(
            nil,
            { draw = TileView.suitDrawTile, tileType = currentPromptCtx.wildType, boundingBox = WIDGET_BOUNDING_BOXES },
            self.ui.layout:col(tileCellWidth, cellHeight)
        )
        self.ui:Label(
            tostring(currentPromptCtx.wildCount),
            { draw = ViewUtil.suitLabelDraw },
            self.ui.layout:col(tileCellWidth, cellHeight)
        )
    end

    if displayOptionSelectBtns then
        local rArr =
            self.ui:Button("placeOptRArr", { draw = rightArrowDraw }, self.ui.layout:col(cellWidth / 2, cellHeight))
        if rArr.hit then
            self.placementOptIdx = self.placementOptIdx + 1
            if self.placementOptIdx > #self.placementOptions then
                self.placementOptIdx = 1
            end
        end
    end

    self.ui.layout:newRow()

    -- also update the color
    self.ui.theme.color.active.bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType]
    self.ui.theme.color.hovered.bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType]

    self.placeButton = self.ui:Button("Place", {
        draw = ViewUtil.suitButtonDraw,
        cornerRadius = promptW * CORNER_RADIUS_SCALER - 3,
        outline = 2,
        scale = self.placeBtnScale,
    }, self.ui.layout:col(promptW, cellHeight))
    -- handle tweening animation
    if self.placeButton.entered then
        -- start new animation
        Log.trace("enter place btn!")
        self.placeHoverTween = nil
        self.placeHoverTween = flux.group()
        self:_btnHoverTween(self.placeHoverTween)
    end
    if self.placeButton.hovered then
        self.placeHoverTween:update(dt)
    elseif self.placeButton.left then
        self.placeBtnScale = 1.0
        self.placeHoverTween = nil
    end
end

--- drawn in screen space (see DrawSys)
function PlaceTileDialogEntity:drawScreen(gameState)
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

return PlaceTileDialogEntity
