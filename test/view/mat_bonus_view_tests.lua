local cute = require("cloudless_sky.extern.cute")
local GameRules = require("cloudless_sky.model.game_rules")
local MatBonus = require("cloudless_sky.model.mat_bonus")
local MatBonusView = require("cloudless_sky.view.mat_bonus_view")
local PlayerMatEntity = require("cloudless_sky.entities.player_mat_entity")
local StarView = require("cloudless_sky.view.star_view")
local ViewUtil = require("cloudless_sky.view.view_util")

local MAT_SIZE = 600

--- @return table rules: a copy of the Base rules with every bonus kind enabled
local allEnabled = function()
    local rules = table.copy(GameRules.DEFAULTS.BASE_GAME_RULES)
    rules.bonusSurrounds.enabled.fountain = true
    rules.bonusSurrounds.bonusValueTiles.fountain = 2
    return rules
end

local newMat = function(rules)
    return PlayerMatEntity.new(1, MAT_SIZE, GameRules.matStarTypes(rules), rules)
end

notion("MatBonusView.notch: two neighboring slots' shared corner on the star outline", function()
    local view = StarView("RED", 0, 0, 60)
    -- slots 1 and 2 meet at (4/6, 1/4) of the star
    local x, y = MatBonusView.notch(view, 1, 2)
    check(math.abs(x - 40) < 0.01 and math.abs(y - 15) < 0.01).is(true)
    -- slots 3 and 4 at (4/6, 3/4)
    x, y = MatBonusView.notch(view, 4, 3)
    check(math.abs(x - 40) < 0.01 and math.abs(y - 45) < 0.01).is(true)
    -- not neighbors
    check(MatBonusView.notch(view, 1, 4) == nil).is(true)
end)

notion("Bonus icons: Base rules show pillars, statues and windows; fountains only when enabled", function()
    local base = GameRules.DEFAULTS.BASE_GAME_RULES
    local icons = newMat(base).bonusIcons
    check(#icons).is(18)
    for _, icon in ipairs(icons) do
        check(icon.kind ~= MatBonus.KIND.FOUNTAIN).is(true)
    end
    check(#newMat(allEnabled()).bonusIcons).is(24)
    check(#PlayerMatEntity.bonusIconsFor(nil, newMat(base).stars)).is(0)
end)

notion("Bonus icons sit in the gaps: off every slot, on the mat, and apart from each other", function()
    local mat = newMat(allEnabled())
    local box = { x = mat.worldPos.x, y = mat.worldPos.y, w = mat.boundingBox.w, h = mat.boundingBox.h }
    local icons = mat.bonusIcons
    for _, icon in ipairs(icons) do
        local what = icon.kind .. " " .. icon.bonusIdx
        for starIdx, star in ipairs(mat.stars) do
            for slotIdx, poly in ipairs(star.polys) do
                if ViewUtil.ptInConvexPoly(poly.verticies, icon.x, icon.y) then
                    error(what .. " is on star " .. starIdx .. " slot " .. slotIdx)
                end
            end
        end
        local margin = icon.size
        if icon.x < box.x - margin or icon.x > box.x + box.w + margin or icon.y < box.y - margin or icon.y > box.y + box.h + margin then
            error(what .. " is off the mat")
        end
    end
    for ii = 1, #icons do
        for jj = ii + 1, #icons do
            local a, b = icons[ii], icons[jj]
            if ViewUtil.euclidianDistance(a.x, a.y, b.x, b.y) < (a.size + b.size) / 2 then
                error(a.kind .. " " .. a.bonusIdx .. " overlaps " .. b.kind .. " " .. b.bonusIdx)
            end
        end
    end
end)

notion("PlayerMatEntity.bonusAt finds each icon at its center and nothing on a slot", function()
    local mat = newMat(allEnabled())
    for _, icon in ipairs(mat.bonusIcons) do
        check(mat:bonusAt(icon.x, icon.y) == icon).is(true)
    end
    for _, star in ipairs(mat.stars) do
        for slotIdx = 1, 6 do
            check(mat:bonusAt(star:centerOfSlot(slotIdx)) == nil).is(true)
        end
    end
end)

notion("BonusInfoDialogEntity text: the reward, the slots to fill and progress", function()
    local BonusInfoDialogEntity = require("cloudless_sky.entities.bonus_info_dialog_entity")
    local text, achieved = BonusInfoDialogEntity.lines({ kind = "statue", tiles = 2, filled = 1, total = 4 })
    check(text.title).is("Statue")
    check(text.reward).is("Pick up 2 bonus tiles")
    check(text.instruction).is("Fill the 4 outlined slots")
    check(text.progress).is("1 / 4 filled")
    check(achieved).is(false)
    text, achieved = BonusInfoDialogEntity.lines({ kind = "pillar", tiles = 1, filled = 4, total = 4 })
    check(text.reward).is("Pick up 1 bonus tile")
    check(text.progress).is("Achieved!")
    check(achieved).is(true)
end)

notion("Windows sit between their two points, arch out from the star, and the pane clears every slot", function()
    local mat = newMat(allEnabled())
    for _, icon in ipairs(mat.bonusIcons) do
        if icon.kind == "window" then
            local slots = GameRules.DEFAULTS.BASE_GAME_RULES.bonusSurrounds.spaces[icon.bonusIdx].slots
            local star = mat.stars[slots[1][1]]
            local nx, ny = MatBonusView.notch(star, slots[1][2], slots[2][2])
            local cx, cy = star:center()
            -- the arch ("up" rotated by rot) points the same way as star center -> notch
            local upX, upY = math.sin(icon.rot), -math.cos(icon.rot)
            local outX, outY = nx - cx, ny - cy
            check((upX * outX + upY * outY) / math.sqrt(outX * outX + outY * outY) > 0.99).is(true)
            -- further out than the notch
            check(ViewUtil.euclidianDistance(cx, cy, icon.x, icon.y) > ViewUtil.euclidianDistance(cx, cy, nx, ny)).is(true)
            for _, corner in ipairs(MatBonusView.windowCorners(icon.x, icon.y, icon.size, icon.rot)) do
                for starIdx, view in ipairs(mat.stars) do
                    for slotIdx, poly in ipairs(view.polys) do
                        if ViewUtil.ptInConvexPoly(poly.verticies, corner[1], corner[2]) then
                            error("window " .. icon.bonusIdx .. " corner is on star " .. starIdx .. " slot " .. slotIdx)
                        end
                    end
                end
            end
        else
            check(icon.rot).is(0)
        end
    end
end)
