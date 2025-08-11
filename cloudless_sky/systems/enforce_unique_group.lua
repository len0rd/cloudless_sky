--- enforce entities that are in a unique group remain unique
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local EnforceUniqueGroupSys = Concord.system({
    pool = { Components.names.uniqueGroup },
})

function EnforceUniqueGroupSys:entityAdded(newEntity)
    local entityToRemove = nil
    for _, e in ipairs(self.pool) do
        if
            e.uniqueGroup
            and e.uniqueGroup.uid ~= newEntity.uniqueGroup.uid
            and e.uniqueGroup.name == newEntity.uniqueGroup.name
        then
            -- match. remove the old
            entityToRemove = e
            -- assuming that this system has always been running and that there
            -- is at most one other entity in a given group
            break
        end
    end
    if entityToRemove then
        entityToRemove:destroy()
    end
end

return EnforceUniqueGroupSys
