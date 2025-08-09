local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local MousePressedSys = Concord.system({
    pool = { Components.names.mouseHandler },
})

function MousePressedSys:mousepressed(x, y, button, istouch)
    -- ensure entities are priority-sorted
    table.sort(self.pool, function(a, b)
        return a.mouseHandler.priority < b.mouseHandler.priority
    end)

    for _, e in ipairs(self.pool) do
        if e.mousePressed(x, y, button, istouch) then
            -- entity has claimed it handled the mouse. done
            return
        end
    end
end

--- reset any click events to nil once an update has concluded
function MousePressedSys:leaveUpdate()
    for _, e in ipairs(self.pool) do
        e.mouseHandler.clickEvent = nil
    end
end

return MousePressedSys
