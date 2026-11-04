local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local MousePressedSys = Concord.system({
    pool = { Components.names.mouseHandler },
    dismissPool = { Components.names.dismissOnClickOutside, Components.names.ephemeral },
})

--- Mouse presses are handled in two phases:
---   1. Claim: entities with a mouseHandler are offered the press in priority order. The first
---      whose :mousePressed returns true claims it. No lower-priority entity sees it.
---   2. Dismiss: every dismissOnClickOutside entity that did not claim the press is marked done.
function MousePressedSys:mousepressed(cameraX, cameraY, button, istouch)
    -- ensure entities are priority-sorted
    local worldX, worldY = camera:worldCoords(cameraX, cameraY)
    self.pool:sort(function(a, b)
        return a.mouseHandler.priority < b.mouseHandler.priority
    end)

    local claimedBy = nil
    for _, e in ipairs(self.pool) do
        if e:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch) then
            claimedBy = e
            break
        end
    end
    self.lastPressedEntity = claimedBy

    for _, e in ipairs(self.dismissPool) do
        if e ~= claimedBy then
            e.ephemeral.done = true
        end
    end
end

--- reset any click events to nil once an update has concluded
function MousePressedSys:leaveUpdate()
    for _, e in ipairs(self.pool) do
        e.mouseHandler.clickEvent = nil
    end
    self.lastPressedEntity = nil
end

return MousePressedSys
