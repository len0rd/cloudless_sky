local cute = require("cloudless_sky.extern.cute")
local Action = require("cloudless_sky.action.action")
local GameState = require("cloudless_sky.model.game_state")
local StartPlacementPhaseAction = require("cloudless_sky.action.start_placement_phase")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

local P1 = 1
local P2 = 2
local CENTER = GameState.CENTER
-- round 1 wild is purple
local WILD = TileType.PURPLE

local take = function(counts, tileType, maxWild)
    return TakeTilesAction.tilesToTake(TestUtil.bagOf(counts), tileType, WILD, maxWild or 1)
end

notion("tilesToTake follows the wild rules", function()
    -- all of the color, plus exactly one wild
    check(take({ RED = 2, PURPLE = 2 }, TileType.RED)).shallowMatches({ RED = 2, PURPLE = 1 })
    -- no wild present
    check(take({ RED = 3, BLUE = 1 }, TileType.RED)).shallowMatches({ RED = 3 })
    -- only wilds: take one
    check(take({ PURPLE = 3 }, TileType.PURPLE)).shallowMatches({ PURPLE = 1 })
    -- more wilds allowed by the rules
    check(take({ RED = 1, PURPLE = 3 }, TileType.RED, 2)).shallowMatches({ RED = 1, PURPLE = 2 })

    -- wild while other colors are present
    local result, reason = take({ RED = 1, PURPLE = 3 }, TileType.PURPLE)
    check(result).is(nil)
    check(type(reason)).is("string")
    -- color not there
    result, reason = take({ RED = 1 }, TileType.BLUE)
    check(result).is(nil)
    check(type(reason)).is("string")
end)

notion("TakeTiles from a display moves the rest to the center", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.factoryDisplays[2], { RED = 2, PURPLE = 1, BLUE = 1 })
    local score = gameState.players[P1].score

    local performed = gameState:performAction(TakeTilesAction(P1, 2, TileType.RED))
    check(#performed).is(1)
    check(gameState.players[P1].hand:num(TileType.RED)).is(2)
    check(gameState.players[P1].hand:num(TileType.PURPLE)).is(1)
    check(gameState.factoryDisplays[2]:total()).is(0)
    check(gameState.center:num(TileType.BLUE)).is(1)
    check(gameState.center:total()).is(1)
    check(performed[1].ctx.toCenter).shallowMatches({ BLUE = 1 })
    -- display picks never touch the token or score
    check(gameState.startTokenHolder).is(nil)
    check(gameState.players[P1].score).is(score)
end)

