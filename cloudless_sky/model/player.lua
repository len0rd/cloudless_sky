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
