--- All game component definitions

local Concord = require("cloudless_sky.extern.concord")

local MAX_PRIORITY = 100

Concord.component("tileFocus", function(c, starIdx, slotIdx)
    assert(starIdx ~= nil and starIdx ~= 0, "valid starIdx is required")
    assert(slotIdx ~= nil and slotIdx ~= 0, "valid slotIdx is required")
    c.starIdx = starIdx
    c.slotIdx = slotIdx
end)

Concord.component("worldPosition", function(c, worldX, worldY)
    c.worldX = worldX or 0
    c.worldY = worldY or 0
end)

Concord.component("cameraPosition", function(c, cameraX, cameraY)
    c.worldX = cameraX or 0
    c.worldY = cameraY or 0
end)

--- Entities that have a draw function
Concord.component("drawable", function(c, priority)
    c.priority = priority or MAX_PRIORITY
end)


--- Entities that have a mousePressed handler which returns true if the mouse event was
--- handled by it or false if not
Concord.component("mouseHandler", function(c, priority)
    c.priority = priority or MAX_PRIORITY
end)
