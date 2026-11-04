--- State machine for a single player turn during a TilePlacement phase
local TurnStateMachine = require("cloudless_sky.states.turn_sm_base")
local WorldStateMachine = require("cloudless_sky.states.world_sm")

local Components = require("cloudless_sky.components")
local PlaceTileDialogEntity = require("cloudless_sky.entities.place_tile_dialog_entity")
local PlaceTileLackingDialogEntity = require("cloudless_sky.entities.place_tile_lacking_dialog_entity")
local PlayerMatTileAnchorSys = require("cloudless_sky.systems.player_mat_tile_anchor")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local ScoreTextEntity = require("cloudless_sky.entities.score_text_entity")
local PassAction = require("cloudless_sky.action.pass")
local PassConfirmDialogEntity = require("cloudless_sky.entities.pass_confirm_dialog_entity")

---@class TilePlacementTurnStateMachine : TurnStateMachine
local TilePlacementTurnStateMachine = TurnStateMachine:extend()

-- after passing, wait this long before ending the turn so the HUD score count-down can be seen
local PASS_END_DELAY_S = 0.8

TilePlacementTurnStateMachine.STATES = {
    -- waiting for current player to place a tile or pass
    WAIT_FOR_PLACEMENT = 1,
    -- a tile has been placed and its animations are playing
    -- TODO: placement bonuses (surrounding pillars/statues/windows) need a state between
    --  SCORING and WAIT_FOR_END where the player picks their bonus tiles
    SCORING = 2,
    -- placement done. player may end their turn
    WAIT_FOR_END = 3,
    -- pass confirmation dialog is open
    CONFIRM_PASS = 4,
    -- player has passed. waiting briefly before ending the turn
    PASSING = 5,
}

function TilePlacementTurnStateMachine:onEnter()
    self.passDialog = nil
    self.passEndTimer = 0
    self:setViewFocus(WorldStateMachine.VIEW.MAT)
    self:_setState(self.STATES.WAIT_FOR_PLACEMENT)
    Log.trace("entering PlacementTurnSM for " .. tostring(self.playerIdx))
end

function TilePlacementTurnStateMachine:hudButtons(state)
    local done = state == self.STATES.WAIT_FOR_END
    -- passing replaces placing a tile, so it's only possible before placing
    local pass = state == self.STATES.WAIT_FOR_PLACEMENT
    -- no undo mid-animation, while confirming a pass, or after passing (passing ends the turn)
    local settled = state == self.STATES.WAIT_FOR_PLACEMENT or state == self.STATES.WAIT_FOR_END
    return done, pass, settled and self.gameState:canUndoChoice()
end

--- @return integer state The turn state implied by the actions taken so far this turn.
---     Used after an undo so the state machine doesn't need to know what was undone
function TilePlacementTurnStateMachine:stateFromHistory()
    -- TODO: once bonuses exist, return CLAIM_BONUS while the player has pending bonus picks
    for ii = self.gameState.turnHistoryStart + 1, #self.gameState.actionHistory do
        if self.gameState.actionHistory[ii].name == "PlaceTile" then
            return self.STATES.WAIT_FOR_END
        end
    end
    return self.STATES.WAIT_FOR_PLACEMENT
end

function TilePlacementTurnStateMachine:onUpdate(dt)
    if self.state == self.STATES.PASSING then
        self.passEndTimer = self.passEndTimer - dt
        if self.passEndTimer <= 0 then
            self.endTurnRequested = true
        end
    end
end

function TilePlacementTurnStateMachine:onLeave()
    -- eg: debug key ended the turn while the dialog was open
    self:_closePassDialog()
end

--- animate undone placements being removed from the mat
function TilePlacementTurnStateMachine:onUndone(undoneActions)
    for _, action in ipairs(undoneActions) do
        if action.name == "PlaceTile" then
            local ctx = action.ctx
            self.graphicsState.matEntities[ctx.playerIdx]:animateTileRemoved(
                ctx.starIdx,
                ctx.slotIdx,
                ctx.placement.tileType
            )
        end
    end
end

--- Open the pass confirmation dialog, pre-filled with suggested tiles to keep
function TilePlacementTurnStateMachine:_openPassDialog()
    local player = self.gameState.players[self.playerIdx]
    local limit = self.gameState:tileCarryoverLimit()
    local suggested = PassAction.suggestKeep(player.hand, limit, self.gameState:getNextRoundWildType())
    self.passDialog = PassConfirmDialogEntity.new(player.hand, limit, suggested, player.score)
    self.graphicsState.world:addEntity(self.passDialog)
    self:_setState(self.STATES.CONFIRM_PASS)
end

function TilePlacementTurnStateMachine:_closePassDialog()
    if self.passDialog then
        self.graphicsState.world:removeEntity(self.passDialog)
        self.passDialog = nil
    end
end

