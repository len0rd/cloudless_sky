--- Pop-up dialog for picking up tiles from a factory display or the center of the table.
--- Shows what would be picked up (and the first-from-center penalty, if any) with a Pick Up button
local Components = require("cloudless_sky.components")
local PopInDialog = require("cloudless_sky.entities.pop_in_dialog")
local TileType = require("cloudless_sky.model.tile_type")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class PickUpDialogEntity : PopInDialog
local PickUpDialogEntity = setmetatable({}, { __index = PopInDialog })
PickUpDialogEntity.__index = PickUpDialogEntity

-- dialog dimensions in screen pixels
local PROMPT_WIDTH = 210 -- wide enough for the penalty line at 32px
local ROW_HEIGHT = 40
local PENALTY_COLOR = { 0.7, 0.1, 0.1 }
local BUTTON_IDLE_COLOR = { 0.85, 0.85, 0.85 }

--- @param source integer GameState.CENTER or a factory display index
--- @param tileType TileType the color picked
--- @param take table TileType -> count that would be picked up (TakeTilesAction.tilesToTake)
--- @param penalty integer points lost for this pick (first pick from the center)
function PickUpDialogEntity.new(source, tileType, take, penalty)
    local numRows = penalty > 0 and 4 or 3
    local entity = PopInDialog.create(PickUpDialogEntity, PROMPT_WIDTH, ROW_HEIGHT * numRows)
    entity.source = source
    entity.tileType = tileType
    entity.take = take
    entity.penalty = penalty
    entity.numRows = numRows

    -- the other color picked up along with tileType (a wild), if any
    entity.extraType = nil
    for _, t in ipairs(TileType.ORDERED) do
        if t ~= tileType and (take[t] or 0) > 0 then
            entity.extraType = t
        end
    end
    return entity
end

function PickUpDialogEntity:actionEvent()
    return {
        type = Components.mouseHandler.eventTypes.pickUpClicked,
        source = self.source,
        tileType = self.tileType,
    }
end

function PickUpDialogEntity:layoutContent(dt, promptW, promptH)
    local pad = PopInDialog.LAYOUT_PAD
    local cellHeight = math.floor(promptH / self.numRows)
    local total = 0
    for _, count in pairs(self.take) do
        total = total + count
    end
    local title = total == 1 and "Take 1 tile" or ("Take " .. total .. " tiles")
    self.ui:Label(title, { draw = ViewUtil.suitLabelDraw }, self.ui.layout:row(promptW, cellHeight))

    self.ui.layout:newRow()
    local numCells = self.extraType and 4 or 2
    local cellW = math.floor((promptW - 2 * pad) / numCells)
    self:tileCountCols(
        self.tileType,
        self.take[self.tileType],
        self.extraType,
        self.extraType and self.take[self.extraType] or 0,
        cellW,
        cellHeight
    )

    if self.penalty > 0 then
        self.ui.layout:newRow()
        self.ui:Label(
            "First pick: -" .. self.penalty .. " pts",
            { draw = ViewUtil.suitLabelDraw, color = { normal = { fg = PENALTY_COLOR } } },
            self.ui.layout:col(promptW, cellHeight)
        )
    end

    self.ui.layout:newRow()
    local tileColor = TileView.TILE_COLOR[self.tileType]
    self:actionButtonCol("Pick Up", {
        normal = { bg = BUTTON_IDLE_COLOR, fg = { 0, 0, 0 } },
        hovered = { bg = tileColor, fg = { 0, 0, 0 } },
        active = { bg = tileColor, fg = { 0, 0, 0 } },
    }, promptW, cellHeight, dt)
end

return PickUpDialogEntity
