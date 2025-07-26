local cute = require("cloudless_sky.extern.cute")
local TileType = require("cloudless_sky.model.tile_type")
local StarType = require("cloudless_sky.model.star_type")
local Star = require("cloudless_sky.model.star")

local DEFAULT_SLOT_COST_FOR_STAR = {
    [StarType.RED] = { 5, 6, 1, 2, 3, 4 },
    [StarType.ORANGE] = { 6, 1, 2, 3, 4, 5 },
    [StarType.YELLOW] = { 3, 4, 5, 6, 1, 2 },
    [StarType.GREEN] = { 2, 3, 4, 5, 6, 1 },
    [StarType.BLUE] = { 4, 5, 6, 1, 2, 3 },
    [StarType.PURPLE] = { 1, 2, 3, 4, 5, 6 },
    [StarType.MULTI] = { 1, 2, 3, 4, 5, 6 },
    -- mono and multistatic slot placement depends on the mat/star position
}

--- @return StarType default. The StarType that's located at the given starIndex on the base-game's play mat
---     nil on bad index
local defaultStarForIndex = function(starIndex)
    local starIndexToType = {
        [1] = StarType.ORANGE,
        [2] = StarType.RED,
        [3] = StarType.BLUE,
        [4] = StarType.YELLOW,
        [5] = StarType.GREEN,
        [6] = StarType.PURPLE,
        [7] = StarType.MULTI,
    }
    return starIndexToType[starIndex]
end

--- Returns the default slot cost array for the STAR index on a PlayerMat
--- See PlayerMat for how this index works
--- @return table slotCosts. The default slot costs for a star at the given starIndex
---     Empty if index is invalid
local getDefaultSlotCostForBoardPosition = function(starIndex)
    local starType = defaultStarForIndex(starIndex)
    if starType then
        return DEFAULT_SLOT_COST_FOR_STAR[starType]
    else
        return {}
    end
end

notion("New star is empty", function()
    local star = Star({ type = StarType.RED, cost = DEFAULT_SLOT_COST_FOR_STAR(StarType.RED) })

    check(star:numOccupied()).is(0)
    check(star:isFull()).is(false)
    check(star:isEmpty()).is(true)
end)

notion("hasSlotCost colored star has std costs", function()
    for _, tileType in ipairs(TileType.ORDERED) do
        local star = Star({ type = tileType, cost = DEFAULT_SLOT_COST_FOR_STAR(tileType) })
        for ii = 1, 6 do
            check(star:hasSlotCost(ii)).is(true)
            check(star:isSlotOfCostCovered(ii)).is(false)
        end
    end
end)

notion("isTileTypeAllowedInSlot", function()
    local star = Star({ type = StarType.RED, cost = DEFAULT_SLOT_COST_FOR_STAR(StarType.RED) })
    check(star:isTileTypeAllowedInSlot(TileType.ORANGE, 1)).is(false)
    check(star:isTileTypeAllowedInSlot(TileType.RED, 1)).is(true)

    star = Star({ type = StarType.MONO, cost = getDefaultSlotCostForBoardPosition(1) })
    for _, tileType in ipairs(TileType.ORDERED) do
        check(star:isTileTypeAllowedInSlot(tileType, 1)).is(true)
    end

    -- empty multi stars can accept
    star = Star({ type = StarType.MULTI, cost = DEFAULT_SLOT_COST_FOR_STAR[StarType.MULTI] })
    for _, tileType in ipairs(TileType.ORDERED) do
        check(star:isTileTypeAllowedInSlot(tileType, 1)).is(true)
    end

    star = Star({
        type = StarType.MULTI_STATIC,
        cost = getDefaultSlotCostForBoardPosition(7),
        color = Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS,
    })
    for _, tileType in ipairs(TileType.ORDERED) do
        check(star:isTileTypeAllowedInSlot(tileType, 1)).is(
            tileType == Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS[1]
        )
    end
end)

notion("placeTile invalid type for star. 0 and not placed", function()
    -- placeTile should return 0 and not change any star state when a tile cannot be placed where specified

    local star = Star({ type = StarType.RED, cost = DEFAULT_SLOT_COST_FOR_STAR[StarType.RED] })
    check(star:placeTile(TileType.ORANGE, 1)).is(0)
    check(star:isEmpty()).is(true)

    star = Star({
        type = StarType.MULTI_STATIC,
        cost = getDefaultSlotCostForBoardPosition(7),
        color = Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS,
    })
    check(star:placeTile(Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS[2], 1)).is(0)
    check(star:isEmpty()).is(true)
end)

notion("placeTile valid tile. good scoring", function()
    -- verify scoring works
    local star = Star({ type = StarType.BLUE, cost = DEFAULT_SLOT_COST_FOR_STAR[StarType.BLUE] })

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
    local star = Star({ type = StarType.ORANGE, cost = DEFAULT_SLOT_COST_FOR_STAR[StarType.ORANGE] })

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
