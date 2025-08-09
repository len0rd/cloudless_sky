--- Pop-up dialog for spaces where the player can place a tile

local Object = require("cloudless_sky.extern.classic")
local Concord = require("cloudless_sky.extern.concord")

---@class PlaceTileDialog
local PlaceTileDialog = Object:extend()

local PROMPT_WIDTH = 120
local PROMPT_HEIGHT = 100

function PlaceTileDialog:new(starIdx, slotIdx)
    self = Concord.entity()
    self:give("tileFocus", starIdx, slotIdx)
        :give("boundingBox", PROMPT_WIDTH, PROMPT_HEIGHT)
        :give("mouseHandler", 10)
        :give("drawable", 10)
        :give("worldPosition", 0, 0)
end

return PlaceTileDialog
