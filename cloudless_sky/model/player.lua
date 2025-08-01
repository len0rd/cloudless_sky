-- Container for everything in the game that pertains to one player:
--      - Their PlayMat with all its stars
--      - Tiles in hand/tiles saved between rounds
--      - Their score
--      - Turn stack (to support undo)
local Object = require("cloudless_sky.extern.classic")
local Player = Object:extend()
local PlayMat = require("cloudless_sky.model.player_mat")
local TileBag = require("cloudless_sky.model.tile_bag")
local ScoreEvent = require("cloudless_sky.model.score_event")
local PlayerEvent = require("cloudless_sky.model.player_event")
local PlacementPossibility = require("cloudless_sky.model.placement_possibility")
local TileType = require("cloudless_sky.model.tile_type")

function Player:new(starConfigs, startScore, name)
    self.mat = PlayMat(starConfigs)
    -- since this TileBag functions as the players hand, the game RNG is not needed
    self.hand = TileBag()
    self.score = startScore
    self.playerName = name
    self.actionHistory = {}
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
        events = self.actionHistory,
    }
end

function Player:generatePlacementPossibilities(starIdx, slotIdx, wildTileType)
    local star = self.mat:getStar(starIdx)
    if star == nil then
        return {}
    end

    local wildQty = self.hand:num(wildTileType)
    local slotCost = star:slotIndexToCost(slotIdx)

    local possibilities = {}

    local possibilitiesForTileType = function(tileType)
        local possibles = {}
        if star:isTileTypeAllowedInSlot(tileType, slotIdx) then
            local numTiles = self.hand:num(tileType)

            if tileType == wildTileType and numTiles >= slotCost then
                -- can play the current wild tile as itself if you really want to...
                table.insert(possibles, PlacementPossibility(tileType, slotCost))
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
    if data["name"] ~= nil then
        self.playerName = data["name"]
    end
    self.score = data.score
    self.mat:deserialize(data.mat)
    self.hand:deserialize(data.hand)
end

--- @return table events All score events performed by the player. Sorted by when they occurred
---     Oldest at index 1
function Player:getAllScoreEvents()
    local scoreEvents = {}
    for _, event in ipairs(self.actionHistory) do
        if event.type == "score" then
            table.insert(scoreEvents, event.data)
        end
    end
    return scoreEvents
end

--- Add a score event/action to this players history
function Player:addScoreEvent(tileType, starIndex, slotIndex, score)
    table.insert(self.actionHistory, PlayerEvent.new("score", ScoreEvent.new(tileType, starIndex, slotIndex, score)))
    -- add this new score to our total!
    self.score = self.score + score[1]
end

return Player
