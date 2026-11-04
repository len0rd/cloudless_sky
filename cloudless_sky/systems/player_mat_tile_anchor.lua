--- System functions for entities that are achored to a particular player mat tile
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")

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

    e.worldPos.x = tileWorldX
    e.worldPos.y = tileWorldY

    -- is this mat even in view right now
    if camera:isWorldCoordsInFrame(tileWorldX, tileWorldY) then
        local tileCameraX, tileCameraY = camera:cameraCoords(tileWorldX, tileWorldY)
        -- anchored entities are sized in screen pixels (they draw in screen space), so convert
        -- their size to world units before shifting their world position
        if tileCameraX + e.boundingBox.w > (w * (1.0 - Constants.hudPadPercent)) then
            e.worldPos.x = e.worldPos.x - e.boundingBox.w / camera.scale
        end
        if tileCameraY + e.boundingBox.h > (h * (1.0 - Constants.hudPadPercent)) then
            e.worldPos.y = e.worldPos.y - e.boundingBox.h / camera.scale
        end
    end
end

--- called on resize. w,h are the new dimensions
--- @param graphicsState table current game graphicsState table
function PlayerMatTileAnchorSys:resize(w, h, graphicsState)
    for _, e in ipairs(self.pool) do
        self.ensureEntityFullyVisible(e, w, h, graphicsState.matEntities)
    end
end

return PlayerMatTileAnchorSys
