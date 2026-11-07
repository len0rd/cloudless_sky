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
---
--- Bonus spaces (MatBonus: pillars, statues, windows, fountains) sit between the slots. They're
--- indexed in the order the rules list them (GameRules bonusSurrounds.spaces). Whether one is achieved
--- comes from which slots hold tiles, so it needs no state of its own
local Object = require("cloudless_sky.extern.classic")
local MatBonus = require("cloudless_sky.model.mat_bonus")
local StarType = require("cloudless_sky.model.star_type")
local Star = require("cloudless_sky.model.star")

---@class PlayerMat : Object
---@field stars Star[]
---@field bonuses MatBonus[] the mat's bonus spaces, by index
local PlayerMat = Object:extend()

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
--- @param bonusSpaces table|nil the bonus spaces (GameRules bonusSurrounds.spaces). nil: none
function PlayerMat:new(starConfigs, bonusSpaces)
    self.stars = {}
    for ii, sConf in ipairs(starConfigs) do
        self.stars[ii] = Star(sConf)
    end
    self.bonuses = {}
    for ii, space in ipairs(bonusSpaces or {}) do
        self.bonuses[ii] = MatBonus(ii, space)
    end
end

--- @return MatBonus|nil the bonus space at \p bonusIdx
function PlayerMat:bonusAt(bonusIdx)
    return self.bonuses[bonusIdx]
end

--- @return integer[] indices of every achieved bonus space, in order
function PlayerMat:achievedBonuses()
    local achieved = {}
    for ii, bonus in ipairs(self.bonuses) do
        if bonus:isAchieved(self) then
            table.insert(achieved, ii)
        end
    end
    return achieved
end

--- @return integer[] indices of the bonus spaces around (\p starIdx, \p slotIdx) that are achieved:
---     after placing a tile there, the bonuses that placement completed
function PlayerMat:bonusesCompletedBy(starIdx, slotIdx)
    local completed = {}
    for ii, bonus in ipairs(self.bonuses) do
        if bonus:surrounds(starIdx, slotIdx) and bonus:isAchieved(self) then
            table.insert(completed, ii)
        end
    end
    return completed
end

function PlayerMat:getStar(starIdx)
    if starIdx < 1 or starIdx > #self.stars then
        return nil
    end
    return self.stars[starIdx]
end

--- @return StarType type The StarType at the given index or nil if invalid index
function PlayerMat:starType(starIndex)
    if starIndex < 1 or starIndex > #self.stars then
        return nil
    end
    return self.stars[starIndex].starType
end

--- @return boolean slotOccupied. True if the given slot in starIdx, otherwise false
function PlayerMat:isOccupied(starIdx, slotIdx)
    if starIdx < 1 or starIdx > #self.stars then
        return false
    end
    return self.stars[starIdx]:isOccupied(slotIdx)
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
        if starIdx and self.stars[starIdx] then
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
    if not star then
        -- invalid starIndex
        return {}
    end
    local score = star:possibleScoreForPlacement(slotIndex)
    if score < 0 then
        -- invalid slotIndex
        return {}
    end

    local events = { score }
    if not star:isOccupied(slotIndex) then
        for ii, bonus in ipairs(self.bonuses) do
            if bonus:completedByFilling(self, starIndex, slotIndex) then
                table.insert(events, ii)
            end
        end
    end
    return events
end

--- @return table events. Table of events that occurred when the tile was placed.
---         First element is the points the tile scored within its star. The rest are the indices
---         of the bonus spaces the placement completed (see bonusesCompletedBy).
---         If either index is invalid, an empty table is returned
function PlayerMat:placeTile(tileType, starIndex, slotIndex)
    local star = self.stars[starIndex]
    Log.trace("place a " .. tileType .. " tile at " .. starIndex .. ", " .. slotIndex)
    if not star then
        -- invalid starIndex
        return {}
    end
    local score = star:placeTile(tileType, slotIndex)
    if score < 1 then
        -- invalid slotIndex
        return {}
    end

    local events = { score }
    for _, bonusIdx in ipairs(self:bonusesCompletedBy(starIndex, slotIndex)) do
        table.insert(events, bonusIdx)
    end
    return events
end

function PlayerMat:removeTile(starIndex, slotIndex)
    local star = self.stars[starIndex]
    if star then
        star:removeTile(slotIndex)
    else
        Log.error("removeTile: bad starIndex" .. starIndex)
    end
end

return PlayerMat
