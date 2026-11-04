--- System functions for entities that are achored to a particular player mat tile
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local BoxedViewSys = require("cloudless_sky.systems.boxed_view")

local PlayerMatTileAnchorSys = Concord.system({
    pool = {
        Components.names.playerMatTileAnchor,
        Components.names.worldPos,
        Components.names.boundingBox,
        Components.names.playerEntity,
    },
})

function PlayerMatTileAnchorSys.ensureEntityFullyVisible(e, w, h, playerMats)
    local tileWorldX, tileWorldY =
        playerMats[e.playerEntity.idx]:centerOfSlot(e.playerMatTileAnchor.starIdx, e.playerMatTileAnchor.slotIdx)
    BoxedViewSys.placeOnScreenNear(e, tileWorldX, tileWorldY, w, h)
end

--- called on resize. w,h are the new dimensions
--- @param graphicsState table current game graphicsState table
function PlayerMatTileAnchorSys:resize(w, h, graphicsState)
    for _, e in ipairs(self.pool) do
        self.ensureEntityFullyVisible(e, w, h, graphicsState.matEntities)
    end
end

return PlayerMatTileAnchorSys
