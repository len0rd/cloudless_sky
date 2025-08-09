--- Entity for a the player mat visual (state of mat is in model.player_mat)

local Concord = require("cloudless_sky.extern.concord")

local PlayerMatEntity = {}

--- Based on the PlayerMatView bounding box and the playerIndex, decide on an origin X,Y for the mat to go
local function determineWorldCoords(matView, playerIdx)
    return 0, 0
end

function PlayerMatEntity:new(playerIdx, w, h) end

return PlayerMatEntity
