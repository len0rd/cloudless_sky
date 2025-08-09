--- Drawing system
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local DrawSys = Concord.system({
    worldPool = { Components.names.drawable, Components.names.worldPos },
    killCheckPool = { Components.names.drawable, Components.names.worldPos, Components.names.killOffCamera },
    cameraPool = { Components.names.drawable, Components.names.cameraPosition },
})

function DrawSys:update(dt, gameState)
    --- TODO: go over killCheckPool and see if any entities can be removed from the world
end

local function sortByPriority(a, b)
    return a.drawable.priority < b.drawable.priority
end

function DrawSys:draw(gameState)
    -- ensure entities are priority-sorted
    table.sort(self.worldPool, sortByPriority)
    camera:attach()
    for _, e in ipairs(self.worldPool) do
        e:draw(gameState)
    end
    camera:detach()

    -- camera pool always has higher priority than world-entities
    table.sort(self.cameraPool, sortByPriority)
    for _, e in ipairs(self.cameraPool) do
        e:draw(gameState)
    end
end

return DrawSys
