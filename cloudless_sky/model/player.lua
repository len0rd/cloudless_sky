-- Container for everything in the game that pertains to one player:
--      - Their PlayMat with all its stars
--      - Tiles in hand/tiles saved between rounds
--      - Their score
---@class Object
local Object = require("cloudless_sky.extern.classic")
local PlayMat = require("cloudless_sky.model.player_mat")
local TileBag = require("cloudless_sky.model.tile_bag")
local PlacementPossibility = require("cloudless_sky.model.placement_possibility")
local TileType = require("cloudless_sky.model.tile_type")

---@class Player : Object
---@field mat PlayerMat
---@field hand TileBag
---@field passedForPhase boolean During the TilePlacementPhase, players are allowed to pass once they are done
---     This boolean keeps track of that
local Player = Object:extend()

--- lowest score a penalty (passing, first pick from the center) can bring a player to
Player.MIN_SCORE_AFTER_PENALTY = 1

--- @return integer penalty Points a player with \p score actually loses for a penalty of \p points
---     (the score can't go below Player.MIN_SCORE_AFTER_PENALTY)
function Player.clampedPenalty(score, points)
    return math.max(0, math.min(points, score - Player.MIN_SCORE_AFTER_PENALTY))
end

function Player:new(starConfigs, startScore, name)
    self.mat = PlayMat(starConfigs)
    -- since this TileBag functions as the players hand, the game RNG is not needed
    self.hand = TileBag()
    self.score = startScore
    self.playerName = name

    self.passedForPhase = false
end

function Player:starType(starIndex)
    return self.mat:starType(starIndex)
end

function Player:serialize()
    return {
        mat = self.mat:serialize(),
        hand = self.hand:serialize(),
        score = self.score,
        name = self.playerName,
    }
end

function Player:generatePlacementPossibilities(starIdx, slotIdx, wildTileType)
    local star = self.mat:getStar(starIdx)
    if not star then
        return {}
    end

    local wildQty = self.hand:num(wildTileType)
    local slotCost = star:slotIndexToCost(slotIdx)

    local possibilities = {}

    local possibilitiesForTileType = function(tileType)
        local possibles = {}
        if star:isTileTypeAllowedInSlot(tileType, slotIdx) then
            local numTiles = self.hand:num(tileType)

            if tileType == wildTileType then
                if numTiles >= slotCost then
                    -- can play the current wild tile as itself if you really want to...
                    table.insert(possibles, PlacementPossibility(tileType, slotCost))
                end
            elseif numTiles > 0 then
                -- must always have at least one tile of the color in order to place
                for wildCount = 0, math.min(wildQty, slotCost - 1) do
                    if slotCost - wildCount - numTiles <= 0 then
                        -- this placement combination has enough to place in this slot
                        table.insert(
                            possibles,
                            PlacementPossibility(tileType, slotCost - wildCount, wildTileType, wildCount)
                        )
                    end
                end
            end
        end
        return possibles
    end

    --- non-basic star types can typically have more than one color on them,
    --- so rotate through all possible tile types to see which work
    if star:isNonBasicType() then
        for _, tileType in ipairs(TileType.ORDERED) do
            local possibles = possibilitiesForTileType(tileType)
            for _, possibility in ipairs(possibles) do
                table.insert(possibilities, possibility)
            end
        end
    else
        possibilities = possibilitiesForTileType(star.starType)
    end
    return possibilities
end

function Player:deserialize(data)
    if data["name"] then
        self.playerName = data["name"]
    end
    self.score = data.score
    self.mat:deserialize(data.mat)
    self.hand:deserialize(data.hand)
end

--- @return boolean occupied. True if the given slot has a tile in it, otherwise false
function Player:isSlotOccupied(starIdx, slotIdx)
    return self.mat:isOccupied(starIdx, slotIdx)
end

return Player
