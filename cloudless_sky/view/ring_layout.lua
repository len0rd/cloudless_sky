--- Lays out n tiles in concentric rings, for a tidy circular cluster of any size (eg: the bonus pool).
--- Tiles point outward like petals. Positions are offsets from the cluster's center in units of tile
--- size (a tile is 1 tall, 2/3 wide), so the same layout can be drawn at any scale.
---
---     - up to SINGLE_RING_MAX tiles: one ring, its radius growing with n
---     - more: rings at fixed radii (fewest that fit), tiles shared between them in proportion to
---       their circumference. Alternate rings are rotated half a step so tiles don't line up
local ViewUtil = require("cloudless_sky.view.view_util")

local RingLayout = {}

-- center to center distance between neighbors on a ring
RingLayout.SPACING = 0.72
-- one ring for this many tiles or fewer
local SINGLE_RING_MAX = 12
-- smallest single ring radius (keeps a few tiles from crowding the middle)
local MIN_RADIUS = 0.6
-- multiple rings: the inner ring's radius, and the distance between rings (a tile is 1 long)
local INNER_RADIUS = 0.75
local RING_GAP = 1.05
-- the first tile of the outer ring is at the top
local START_ANGLE = -math.pi / 2

--- @return integer how many tiles fit on a ring of radius \p r
local function capacity(r)
    return math.floor(2 * math.pi * r / RingLayout.SPACING)
end

--- @return number[] radii ring radii (inner first)
--- @return integer[] counts tiles on each ring
local function rings(n)
    if n <= SINGLE_RING_MAX then
        return { math.max(MIN_RADIUS, n * RingLayout.SPACING / (2 * math.pi)) }, { n }
    end
    -- fewest rings that fit
    local radii, total = {}, 0
    while total < n do
        local r = INNER_RADIUS + #radii * RING_GAP
        table.insert(radii, r)
        total = total + capacity(r)
    end
    -- share in proportion to circumference (inner rings first), capped by each ring's capacity.
    -- What's left over goes to the outer rings
    local sumR = 0
    for _, r in ipairs(radii) do
        sumR = sumR + r
    end
    local counts, placed = {}, 0
    for ii, r in ipairs(radii) do
        counts[ii] = math.min(capacity(r), math.floor(n * r / sumR + 0.5))
        placed = placed + counts[ii]
    end
    for ii = #radii, 1, -1 do
        local extra = math.min(capacity(radii[ii]) - counts[ii], n - placed)
        counts[ii] = counts[ii] + extra
        placed = placed + extra
    end
    -- rounding may have given out too many: take them back from the inner rings
    for ii = 1, #radii do
        local over = math.min(counts[ii], placed - n)
        counts[ii] = counts[ii] - over
        placed = placed - over
    end
    return radii, counts
end

--- @param n integer number of tiles
--- @return table[] slots {x, y, rot} for each tile: its center as an offset from the cluster's center,
---     and its rotation (pointing away from the center). Outer ring first, clockwise from the top
--- @return number radius distance from the center to the furthest tile's tip
function RingLayout.slots(n)
    local slots = {}
    if n <= 0 then
        return slots, 0
    end
    local radii, counts = rings(n)
    for ii = #radii, 1, -1 do
        local count = counts[ii]
        local offset = ((#radii - ii) % 2 == 1) and math.pi / math.max(1, count) or 0
        for _, point in ipairs(ViewUtil.pointsOnCircle(0, 0, radii[ii], count, START_ANGLE + offset)) do
            -- a tile at rot 0 points up (see TileView.betterPolyVerticies): turn it to point outward
            table.insert(slots, { x = point.x, y = point.y, rot = point.angle + math.pi / 2 })
        end
    end
    -- half a tile beyond the outer ring
    return slots, radii[#radii] + 0.5
end

return RingLayout
