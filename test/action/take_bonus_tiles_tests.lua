local cute = require("cloudless_sky.extern.cute")
local BonusPickup = require("cloudless_sky.model.bonus_pickup")
local Canonical = require("cloudless_sky.model.canonical")
local FillBonusPoolAction = require("cloudless_sky.action.fill_bonus_pool")
local GameFlow = require("cloudless_sky.model.game_flow")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local PlacementPossibility = require("cloudless_sky.model.placement_possibility")
local SaveGame = require("cloudless_sky.model.save_game")
local TakeBonusTilesAction = require("cloudless_sky.action.take_bonus_tiles")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

local P1 = 1

--- Mark slots of player 1's mat as filled (test setup: no tiles, score or history)
local occupy = function(gameState, slots)
    local mat = gameState.players[P1].mat
    for _, slot in ipairs(slots) do
        mat:getStar(slot[1]).occupiedSlots[slot[2]] = true
    end
end

--- Player 1 places on star 1 (orange) slot \p slotIdx, paying in orange
--- @return Action[]|nil performed, string|nil reason
local placeOrange = function(gameState, slotIdx)
    local cost = gameState.players[P1].mat:getStar(1):slotIndexToCost(slotIdx)
    gameState.players[P1].hand:addTiles(TileType.ORANGE, cost)
    return gameState:performAction(PlaceTileAction(P1, 1, slotIdx, PlacementPossibility(TileType.ORANGE, cost)))
end

--- A game with a full bonus pool, and player 1's mat one tile (star 1 slot 3) away from completing
--- pillar 1 (7.1 7.6 1.3 1.4) and statue 7 (1.2 1.3 2.5 2.6)
local pillarAndStatueGame = function(rules)
    local gameState = TestUtil.newGame(rules)
    assert(gameState:performAction(FillBonusPoolAction()))
    occupy(gameState, { { 7, 1 }, { 7, 6 }, { 1, 4 }, { 1, 2 }, { 2, 5 }, { 2, 6 } })
    return gameState
end

--- @return table TileType -> count: the first \p n tiles of the bonus pool, in TileType order
local firstPoolTiles = function(gameState, n)
    local take = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        local count = math.min(n, gameState.bonusPool:num(tileType))
        if count > 0 then
            take[tileType] = count
            n = n - count
        end
    end
    return take
end

notion("Completing a pillar and a statue at once owes their tiles added together", function()
    local gameState = pillarAndStatueGame()
    check(BonusPickup.owed(gameState) == nil).is(true)
    local performed = placeOrange(gameState, 3)
    check(performed ~= nil).is(true)
    check(table.concat(performed[1].ctx.bonuses, ",")).is("1,7")
    check(performed[1].ctx.bonusTiles).is(3)
    local owed = BonusPickup.owed(gameState)
    check(owed.playerIdx).is(P1)
    check(owed.count).is(3)
end)

notion("A placement without a bonus owes nothing, and records no bonus", function()
    local gameState = pillarAndStatueGame()
    local performed = placeOrange(gameState, 5)
    check(performed[1].ctx.bonuses == nil and performed[1].ctx.bonusTiles == nil).is(true)
    check(BonusPickup.owed(gameState) == nil).is(true)
end)

notion("Bonuses of a disabled kind earn nothing", function()
    local rules = TestUtil.copyRules()
    rules.bonusSurrounds.enabled.pillar = false
    local gameState = pillarAndStatueGame(rules)
    placeOrange(gameState, 3)
    check(table.concat(BonusPickup.owed(gameState).bonuses, ",")).is("7")
    check(BonusPickup.owed(gameState).count).is(2)

    -- fountains are off in the Base rules: window 13 (1.1 1.6) + fountain 24 (6.6 6.1 1.6 1.5) owes 3
    gameState = TestUtil.newGame()
    assert(gameState:performAction(FillBonusPoolAction()))
    occupy(gameState, { { 1, 1 }, { 6, 6 }, { 6, 1 }, { 1, 5 } })
    placeOrange(gameState, 6)
    check(BonusPickup.owed(gameState).count).is(3)

    -- turned on (worth 2): 5
    rules = TestUtil.copyRules()
    rules.bonusSurrounds.enabled.fountain = true
    rules.bonusSurrounds.bonusValueTiles.fountain = 2
    gameState = TestUtil.newGame(rules)
    assert(gameState:performAction(FillBonusPoolAction()))
    occupy(gameState, { { 1, 1 }, { 6, 6 }, { 6, 1 }, { 1, 5 } })
    placeOrange(gameState, 6)
    check(BonusPickup.owed(gameState).count).is(5)
end)

notion("A short bonus pool owes every tile left; an empty one owes nothing", function()
    local gameState = pillarAndStatueGame()
    -- leave 2 tiles in the pool
    local pool = gameState.bonusPool
    local extra = pool:total() - 2
    for _, tileType in ipairs(TileType.ORDERED) do
        local n = math.min(extra, pool:num(tileType))
        pool:removeTiles(tileType, n)
        gameState.tileBag:addTiles(tileType, n)
        extra = extra - n
    end
    placeOrange(gameState, 3)
    check(BonusPickup.owed(gameState).count).is(2)

    for _, tileType in ipairs(TileType.ORDERED) do
        gameState.tileBag:addTiles(tileType, pool:num(tileType))
        pool:removeTiles(tileType, pool:num(tileType))
    end
    check(BonusPickup.owed(gameState) == nil).is(true)
end)

