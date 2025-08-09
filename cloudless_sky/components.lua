--- All game component definitions

local Concord = require("cloudless_sky.extern.concord")
local Constants = require("cloudless_sky.constants")

local Components = {}

Components.names = {
    playerMatTileAnchor = "playerMatTileAnchor",
    playerMatTileFocus = "playerMatTileFocus",
    killOffCamera = "killOffCamera",
    worldPos = "worldPos",
    cameraPos = "cameraPos",
    drawable = "drawable",
    mouseHandler = "mouseHandler",
    mouseFocusable = "mouseFocusable",
    boundingBox = "boundingBox",
    playerEntity = "playerEntity",
}

--- Entity should remain anchored on a particular player mat tile
Concord.component(Components.names.playerMatTileAnchor, function(c, starIdx, slotIdx)
    assert(starIdx ~= nil and starIdx ~= 0, "valid starIdx is required")
    assert(slotIdx ~= nil and slotIdx ~= 0, "valid slotIdx is required")
    c.starIdx = starIdx
    c.slotIdx = slotIdx
end)

--- This entity is tied to a particular player and should only by updated when its that players turn
Concord.component(Components.names.playerEntity, function(c, playerIdx)
    c.idx = playerIdx
end)

--- If the entity is not in the cameras current view port, remove it from the world
Concord.component(Components.names.killOffCamera)

--- Entity has a position in the world frame. Typically defines its top-left BBox corner
Concord.component(Components.names.worldPos, function(c, worldX, worldY)
    c.x = worldX or 0
    c.y = worldY or 0
end)

--- Entity has a position in the camera frame. Typically defines its top-left BBox corner
Concord.component(Components.names.cameraPos, function(c, cameraX, cameraY)
    c.x = cameraX or 0
    c.y = cameraY or 0
end)

--- Entity has an update and draw function. Smaller number = higher priority
Concord.component(Components.names.drawable, function(c, priority)
    c.priority = priority or Constants.drawPriority.min
end)

--- Entity has a mousePressed handler which returns true if the mouse event was
--- handled by it or false if not. Smaller number = higher priority
--- If the entity handled a mouse press, it can optionally set clickEvent to something. clickEvent will
--- be reset to nil at the end of each update (on :leaveUpdate )
Concord.component(Components.names.mouseHandler, function(c, priority)
    c.priority = priority or Constants.drawPriority.min
    c.clickEvent = nil
end)

--- Entity dimensions can be contained within a width/height
Concord.component(Components.names.boundingBox, function(c, w, h)
    assert(w ~= nil and w > 0, "boundingBox component must have a width! got: " .. tostring(w))
    assert(h ~= nil and h > 0, "boundingBox component must have a height! got: " .. tostring(h))
    c.w = w
    c.h = h
end)

return Components
