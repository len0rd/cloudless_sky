local cute = require("cloudless_sky.extern.cute")
local Action = require("cloudless_sky.action.action")
local AddScoreAction = require("cloudless_sky.action.add_score")
local EndRoundAction = require("cloudless_sky.action.end_round")
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

local P1 = 1
local P2 = 2

local placementOver = function(gameState)
    gameState.round.phase = GameState.RoundPhase.TILE_PLACEMENT
    for _, player in ipairs(gameState.players) do
        player.passedForPhase = true
    end
end

notion("EndRound advances the round and hands the start to the token holder", function()
    local gameState = TestUtil.newGame()
    placementOver(gameState)
    gameState.startTokenHolder = P2
    gameState.players[P1].hand:addTiles(TileType.RED, 2)

    gameState:performAction(EndRoundAction())
    check(gameState.round.idx).is(2)
    check(gameState:getCurrentWildType()).is(TileType.GREEN)
    check(gameState.round.phase).is(GameState.RoundPhase.TILE_SELECTION)
    check(gameState.startPlayer).is(P2)
    check(gameState.startTokenHolder).is(nil)
    check(gameState.players[P1].passedForPhase).is(false)
    check(gameState.players[P2].passedForPhase).is(false)
    -- kept tiles stay in hand
    check(gameState.players[P1].hand:num(TileType.RED)).is(2)
end)

notion("EndRound keeps the start player if nobody took the token", function()
    local gameState = TestUtil.newGame()
    placementOver(gameState)
    gameState.startPlayer = P2
    gameState:performAction(EndRoundAction())
    check(gameState.startPlayer).is(P2)
end)

notion("EndRound is rejected until everyone passed, and in the final round", function()
    local gameState = TestUtil.newGame()
    check(gameState:performAction(EndRoundAction())).is(nil)

    placementOver(gameState)
    gameState.round.idx = #gameState.rules.wildPerRound
    check(gameState:performAction(EndRoundAction())).is(nil)
    gameState.round.idx = 1
end)

notion("EndRound undo and serialize roundtrip restore the previous round", function()
    local gameState = TestUtil.newGame()
    placementOver(gameState)
    gameState.startTokenHolder = P2

    gameState:performAction(EndRoundAction())
    local restored = Action.deserialize(gameState.actionHistory[1]:serialize())
    gameState.actionHistory[1] = restored
    gameState:undoLastAction()

    check(gameState.round.idx).is(1)
    check(gameState.round.phase).is(GameState.RoundPhase.TILE_PLACEMENT)
    check(gameState.startPlayer).is(P1)
    check(gameState.startTokenHolder).is(P2)
    check(gameState.players[P1].passedForPhase).is(true)
    check(gameState.players[P2].passedForPhase).is(true)
end)

notion("GameState factory display count comes from the rules by player count", function()
    local rng = love.math.newRandomGenerator(TestUtil.SEED)
    check(GameState(GameRules.currentRules(), { "a", "b" }, rng, TestUtil.SEED):numFactoryDisplays()).is(5)
    check(GameState(GameRules.currentRules(), { "a", "b", "c" }, rng, TestUtil.SEED):numFactoryDisplays()).is(7)
    check(GameState(GameRules.currentRules(), { "a", "b", "c", "d" }, rng, TestUtil.SEED):numFactoryDisplays()).is(9)
end)

notion("GameState tile sources and beginTurn", function()
    local gameState = TestUtil.newGame()
    check(gameState:allTileSourcesEmpty()).is(true)
    check(gameState:tileSource(GameState.CENTER) == gameState.center).is(true)
    check(gameState:tileSource(3) == gameState.factoryDisplays[3]).is(true)
    check(gameState:tileSource(99)).is(nil)

    gameState.factoryDisplays[5]:addTile(TileType.RED)
    check(gameState:allTileSourcesEmpty()).is(false)

    gameState:performAction(AddScoreAction(P1, 1))
    gameState:performAction(AddScoreAction(P1, 1))
    local turnIdx = gameState.turnIdx
    gameState:beginTurn(P2)
    check(gameState.currentTurnPlayer).is(P2)
    check(gameState.turnIdx).is(turnIdx + 1)
    -- the BeginTurn is the new turn's undo barrier
    check(#gameState.actionHistory).is(3)
    check(gameState.actionHistory[3].name).is("BeginTurn")
    check(gameState:turnStartIndex()).is(3)
    -- actions from before the turn began can't be undone
    check(gameState:canUndoChoice()).is(false)
end)
