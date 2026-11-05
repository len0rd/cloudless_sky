--- State machine for a single player turn during a TileSelection phase:
--- pick tiles of one color from a factory display or the center of the table, then press Done
--- (the pick can be undone until then)
local TurnStateMachine = require("cloudless_sky.states.turn_sm_base")
local WorldStateMachine = require("cloudless_sky.states.world_sm")

local Components = require("cloudless_sky.components")
local PickUpDialogEntity = require("cloudless_sky.entities.pick_up_dialog_entity")
local TableAreaEntity = require("cloudless_sky.entities.table_area_entity")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")

---@class TileSelectionTurnStateMachine : TurnStateMachine
local TileSelectionTurnStateMachine = TurnStateMachine:extend()

TileSelectionTurnStateMachine.STATES = {
    -- waiting for the player to pick tiles
    WAIT_FOR_PICK = 1,
    -- tiles were picked and are animating off the table
    PICKING = 2,
    -- pick done. player may end their turn (or undo)
    WAIT_FOR_END = 3,
}

function TileSelectionTurnStateMachine:onEnter()
    -- the open PickUpDialogEntity, if any
    self.pickUpDialog = nil
    self:setViewFocus(WorldStateMachine.VIEW.TABLE)
    self:_setState(self:stateFromHistory())
    Log.trace("entering SelectionTurnSM for " .. tostring(self.playerIdx))
end

function TileSelectionTurnStateMachine:hudButtons(state)
    local done = state == self.STATES.WAIT_FOR_END
    local undo = state ~= self.STATES.PICKING and self.gameState:canUndoChoice()
    -- passing is only for the placement phase
    return done, false, undo
end

function TileSelectionTurnStateMachine:stateFromHistory()
    for ii = self.gameState.turnHistoryStart + 1, #self.gameState.actionHistory do
        if self.gameState.actionHistory[ii].name == "TakeTiles" then
            return self.STATES.WAIT_FOR_END
        end
    end
    return self.STATES.WAIT_FOR_PICK
end

--- @return integer total number of tiles in a TileType -> count table
local function total(counts)
    local sum = 0
    for _, count in pairs(counts) do
        sum = sum + count
    end
    return sum
end

--- Show what picking \p pressCtx.tileType from \p pressCtx.source would pick up, with a Pick Up button
--- @param pressCtx table tableTileClicked click event from TableAreaEntity
function TileSelectionTurnStateMachine:_openPickUpDialog(pressCtx)
    local take = TableAreaEntity.takeFor(self.gameState, pressCtx.source, pressCtx.tileType)
    if not take then
        return
    end
    local penalty = TakeTilesAction.penaltyFor(self.gameState, self.playerIdx, pressCtx.source, total(take))
    local dialog = PickUpDialogEntity.new(pressCtx.source, pressCtx.tileType, take, penalty)
    dialog:placeNear(pressCtx.worldX, pressCtx.worldY)
    self.graphicsState.world:addEntity(dialog)
    self.pickUpDialog = dialog
end

--- Take the tiles and animate them off the table. Moves to PICKING, then WAIT_FOR_END
--- @param pressCtx table pickUpClicked click event from PickUpDialogEntity
--- @param dialogEntity table the dialog that was clicked. Closed once the tiles are taken
function TileSelectionTurnStateMachine:_pickUp(pressCtx, dialogEntity)
    local action = TakeTilesAction(self.playerIdx, pressCtx.source, pressCtx.tileType)
    local performed, reason = self.gameState:performAction(action)
    if not performed then
        -- dialog should only ever offer valid picks, so this is a bug
        Log.error("invalid pick offered by dialog: " .. tostring(reason))
        return
    end
    dialogEntity.ephemeral.done = true
    self:_setState(self.STATES.PICKING)

    local turnIdx = self.gameState.turnIdx
    self.graphicsState.table:animateTake(action.ctx, function()
        if turnIdx == self.gameState.turnIdx and self.state == self.STATES.PICKING then
            self:_setState(self:stateFromHistory())
        end
    end)
end

function TileSelectionTurnStateMachine:onClickEvent(pressCtx, entity)
    local eventTypes = Components.mouseHandler.eventTypes
    if pressCtx.type == eventTypes.tableTileClicked then
        if self.state == self.STATES.WAIT_FOR_PICK then
            self:_openPickUpDialog(pressCtx)
        end
    elseif pressCtx.type == eventTypes.pickUpClicked then
        if self.state == self.STATES.WAIT_FOR_PICK then
            self:_pickUp(pressCtx, entity)
        end
    end
end

return TileSelectionTurnStateMachine
