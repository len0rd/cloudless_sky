local cute = require("cloudless_sky.extern.cute")
local TableAreaEntity = require("cloudless_sky.entities.table_area_entity")

-- world size of the table (TableAreaEntity TABLE_W / TABLE_H)
local TABLE_W, TABLE_H = 1200, 800
-- the current round's tile is drawn up to this much bigger, with a marker around it
local MAX_TILE_SCALE = 1.2 * 1.15
-- "Round N of M" label under the track (TableAreaEntity TRACK_LABEL_TOP + TRACK_LABEL_H, from the
-- middle of the track)
local LABEL_BOTTOM = 38 + 24

--- @return boolean True if the rect (x, y, w, h) and the circle overlap
local function rectHitsCircle(x, y, w, h, cx, cy, r)
    local nearX = math.max(x, math.min(cx, x + w))
    local nearY = math.max(y, math.min(cy, y + h))
    return (nearX - cx) ^ 2 + (nearY - cy) ^ 2 < r * r
end

notion("TableAreaEntity round track is left to right, one slot per round", function()
    local slots = TableAreaEntity.roundTrackLayout(100, 50, 6)
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
        TableAreaEntity._layout(fake, numDisplays, 6)

        -- the area the track can cover: every tile at its biggest, plus the label underneath
        local first, last = fake.roundTrack[1], fake.roundTrack[6]
        local grow = first.size * (MAX_TILE_SCALE - 1) / 2
        local x = first.x - grow
        local y = first.y - grow
        local w = last.x + last.size + grow - x
        local h = math.max(first.y + first.size + grow, first.y + first.size / 2 + LABEL_BOTTOM) - y

        check(x >= 0 and y >= 0 and x + w <= TABLE_W and y + h <= TABLE_H).is(true)
        for source, group in pairs(fake.groups) do
            if rectHitsCircle(x, y, w, h, group.x, group.y, group.radius) then
                error(numDisplays .. " displays: round track overlaps tile source " .. source)
            end
        end
    end
end)
