local cute = require("cloudless_sky.extern.cute")
local FillFactoryDisplaysAction = require("cloudless_sky.action.fill_factory_displays")
local GameState = require("cloudless_sky.model.game_state")
local Invariants = require("cloudless_sky.model.invariants")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

--- @return boolean True if any failure message contains \p text
local mentions = function(failures, text)
    for _, msg in ipairs(failures) do
        if msg:find(text, 1, true) then
            return true
        end
    end
    return false
end

notion("Invariants hold for a new game and after actions", function()
    local gameState = TestUtil.newGame()
    check(#Invariants.check(gameState)).is(0)
    check(Invariants.expectedTileTotal(gameState.rules)).is(132)

    gameState:performAction(FillFactoryDisplaysAction())
    local display = gameState.factoryDisplays[1]
    local tileType = nil
    for _, t in ipairs(TileType.ORDERED) do
        if display:num(t) > 0 and t ~= gameState:getCurrentWildType() then
            tileType = t
        end
    end
    if tileType then
        gameState:performAction(TakeTilesAction(1, 1, tileType))
    end
    check(#Invariants.check(gameState)).is(0)
end)

notion("Invariants catch lost, duplicated and negative tiles", function()
    local gameState = TestUtil.newGame()
    gameState.tileBag:removeTiles(TileType.RED, 1)
    check(mentions(Invariants.check(gameState), "RED tiles total 21")).is(true)

    gameState = TestUtil.newGame()
    gameState.players[2].hand:addTiles(TileType.BLUE, 2)
    check(mentions(Invariants.check(gameState), "BLUE tiles total 24")).is(true)

    gameState = TestUtil.newGame()
    gameState.center:setCountForTileType(TileType.GREEN, -1)
    check(mentions(Invariants.check(gameState), "center has -1 GREEN")).is(true)

    gameState = TestUtil.newGame()
    gameState.bonusPool:setCountForTileType(TileType.RED, -2)
    check(mentions(Invariants.check(gameState), "bonus pool has -2 RED")).is(true)
end)

notion("Invariants catch bad scores, players, rounds and phases", function()
    local gameState = TestUtil.newGame()
    gameState.players[1].score = 0
    gameState.currentTurnPlayer = 3
    gameState.startTokenHolder = 7
    gameState.round.idx = #gameState.rules.wildPerRound + 1
    local failures = Invariants.check(gameState)
    check(mentions(failures, "player 1 score 0")).is(true)
    check(mentions(failures, "currentTurnPlayer 3")).is(true)
    check(mentions(failures, "startTokenHolder 7")).is(true)
    check(mentions(failures, "round 7")).is(true)

    gameState = TestUtil.newGame()
    gameState.players[1].passedForPhase = true
    check(mentions(Invariants.check(gameState), "passed during the selection phase")).is(true)

    gameState = TestUtil.newGame()
    gameState.round.phase = GameState.RoundPhase.TILE_PLACEMENT
    gameState.tileBag:removeTiles(TileType.RED, 1)
    gameState.center:addTile(TileType.RED)
    check(mentions(Invariants.check(gameState), "left on the table")).is(true)
end)

notion("GameState serializes its seed", function()
    local gameState = TestUtil.newGame()
    check(gameState.seed).is(TestUtil.SEED)
    check(gameState:serialize().seed).is(TestUtil.SEED)
end)
