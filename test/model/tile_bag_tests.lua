local cute = require("cloudless_sky.extern.cute")
local TileType = require("cloudless_sky.model.tile_type")
local TileBag = require("cloudless_sky.model.tile_bag")

notion("setCountForTileType updates a color", function()
    local bag = TileBag()

    check(bag:num(TileType.BLUE)).is(0)
    bag:setCountForTileType(TileType.BLUE, 20)
    check(bag:num(TileType.BLUE)).is(20)
    check(bag:num(TileType.PURPLE)).is(0)
end)

notion("New TileBag is empty", function()
    local bag = TileBag()

    check(bag:isEmpty()).is(true)
    check(bag:total()).is(0)
end)

notion("takeRandomTile returns valid tile type", function()
    local rng = love.math.newRandomGenerator(0xdeadbeef)
    local bag = TileBag()

    bag:setCountForTileType(TileType.GREEN, 20)
    check(bag:takeRandomTile(rng)).is(TileType.GREEN)
    check(bag:total()).is(19)
    check(bag:num(TileType.GREEN)).is(19)
end)

notion("takeRandomTile repeatable with seed", function()
    -- just sanity check we get the same sequence of values with the same seed
    local rng = love.math.newRandomGenerator(0xdeadbeef)
    local bag = TileBag(20)

    local numInBag = bag:total()
    -- assumes TileType order :/
    local expectedTiles = { TileType.PURPLE, TileType.RED, TileType.BLUE, TileType.YELLOW, TileType.GREEN }
    for _, expectedType in ipairs(expectedTiles) do
        check(bag:takeRandomTile(rng)).is(expectedType)
    end
    check(bag:total()).is(numInBag - #expectedTiles)
end)

notion("takeRandomTiles repeatable with seed", function()
    -- just sanity check we get the same sequence of values with the same seed
    local rng = love.math.newRandomGenerator(0xdeadbeef)
    local bag = TileBag(20)

    local numInBag = bag:total()
    -- assumes TileType order :/
    local expectedTiles = { TileType.PURPLE, TileType.RED, TileType.BLUE, TileType.YELLOW, TileType.GREEN }
    local actualTiles = bag:takeRandomTiles(rng, #expectedTiles)
    check(actualTiles).shallowMatches(expectedTiles)
    check(bag:total()).is(numInBag - #expectedTiles)
    -- add the tiles back in. then each tile should be back at its starting qty of 20
    bag:addTileList(actualTiles)
    check(bag:total()).is(numInBag)
    for _, tileType in pairs(TileType.ORDERED) do
        check(bag:num(tileType)).is(20)
    end
end)

notion("takeRandomTiles returns at most total", function()
    -- verify takeRandomTiles will not return more tiles than whats present in the bag
    local rng = love.math.newRandomGenerator(0xdeadbeef)
    local bag = TileBag(1)

    local numInBag = bag:total()
    check(numInBag).is(#TileType.ORDERED)

    local actualTiles = bag:takeRandomTiles(rng, numInBag + 2)
    check(#actualTiles).is(numInBag)
    check(bag:total()).is(0)
    check(bag:isEmpty()).is(true)
    -- since there's only one of each tileType in this bag, verify all tiles returned are unique
    local unique = true
    local seen = {}
    for _, tile in ipairs(actualTiles) do
        if seen[tile] then
            unique = false
            break
        end
        seen[tile] = true
    end
    check(unique).is(true)
end)