notion("TakeBonusTiles moves the owed tiles from the pool to the hand, and is checked", function()
    local gameState = pillarAndStatueGame()
    -- nothing owed yet
    check(gameState:performAction(TakeBonusTilesAction(P1, firstPoolTiles(gameState, 3))) == nil).is(true)
    placeOrange(gameState, 3)

    -- wrong count, wrong player, tiles the pool doesn't have
    check(gameState:performAction(TakeBonusTilesAction(P1, firstPoolTiles(gameState, 2))) == nil).is(true)
    check(gameState:performAction(TakeBonusTilesAction(2, firstPoolTiles(gameState, 3))) == nil).is(true)
    local missing = nil
    for _, tileType in ipairs(TileType.ORDERED) do
        if gameState.bonusPool:num(tileType) == 0 then
            missing = tileType
        end
    end
    if missing then
        check(gameState:performAction(TakeBonusTilesAction(P1, { [missing] = 3 })) == nil).is(true)
    end

    local take = firstPoolTiles(gameState, 3)
    local poolBefore, handBefore = gameState.bonusPool:total(), gameState.players[P1].hand:total()
    check(gameState:performAction(TakeBonusTilesAction(P1, take)) ~= nil).is(true)
    check(gameState.bonusPool:total()).is(poolBefore - 3)
    check(gameState.players[P1].hand:total()).is(handBefore + 3)
    check(BonusPickup.owed(gameState) == nil).is(true)
end)

notion("TakeBonusTiles allows several tiles of the wild color", function()
    local gameState = pillarAndStatueGame()
    local wild = gameState:getCurrentWildType()
    -- make the pool hold 3 wilds
    for _, tileType in ipairs(TileType.ORDERED) do
        if tileType ~= wild and gameState.bonusPool:num(tileType) > 0 and gameState.bonusPool:num(wild) < 3 then
            local n = math.min(3 - gameState.bonusPool:num(wild), gameState.bonusPool:num(tileType))
            gameState.bonusPool:removeTiles(tileType, n)
            gameState.bonusPool:addTiles(wild, n)
        end
    end
    placeOrange(gameState, 3)
    check(gameState:performAction(TakeBonusTilesAction(P1, { [wild] = 3 })) ~= nil).is(true)
    check(gameState.players[P1].hand:num(wild)).is(3)
end)

notion("Undo takes back the pickup first, then the placement", function()
    local gameState = pillarAndStatueGame()
    local before = Canonical.encode(gameState:serialize())
    placeOrange(gameState, 3)
    local placed = Canonical.encode(gameState:serialize())
    gameState:performAction(TakeBonusTilesAction(P1, firstPoolTiles(gameState, 3)))

    gameState:undoLastChoice()
    check(Canonical.encode(gameState:serialize()) == placed).is(true)
    check(BonusPickup.owed(gameState).count).is(3)
    gameState:undoLastChoice()
    -- the orange tiles placeOrange added to the hand are back in it
    gameState.players[P1].hand:removeTiles(TileType.ORANGE, 2)
    check(Canonical.encode(gameState:serialize()) == before).is(true)
    check(BonusPickup.owed(gameState) == nil).is(true)
end)

notion("The bonus pool is topped up after a turn only when it has room and there are tiles", function()
    local gameState = TestUtil.newGame()
    check(GameFlow.poolNeedsTopUp(gameState)).is(true)
    gameState:performAction(FillBonusPoolAction())
    check(GameFlow.poolNeedsTopUp(gameState)).is(false)

    -- one tile short, with tiles in the bag
    local some = firstPoolTiles(gameState, 1)
    for tileType, n in pairs(some) do
        gameState.bonusPool:removeTiles(tileType, n)
        gameState.tileBag:addTiles(tileType, n)
    end
    check(GameFlow.poolNeedsTopUp(gameState)).is(true)
    -- bag and tower empty: nothing to top up with
    for _, bag in ipairs({ gameState.tileBag, gameState.discard }) do
        for _, tileType in ipairs(TileType.ORDERED) do
            bag:removeTiles(tileType, bag:num(tileType))
        end
    end
    check(GameFlow.poolNeedsTopUp(gameState)).is(false)
end)

notion("PlaceTile's bonus record and TakeBonusTiles survive serializing (as in a save)", function()
    local Action = require("cloudless_sky.action.action")
    local gameState = pillarAndStatueGame()
    local placed = placeOrange(gameState, 3)[1]
    local take = TakeBonusTilesAction(P1, firstPoolTiles(gameState, 3))
    assert(gameState:performAction(take))
    for _, action in ipairs({ placed, take }) do
        local copy = Action.deserialize(action:serialize())
        check(copy.name).is(action.name)
        check(Canonical.encode(copy.ctx.tiles or copy.ctx.placement) == Canonical.encode(action.ctx.tiles or action.ctx.placement)).is(true)
    end
    -- the saved PlaceTile carries its bonuses (the replay recomputes and compares them)
    local saved = SaveGame.build(gameState)
    local entry = saved.history[#saved.history - 2]
    check(entry.name).is("PlaceTile")
    check(entry.ctx.bonusTiles).is(3)
    check(saved.history[#saved.history].name).is("TakeBonusTiles")
end)
