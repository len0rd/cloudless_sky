--- Every update, remove any ephemeral enetities that say they're done
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local EnforceEphemeralSys = Concord.system({
    pool = { Components.names.ephemeral },
})

function EnforceEphemeralSys:update(dt, gameState)
    for _, e in ipairs(self.pool) do
        if e.ephemeral.done then
            e:destroy()
        end
    end

    -- ensure all pools are updated before continuing the update event
    self:getWorld():__flush()
end

return EnforceEphemeralSys