--- Perform the pass and end the turn shortly after (once the HUD shows the score change)
--- @param keep table TileType -> count of tiles to keep
function TilePlacementTurnStateMachine:_pass(keep)
    self:_closePassDialog()
    local performed, reason = self.gameState:performAction(PassAction(self.playerIdx, keep))
    if not performed then
        -- dialog should only allow valid choices, so this is a bug
        Log.error("invalid pass from dialog: " .. tostring(reason))
        self:_setState(self:stateFromHistory())
        return
    end
    Log.debug("player " .. tostring(self.playerIdx) .. " passed for the round")
    self.passEndTimer = PASS_END_DELAY_S
    self:_setState(self.STATES.PASSING)
end

function TilePlacementTurnStateMachine:_addPlaceDialogEntity(pressCtx)
    local player = self.gameState.players[pressCtx.playerIdx]
    if player:isSlotOccupied(pressCtx.starIdx, pressCtx.slotIdx) then
        -- slot is already occupied. show scoring information
        -- TODO: look through action history to see all the cool things the player did by playing in this particular slot
        print("already played here!")
    else
        local placementOpts = player:generatePlacementPossibilities(
            pressCtx.starIdx,
            pressCtx.slotIdx,
            self.gameState:getCurrentWildType()
        )
        local prompt = nil
        if placementOpts and #placementOpts > 0 then
            -- player has enough in hand to place here
            prompt = PlaceTileDialogEntity.new(
                pressCtx.playerIdx,
                pressCtx.starIdx,
                pressCtx.slotIdx,
                self.gameState:getMatSlotCost(pressCtx.starIdx, pressCtx.slotIdx),
                placementOpts,
                self.gameState:getStarType(pressCtx.starIdx)
            )
        else
            -- player is lacking the tiles needed to place here
            prompt = PlaceTileLackingDialogEntity.new(
                pressCtx.playerIdx,
                pressCtx.starIdx,
                pressCtx.slotIdx,
                self.gameState:getMatSlotCost(pressCtx.starIdx, pressCtx.slotIdx)
            )
        end

        self.graphicsState.world:addEntity(prompt)
        local w, h = love.graphics.getPixelDimensions()
        PlayerMatTileAnchorSys.ensureEntityFullyVisible(prompt, w, h, self.graphicsState.matEntities)
    end
end

--- Perform tile placement on game state and kick off animations.
--- Moves to SCORING, then to WAIT_FOR_END once the tile animation completes
--- @param pressCtx table placeTileClicked click event from PlaceTileDialogEntity
--- @param dialogEntity table the dialog that was clicked. Closed once the tile is placed
function TilePlacementTurnStateMachine:_placeTile(pressCtx, dialogEntity)
    local action = PlaceTileAction(self.playerIdx, pressCtx.starIdx, pressCtx.slotIdx, pressCtx.placementOpt)
    local performed, reason = self.gameState:performAction(action)
    if not performed then
        -- dialog should only ever offer valid placements, so this is a bug
        Log.error("invalid placement offered by dialog: " .. tostring(reason))
        return
    end
    dialogEntity.ephemeral.done = true
    self:_setState(self.STATES.SCORING)

    -- tile bounce-in. once done, the player may end their turn (or undo).
    -- ignore the callback if the turn has changed since (eg: player passed mid-animation)
    local turnIdx = self.gameState.turnIdx
    local matEntity = self.graphicsState.matEntities[self.playerIdx]
    matEntity:animateTilePlaced(pressCtx.starIdx, pressCtx.slotIdx, function()
        if turnIdx == self.gameState.turnIdx and self.state == self.STATES.SCORING then
            self:_setState(self:stateFromHistory())
        end
    end)

    -- "+N Points!" popup at the slot. The HUD score tweens up on its own once it sees the new score
    local scoreText = ScoreTextEntity.new(self.playerIdx, pressCtx.starIdx, pressCtx.slotIdx, action.score)
    self.graphicsState.world:addEntity(scoreText)
    local w, h = love.graphics.getPixelDimensions()
    PlayerMatTileAnchorSys.ensureEntityFullyVisible(scoreText, w, h, self.graphicsState.matEntities)
end

function TilePlacementTurnStateMachine:onClickEvent(pressCtx, entity)
    local eventTypes = Components.mouseHandler.eventTypes
    if pressCtx.type == eventTypes.matSlotClicked then
        -- only one placement per turn
        if self.state == self.STATES.WAIT_FOR_PLACEMENT then
            self:_addPlaceDialogEntity(pressCtx)
        end
    elseif pressCtx.type == eventTypes.placeTileClicked then
        if self.state == self.STATES.WAIT_FOR_PLACEMENT then
            self:_placeTile(pressCtx, entity)
        end
    elseif pressCtx.type == eventTypes.passClicked then
        if self.state == self.STATES.WAIT_FOR_PLACEMENT then
            self:_openPassDialog()
        end
    elseif pressCtx.type == eventTypes.passCancelled then
        self:_closePassDialog()
        self:_setState(self:stateFromHistory())
    elseif pressCtx.type == eventTypes.passConfirmed then
        if self.state == self.STATES.CONFIRM_PASS then
            self:_pass(pressCtx.keep)
        end
    end
end

return TilePlacementTurnStateMachine
