local cute = require("cloudless_sky.extern.cute")
local BonusReferenceState = require("cloudless_sky.states.bonus_reference_state")
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local GameRules = require("cloudless_sky.model.game_rules")
local ViewUtil = require("cloudless_sky.view.view_util")

local function inside(inner, outer)
    return inner.x >= outer.x and inner.y >= outer.y and inner.x + inner.w <= outer.x + outer.w and inner.y + inner.h <= outer.y + outer.h
end

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

notion("BonusReferenceState.computeLayout fits every bonus in the centered panel without overlaps", function()
    local bonuses = EndGameBonus.reference(GameRules.DEFAULTS.BASE_GAME_RULES)
    for _, size in ipairs({ { 1280, 720 }, { 1920, 1080 }, { 800, 900 } }) do
        local w, h = size[1], size[2]
        local layout = BonusReferenceState.computeLayout(bonuses, w, h)
        local p = layout.panel
        check(#layout.items).is(#bonuses)
        check(#layout.sections).is(2)
        -- centered
        check(math.abs((p.x + p.w / 2) - w / 2) <= 1).is(true)
        check(math.abs((p.y + p.h / 2) - h / 2) <= 1).is(true)
        check(inside(layout.back, p)).is(true)
        for ii, item in ipairs(layout.items) do
            check(item.bonus == bonuses[ii]).is(true)
            check(inside(item.rect, p)).is(true)
            check(overlap(item.rect, layout.back)).is(false)
            for jj = ii + 1, #layout.items do
                check(overlap(item.rect, layout.items[jj].rect)).is(false)
            end
        end
    end
end)

notion("BonusReferenceState.itemAt finds the bonus under a point", function()
    local bonuses = EndGameBonus.reference(GameRules.DEFAULTS.BASE_GAME_RULES)
    local layout = BonusReferenceState.computeLayout(bonuses, 1280, 720)
    for ii, item in ipairs(layout.items) do
        local r = item.rect
        check(BonusReferenceState.itemAt(layout, r.x + r.w / 2, r.y + r.h / 2)).is(ii)
    end
    -- the title isn't a bonus
    local t = layout.title
    check(BonusReferenceState.itemAt(layout, t.x + t.w / 2, t.y + t.h / 2)).is(nil)
    check(ViewUtil.ptInRect(0, 0, layout.panel.x, layout.panel.y, layout.panel.w, layout.panel.h)).is(false)
end)
