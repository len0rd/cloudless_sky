local cute = require("cloudless_sky.extern.cute")
local Action = require("cloudless_sky.action.action")
local FillFactoryDisplaysAction = require("cloudless_sky.action.fill_factory_displays")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

--- @return integer total number of tiles in a TileType -> count table
local total = function(counts)
    local sum = 0
    for _, count in pairs(counts) do
        sum = sum + count
    end
    return sum
end

--- @return integer every tile in the bag, tower and displays
local tilesInPlay = function(gameState)
    local sum = gameState.tileBag:total() + gameState.discard:total()
    for _, display in ipairs(gameState.factoryDisplays) do
        sum = sum + display:total()
    end
    return sum
end

--- @return string the contents of every display
local displaysString = function(gameState)
    local parts = {}
    for ii, display in ipairs(gameState.factoryDisplays) do
        for _, tileType in ipairs(TileType.ORDERED) do
            table.insert(parts, ii .. tileType .. display:num(tileType))
        end
    end
    return table.concat(parts, ",")
end

notion("FillFactoryDisplays fills every display from the bag", function()
    local gameState = TestUtil.newGame()
    local numDisplays = gameState:numFactoryDisplays()
    check(numDisplays).is(5)
    local bagBefore = gameState.tileBag:total()

    local performed = gameState:performAction(FillFactoryDisplaysAction())
    check(#performed).is(1)
    for _, display in ipairs(gameState.factoryDisplays) do
        check(display:total()).is(4)
    end
    check(gameState.tileBag:total()).is(bagBefore - 4 * numDisplays)

    -- one event per display, in order, each adding up to tilesPerDisplay
    local events = performed[1].ctx.events
    check(#events).is(numDisplays)
    for ii, event in ipairs(events) do
        check(event.display).is(ii)
        check(total(event.tiles)).is(4)
        for tileType, count in pairs(event.tiles) do
            check(gameState.factoryDisplays[ii]:num(tileType)).is(count)
        end
    end
end)

notion("FillFactoryDisplays is repeatable for the same seed", function()
    local a = TestUtil.newGame()
    local b = TestUtil.newGame()
    a:performAction(FillFactoryDisplaysAction())
    b:performAction(FillFactoryDisplaysAction())
    check(displaysString(a)).is(displaysString(b))
end)

notion("FillFactoryDisplays refills the bag from the tower when it runs out", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { RED = 6 })
    TestUtil.setBag(gameState.discard, { BLUE = 10, GREEN = 4 })
    local before = tilesInPlay(gameState)

    local performed = gameState:performAction(FillFactoryDisplaysAction())
    local events = performed[1].ctx.events

    -- display 1: 4 red. display 2: 2 red, refill, then 2 more
    check(events[1].display).is(1)
    check(events[1].tiles).shallowMatches({ RED = 4 })
    check(events[2].display).is(2)
    check(events[2].tiles).shallowMatches({ RED = 2 })
    check(events[3].refill).shallowMatches({ BLUE = 10, GREEN = 4 })
    check(events[4].display).is(2)
    check(total(events[4].tiles)).is(2)
    check(gameState.factoryDisplays[2]:num(TileType.RED)).is(2)

    -- 6 + 14 = 20 tiles = all 5 displays
    check(gameState.discard:total()).is(0)
    check(gameState.tileBag:total()).is(0)
    for _, display in ipairs(gameState.factoryDisplays) do
        check(display:total()).is(4)
    end
    check(tilesInPlay(gameState)).is(before)
end)

notion("FillFactoryDisplays fills what it can when the bag and tower are both empty", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { RED = 3, PURPLE = 3 })
    TestUtil.setBag(gameState.discard, {})

    local performed = gameState:performAction(FillFactoryDisplaysAction())
    check(performed ~= nil).is(true)
    check(gameState.factoryDisplays[1]:total()).is(4)
    check(gameState.factoryDisplays[2]:total()).is(2)
    check(gameState.factoryDisplays[3]:total()).is(0)
    check(#performed[1].ctx.events).is(2)
end)

notion("FillFactoryDisplays requires empty displays", function()
    local gameState = TestUtil.newGame()
    gameState.factoryDisplays[3]:addTile(TileType.RED)
    local performed, reason = gameState:performAction(FillFactoryDisplaysAction())
    check(performed).is(nil)
    check(type(reason)).is("string")
end)

notion("FillFactoryDisplays undo restores bag, tower, displays and rng", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { RED = 3, ORANGE = 4 })
    TestUtil.setBag(gameState.discard, { BLUE = 10, GREEN = 10, YELLOW = 5 })
    local before = TestUtil.snapshot(gameState)

    gameState:performAction(FillFactoryDisplaysAction())
    local firstFill = displaysString(gameState)
    check(TestUtil.snapshot(gameState)).isnt(before)

    check(gameState:undoLastAction().name).is("FillFactoryDisplays")
    check(TestUtil.snapshot(gameState)).is(before)

    -- rng was restored too: filling again draws the same tiles
    gameState:performAction(FillFactoryDisplaysAction())
    check(displaysString(gameState)).is(firstFill)
end)

notion("FillFactoryDisplays serialize/deserialize roundtrip keeps events", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { RED = 2 })
    TestUtil.setBag(gameState.discard, { BLUE = 30 })
    gameState:performAction(FillFactoryDisplaysAction())

    local original = gameState.actionHistory[1]
    local restored = Action.deserialize(original:serialize())
    check(restored.name).is("FillFactoryDisplays")
    check(#restored.ctx.events).is(#original.ctx.events)
    check(restored.ctx.events[2].refill).shallowMatches({ BLUE = 30 })
    check(restored.ctx.rngStateBefore).is(original.ctx.rngStateBefore)

    -- the restored action can undo the fill
    gameState.actionHistory[1] = restored
    gameState:undoLastAction()
    check(gameState.tileBag:total()).is(2)
    check(gameState.discard:total()).is(30)
end)
