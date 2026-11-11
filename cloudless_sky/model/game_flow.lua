--- The game's automatic flow: the actions the game performs by itself between player choices, in the
--- order the rules need them. Model only (no view), so anything can drive a game: the UI's state
--- machines (which add animation and timing around these steps) or a headless runner.
---
--- A game goes:
---     round:      startRound (the bonus pool's first fill + the factory displays), beginRound
---     selection:  players take tiles (TakeTilesAction) and end their turn (endTurn) until
---                 selectionOver, then startPlacement
---     placement:  players place tiles (PlaceTileAction, then TakeBonusTilesAction if BonusPickup.owed)
---                 or pass (PassAction), ending each turn (endTurn). A player with an empty hand is
---                 passed for (passEmptyHand). Once placementOver: endRound (not after the final round)
---     game over:  once isGameOver, each player in turn (nextToScore): beginScoring, scorePlayer
---
--- Every function performs game (non-player) actions, which are always valid: one failing is a bug and
--- raises an error. Each returns the actions it performed (in order), so a view can animate their events
local BeginTurnAction = require("cloudless_sky.action.begin_turn")
local EndRoundAction = require("cloudless_sky.action.end_round")
local FillBonusPoolAction = require("cloudless_sky.action.fill_bonus_pool")
local FillFactoryDisplaysAction = require("cloudless_sky.action.fill_factory_displays")
local PassAction = require("cloudless_sky.action.pass")
local ScoreEndGameAction = require("cloudless_sky.action.score_end_game")
local StartPlacementPhaseAction = require("cloudless_sky.action.start_placement_phase")

local GameFlow = {}

--- Perform \p action, raising an error if it's invalid
--- @return Action[] performed (\p action and its follow-ups)
local function perform(gameState, action)
    local performed, reason = gameState:performAction(action)
    if not performed then
        error("game action " .. action.name .. " failed: " .. tostring(reason))
    end
    return performed
end

--- Append \p performed's actions to \p list
local function append(list, performed)
    for _, action in ipairs(performed) do
        table.insert(list, action)
    end
    return list
end

--------------------------------------------------------------------------------
-- where the game is
--------------------------------------------------------------------------------

--- @return boolean True once the bonus pool has been filled at the start of the game
function GameFlow.bonusPoolFilled(gameState)
    for _, action in ipairs(gameState.actionHistory) do
        if action.name == "FillBonusPool" then
            return true
        end
    end
    return false
end

--- @return integer|nil index in the action history of this round's FillFactoryDisplays. nil if the
---     displays haven't been filled yet this round
function GameFlow.roundFillIndex(gameState)
    local history = gameState.actionHistory
    for ii = #history, 1, -1 do
        local name = history[ii].name
        if name == "FillFactoryDisplays" then
            return ii
        elseif name == "EndRound" then
            return nil
        end
    end
    return nil
end

--- @return boolean True once the tile selection phase is over: every display and the center are empty
function GameFlow.selectionOver(gameState)
    return gameState:allTileSourcesEmpty()
end

--- @return boolean True once the placement phase is over: everyone has passed
function GameFlow.placementOver(gameState)
    return gameState:allPlayersPassed()
end

--- @return boolean True once the game is over: everyone has passed in the final round. Then the
---     end-game bonuses are scored (nextToScore)
function GameFlow.isGameOver(gameState)
    return gameState:isFinalRound() and gameState:allPlayersPassed()
end

--- @return boolean True if the bonus pool has room and there are tiles to top it up with (bag or tower)
function GameFlow.poolNeedsTopUp(gameState)
    return gameState.bonusPool:total() < FillBonusPoolAction.capacity(gameState)
        and gameState.tileBag:total() + gameState.discard:total() > 0
end

--- @return integer|nil the next player whose end-game bonuses haven't been scored (in player order).
---     nil once everyone has been
function GameFlow.nextToScore(gameState)
    for ii, player in ipairs(gameState.players) do
        if player.endGameBonus == nil then
            return ii
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- steps
--------------------------------------------------------------------------------

--- Start a round: fill the bonus pool (the first round only) and the factory displays. The first turn
--- begins separately (beginRound), so a view can animate the fill first
--- @return Action[] performed
function GameFlow.startRound(gameState)
    local performed = {}
    if not GameFlow.bonusPoolFilled(gameState) then
        append(performed, perform(gameState, FillBonusPoolAction()))
    end
    return append(performed, perform(gameState, FillFactoryDisplaysAction()))
end

--- Begin the round's first turn (tile selection): the start player's
--- @return Action[] performed
function GameFlow.beginRound(gameState)
    return perform(gameState, BeginTurnAction(gameState.startPlayer))
end

--- Start the placement phase: the start player token holder (or the start player) goes first
--- @return Action[] performed
function GameFlow.startPlacement(gameState)
    local performed = perform(gameState, StartPlacementPhaseAction())
    return append(performed, perform(gameState, BeginTurnAction(gameState.startTokenHolder or gameState.startPlayer)))
end

--- End the current turn and begin the next player's. After a placement turn the bonus pool is topped
--- back up first (the bonus tiles picked up this turn)
--- @param wasPlacement boolean the turn was a tile placement turn
--- @return Action[] performed. The pool's fill (FillBonusPool), if any, comes first
function GameFlow.endTurn(gameState, wasPlacement)
    local performed = {}
    if wasPlacement and GameFlow.poolNeedsTopUp(gameState) then
        append(performed, perform(gameState, FillBonusPoolAction()))
    end
    local before = #gameState.actionHistory
    gameState:incrementTurn()
    for ii = before + 1, #gameState.actionHistory do
        table.insert(performed, gameState.actionHistory[ii])
    end
    return performed
end

--- During placement: if the current player has no tiles, pass for them (no tiles, so no penalty) and
--- end their turn
--- @return Action[]|nil performed. nil if they have tiles (they take their turn)
function GameFlow.passEmptyHand(gameState)
    local playerIdx = gameState.currentTurnPlayer
    if not gameState.players[playerIdx].hand:isEmpty() then
        return nil
    end
    Log.debug("player " .. playerIdx .. " has no tiles. passing for them")
    local performed = perform(gameState, PassAction(playerIdx, {}))
    return append(performed, GameFlow.endTurn(gameState, false))
end

--- End the round (round upkeep, EndRoundAction). Nothing after the final round: the game is over
--- @return Action[] performed
function GameFlow.endRound(gameState)
    if gameState:isFinalRound() then
        return {}
    end
    return perform(gameState, EndRoundAction())
end

--- Begin \p playerIdx's end-game scoring turn (unless it has already begun, eg: a save made mid-way)
--- @return Action[] performed
function GameFlow.beginScoring(gameState, playerIdx)
    local history = gameState.actionHistory
    local last = history[#history]
    if last and last.name == "BeginTurn" and last.ctx.playerIdx == playerIdx then
        return {}
    end
    return perform(gameState, BeginTurnAction(playerIdx))
end

--- Score \p playerIdx's end-game bonuses (ScoreEndGameAction)
--- @return Action[] performed. The first is the ScoreEndGameAction (ctx.total: points scored)
function GameFlow.scorePlayer(gameState, playerIdx)
    return perform(gameState, ScoreEndGameAction(playerIdx))
end

return GameFlow
