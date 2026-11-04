--- State machine for one round of the game (see docs/game_sm.drawio.svg):
---     1. FILLING:   fill the factory displays (animated one display at a time)
---     2. SELECTION: players take TileSelection turns until the displays and center are empty
---     3. PLACEMENT: players take TilePlacement turns until everyone has passed
---     4. round end upkeep (EndRoundAction), then pop back to the Game. After the final round there
---        is no upkeep: the game is over
--- Turns are pushed on top of this state machine. When one pops, resume moves to the next player.
local WorldStateMachine = require("cloudless_sky.states.world_sm")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

local EndRoundAction = require("cloudless_sky.action.end_round")
local FillFactoryDisplaysAction = require("cloudless_sky.action.fill_factory_displays")
local PassAction = require("cloudless_sky.action.pass")
local StartPlacementPhaseAction = require("cloudless_sky.action.start_placement_phase")
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

--- Perform a game (non-player) action. These should always be valid, so failing is a bug
local function performGameAction(gameState, action)
    local performed, reason = gameState:performAction(action)
    if not performed then
        error("game action " .. action.name .. " failed: " .. tostring(reason))
    end
    return performed
end

function GameRoundStateMachine:enter(fromState, gameState, graphicsState)
    self:_bind(gameState, graphicsState)
    Log.info("starting round " .. gameState.round.idx .. " (wild: " .. tostring(gameState:getCurrentWildType()) .. ")")

    -- no turn yet: nothing for the HUD buttons to do
    local hud = graphicsState.hud.container
    hud:setDoneEnabled(false)
    hud:setPassEnabled(false)
    hud:setUndoEnabled(false)
    self:setViewFocus(WorldStateMachine.VIEW.TABLE)

    self.state = self.STATES.FILLING
    self.fillDone = false
    local performed = performGameAction(gameState, FillFactoryDisplaysAction())
    graphicsState.table:playFill(performed[1].ctx.events, function()
        self.fillDone = true
    end)
end

function GameRoundStateMachine:resume(fromState)
    -- a turn just ended
    self.gameState:incrementTurn()
end

--- Start the placement phase: the start player token holder goes first
function GameRoundStateMachine:_startPlacement()
    local gameState = self.gameState
    performGameAction(gameState, StartPlacementPhaseAction())
    gameState:beginTurn(gameState.startTokenHolder or gameState.startPlayer)
    self.state = self.STATES.PLACEMENT
    Log.info("placement phase. player " .. gameState.currentTurnPlayer .. " starts")
end

--- @return boolean True if the round is over (and this state machine popped)
function GameRoundStateMachine:_updatePlacement()
    local gameState = self.gameState
    if gameState:allPlayersPassed() then
        if not gameState:isFinalRound() then
            performGameAction(gameState, EndRoundAction())
        end
        GameStateMachineMgr.pop()
        return true
    end

    local playerIdx = gameState.currentTurnPlayer
    if gameState.players[playerIdx].hand:isEmpty() then
        -- nothing to place: pass for them (no tiles, so no penalty) and move on
        Log.debug("player " .. playerIdx .. " has no tiles. passing for them")
        performGameAction(gameState, PassAction(playerIdx, {}))
        gameState:incrementTurn()
        return false
    end
    GameStateMachineMgr.push(self.placementTurn, playerIdx, gameState, self.graphicsState)
    return false
end

function GameRoundStateMachine:update(dt)
    local gameState = self.gameState

    if self.state == self.STATES.FILLING then
        if self.fillDone then
            gameState:beginTurn(gameState.startPlayer)
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
        if gameState:allTileSourcesEmpty() then
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
