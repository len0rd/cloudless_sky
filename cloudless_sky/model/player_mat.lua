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

--- The stars of the first/default map used in the base game
PlayerMat.BASE_GAME_DEFAULT_MAT = {
    StarType.ORANGE,
    StarType.RED,
    StarType.BLUE,
    StarType.YELLOW,
    StarType.GREEN,
    StarType.PURPLE,
    StarType.MULTI,
}

--- @param starConfigs table. List of starConfigs of the format described in
---     @ref Star:new. Indicies of the table should correspond to the Mat index
---     of the star
function PlayerMat:new(starConfigs)
    self.stars = {}
    for ii, sConf in ipairs(starConfigs) do
        self.stars[ii] = Star(sConf)
    end
end

--- @return StarType type The StarType at the given index or nil if invalid index
function PlayerMat:starType(starIndex)
    if starIndex < 1 or starIndex > #self.stars then
        return nil
    end
    return self.stars[starIndex].starType
end

function PlayerMat:serialize()
    local serialized = {}
    for ii, star in ipairs(self.stars) do
        serialized[tostring(ii)] = star:serialize()
    end
    return serialized
end

function PlayerMat:deserialize(data)
    for ii, starData in pairs(data) do
        local starIdx = tonumber(ii)
        if starIdx ~= nil and self.stars[starIdx] ~= nil then
            self.stars[starIdx]:deserialize(starData)
        end
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
function PlayerMat:placeTile(tileType, starIndex, slotIndex)
    local star = self.stars[starIndex]
    print("place a " .. tileType .. " tile at " .. starIndex .. ", " .. slotIndex)
    if star == nil then
        -- invalid starIndex
        return {}
    end
    local score = star:placeTile(tileType, slotIndex)
    if score < 1 then
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
