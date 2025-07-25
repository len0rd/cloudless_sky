-- basically just a container for all the stars a players using
--- PlayerMat star indicies:
---
---        *     *
---       *1*   *2*
---        *     *
---      *    *    *
---     *6*  *7*  *3*
---      *    *    *
---        *     *
---       *5*   *4*
---        *     *
local Object = require("cloudless_sky.extern.classic")
local PlayerMat = Object:extend()
local StarType = require("cloudless_sky.model.star_type")
local Star = require("cloudless_sky.model.star")

--- @return StarType default. The StarType that's located at the given starIndex on the base-game's play mat
---     nil on bad index
function PlayerMat.defaultStarForIndex(starIndex)
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

function PlayerMat:new(starTypes, starSlotCosts, starSlotColors)
    self.stars = {}
    for ii, sType in ipairs(starTypes) do
        local slotCost = nil
        if starSlotCosts ~= nil and starSlotCosts[ii] ~= nil then
            slotCost = starSlotCosts[ii]
        end

        local slotColor = nil
        if starSlotColors ~= nil and starSlotColors[ii] ~= nil then
            slotColor = starSlotColors[ii]
        end

        self.stars[ii] = Star(sType, slotCost, slotColor)
    end
end

--- @return table events. Table of events that could occur if a tile was placed in the specified position
---     The first element is the points the tile would score (purely for adjacency, nothing related to end-game bonuses)
---     All subsequent elements are possible Placement bonuses the player would earn by placling the tile.
---         If either index is invalid, an empty table is returned
function PlayerMat:possibleEventsForPlacement(starIndex, slotIndex)
    local star = self.stars[starIndex]
    if star == nil then
        -- invalid starIndex
        return {}
    end
    local score = star:possibleScoreForPlacement(slotIndex)
    if score < 0 then
        -- invalid slotIndex
        return {}
    end

    -- TODO: placement bonus calculation!
    return { score }
end

--- @return table events. Table of events that occurred when the tile was placed.
---         First element is the points the tile scored within its star.
---         If either index is invalid, an empty table is returned
function PlayerMat:placeTile(starIndex, slotIndex)
    local star = self.stars[starIndex]
    if star == nil then
        -- invalid starIndex
        return {}
    end
    local score = star:placeTile(slotIndex)
    if score < 0 then
        -- invalid slotIndex
        return {}
    end

    -- TODO: placement bonus calculation!
    return { score }
end

function PlayerMat:removeTile(starIndex, slotIndex)
    local star = self.stars[starIndex]
    if star ~= nil then
        star:removeTile(slotIndex)
    else
        print("removeTile: bad starIndex" .. starIndex)
    end
end

return PlayerMat
