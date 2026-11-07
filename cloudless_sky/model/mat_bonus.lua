--- A bonus space on a player mat (a pillar, statue, window or fountain) and the mat slots around it.
--- The space is achieved once every one of its slots holds a tile. Achieving one earns the player
--- tiles from the bonus pool (GameRules.bonusTiles: its kind's value, 0 if the kind is disabled).
---
--- The spaces of a mat come from the rules (GameRules bonusSurrounds.spaces), in a fixed order, so a
--- bonus is identified by its index like stars and slots are. See PlayerMat
local Object = require("cloudless_sky.extern.classic")

---@class MatBonus : Object
---@field idx integer index of the space on the mat (GameRules bonusSurrounds.spaces)
---@field kind string MatBonus.KIND
---@field slots table[] { {starIdx, slotIdx}, ... } the slots around the space
local MatBonus = Object:extend()

--- Kinds of bonus space. The values are the keys of GameRules bonusSurrounds.enabled / bonusValueTiles
MatBonus.KIND = {
    PILLAR = "pillar",
    STATUE = "statue",
    WINDOW = "window",
    FOUNTAIN = "fountain",
}

--- Display names
MatBonus.LABEL = {
    pillar = "Pillar",
    statue = "Statue",
    window = "Window",
    fountain = "Fountain",
}

--- @param space table { kind = MatBonus.KIND, slots = { {starIdx, slotIdx}, ... } }
function MatBonus:new(idx, space)
    self.idx = idx
    self.kind = space.kind
    self.slots = space.slots
end

--- @param mat PlayerMat
--- @return boolean True if every slot around the space holds a tile
function MatBonus:isAchieved(mat)
    for _, slot in ipairs(self.slots) do
        if not mat:isOccupied(slot[1], slot[2]) then
            return false
        end
    end
    return true
end

--- @return boolean True if slot \p slotIdx of star \p starIdx is one of the slots around the space
function MatBonus:surrounds(starIdx, slotIdx)
    for _, slot in ipairs(self.slots) do
        if slot[1] == starIdx and slot[2] == slotIdx then
            return true
        end
    end
    return false
end

--- @param mat PlayerMat
--- @return boolean True if every slot around the space except (\p starIdx, \p slotIdx) holds a tile:
---     filling that slot would achieve it. False if the space isn't around that slot
function MatBonus:completedByFilling(mat, starIdx, slotIdx)
    if not self:surrounds(starIdx, slotIdx) then
        return false
    end
    for _, slot in ipairs(self.slots) do
        if not (slot[1] == starIdx and slot[2] == slotIdx) and not mat:isOccupied(slot[1], slot[2]) then
            return false
        end
    end
    return true
end

return MatBonus
