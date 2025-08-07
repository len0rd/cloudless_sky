--- All game component definitions

local Concord = require("cloudless_sky.extern.concord")

local MIN_PRIORITY = 100

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
    c.cameraX = cameraX or 0
    c.cameraY = cameraY or 0
end)

--- Entities that have a draw function. Smaller number = higher priority
Concord.component("drawable", function(c, priority)
    c.priority = priority or MIN_PRIORITY
end)

--- Entities that have a mousePressed handler which returns true if the mouse event was
--- handled by it or false if not. Smaller number = higher priority
Concord.component("mouseHandler", function(c, priority)
    c.priority = priority or MIN_PRIORITY
end)

--- Entity dimensions can be contained within a width/height
Concord.component("boundingBox", function(c, w, h)
    assert(w ~= nil and w > 0, "boundingBox component must have a width! got: " .. tostring(w))
    assert(h ~= nil and h > 0, "boundingBox component must have a height! got: " .. tostring(h))
    c.w = w
    c.h = h
end)
