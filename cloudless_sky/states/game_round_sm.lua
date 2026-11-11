--- State machine for one round of the game (see docs/game_sm.drawio.svg):
---     1. FILLING:   fill the factory displays (animated one display at a time). At the start of the
---                   game the bonus pool is filled first
---     2. SELECTION: players take TileSelection turns until the displays and center are empty
---     3. PLACEMENT: players take TilePlacement turns until everyone has passed
---     4. round end upkeep (EndRoundAction), then pop back to the Game. After the final round there
---        is no upkeep: the game is over
--- Turns are pushed on top of this state machine. When one pops, resume moves to the next player.
--- After a placement turn the bonus pool is topped back up first (bonus tiles the player picked up).
---
--- Entering also resumes a round part way through (a loaded save game): where the round is comes from
--- the model and its history, so nothing is performed twice.
---
--- The actions themselves come from GameFlow (model only, shared with headless games): this state
--- machine adds the view, the animation and the timing around them.
local WorldStateMachine = require("cloudless_sky.states.world_sm")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

local GameFlow = require("cloudless_sky.model.game_flow")
local TilePlacementTurnStateMachine = require("cloudless_sky.states.tile_placement_turn_sm")
local TileSelectionTurnStateMachine = require("cloudless_sky.states.tile_selection_turn_sm")

---@class GameRoundStateMachine : WorldStateMachine
local GameRoundStateMachine = WorldStateMachine:extend()

GameRoundStateMachine.STATES = {
    FILLING = 1,
    SELECTION = 2,
    PLACEMENT = 3,
}

function GameRoundStateMachine:new()
    self.selectionTurn = TileSelectionTurnStateMachine()
    self.placementTurn = TilePlacementTurnStateMachine()
end

function GameRoundStateMachine:enter(fromState, gameState, graphicsState)
    self:_bind(gameState, graphicsState)

    -- no turn yet: nothing for the HUD buttons to do
    local hud = graphicsState.hud.container
    hud:setDoneEnabled(false)
    hud:setPassEnabled(false)
    hud:setUndoEnabled(false)
    self:setViewFocus(WorldStateMachine.VIEW.TABLE)

    local fillIdx = GameFlow.roundFillIndex(gameState)
    if fillIdx then
        self:_resumeRound(fillIdx)
        return
    end

    Log.info("starting round " .. gameState.round.idx .. " (wild: " .. tostring(gameState:getCurrentWildType()) .. ")")
    self.state = self.STATES.FILLING
    self.fillDone = false
    -- the bonus pool's first fill (the start of the game) and the displays' fill, performed together so
    -- a save can't come between them. The first turn begins once they've been animated (see update)
    for _, action in ipairs(GameFlow.startRound(gameState)) do
        if action.name == "FillBonusPool" then
            graphicsState.table:playFill(action.ctx.events)
        elseif action.name == "FillFactoryDisplays" then
            graphicsState.table:playFill(action.ctx.events, function()
                self.fillDone = true
            end)
        end
    end
end

--- Pick a round back up part way through (a loaded save game). The view was built from the model,
--- so only the state machine needs to catch up
--- @param fillIdx integer history index of this round's FillFactoryDisplays
function GameRoundStateMachine:_resumeRound(fillIdx)
    local gameState = self.gameState
    Log.info("resuming round " .. gameState.round.idx .. " (wild: " .. tostring(gameState:getCurrentWildType()) .. ")")
    if gameState.round.phase == gameState.RoundPhase.TILE_PLACEMENT then
        self.state = self.STATES.PLACEMENT
        return
    end
    self.state = self.STATES.SELECTION
    if gameState:turnStartIndex() == fillIdx then
        -- saved while the fill was animating: the first turn hadn't begun yet (see FILLING in update)
        GameFlow.beginRound(gameState)
    end
end

function GameRoundStateMachine:resume(fromState)
    -- only a turn ending moves the game on. Not eg: the menu closing, or a load replacing this game
    if self.abandoned or (fromState ~= self.selectionTurn and fromState ~= self.placementTurn) then
        return
    end
    -- after a placement turn the bonus pool is topped back up (animated on the table)
    for _, action in ipairs(GameFlow.endTurn(self.gameState, fromState == self.placementTurn)) do
        if action.name == "FillBonusPool" then
            self.graphicsState.table:playFill(action.ctx.events)
        end
    end
end

--- Start the placement phase: the start player token holder goes first
function GameRoundStateMachine:_startPlacement()
    local gameState = self.gameState
    GameFlow.startPlacement(gameState)
    self.state = self.STATES.PLACEMENT
    Log.info("placement phase. player " .. gameState.currentTurnPlayer .. " starts")
end

--- @return boolean True if the round is over (and this state machine popped)
function GameRoundStateMachine:_updatePlacement()
    local gameState = self.gameState
    if GameFlow.placementOver(gameState) then
        GameFlow.endRound(gameState)
        GameStateMachineMgr.pop()
        return true
    end

    -- nothing to place: they're passed for, and the next player is up
    if GameFlow.passEmptyHand(gameState) then
        return false
    end
    GameStateMachineMgr.push(self.placementTurn, gameState.currentTurnPlayer, gameState, self.graphicsState)
    return false
end

function GameRoundStateMachine:update(dt)
    local gameState = self.gameState

    if self.state == self.STATES.FILLING then
        if self.fillDone then
            GameFlow.beginRound(gameState)
            self.state = self.STATES.SELECTION
        else
            local pressCtx = self:pendingClick()
            if pressCtx then
                self:handleCommonClick(pressCtx)
            end
            self:updateWorld(dt)
        end
        return
    end

    if self.state == self.STATES.SELECTION then
        if GameFlow.selectionOver(gameState) then
            self:_startPlacement()
        else
            GameStateMachineMgr.push(self.selectionTurn, gameState.currentTurnPlayer, gameState, self.graphicsState)
        end
        return
    end

    if self.state == self.STATES.PLACEMENT then
        self:_updatePlacement()
    end
end

return GameRoundStateMachine
