local cute = require("cloudless_sky.extern.cute")
local TileDraw = require("cloudless_sky.action.tile_draw")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

--- Draw \p count tiles from \p gameState
--- @return table drawn TileType of each tile drawn
--- @return table refills the moved table of each refill
--- @return integer n number drawn
local function drawAll(gameState, count)
    local drawn, refills = {}, {}
    local n = TileDraw.draw(gameState, count, function(tileType)
        table.insert(drawn, tileType)
    end, function(moved)
        table.insert(refills, moved)
    end)
    return drawn, refills, n
end

notion("TileDraw draws from the bag", function()
    local gameState = TestUtil.newGame()
    local bagBefore = gameState.tileBag:total()
    local drawn, refills, n = drawAll(gameState, 7)
    check(n).is(7)
    check(#drawn).is(7)
    check(#refills).is(0)
    check(gameState.tileBag:total()).is(bagBefore - 7)
end)

notion("TileDraw refills the bag from the tower when it runs out", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { [TileType.RED] = 2 })
    TestUtil.setBag(gameState.discard, { [TileType.BLUE] = 3, [TileType.GREEN] = 1 })

    local drawn, refills, n = drawAll(gameState, 5)
    check(n).is(5)
    check(drawn[1]).is(TileType.RED)
    check(drawn[2]).is(TileType.RED)
    check(#refills).is(1)
    check(refills[1][TileType.BLUE]).is(3)
    check(refills[1][TileType.GREEN]).is(1)
    check(refills[1][TileType.RED]).is(nil)
    check(gameState.discard:total()).is(0)
    check(gameState.tileBag:total()).is(1)

    -- undoing the refill puts the moved tiles back in the tower (the tile still in the bag came from it)
    TileDraw.undoRefill(gameState, { [TileType.GREEN] = 1 })
    check(gameState.tileBag:total()).is(0)
    check(gameState.discard:num(TileType.GREEN)).is(1)
end)

notion("TileDraw stops short when the bag and tower are both empty", function()
    local gameState = TestUtil.newGame()
    TestUtil.setBag(gameState.tileBag, { [TileType.YELLOW] = 1 })
    TestUtil.setBag(gameState.discard, {})
    local drawn, refills, n = drawAll(gameState, 4)
    check(n).is(1)
    check(#drawn).is(1)
    check(#refills).is(0)
end)

notion("TileBag moveAllTo moves every tile and reports what moved", function()
    local from = TestUtil.bagOf({ [TileType.RED] = 2, [TileType.PURPLE] = 5 })
    local to = TestUtil.bagOf({ [TileType.RED] = 1 })
    local moved = from:moveAllTo(to)
    check(from:total()).is(0)
    check(to:num(TileType.RED)).is(3)
    check(to:num(TileType.PURPLE)).is(5)
    check(moved[TileType.RED]).is(2)
    check(moved[TileType.PURPLE]).is(5)
    check(moved[TileType.BLUE]).is(nil)
end)
