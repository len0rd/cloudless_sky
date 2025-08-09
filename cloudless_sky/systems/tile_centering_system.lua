--- Systems that ensure entities stay centered on the tile they are in relation to

local Concord = require("cloudless_sky.extern.concord")

local TileWorldCenteringSystem = Concord.system({
    pool = { "tileFocus", "worldPosition", "boundingBox" },
})

--- On a resize, ensure the entity stays centered on a tile
function TileWorldCenteringSystem:resize(w, h)
    for _, e in ipairs(self.pool) do
    end
end

return TileWorldCenteringSystem
