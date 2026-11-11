--- Pop-up dialog for spaces where the player can place a tile
local Components = require("cloudless_sky.components")
local PopInDialog = require("cloudless_sky.entities.pop_in_dialog")
local StarView = require("cloudless_sky.view.star_view")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class PlaceTileDialogEntity : PopInDialog
local PlaceTileDialogEntity = setmetatable({}, { __index = PopInDialog })
PlaceTileDialogEntity.__index = PlaceTileDialogEntity

-- dialog dimensions in screen pixels
local PROMPT_WIDTH = 160
local PROMPT_HEIGHT = 120
local NUM_ROWS = 3

-- stuff for drawing arrows
local MAX_ARROW_SIZE = PROMPT_HEIGHT / 10
local PAD = 2

local drawArrow = function(vertices, x, y, w, h)
    ViewUtil.shiftVerticies(vertices, x, y)
    love.graphics.setColor(love.math.colorFromBytes(30, 30, 30))
    love.graphics.polygon("fill", vertices)

    if PopInDialog.WIDGET_BOUNDING_BOXES then
        love.graphics.setColor({ 0.5, 0, 0 })
        love.graphics.rectangle("line", x, y, w, h)
    end
end

--- triangle vertices
---      1
---  3 <|
---     2
local leftArrowDraw = function(text, opt, x, y, w, h)
    local size = math.max(math.min(w, h), MAX_ARROW_SIZE)
    local wOffset = ((w - size) / 2) + PAD
    local hOffset = ((h - size) / 2) + PAD
    -- stylua: ignore start
    drawArrow({
        w - wOffset, hOffset,
        w - wOffset, h - hOffset,
        wOffset,     h / 2,
    }, x, y, w, h)
    -- stylua: ignore end
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
    drawArrow({
        wOffset,     hOffset,
        w - wOffset, h / 2,
        wOffset,     h - hOffset,
    }, x, y, w, h)
    -- stylua: ignore end
end

function PlaceTileDialogEntity.new(playerIdx, starIdx, slotIdx, tileCost, placementOptions, starType)
    local entity = PopInDialog.create(PlaceTileDialogEntity, PROMPT_WIDTH, PROMPT_HEIGHT)
    entity
        :give(Components.names.playerMatTileAnchor, starIdx, slotIdx)
        :give(Components.names.playerEntity, playerIdx)
        :give(Components.names.killOffCamera) -- in the event state machine doesnt remove the prompt, ensure its removed once off camera

    entity.tileCost = tileCost
    entity.placementOptions = placementOptions
    entity.placementOptIdx = 1
    entity.starType = starType
    return entity
end

function PlaceTileDialogEntity:actionEvent()
    return {
        type = Components.mouseHandler.eventTypes.placeTileClicked,
        starIdx = self.playerMatTileAnchor.starIdx,
        slotIdx = self.playerMatTileAnchor.slotIdx,
        placementOpt = self.placementOptions[self.placementOptIdx],
    }
end

--- A press on an arrow shows the previous / next placement option. Otherwise as any pop-in dialog
--- (the Place button, claiming presses inside it)
function PlaceTileDialogEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    if button == 1 then
        for step, r in pairs({ [-1] = self.leftArrowRect, [1] = self.rightArrowRect }) do
            if r and ViewUtil.ptInRect(cameraX, cameraY, r.x, r.y, r.w, r.h) then
                self:_cycleOption(step)
                return true
            end
        end
    end
    return PopInDialog.mousePressed(self, cameraX, cameraY, worldX, worldY, button, istouch)
end

function PlaceTileDialogEntity:_cycleOption(step)
    self.placementOptIdx = ((self.placementOptIdx - 1 + step) % #self.placementOptions) + 1
end

function PlaceTileDialogEntity:layoutContent(dt, promptW, promptH)
    local pad = PopInDialog.LAYOUT_PAD
    local cellHeight = math.floor(promptH / NUM_ROWS)
    self.ui:Label("Cost: " .. self.tileCost, { draw = ViewUtil.suitLabelDraw }, self.ui.layout:row(promptW, cellHeight))

    -- cost option row --
    local option = self.placementOptions[self.placementOptIdx]
    local displayOptionSelectBtns = #self.placementOptions > 1
    local displayWildTile = option.wildCount > 0

    -- L/R arrow buttons take up 1/6 each. Tile display takes up the other 2/3
    -- decide how much X-space each element gets based on the placement options
    local cellWidth = math.floor((promptW - 2 * pad) / 3)
    if not displayOptionSelectBtns then
        cellWidth = math.floor((promptW - 2 * pad) / 2)
    end
    local tileCellWidth = cellWidth
    if displayWildTile then
        tileCellWidth = math.floor(tileCellWidth / 2)
    end

    self.ui.layout:newRow()
    -- the arrows cycle the option on a press (see mousePressed); suit only draws them
    self.leftArrowRect, self.rightArrowRect = nil, nil
    if displayOptionSelectBtns then
        local x, y, w, h = self.ui.layout:col(cellWidth / 2, cellHeight)
        self.ui:Button("placeOptLArr", { draw = leftArrowDraw }, x, y, w, h)
        self.leftArrowRect = { x = x, y = y, w = w, h = h }
    end
    self:tileCountCols(option.tileType, option.tileCount, option.wildType, option.wildCount, tileCellWidth, cellHeight)
    if displayOptionSelectBtns then
        local x, y, w, h = self.ui.layout:col(cellWidth / 2, cellHeight)
        self.ui:Button("placeOptRArr", { draw = rightArrowDraw }, x, y, w, h)
        self.rightArrowRect = { x = x, y = y, w = w, h = h }
    end

    self.ui.layout:newRow()
    -- the option may have changed above
    local tileColor = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType]
    self:actionButtonCol("Place", {
        normal = { bg = StarView.UNPLACED_SLOT_COLOR[self.starType], fg = { 0, 0, 0 } },
        hovered = { bg = tileColor, fg = { 0, 0, 0 } },
        active = { bg = tileColor, fg = { 0, 0, 0 } },
    }, promptW, cellHeight, dt)
end

return PlaceTileDialogEntity
