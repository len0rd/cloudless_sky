--- Dialog to display when a slot is clicked during place phase but player has insufficient tiles
local Components = require("cloudless_sky.components")
local PopInDialog = require("cloudless_sky.entities.pop_in_dialog")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class PlaceTileLackingDialogEntity : PopInDialog
local PlaceTileLackingDialogEntity = setmetatable({}, { __index = PopInDialog })
PlaceTileLackingDialogEntity.__index = PlaceTileLackingDialogEntity

-- dialog dimensions in screen pixels
local PROMPT_WIDTH = 190 -- wide enough for "Need More Tiles!" at 32px
local PROMPT_HEIGHT = 100
local NUM_ROWS = 3

function PlaceTileLackingDialogEntity.new(playerIdx, starIdx, slotIdx, tileCost)
    local entity = PopInDialog.create(PlaceTileLackingDialogEntity, PROMPT_WIDTH, PROMPT_HEIGHT)
    entity
        :give(Components.names.playerMatTileAnchor, starIdx, slotIdx)
        :give(Components.names.playerEntity, playerIdx)
        :give(Components.names.killOffCamera) -- in the event state machine doesnt remove the prompt, ensure its removed once off camera

    entity.tileCost = tileCost
    return entity
end

function PlaceTileLackingDialogEntity:layoutContent(dt, promptW, promptH)
    local cellHeight = math.floor(promptH / NUM_ROWS)
    self.ui:Label("Cost: " .. self.tileCost, { draw = ViewUtil.suitLabelDraw }, self.ui.layout:row(promptW, cellHeight))
    self.ui:Label("Need More Tiles!", { draw = ViewUtil.suitLabelDraw }, self.ui.layout:row(promptW, cellHeight))
end

return PlaceTileLackingDialogEntity
