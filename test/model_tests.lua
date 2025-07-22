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

    check(bag:empty()).is(true)
    check(bag:total()).is(0)
end)

notion("takeRandomTile returns valid tile type", function()
    local rng = love.math.newRandomGenerator(0xdeadbeef)
    local bag = TileBag(rng)

    bag:setCountForTileType(TileType.GREEN, 20)
    check(bag:takeRandomTile()).is(TileType.GREEN)
    check(bag:total()).is(19)
    check(bag:num(TileType.GREEN)).is(19)
end)

notion("takeRandomTile repeatable with seed", function()
    -- just sanity check we get the same sequence of values with the same seed
    local rng = love.math.newRandomGenerator(0xdeadbeef)
    local bag = TileBag(rng)

    for _, validTileType in ipairs(TileType.ORDERED) do
        bag:setCountForTileType(validTileType, 20)
    end

    -- assumes TileType order :/
    local expectedTiles = { TileType.PURPLE, TileType.RED, TileType.BLUE, TileType.YELLOW, TileType.GREEN }
    for _, expectedType in ipairs(expectedTiles) do
        check(bag:takeRandomTile()).is(expectedType)
    end
end)
