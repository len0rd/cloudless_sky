-- Container for everything in the game that pertains to one player:
--      - Their PlayMat with all its stars
--      - Tiles in hand/tiles saved between rounds
--      - Their score
--      - Turn stack (to support undo)
local Object = require("cloudless_sky.extern.classic")
local Player = Object:extend()
local PlayMat = require("cloudless_sky.model.player_mat")
local TileBag = require("cloudless_sky.model.tile_bag")


function Player:new()
