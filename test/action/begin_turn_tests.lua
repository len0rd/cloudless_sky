local cute = require("cloudless_sky.extern.cute")
local AddScoreAction = require("cloudless_sky.action.add_score")
local BeginTurnAction = require("cloudless_sky.action.begin_turn")
local EndRoundAction = require("cloudless_sky.action.end_round")
local FillFactoryDisplaysAction = require("cloudless_sky.action.fill_factory_displays")
local StartPlacementPhaseAction = require("cloudless_sky.action.start_placement_phase")
local TestUtil = require("test.test_util")

local P1 = 1
local P2 = 2

notion("BeginTurn sets the turn and undo restores it", function()
    local gameState = TestUtil.newGame()
    local turnIdx = gameState.turnIdx
    local action = BeginTurnAction(P2)
    check(gameState:performAction(action) ~= nil).is(true)
    check(gameState.currentTurnPlayer).is(P2)
    check(gameState.turnIdx).is(turnIdx + 1)

    gameState:undoLastAction()
    check(gameState.currentTurnPlayer).is(P1)
    check(gameState.turnIdx).is(turnIdx)

    check(gameState:performAction(BeginTurnAction(99))).is(nil)
end)

notion("undo barriers: undo stops at the start of the turn", function()
    local gameState = TestUtil.newGame()
    check(gameState:turnStartIndex()).is(0)
    -- nothing performed yet
    check(gameState:canUndoChoice()).is(false)

    gameState:performAction(AddScoreAction(P1, 1))
    gameState:beginTurn(P2)
    check(gameState:turnStartIndex()).is(2)
    check(gameState:canUndoChoice()).is(false)
    check(gameState:undoLastChoice()).is(nil)

    -- two choices undo one at a time, then stop at the BeginTurn
    gameState:performAction(AddScoreAction(P2, 1))
    gameState:performAction(AddScoreAction(P2, 2))
    check(gameState:canUndoChoice()).is(true)
    check(#gameState:undoLastChoice()).is(1)
    check(gameState.players[P2].score).is(TestUtil.newGame().players[P2].score + 1)
    check(#gameState:undoLastChoice()).is(1)
    check(gameState:canUndoChoice()).is(false)
    check(#gameState.actionHistory).is(2)
    check(gameState.currentTurnPlayer).is(P2)
end)

notion("round actions are undo barriers", function()
    local gameState = TestUtil.newGame()
    check(gameState:performAction(FillFactoryDisplaysAction()) ~= nil).is(true)
    check(gameState:canUndoChoice()).is(false)
    check(gameState:turnStartIndex()).is(1)

    -- empty the table so the placement phase can start
    for _, display in ipairs(gameState.factoryDisplays) do
        for tileType, count in pairs(display:serialize()) do
            if count > 0 then
                display:removeTiles(tileType, count)
                gameState.tileBag:addTiles(tileType, count)
            end
        end
    end
    check(gameState:performAction(StartPlacementPhaseAction()) ~= nil).is(true)
    check(gameState:canUndoChoice()).is(false)

    for _, player in ipairs(gameState.players) do
        player.passedForPhase = true
    end
    check(gameState:performAction(EndRoundAction()) ~= nil).is(true)
    check(gameState:canUndoChoice()).is(false)
    check(gameState:turnStartIndex()).is(3)
end)
