local cute = require("cloudless_sky.extern.cute")
local TileType = require("cloudless_sky.model.tile_type")
local StarType = require("cloudless_sky.model.star_type")
local Star = require("cloudless_sky.model.star")

notion("New star is empty", function()
    local star = Star(StarType.RED)

    check(star:numOccupied()).is(0)
    check(star:isFull()).is(false)
    check(star:isEmpty()).is(true)
end)

notion("hasSlotCost colored star has std costs", function()
    for _, tileType in ipairs(TileType.ORDERED) do
        local star = Star(tileType)
        for ii = 1, 6 do
            check(star:hasSlotCost(ii)).is(true)
            check(star:isSlotOfCostCovered(ii)).is(false)
        end
    end
end)

notion("isTileTypeAllowedInSlot", function()
    local star = Star(StarType.RED)
    check(star:isTileTypeAllowedInSlot(TileType.ORANGE, 1)).is(false)
    check(star:isTileTypeAllowedInSlot(TileType.RED, 1)).is(true)

    star = Star(StarType.MONO, Star.getDefaultSlotCostForBoardPosition(1))
    for _, tileType in ipairs(TileType.ORDERED) do
        check(star:isTileTypeAllowedInSlot(tileType, 1)).is(true)
    end

    -- empty multi stars can accept
    star = Star(StarType.MULTI)
    for _, tileType in ipairs(TileType.ORDERED) do
        check(star:isTileTypeAllowedInSlot(tileType, 1)).is(true)
    end

    star = Star(
        StarType.MULTI_STATIC,
        Star.getDefaultSlotCostForBoardPosition(7),
        Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS
    )
    for _, tileType in ipairs(TileType.ORDERED) do
        check(star:isTileTypeAllowedInSlot(tileType, 1)).is(
            tileType == Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS[1]
        )
    end
end)

notion("placeTile invalid type for star. 0 and not placed", function()
    -- placeTile should return 0 and not change any star state when a tile cannot be placed where specified

    local star = Star(StarType.RED)
    check(star:placeTile(TileType.ORANGE, 1)).is(0)
    check(star:isEmpty()).is(true)

    star = Star(
        StarType.MULTI_STATIC,
        Star.getDefaultSlotCostForBoardPosition(7),
        Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS
    )
    check(star:placeTile(Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS[2], 1)).is(0)
    check(star:isEmpty()).is(true)
end)

notion("placeTile valid tile. good scoring", function()
    -- verify scoring works
    local star = Star(StarType.BLUE)

    check(star:placeTile(TileType.BLUE, 3)).is(1)
    check(star:isEmpty()).is(false)
    check(star:numOccupied()).is(1)

    check(star:placeTile(TileType.BLUE, 2)).is(2)
    check(star:numOccupied()).is(2)

    check(star:placeTile(TileType.BLUE, 1)).is(3)
    check(star:numOccupied()).is(3)

    check(star:placeTile(TileType.BLUE, 4)).is(4)
    check(star:numOccupied()).is(4)

    check(star:placeTile(TileType.BLUE, 5)).is(5)
    check(star:numOccupied()).is(5)

    check(star:placeTile(TileType.BLUE, 6)).is(6)
    check(star:numOccupied()).is(6)

    check(star:placeTile(TileType.BLUE, 6)).is(0)
    check(star:numOccupied()).is(6)
end)

notion("placeTile non-adjacent. correct points", function()
    -- be the worst possible player
    local star = Star(StarType.ORANGE)

    check(star:placeTile(TileType.ORANGE, 2)).is(1)
    check(star:numOccupied()).is(1)

    check(star:placeTile(TileType.ORANGE, 4)).is(1)
    check(star:numOccupied()).is(2)

    check(star:placeTile(TileType.ORANGE, 6)).is(1)
    check(star:numOccupied()).is(3)

    check(star:placeTile(TileType.ORANGE, 1)).is(3)
    check(star:numOccupied()).is(4)

    check(star:placeTile(TileType.ORANGE, 5)).is(5)
    check(star:numOccupied()).is(5)
end)
