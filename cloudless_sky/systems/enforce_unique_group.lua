--- enforce entities that are in a unique group remain unique
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local EnforceUniqueGroupSys = Concord.system({
    pool = { Components.names.uniqueGroup },
})

function EnforceUniqueGroupSys:entityAdded(newEntity)
    for _, e in ipairs(self.pool) do
        if e ~= newEntity and e.uniqueGroup.name == newEntity.uniqueGroup.name then
            -- match. remove the old
            self:getWorld():removeEntity(e)
        end
    end
end

return EnforceUniqueGroupSys