notion("TakeTiles first pick from the center takes the token and loses points", function()
    local gameState = TestUtil.newGame()
    gameState.players[P1].score = 10
    TestUtil.setBag(gameState.center, { YELLOW = 3, PURPLE = 2, RED = 4 })

    local performed = gameState:performAction(TakeTilesAction(P1, CENTER, TileType.YELLOW))
    check(#performed).is(2)
    check(performed[2].name).is("AddScore")
    check(performed[2].isFollowUp).is(true)
    -- 3 yellow + 1 wild
    check(gameState.players[P1].score).is(6)
    check(gameState.startTokenHolder).is(P1)
    check(gameState.center:num(TileType.RED)).is(4)
    check(gameState.center:num(TileType.PURPLE)).is(1)

    -- the second center pick has no penalty
    local score2 = gameState.players[P2].score
    performed = gameState:performAction(TakeTilesAction(P2, CENTER, TileType.RED))
    check(#performed).is(1)
    check(gameState.players[P2].score).is(score2)
    check(gameState.startTokenHolder).is(P1)
end)

notion("TakeTiles center penalty stops at a score of 1", function()
    local gameState = TestUtil.newGame()
    gameState.players[P1].score = 3
    TestUtil.setBag(gameState.center, { RED = 6 })
    gameState:performAction(TakeTilesAction(P1, CENTER, TileType.RED))
    check(gameState.players[P1].score).is(1)
    check(gameState.actionHistory[1].ctx.penalty).is(2)
end)

notion("TakeTiles center penalty can be turned off by the rules", function()
    local rules = TestUtil.copyRules()
    rules.factoryDisplay.centerFirstPickPenalty = false
    local gameState = TestUtil.newGame(rules)
    local score = gameState.players[P1].score
    TestUtil.setBag(gameState.center, { RED = 3 })

    local performed = gameState:performAction(TakeTilesAction(P1, CENTER, TileType.RED))
    check(#performed).is(1)
    check(gameState.players[P1].score).is(score)
    -- the token is still taken
    check(gameState.startTokenHolder).is(P1)
end)

notion("TakeTiles invalid picks are rejected and leave state unchanged", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.factoryDisplays[1], { RED = 2, PURPLE = 2 })
    local before = TestUtil.snapshot(gameState)

    local invalid = {
        TakeTilesAction(P1, 1, TileType.PURPLE), -- wild with another color present
        TakeTilesAction(P1, 1, TileType.BLUE), -- not there
        TakeTilesAction(P1, 2, TileType.RED), -- empty display
        TakeTilesAction(P1, 99, TileType.RED), -- no such display
        TakeTilesAction(99, 1, TileType.RED), -- no such player
    }
    for ii, action in ipairs(invalid) do
        local performed, reason = gameState:performAction(action)
        if performed ~= nil then
            error("invalid take #" .. ii .. " was performed")
        end
        check(type(reason)).is("string")
        check(TestUtil.snapshot(gameState)).is(before)
    end

    -- not during the placement phase
    gameState.round.phase = GameState.RoundPhase.TILE_PLACEMENT
    check(gameState:performAction(TakeTilesAction(P1, 1, TileType.RED))).is(nil)
    gameState.round.phase = GameState.RoundPhase.TILE_SELECTION
end)

notion("TakeTiles undo restores display, center, hand, token and score", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.factoryDisplays[1], { RED = 2, PURPLE = 1, BLUE = 1 })
    TestUtil.setBag(gameState.center, { GREEN = 2, ORANGE = 1 })
    gameState.players[P1].score = 8
    local before = TestUtil.snapshot(gameState)

    gameState:performAction(TakeTilesAction(P1, 1, TileType.RED))
    local afterDisplay = TestUtil.snapshot(gameState)
    gameState:performAction(TakeTilesAction(P1, CENTER, TileType.GREEN))
    check(gameState.startTokenHolder).is(P1)

    check(#gameState:undoLastChoice()).is(2)
    check(TestUtil.snapshot(gameState)).is(afterDisplay)
    check(#gameState:undoLastChoice()).is(1)
    check(TestUtil.snapshot(gameState)).is(before)
end)

notion("TakeTiles serialize/deserialize roundtrip keeps results", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.center, { RED = 2, PURPLE = 1 })
    gameState:performAction(TakeTilesAction(P1, CENTER, TileType.RED))

    local restored = Action.deserialize(gameState.actionHistory[1]:serialize())
    check(restored.name).is("TakeTiles")
    check(restored.ctx.source).is(CENTER)
    check(restored.ctx.tileType).is(TileType.RED)
    check(restored.ctx.taken).shallowMatches({ RED = 2, PURPLE = 1 })
    check(restored.ctx.tookToken).is(true)
    check(restored.ctx.penalty).is(3)
end)

notion("StartPlacementPhase requires empty sources and is undoable", function()
    local gameState = TestUtil.newGame()
    gameState.center:addTile(TileType.RED)
    check(gameState:performAction(StartPlacementPhaseAction())).is(nil)

    gameState.center:removeTiles(TileType.RED, 1)
    check(gameState:allTileSourcesEmpty()).is(true)
    gameState:performAction(StartPlacementPhaseAction())
    check(gameState.round.phase).is(GameState.RoundPhase.TILE_PLACEMENT)
    gameState:undoLastAction()
    check(gameState.round.phase).is(GameState.RoundPhase.TILE_SELECTION)
end)
