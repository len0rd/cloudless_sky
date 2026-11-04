local cute = require("cloudless_sky.extern.cute")
local Action = require("cloudless_sky.action.action")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local PlacementPossibility = require("cloudless_sky.model.placement_possibility")
local TileBag = require("cloudless_sky.model.tile_bag")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

local P1 = 1
local PURPLE_STAR = 6 -- costs { 1, 2, 3, 4, 5, 6 }

--- place a tile on the purple star paying entirely in purple
local placePurple = function(gameState, slotIdx)
    local cost = gameState.players[P1].mat:getStar(PURPLE_STAR):slotIndexToCost(slotIdx)
    gameState.players[P1].hand:addTiles(TileType.PURPLE, cost)
    return gameState:performAction(PlaceTileAction(P1, PURPLE_STAR, slotIdx, PlacementPossibility(TileType.PURPLE, cost)))
end

--- @return table names of the given actions, in order
local names = function(actions)
    local result = {}
    for ii, a in ipairs(actions) do
        result[ii] = a.name
    end
    return result
end

--------------------------------------------------------------------------------
-- Test-only actions modelling the future bonus flow:
--   TestPlace (choice) -> TestGrant (follow-up) -> TestGrantChild (follow-up of a follow-up)
--   TestPick (separate choice, one per bonus tile picked)
-- Each records itself in gameState.testLog so undo order can be checked
--------------------------------------------------------------------------------
local defineTestAction = function(name, followUpFactory)
    local TestAction = Action:extend()
    function TestAction:new(ctx)
        TestAction.super.new(self, name, ctx or {})
    end
    function TestAction.deserialize(ctx)
        return TestAction(ctx)
    end
    function TestAction:perform(gameState)
        gameState.testLog = gameState.testLog or {}
        table.insert(gameState.testLog, "+" .. name)
        return followUpFactory and followUpFactory() or {}
    end
    function TestAction:undo(gameState)
        table.insert(gameState.testLog, "-" .. name)
    end
    Action.register(name, TestAction)
    return TestAction
end

local TestGrantChild = defineTestAction("TestGrantChild")
local TestScore = defineTestAction("TestScore")
local TestGrant = defineTestAction("TestGrant", function()
    return { TestGrantChild() }
end)
local TestPlace = defineTestAction("TestPlace", function()
    return { TestScore(), TestGrant() }
end)
local TestPick = defineTestAction("TestPick")

notion("undoLastChoice undoes a placement and its score together", function()
    local gameState = TestUtil.newGame()
    local before = TestUtil.snapshot(gameState, P1)

    placePurple(gameState, 1)
    check(gameState:canUndoChoice()).is(true)

    local undone = gameState:undoLastChoice()
    check(names(undone)).shallowMatches({ "AddScore", "PlaceTile" })
    check(#gameState.actionHistory).is(0)
    check(gameState:canUndoChoice()).is(false)
    check(gameState.players[P1].hand:num(TileType.PURPLE)).is(1) -- payment returned to hand
    -- remove the purple tile placePurple added so the snapshot matches exactly
    gameState.players[P1].hand:removeTiles(TileType.PURPLE, 1)
    check(TestUtil.snapshot(gameState, P1)).is(before)
end)

notion("undoLastChoice only undoes the most recent choice", function()
    local gameState = TestUtil.newGame()
    placePurple(gameState, 1)
    local afterFirst = TestUtil.snapshot(gameState, P1)
    placePurple(gameState, 2)

    local undone = gameState:undoLastChoice()
    check(names(undone)).shallowMatches({ "AddScore", "PlaceTile" })
    -- second placement's payment is back in hand; otherwise identical to after the first placement
    gameState.players[P1].hand:removeTiles(TileType.PURPLE, 2)
    check(TestUtil.snapshot(gameState, P1)).is(afterFirst)
    check(gameState:canUndoChoice()).is(true)
end)

notion("undoLastChoice can't undo previous turns", function()
    local gameState = TestUtil.newGame()
    check(gameState.turnIdx).is(1)
    placePurple(gameState, 1)

    gameState:incrementTurn()
    check(gameState.turnIdx).is(2)
    check(gameState.turnHistoryStart).is(#gameState.actionHistory)
    check(gameState:canUndoChoice()).is(false)
    check(gameState:undoLastChoice()).is(nil)
    -- previous turn's placement is untouched
    check(#gameState.actionHistory).is(2)
    check(gameState.players[P1]:isSlotOccupied(PURPLE_STAR, 1)).is(true)
end)

notion("follow-ups are marked and undone with their choice; later choices undo one at a time", function()
    local gameState = TestUtil.newGame()
    gameState:performAction(TestPlace())
    gameState:performAction(TestPick())
    gameState:performAction(TestPick())

    check(names(gameState.actionHistory)).shallowMatches({
        "TestPlace",
        "TestScore",
        "TestGrant",
        "TestGrantChild",
        "TestPick",
        "TestPick",
    })
    local followUpFlags = {}
    for ii, a in ipairs(gameState.actionHistory) do
        followUpFlags[ii] = a.isFollowUp
    end
    check(followUpFlags).shallowMatches({ false, true, true, true, false, false })

    -- each pick is its own choice
    check(names(gameState:undoLastChoice())).shallowMatches({ "TestPick" })
    check(names(gameState:undoLastChoice())).shallowMatches({ "TestPick" })
    -- the placement and its whole follow-up chain undo together, newest first
    check(names(gameState:undoLastChoice())).shallowMatches({ "TestGrantChild", "TestGrant", "TestScore", "TestPlace" })
    check(gameState:undoLastChoice()).is(nil)

    check(gameState.testLog).shallowMatches({
        "+TestPlace",
        "+TestScore",
        "+TestGrant",
        "+TestGrantChild",
        "+TestPick",
        "+TestPick",
        "-TestPick",
        "-TestPick",
        "-TestGrantChild",
        "-TestGrant",
        "-TestScore",
        "-TestPlace",
    })
end)

notion("isFollowUp survives serialize/deserialize", function()
    local gameState = TestUtil.newGame()
    gameState:performAction(TestPlace())
    for _, a in ipairs(gameState.actionHistory) do
        local restored = Action.deserialize(a:serialize())
        check(restored.name).is(a.name)
        check(restored.isFollowUp).is(a.isFollowUp)
    end
end)

notion("rng state is serialized and restoring it repeats the same draws", function()
    local gameState = TestUtil.newGame()
    local serialized = gameState:serialize()
    check(type(serialized.rngState)).is("string")

    local bag = TileBag(5)
    local firstDraws = bag:takeRandomTiles(gameState.rng, 5)

    local restoredRng = love.math.newRandomGenerator()
    restoredRng:setState(serialized.rngState)
    local replayDraws = TileBag(5):takeRandomTiles(restoredRng, 5)
    check(replayDraws).shallowMatches(firstDraws)
end)
