--- Pop-up dialog for spaces where the player can place a tile

local Object = require("cloudless_sky.extern.classic")
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

local PROMPT_WIDTH = 120
local PROMPT_HEIGHT = 100

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

    EUtil.extendEntity(entity, PlaceTileDialogEntity)

    entity.tileCost = tileCost
    entity.placementOptions = placementOptions
    entity.placementOptIdx = 1

    entity.placeBtnScale = 1.0

    entity.scale = 0.1
    entity.transitionTween = flux.group()
    entity.transitionTween:to(entity, 0.25, { scale = MAX_SCALE }):after(entity, 0.25, { scale = 1.0 })

    entity.placeHoverTween = nil

    entity.ui = suit.new()
    entity.ui.theme.color = {
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

    return entity
end

function PlaceTileDialogEntity:_btnHoverTween(tween)
    tween:to(self, 0.5, { placeBtnScale = 1.1 }):after(self, 0.5, { placeBtnScale = 1.0 }):oncomplete(function()
        self:_btnHoverTween(tween)
    end)
end

function PlaceTileDialogEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    if button == 1 then
        -- check if click is within the prompt:
        local clickInBBox =
            ViewUtil.ptInRect(worldX, worldY, self.worldPos.x, self.worldPos.y, self.boundingBox.w, self.boundingBox.h)

        if clickInBBox then
            local btn = self.placeButton
            -- place button was pressed. provide info to state machine
            if ViewUtil.ptInRect(worldX, worldY, btn.x, btn.y, btn.w, btn.h) then
                self.mouseHandler.clickEvent = {
                    type = Components.mouseHandler.eventTypes.placeTileClicked,
                    starIdx = self.playerMatTileAnchor.starIdx,
                    slotIdx = self.playerMatTileAnchor.slotIdx,
                    placementOpt = self.placementOptions[self.placementOptIdx],
                }
            end
        end

        return clickInBBox
    end

    return false
end

function PlaceTileDialogEntity:update(dt, gameState)
    self.transitionTween:update(dt)

    local promptW = self.boundingBox.w * self.scale
    local promptH = self.boundingBox.h * self.scale
    local NUM_ROWS = 3
    local cellHeight = promptH / NUM_ROWS

    local mouseWorldX, mouseWorldY = camera:mousePosition()
    self.ui:enterFrame(mouseWorldX, mouseWorldY)

    local LAYOUT_PAD = 1

    self.ui.layout:reset(self.worldPos.x, self.worldPos.y, LAYOUT_PAD, LAYOUT_PAD)
    self.ui:Label("Cost: " .. self.tileCost, { font = fonts.ithaca["16"] }, self.ui.layout:row(promptW, cellHeight))

    -- cost option row --
    local currentPromptCtx = self.placementOptions[self.placementOptIdx]
    currentPromptCtx["draw"] = TileView.suitDrawTile
    currentPromptCtx["boundingBox"] = WIDGET_BOUNDING_BOXES

    local displayOptionSelectBtns = #self.placementOptions > 1
    local displayWildTile = self.placementOptions[self.placementOptIdx].wildCount > 0

    -- L/R arrow buttons take up 1/6 each. Tile display takes up the other 2/3
    -- decide how much X-space each element gets based on the placement options
    local cellWidth = (promptW - 2 * LAYOUT_PAD) / 3
    if not displayOptionSelectBtns then
        cellWidth = (promptW - 2 * LAYOUT_PAD) / 2
    end
    local tileCellWidth = cellWidth
    if displayWildTile then
        tileCellWidth = tileCellWidth / 2
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
    self.ui:Label(tostring(currentPromptCtx.tileCount), {}, self.ui.layout:col(tileCellWidth, cellHeight))
    if displayWildTile then
        self.ui:Label(
            nil,
            { draw = TileView.suitDrawTile, tileType = currentPromptCtx.wildType, boundingBox = WIDGET_BOUNDING_BOXES },
            self.ui.layout:col(tileCellWidth, cellHeight)
        )
        self.ui:Label(tostring(currentPromptCtx.wildCount), {}, self.ui.layout:col(tileCellWidth, cellHeight))
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

    local placeW = (promptW - 2 * LAYOUT_PAD) * self.placeBtnScale
    local placeH = (cellHeight - NUM_ROWS * LAYOUT_PAD) * self.placeBtnScale
    local placeX, placeY, placeW, placeH = self.ui.layout:col(placeW, placeH)
    placeX = placeX - math.max((placeW - promptW) / 2, 0)

    -- also update the color
    self.ui.theme.color.active.bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType]
    self.ui.theme.color.hovered.bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType]

    self.placeButton = self.ui:Button("Place", {
        font = fonts.ithaca["16"],
        cornerRadius = promptW * CORNER_RADIUS_SCALER - 3,
        outline = 2,
        scale = self.placeBtnScale,
    }, placeX, placeY, placeW, placeH)
    -- handle tweening animation
    if self.placeButton.entered then
        -- start new animation
        print("enter place btn!")
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

    if self.placeButton.hit then
        return self.placementOptions[self.placementOptIdx]
    end
    return nil
end

function PlaceTileDialogEntity:draw(gameState)
    love.graphics.push()
    do
        local width = self.boundingBox.w * self.scale
        local height = self.boundingBox.h * self.scale
        local cornerR = width * CORNER_RADIUS_SCALER

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", self.worldPos.x, self.worldPos.y, width, height, cornerR, cornerR)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.worldPos.x, self.worldPos.y, width, height, cornerR, cornerR)

        self.ui:draw()
    end
    love.graphics.pop()
end

return PlaceTileDialogEntity
