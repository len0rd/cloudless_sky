local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local MousePressedSys = Concord.system({
    pool = { Components.names.mouseHandler },
})

function MousePressedSys:mousepressed(cameraX, cameraY, button, istouch)
    -- ensure entities are priority-sorted
    local worldX, worldY = camera:worldCoords(cameraX, cameraY)
    self.pool:sort(function(a, b)
        return a.mouseHandler.priority < b.mouseHandler.priority
    end)

    for _, e in ipairs(self.pool) do
        if e:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch) then
            -- entity has claimed it handled the mouse. done
            self.lastPressedEntity = e
            return
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
