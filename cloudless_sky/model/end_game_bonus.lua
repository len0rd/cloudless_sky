--- End-game bonuses (rules.endGameBonus), scored once the final round is over.
---
--- Per the rules (see docs/reference/rulebooks/azul-summer-pavilion.md "End of the Game"):
---     - completed star: every space of a star filled. Points depend on the star's type
---       (rules.endGameBonus.starCompletion)
---     - number bonus: every space of a value (eg: every 1) covered across all stars on the board
---       (rules.endGameBonus.slotCompletion)
--- Leftover tiles are not scored here: the final round's Pass already discards them with a penalty
---
--- A bonus is plain data so it can be stored in an action's ctx and drawn by views:
---     { kind = "star", starIdx = i, starType = StarType, points = n }
---     { kind = "number", value = v, slots = { { starIdx, slotIdx }, ... }, points = n }
--- Reference bonuses (EndGameBonus.reference) leave out starIdx and slots
local StarType = require("cloudless_sky.model.star_type")

local EndGameBonus = {}

EndGameBonus.KIND = {
    STAR = "star",
    NUMBER = "number",
}

--- @return integer[] the values with a number bonus, ascending
local function numberValues(rules)
    local values = {}
    for value in pairs(rules.endGameBonus.slotCompletion) do
        table.insert(values, tonumber(value))
    end
    table.sort(values)
    return values
end

--- @return integer|nil points for covering every space of \p value. Rules loaded from json may key
---     slotCompletion by string
local function numberPoints(rules, value)
    local slotCompletion = rules.endGameBonus.slotCompletion
    return slotCompletion[value] or slotCompletion[tostring(value)]
end

--- @param rules table GameRules
--- @param player Player
--- @return table[] bonuses what \p player has earned: completed stars in mat order, then number
---     bonuses in ascending value
function EndGameBonus.forPlayer(rules, player)
    local bonuses = {}
    local stars = player.mat.stars

    for starIdx, star in ipairs(stars) do
        local points = rules.endGameBonus.starCompletion[star.starType]
        if star:isFull() and points then
            table.insert(bonuses, { kind = EndGameBonus.KIND.STAR, starIdx = starIdx, starType = star.starType, points = points })
        end
    end

    for _, value in ipairs(numberValues(rules)) do
        local slots = {}
        local covered = true
        for starIdx, star in ipairs(stars) do
            for slotIdx = 1, star:numSlots() do
                if star:slotIndexToCost(slotIdx) == value then
                    table.insert(slots, { starIdx, slotIdx })
                    covered = covered and star:isOccupied(slotIdx)
                end
            end
        end
        if covered and #slots > 0 then
            table.insert(bonuses, { kind = EndGameBonus.KIND.NUMBER, value = value, slots = slots, points = numberPoints(rules, value) })
        end
    end
    return bonuses
end

--- @return integer the sum of \p bonuses' points
function EndGameBonus.total(bonuses)
    local sum = 0
    for _, bonus in ipairs(bonuses) do
        sum = sum + bonus.points
    end
    return sum
end

--- @param rules table GameRules
--- @return table[] bonuses every bonus that can be scored: star types by points (ties in StarType order),
---     then number bonuses in ascending value
function EndGameBonus.reference(rules)
    local bonuses = {}
    local order = {}
    for ii, starType in ipairs(StarType.ORDERED) do
        order[starType] = ii
    end
    for starType, points in pairs(rules.endGameBonus.starCompletion) do
        table.insert(bonuses, { kind = EndGameBonus.KIND.STAR, starType = starType, points = points })
    end
    table.sort(bonuses, function(a, b)
        if a.points ~= b.points then
            return a.points < b.points
        end
        return (order[a.starType] or math.huge) < (order[b.starType] or math.huge)
    end)
    for _, value in ipairs(numberValues(rules)) do
        table.insert(bonuses, { kind = EndGameBonus.KIND.NUMBER, value = value, points = numberPoints(rules, value) })
    end
    return bonuses
end

--- @return string name of a star type for text, eg: "red", "multicolor"
local function starName(starType)
    if starType == StarType.MULTI then
        return "multicolor"
    end
    return string.lower(tostring(starType))
end

--- @return string explanation of a bonus, eg: "Full red star = 14 pts"
function EndGameBonus.describe(bonus)
    if bonus.kind == EndGameBonus.KIND.STAR then
        return "Full " .. starName(bonus.starType) .. " star = " .. bonus.points .. " pts"
    end
    return "Every " .. bonus.value .. " on your board covered = " .. bonus.points .. " pts"
end

return EndGameBonus
