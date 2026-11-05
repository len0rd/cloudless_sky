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

notion("TableAreaEntity expanded bonus pool is full size and fits on the table (2-4 players)", function()
    for _, numDisplays in ipairs({ 5, 7, 9 }) do
        for _, poolSize in ipairs({ 5, 10, 20 }) do
            local fake = { worldPos = { x = 0, y = 0 }, viewRng = love.math.newRandomGenerator(1) }
            TableAreaEntity._layout(fake, numDisplays, poolSize)
            local small, big = fake.poolSmall, fake.poolBig
            check(big.scale).is(1)
            local r = fake.bonusPool:radiusAt(1)
            check(big.x - r >= 0 and big.x + r <= TABLE_W and big.y - r >= 0 and big.y + r <= TABLE_H).is(true)

            -- expanding moves smoothly from the corner to the big placement
            local x0, y0, s0 = TableAreaEntity.poolPlacementAt(small, big, 0)
            local x1, y1, s1 = TableAreaEntity.poolPlacementAt(small, big, 1)
            check(x0 == small.x and y0 == small.y and s0 == small.scale).is(true)
            check(x1 == big.x and y1 == big.y and s1 == 1).is(true)
            local _, _, sMid = TableAreaEntity.poolPlacementAt(small, big, 0.5)
            check(sMid > small.scale and sMid < 1).is(true)
        end
    end
end)

notion("BonusPoolView contains points on its disc at its current placement", function()
    local fake = { worldPos = { x = 0, y = 0 }, viewRng = love.math.newRandomGenerator(1) }
    TableAreaEntity._layout(fake, 5, 10)
    local pool, small, big = fake.bonusPool, fake.poolSmall, fake.poolBig
    pool:setPlacement(small.x, small.y, small.scale)
    check(pool:contains(small.x, small.y)).is(true)
    -- a point just outside the small disc, but inside the big one
    local outside = small.x - pool:radiusAt(small.scale) - 5
    check(pool:contains(outside, small.y)).is(false)
    pool:setPlacement(big.x, big.y, big.scale)
    check(pool:contains(outside, small.y)).is(true)
end)

notion("BonusPoolView keeps tiles in their slots as it moves, and frees slots when tiles leave", function()
    local fake = { worldPos = { x = 0, y = 0 }, viewRng = love.math.newRandomGenerator(1) }
    TableAreaEntity._layout(fake, 5, 10)
    local pool = fake.bonusPool
    local red = pool:addTile("RED")
    local blue = pool:addTile("BLUE")
    check(red.slot).is(1)
    check(blue.slot).is(2)
    pool:setPlacement(500, 300, 1)
    local x, y = pool:slotPosition(2)
    check(blue.x).is(x)
    check(blue.y).is(y)
    check(pool:tileAt(blue.x, blue.y) == blue).is(true)

    pool:removeTiles("RED", 1)
    check(pool:counts().RED).is(0)
    -- the freed slot is reused
    check(pool:addTile("GREEN").slot).is(1)
end)
