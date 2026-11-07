local cute = require("cloudless_sky.extern.cute")
local GameRules = require("cloudless_sky.model.game_rules")
local MatBonus = require("cloudless_sky.model.mat_bonus")
local PlayerMat = require("cloudless_sky.model.player_mat")
local TileType = require("cloudless_sky.model.tile_type")

local SPACES = GameRules.DEFAULTS.BASE_GAME_RULES.bonusSurrounds.spaces

--- @return PlayerMat a fresh mat with \p rules' stars and bonus spaces (default: Base)
local newMat = function(rules)
    rules = rules or GameRules.DEFAULTS.BASE_GAME_RULES
    return PlayerMat(rules.playerMat.stars, rules.bonusSurrounds.spaces)
end

--- Place any allowed tile in (starIdx, slotIdx)
--- @return table events from PlayerMat:placeTile
local fill = function(mat, starIdx, slotIdx)
    local star = mat:getStar(starIdx)
    for _, tileType in ipairs(TileType.ORDERED) do
        if star:isTileTypeAllowedInSlot(tileType, slotIdx) then
            return mat:placeTile(tileType, starIdx, slotIdx)
        end
    end
    error("no tile fits star " .. starIdx .. " slot " .. slotIdx)
end

--- @return table events of filling every slot of bonus \p bonusIdx (the last placement's events)
local fillBonus = function(mat, bonusIdx)
    local events
    for _, slot in ipairs(SPACES[bonusIdx].slots) do
        if not mat:isOccupied(slot[1], slot[2]) then
            events = fill(mat, slot[1], slot[2])
        end
    end
    return events
end

--- @return integer[] events[2..n]: the bonus indices
local bonusEvents = function(events)
    local result = {}
    for ii = 2, #events do
        result[#result + 1] = events[ii]
    end
    return table.concat(result, ",")
end

notion("Mat bonus spaces: 6 of each kind, every slot real, no slot listed twice in a space", function()
    local counts = {}
    for ii, space in ipairs(SPACES) do
        counts[space.kind] = (counts[space.kind] or 0) + 1
        check(MatBonus.LABEL[space.kind] ~= nil).is(true)
        local seen = {}
        for _, slot in ipairs(space.slots) do
            check(slot[1] >= 1 and slot[1] <= 7 and slot[2] >= 1 and slot[2] <= 6).is(true)
            local key = slot[1] .. "." .. slot[2]
            if seen[key] then
                error("space " .. ii .. " lists " .. key .. " twice")
            end
            seen[key] = true
        end
        check(#space.slots).is(space.kind == "window" and 2 or 4)
    end
    for _, kind in pairs(MatBonus.KIND) do
        check(counts[kind]).is(6)
    end
end)

notion("Windows sit on an outer star's cost 5 and 6 slots (both presets), fountains on cost 6,1 and the next star's 4,5 (Base)", function()
    for _, preset in ipairs(GameRules.PRESETS) do
        local stars = preset.rules.playerMat.stars
        local cost = function(slot)
            return stars[slot[1]].cost[slot[2]]
        end
        for _, space in ipairs(preset.rules.bonusSurrounds.spaces) do
            if space.kind == "window" then
                local a, b = cost(space.slots[1]), cost(space.slots[2])
                check(math.min(a, b) == 5 and math.max(a, b) == 6).is(true)
            elseif space.kind == "fountain" and preset.id == "base" then
                -- (the layout is by position on the mat: Mono Stars costs are ordered differently)
                local s = space.slots
                check(s[1][1] == s[2][1] and s[3][1] == s[4][1] and s[1][1] ~= s[3][1]).is(true)
                local first = { cost(s[1]), cost(s[2]) }
                local second = { cost(s[3]), cost(s[4]) }
                table.sort(first)
                table.sort(second)
                check(first[1] == 1 and first[2] == 6).is(true)
                check(second[1] == 4 and second[2] == 5).is(true)
            end
        end
    end
end)

notion("PlayerMat reports a bonus once its last slot is filled, as a placement event", function()
    local mat = newMat()
    check(#mat.bonuses).is(24)
    -- window 13: star 1 slots 1 and 6
    check(bonusEvents(fill(mat, 1, 1))).is("")
    check(#mat:achievedBonuses()).is(0)
    check(bonusEvents(fill(mat, 1, 6))).is("13")
    check(table.concat(mat:achievedBonuses(), ",")).is("13")
    check(mat:bonusAt(13).kind).is("window")
    check(mat:bonusAt(13):isAchieved(mat)).is(true)
end)

notion("PlayerMat: one placement can complete several bonuses", function()
    local mat = newMat()
    -- statue 7 (1.2 1.3 2.5 2.6) and fountain 19 (1.1 1.2 2.1 2.6) share 1.2 and 2.6. Window 13
    -- (1.1 1.6) shares 1.1
    for _, slot in ipairs({ { 1, 3 }, { 2, 5 }, { 2, 6 }, { 1, 1 }, { 2, 1 }, { 1, 6 } }) do
        fill(mat, slot[1], slot[2])
    end
    check(table.concat(mat:achievedBonuses(), ",")).is("13")
    check(table.concat(mat:possibleEventsForPlacement(1, 2), ",", 2)).is("7,19")
    check(bonusEvents(fill(mat, 1, 2))).is("7,19")
    check(table.concat(mat:achievedBonuses(), ",")).is("7,13,19")
end)

notion("PlayerMat: removing a tile un-achieves its bonuses", function()
    local mat = newMat()
    fillBonus(mat, 1)
    check(table.concat(mat:achievedBonuses(), ",")).is("1")
    mat:removeTile(7, 1)
    check(#mat:achievedBonuses()).is(0)
    check(#mat:bonusesCompletedBy(1, 3)).is(0)
end)

notion("PlayerMat possible events: none for an occupied slot or bad index, a bonus only on its last slot", function()
    local mat = newMat()
    check(#mat:possibleEventsForPlacement(9, 1)).is(0)
    check(#mat:possibleEventsForPlacement(1, 1)).is(1)
    fill(mat, 1, 1)
    check(bonusEvents(mat:possibleEventsForPlacement(1, 6))).is("13")
    -- already filled: the score only
    check(#mat:possibleEventsForPlacement(1, 1)).is(1)
end)

notion("PlayerMat with no bonus spaces (rules without them) has no bonuses", function()
    local mat = PlayerMat(GameRules.DEFAULTS.BASE_GAME_RULES.playerMat.stars)
    check(#mat.bonuses).is(0)
    check(#fill(mat, 1, 1)).is(1)
end)

notion("GameRules.bonusTiles: the kind's value, 0 when disabled", function()
    local rules = GameRules.DEFAULTS.BASE_GAME_RULES
    check(GameRules.bonusTiles(rules, "pillar")).is(1)
    check(GameRules.bonusTiles(rules, "statue")).is(2)
    check(GameRules.bonusTiles(rules, "window")).is(3)
    check(GameRules.bonusTiles(rules, "fountain")).is(0)
    local copy = table.copy(rules)
    copy.bonusSurrounds.enabled.window = false
    check(GameRules.bonusTiles(copy, "window")).is(0)
end)
