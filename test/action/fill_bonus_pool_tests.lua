local cute = require("cloudless_sky.extern.cute")
local FillBonusPoolAction = require("cloudless_sky.action.fill_bonus_pool")
local SaveGame = require("cloudless_sky.model.save_game")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

--- @return string the contents of the bag, tower and bonus pool
local function bagsString(gameState)
    local parts = {}
    for _, entry in ipairs({ gameState.tileBag, gameState.discard, gameState.bonusPool }) do
        for _, tileType in ipairs(TileType.ORDERED) do
            table.insert(parts, tileType .. entry:num(tileType))
        end
    end
    return table.concat(parts, ",")
end

notion("FillBonusPool fills the pool to numBonusTiles from the bag", function()
    local gameState = TestUtil.newGame()
    local capacity = gameState.rules.bonusSurrounds.numBonusTiles
    local bagBefore = gameState.tileBag:total()
    check(gameState.bonusPool:total()).is(0)

    local performed = gameState:performAction(FillBonusPoolAction())
    check(performed ~= nil).is(true)
    check(gameState.bonusPool:total()).is(capacity)
    check(gameState.tileBag:total()).is(bagBefore - capacity)

    -- the events add up to what went in the pool
    local fromEvents = 0
    for _, event in ipairs(performed[1].ctx.events) do
        for _, count in pairs(event.pool or {}) do
            fromEvents = fromEvents + count
        end
    end
    check(fromEvents).is(capacity)
end)

notion("FillBonusPool is rejected when the pool is full", function()
    local gameState = TestUtil.newGame()
    gameState:performAction(FillBonusPoolAction())
    local performed, reason = gameState:performAction(FillBonusPoolAction())
    check(performed).is(nil)
    check(reason:find("full", 1, true) ~= nil).is(true)
end)

notion("FillBonusPool tops up a partly empty pool", function()
    local gameState = TestUtil.newGame()
    local capacity = gameState.rules.bonusSurrounds.numBonusTiles
    gameState.tileBag:removeTiles(TileType.RED, 3)
    gameState.bonusPool:addTiles(TileType.RED, 3)

    gameState:performAction(FillBonusPoolAction())
    check(gameState.bonusPool:total()).is(capacity)
    check(gameState.bonusPool:num(TileType.RED) >= 3).is(true)
end)

notion("FillBonusPool follows the rules' pool size", function()
    for _, size in ipairs({ 5, 20 }) do
        local rules = TestUtil.copyRules()
        rules.bonusSurrounds.numBonusTiles = size
        local gameState = TestUtil.newGame(rules)
        gameState:performAction(FillBonusPoolAction())
        check(gameState.bonusPool:total()).is(size)
    end
end)

notion("FillBonusPool refills the bag from the tower, and leaves the pool short when both run out", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { [TileType.BLUE] = 2 })
    TestUtil.setBag(gameState.discard, { [TileType.GREEN] = 3 })

    local performed = gameState:performAction(FillBonusPoolAction())
    local events = performed[1].ctx.events
    check(#events).is(3)
    check(events[1].pool[TileType.BLUE]).is(2)
    check(events[2].refill[TileType.GREEN]).is(3)
    check(events[3].pool[TileType.GREEN]).is(3)
    check(gameState.bonusPool:total()).is(5)
    check(gameState.tileBag:total()).is(0)
    check(gameState.discard:total()).is(0)
end)

notion("FillBonusPool undo restores the bag, tower, pool and rng", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { [TileType.BLUE] = 4, [TileType.RED] = 1 })
    TestUtil.setBag(gameState.discard, { [TileType.GREEN] = 6, [TileType.YELLOW] = 6 })
    local before = bagsString(gameState)
    local rngBefore = gameState.rng:getState()

    local performed = gameState:performAction(FillBonusPoolAction())
    check(bagsString(gameState) ~= before).is(true)
    performed[1]:undo(gameState)
    check(bagsString(gameState)).is(before)
    check(gameState.rng:getState()).is(rngBefore)
end)

notion("FillBonusPool round-trips through SaveGame", function()
    local gameState = TestUtil.newGame()
    gameState:performAction(FillBonusPoolAction())
    local loaded, reason = SaveGame.decode(SaveGame.encode(gameState))
    check(reason).is(nil)
    check(bagsString(loaded)).is(bagsString(gameState))
    check(loaded.actionHistory[1].name).is("FillBonusPool")
end)
