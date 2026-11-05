local cute = require("cloudless_sky.extern.cute")
local RoundTrackView = require("cloudless_sky.view.round_track_view")
local TableAreaEntity = require("cloudless_sky.entities.table_area_entity")
local ViewUtil = require("cloudless_sky.view.view_util")

-- world size of the table (TableAreaEntity TABLE_W / TABLE_H)
local TABLE_W, TABLE_H = 1200, 800

--- @return boolean True if the rect (x, y, w, h) and the circle overlap
local function rectHitsCircle(x, y, w, h, cx, cy, r)
    local nearX = math.max(x, math.min(cx, x + w))
    local nearY = math.max(y, math.min(cy, y + h))
    return (nearX - cx) ^ 2 + (nearY - cy) ^ 2 < r * r
end

notion("RoundTrackView round track is left to right, one slot per round", function()
    local slots = RoundTrackView.layout(100, 50, 6)
    check(#slots).is(6)
    for ii = 2, #slots do
        check(slots[ii].x > slots[ii - 1].x).is(true)
        check(slots[ii].y).is(slots[1].y)
    end
end)

notion("TableAreaEntity round track fits on the table clear of every display (2-4 players)", function()
    -- 2, 3 and 4 players have 5, 7 and 9 displays
    for _, numDisplays in ipairs({ 5, 7, 9 }) do
        local fake = { worldPos = { x = 0, y = 0 }, viewRng = love.math.newRandomGenerator(1) }
        TableAreaEntity._layout(fake, numDisplays, 10)
        local slots = RoundTrackView.layout(0, 0, 6)

        -- the area the track can cover: every tile at its biggest, plus the label underneath
        local first, last = slots[1], slots[6]
        local grow = first.size * (RoundTrackView.MAX_SCALE - 1) / 2
        local x = first.x - grow
        local y = first.y - grow
        local w = last.x + last.size + grow - x
        local h = math.max(first.y + first.size + grow, first.y + first.size / 2 + RoundTrackView.LABEL_BOTTOM) - y

        check(x >= 0 and y >= 0 and x + w <= TABLE_W and y + h <= TABLE_H).is(true)
        for source, group in pairs(fake.groups) do
            if rectHitsCircle(x, y, w, h, group.x, group.y, group.radius) then
                error(numDisplays .. " displays: round track overlaps tile source " .. source)
            end
        end
    end
end)

notion("TableAreaEntity bonus pool sits in the top-right corner clear of every display (2-4 players)", function()
    for _, numDisplays in ipairs({ 5, 7, 9 }) do
        for _, poolSize in ipairs({ 5, 10, 20 }) do
            local fake = { worldPos = { x = 0, y = 0 }, viewRng = love.math.newRandomGenerator(1) }
            TableAreaEntity._layout(fake, numDisplays, poolSize)
            local pool = fake.bonusPool
            local r = pool:radius()
            local what = numDisplays .. " displays, " .. poolSize .. " tile pool: "

            -- on the table, right of the round track
            check(pool.x + r <= TABLE_W and pool.y - r >= 0).is(true)
            local slots = RoundTrackView.layout(0, 0, 6)
            check(pool.x - r > slots[6].x + slots[6].size).is(true)
            -- its tiles are smaller than normal
            check(pool.scale < 1).is(true)
            -- the label under it
            local lx, ly, lw, lh = TableAreaEntity.poolLabelRect(fake)
            check(ly + lh <= TABLE_H).is(true)
            for source, group in pairs(fake.groups) do
                if ViewUtil.euclidianDistance(pool.x, pool.y, group.x, group.y) < r + group.radius then
                    error(what .. "overlaps tile source " .. source)
                end
                if rectHitsCircle(lx, ly, lw, lh, group.x, group.y, group.radius) then
                    error(what .. "its label overlaps tile source " .. source)
                end
            end
        end
    end
end)
