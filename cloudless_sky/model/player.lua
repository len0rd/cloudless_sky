-- Container for everything in the game that pertains to one player:
--      - Their PlayMat with all its stars
--      - Tiles in hand/tiles saved between rounds
--      - Their score
--      - Turn stack (to support undo)
local Object = require("cloudless_sky.extern.classic")
local Player = Object:extend()
local PlayMat = require("cloudless_sky.model.player_mat")
local TileBag = require("cloudless_sky.model.tile_bag")
local GameRules = require("cloudless_sky.model.game_rules")

function Player:new(starConfig, x, y, matSize, name)
    self.mat = PlayMat(GameRules.currentRules().playerMat.stars)
    -- since this TileBag functions as the players hand, the game RNG is not needed
    self.hand = TileBag()
    self.score = GameRules.currentRules().startScore
    self.playerName = name
end

function Player:serialize()
    return {
        mat = self.mat.serialze(),
        hand = self.hand.serialize(),
        score = self.score,
        name = self.playerName,
    }
end

function Player:deserialize(data)
    self.playerName = data.name
    self.score = data.score
    self.mat:deserialize(data.mat)
    self.hand:deserialize(data.hand)
end
