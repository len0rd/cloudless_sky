local cute = require("cloudless_sky.extern.cute")
local Action = require("cloudless_sky.action.action")
local PassAction = require("cloudless_sky.action.pass")
local GameRules = require("cloudless_sky.model.game_rules")
local TileBag = require("cloudless_sky.model.tile_bag")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

local P1 = 1
local P2 = 2

--- @return TileBag a bag with the given TileType -> count contents
local bagOf = function(counts)
    local bag = TileBag()
    for tileType, count in pairs(counts) do
        bag:addTiles(tileType, count)
    end
    return bag
end

local snapshot = function(gameState)
    return TestUtil.snapshot(gameState, P1) .. ",passed=" .. tostring(gameState.players[P1].passedForPhase)
end

notion("Pass keeps chosen tiles in hand, discards the rest and loses a point per discard", function()
    local gameState = TestUtil.newGame()
    local player = gameState.players[P1]
    player.score = 20
    player.hand:addTiles(TileType.RED, 5)
    player.hand:addTiles(TileType.PURPLE, 3)
    player.hand:addTiles(TileType.BLUE, 1)

    local performed = gameState:performAction(PassAction(P1, { RED = 2, PURPLE = 2 }))

    check(player.hand:num(TileType.RED)).is(2)
    check(player.hand:num(TileType.PURPLE)).is(2)
    check(player.hand:num(TileType.BLUE)).is(0)
    check(player.hand:total()).is(4)
    check(gameState.discard:num(TileType.RED)).is(3)
    check(gameState.discard:num(TileType.PURPLE)).is(1)
    check(gameState.discard:num(TileType.BLUE)).is(1)
    check(player.score).is(20 - 5)
    check(player.passedForPhase).is(true)

    check(#performed).is(2)
    check(performed[1].name).is("Pass")
    check(performed[2].name).is("AddScore")
    check(performed[2].ctx.score).is(-5)
    check(performed[2].isFollowUp).is(true)
end)

notion("Pass penalty can't take the score below 1", function()
    local gameState = TestUtil.newGame()
    local player = gameState.players[P1]
    player.score = 3
    player.hand:addTiles(TileType.RED, 9)

    gameState:performAction(PassAction(P1, {}))
    check(player.score).is(1)
    check(gameState.discard:num(TileType.RED)).is(9)

    -- already at the floor: no penalty and no AddScore follow-up
    local gameState2 = TestUtil.newGame()
    local player2 = gameState2.players[P1]
    player2.score = 1
    player2.hand:addTiles(TileType.RED, 3)
    local performed = gameState2:performAction(PassAction(P1, {}))
    check(#performed).is(1)
    check(player2.score).is(1)
end)

notion("Pass with a hand within the limit keeps everything and loses nothing", function()
    local gameState = TestUtil.newGame()
    local player = gameState.players[P1]
    local startScore = player.score
    player.hand:addTiles(TileType.GREEN, 2)
    player.hand:addTiles(TileType.ORANGE, 1)

    local performed = gameState:performAction(PassAction(P1, { GREEN = 2, ORANGE = 1 }))
    check(#performed).is(1)
    check(player.hand:total()).is(3)
    check(gameState.discard:total()).is(0)
    check(player.score).is(startScore)
end)

notion("Pass invalid keeps are rejected and leave state unchanged", function()
    local gameState = TestUtil.newGame()
    local player = gameState.players[P1]
    player.hand:addTiles(TileType.RED, 6)
    player.hand:addTiles(TileType.BLUE, 1)

    local invalid = {
        PassAction(P1, { RED = 5 }), -- over the limit of 4
        PassAction(P1, { BLUE = 2 }), -- more than in hand
        PassAction(P1, { RED = -1 }), -- negative
        PassAction(P1, { RED = 1.5 }), -- not a whole number
        PassAction(P1, { NOT_A_COLOR = 1 }), -- unknown type
        PassAction(99, {}), -- bad player
    }
    local before = snapshot(gameState)
    for ii, action in ipairs(invalid) do
        local performed, reason = gameState:performAction(action)
        if performed ~= nil then
            error("invalid pass #" .. ii .. " was performed")
        end
        check(type(reason)).is("string")
        check(snapshot(gameState)).is(before)
    end

    -- can't pass twice
    check(gameState:performAction(PassAction(P1, { RED = 4 })) ~= nil).is(true)
    local performed = gameState:performAction(PassAction(P1, {}))
    check(performed).is(nil)
end)

notion("Pass carryover limit comes from the rules, capped at GameRules.MAX_TILE_CARRYOVER", function()
    local rules = TestUtil.copyRules()
    rules.playerMat.maxTileCarryoverPerRound = 2
    local gameState = TestUtil.newGame(rules)
    check(gameState:tileCarryoverLimit()).is(2)
    gameState.players[P1].hand:addTiles(TileType.RED, 5)
    check(PassAction(P1, { RED = 3 }):validate(gameState)).is(false)
    check(PassAction(P1, { RED = 2 }):validate(gameState)).is(true)

    rules = TestUtil.copyRules()
    rules.playerMat.maxTileCarryoverPerRound = 12
    gameState = TestUtil.newGame(rules)
    check(gameState:tileCarryoverLimit()).is(GameRules.MAX_TILE_CARRYOVER)
    check(GameRules.MAX_TILE_CARRYOVER).is(10)
    gameState.players[P1].hand:addTiles(TileType.RED, 12)
    check(PassAction(P1, { RED = 11 }):validate(gameState)).is(false)
    check(PassAction(P1, { RED = 10 }):validate(gameState)).is(true)

    -- default rules were not modified
    check(GameRules.currentRules().playerMat.maxTileCarryoverPerRound).is(4)
end)

notion("Pass in the final round keeps nothing", function()
    local gameState = TestUtil.newGame()
    gameState.round.idx = #gameState.rules.wildPerRound
    check(gameState:isFinalRound()).is(true)
    check(gameState:tileCarryoverLimit()).is(0)
    check(gameState:getNextRoundWildType()).is(nil)

    local player = gameState.players[P1]
    player.score = 10
    player.hand:addTiles(TileType.RED, 3)
    check(PassAction(P1, { RED = 1 }):validate(gameState)).is(false)
    gameState:performAction(PassAction(P1, {}))
    check(player.hand:total()).is(0)
    check(player.score).is(7)
    gameState.round.idx = 1
end)

notion("Pass undo restores hand, tower, score and passed flag", function()
    local gameState = TestUtil.newGame()
    local player = gameState.players[P1]
    player.score = 9
    player.hand:addTiles(TileType.RED, 5)
    player.hand:addTiles(TileType.YELLOW, 2)
    local before = snapshot(gameState)

    gameState:performAction(PassAction(P1, { YELLOW = 2, RED = 1 }))
    check(snapshot(gameState)).isnt(before)

    check(gameState:undoLastAction().name).is("AddScore")
    check(gameState:undoLastAction().name).is("Pass")
    check(snapshot(gameState)).is(before)
end)

notion("PassAction serialize/deserialize roundtrip keeps results", function()
    local gameState = TestUtil.newGame()
    gameState.players[P1].hand:addTiles(TileType.RED, 6)
    gameState:performAction(PassAction(P1, { RED = 4 }))

    local restored = Action.deserialize(gameState.actionHistory[1]:serialize())
    check(restored.name).is("Pass")
    check(restored.ctx.playerIdx).is(P1)
    check(restored.ctx.keep).shallowMatches({ RED = 4 })
    check(restored.ctx.discarded).shallowMatches({ RED = 2 })
    check(restored.ctx.penalty).is(2)
end)

notion("suggestKeep prefers next round's wild, then most plentiful colors", function()
    -- wild first, then fill from the most plentiful
    check(PassAction.suggestKeep(bagOf({ RED = 10, GREEN = 2, BLUE = 1 }), 4, TileType.GREEN)).shallowMatches({
        GREEN = 2,
        RED = 2,
    })
    -- no wild in hand: most plentiful color first, as many as fit
    check(PassAction.suggestKeep(bagOf({ RED = 10, PURPLE = 2 }), 4, TileType.GREEN)).shallowMatches({ RED = 4 })
    -- most plentiful color is taken fully before moving to the next
    check(PassAction.suggestKeep(bagOf({ BLUE = 3, ORANGE = 2, PURPLE = 1 }), 4, nil)).shallowMatches({
        BLUE = 3,
        ORANGE = 1,
    })
    -- ties broken by TileType.ORDERED (RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE)
    check(PassAction.suggestKeep(bagOf({ BLUE = 3, RED = 3 }), 4, nil)).shallowMatches({ RED = 3, BLUE = 1 })
    -- more wilds than the limit
    check(PassAction.suggestKeep(bagOf({ GREEN = 6, RED = 9 }), 4, TileType.GREEN)).shallowMatches({ GREEN = 4 })
    -- fewer tiles than the limit: keep everything
    check(PassAction.suggestKeep(bagOf({ RED = 1, BLUE = 2 }), 4, TileType.GREEN)).shallowMatches({ RED = 1, BLUE = 2 })
    -- final round: limit 0
    check(PassAction.suggestKeep(bagOf({ RED = 5 }), 0, nil)).shallowMatches({})
end)

notion("incrementTurn skips players who have passed", function()
    local gameState = TestUtil.newGame()
    check(gameState.currentTurnPlayer).is(P1)
    check(gameState:allPlayersPassed()).is(false)

    gameState:performAction(PassAction(P1, {}))
    gameState:incrementTurn()
    check(gameState.currentTurnPlayer).is(P2)
    -- P1 passed, so it's P2's turn again
    gameState:incrementTurn()
    check(gameState.currentTurnPlayer).is(P2)
    check(gameState:allPlayersPassed()).is(false)

    gameState:performAction(PassAction(P2, {}))
    check(gameState:allPlayersPassed()).is(true)
end)
