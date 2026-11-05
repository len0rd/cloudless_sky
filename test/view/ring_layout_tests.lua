local cute = require("cloudless_sky.extern.cute")
local RingLayout = require("cloudless_sky.view.ring_layout")
local ViewUtil = require("cloudless_sky.view.view_util")

--- @return number distance between the closest two slots
local function closestPair(slots)
    local closest = math.huge
    for ii = 1, #slots do
        for jj = ii + 1, #slots do
            closest = math.min(closest, ViewUtil.euclidianDistance(slots[ii].x, slots[ii].y, slots[jj].x, slots[jj].y))
        end
    end
    return closest
end

--- @return integer number of distinct distances from the center (rings)
local function numRings(slots)
    local radii = {}
    for _, slot in ipairs(slots) do
        local r = math.floor(ViewUtil.euclidianDistance(slot.x, slot.y, 0, 0) * 1000 + 0.5)
        radii[r] = true
    end
    local count = 0
    for _ in pairs(radii) do
        count = count + 1
    end
    return count
end

notion("RingLayout gives every tile a slot, spaced apart, inside the radius (5-20 tiles)", function()
    for n = 5, 20 do
        local slots, radius = RingLayout.slots(n)
        check(#slots).is(n)
        -- neighbors don't overlap (a tile is 2/3 wide; the chord is a little shorter than the arc)
        if closestPair(slots) < 0.68 then
            error(n .. " tiles: closest pair is " .. closestPair(slots) .. " apart")
        end
        for _, slot in ipairs(slots) do
            if ViewUtil.euclidianDistance(slot.x, slot.y, 0, 0) + 0.5 > radius + 1e-9 then
                error(n .. " tiles: a slot reaches past the radius " .. radius)
            end
        end
    end
end)

notion("RingLayout uses one ring for a few tiles, more rings for many", function()
    for n = 5, 8 do
        check(numRings(RingLayout.slots(n))).is(1)
    end
    check(numRings(RingLayout.slots(20))).is(2)
    -- more tiles never make a smaller cluster
    local _, r5 = RingLayout.slots(5)
    local _, r10 = RingLayout.slots(10)
    local _, r20 = RingLayout.slots(20)
    check(r5 <= r10 and r10 <= r20).is(true)
end)

notion("RingLayout is repeatable and points tiles outward", function()
    local a = RingLayout.slots(13)
    local b = RingLayout.slots(13)
    for ii, slot in ipairs(a) do
        check(slot.x).is(b[ii].x)
        check(slot.y).is(b[ii].y)
        -- rot 0 points up; a slot's rotation turns "up" to point from the center through the slot
        local dirX, dirY = math.sin(slot.rot), -math.cos(slot.rot)
        local len = ViewUtil.euclidianDistance(slot.x, slot.y, 0, 0)
        check(math.abs(dirX - slot.x / len) < 1e-9 and math.abs(dirY - slot.y / len) < 1e-9).is(true)
    end
    check(#RingLayout.slots(0)).is(0)
end)
