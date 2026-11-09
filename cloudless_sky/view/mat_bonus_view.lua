--- Icons for the bonus spaces on a player mat (MatBonus: pillars, statues, windows, fountains). See
--- docs/bonus_icons.drawio.png for the look.
---
--- Where each icon goes comes from the star polygons (StarView.SLOT_VERTEX_SCALARS), not hand placed
--- coordinates. Two neighboring slots of one star share two vertices: the star's center and one point
--- on the star's outline, its "notch" (the inside corner between the two star points).
---     - a window (2 slots of one star) sits just outside that star's notch
---     - a pillar, statue or fountain (2 slots on each of 2 stars) sits midway between the two stars'
---       notches: in the gap between the stars. A fountain's midpoint is where two outer stars' tips
---       touch, so its icon is pushed out from the mat's center into the open area past them
local ViewUtil = require("cloudless_sky.view.view_util")

local MatBonusView = {}

-- icon sizes and the window's offset out of its notch, as a share of the star size
MatBonusView.ICON_SHARE = 0.16
MatBonusView.WINDOW_ICON_SHARE = 0.15
local WINDOW_OUT_SHARE = 0.08
local FOUNTAIN_OUT_SHARE = 0.12

local FILL_COLOR = { 0.85, 0.9, 0.98, 1 }
local OUTLINE_COLOR = { 0.86, 0.86, 0.86, 1 }
local ACHIEVED_OUTLINE_COLOR = { 1, 0.84, 0.3, 1 }
-- shared vertices closer than this (world units) are the same point
local EPSILON = 0.01

--- @return table[] {x, y} vertices of \p poly (flat {x1, y1, x2, y2...})
local function points(poly)
    local result = {}
    for ii = 1, #poly, 2 do
        table.insert(result, { poly[ii], poly[ii + 1] })
    end
    return result
end

--- @param starView StarView
--- @return number|nil x, number|nil y. The vertex slots \p slotA and \p slotB share on the star's outline
---     (not the star's center). nil if the slots aren't neighbors
function MatBonusView.notch(starView, slotA, slotB)
    local cx, cy = starView:center()
    for _, a in ipairs(points(starView.polys[slotA].verticies)) do
        local isCenter = math.abs(a[1] - cx) < EPSILON and math.abs(a[2] - cy) < EPSILON
        if not isCenter then
            for _, b in ipairs(points(starView.polys[slotB].verticies)) do
                if math.abs(a[1] - b[1]) < EPSILON and math.abs(a[2] - b[2]) < EPSILON then
                    return a[1], a[2]
                end
            end
        end
    end
    return nil, nil
end

--- @param bonus MatBonus the space
--- @param starViews StarView[] the mat's stars, by star index
--- @return number x, number y, number size. Where the space's icon goes (its center) and its size, in
---     world units
function MatBonusView.anchor(bonus, starViews)
    -- the space's slots, by star
    local byStar, order = {}, {}
    for _, slot in ipairs(bonus.slots) do
        if not byStar[slot[1]] then
            byStar[slot[1]] = {}
            table.insert(order, slot[1])
        end
        table.insert(byStar[slot[1]], slot[2])
    end
    local notches = {}
    for _, starIdx in ipairs(order) do
        local slots = byStar[starIdx]
        local x, y = MatBonusView.notch(starViews[starIdx], slots[1], slots[2])
        assert(x, "bonus " .. tostring(bonus.idx) .. ": star " .. starIdx .. " slots aren't neighbors")
        table.insert(notches, { x = x, y = y, star = starViews[starIdx] })
    end

    local starSize = starViews[order[1]].size
    if #notches == 1 then
        -- just outside the notch, away from the star's center
        local n = notches[1]
        local cx, cy = n.star:center()
        local dist = ViewUtil.euclidianDistance(cx, cy, n.x, n.y)
        local out = starSize * WINDOW_OUT_SHARE
        return n.x + (n.x - cx) / dist * out, n.y + (n.y - cy) / dist * out, starSize * MatBonusView.WINDOW_ICON_SHARE
    end
    local a, b = notches[1], notches[2]
    local x, y = (a.x + b.x) / 2, (a.y + b.y) / 2
    if bonus.kind == "fountain" then
        -- away from the mat's center (the middle of all its stars)
        local mx, my = 0, 0
        for _, view in ipairs(starViews) do
            local cx, cy = view:center()
            mx, my = mx + cx / #starViews, my + cy / #starViews
        end
        local dist = ViewUtil.euclidianDistance(mx, my, x, y)
        local out = starSize * FOUNTAIN_OUT_SHARE
        x, y = x + (x - mx) / dist * out, y + (y - my) / dist * out
    end
    return x, y, starSize * MatBonusView.ICON_SHARE
end

--------------------------------------------------------------------------------
-- drawing
--------------------------------------------------------------------------------

--- fill \p fn's shape, then outline it
local function shape(fn, outline, lineWidth)
    love.graphics.setColor(FILL_COLOR)
    fn("fill")
    love.graphics.setColor(outline)
    love.graphics.setLineWidth(lineWidth)
    fn("line")
end

local DRAW = {}

function DRAW.pillar(cx, cy, s, outline, lw)
    shape(function(mode)
        love.graphics.circle(mode, cx, cy, s * 0.4)
    end, outline, lw)
end

function DRAW.window(cx, cy, s, outline, lw)
    local w, h = s * 0.6, s * 0.85
    local left, top = cx - w / 2, cy - h / 2
    local r = w / 2
    -- an arched pane: a half circle on a rectangle
    local outlinePts = { left, top + h, left, top + r }
    for ii = 0, 12 do
        local angle = math.pi + ii * math.pi / 12
        table.insert(outlinePts, cx + math.cos(angle) * r)
        table.insert(outlinePts, top + r + math.sin(angle) * r)
    end
    table.insert(outlinePts, left + w)
    table.insert(outlinePts, top + h)
    love.graphics.setColor(FILL_COLOR)
    love.graphics.rectangle("fill", left, top + r, w, h - r)
    love.graphics.arc("fill", cx, top + r, r, math.pi, 2 * math.pi)
    love.graphics.setColor(outline)
    love.graphics.setLineWidth(lw)
    love.graphics.polygon("line", outlinePts)
    -- crossbar
    love.graphics.line(left, top + r, left + w, top + r)
end

function DRAW.statue(cx, cy, s, outline, lw)
    -- a flat diamond base with an upright block standing on it
    local baseY = cy + s * 0.22
    shape(function(mode)
        love.graphics.polygon(mode, cx - s * 0.48, baseY, cx, baseY - s * 0.2, cx + s * 0.48, baseY, cx, baseY + s * 0.2)
    end, outline, lw)
    shape(function(mode)
        love.graphics.rectangle(mode, cx - s * 0.14, cy - s * 0.48, s * 0.28, s * 0.66)
    end, outline, lw)
end

function DRAW.fountain(cx, cy, s, outline, lw)
    -- a triangular base, a wide bowl on it and a dome on top
    shape(function(mode)
        love.graphics.polygon(mode, cx - s * 0.45, cy + s * 0.42, cx + s * 0.45, cy + s * 0.42, cx, cy - s * 0.05)
    end, outline, lw)
    shape(function(mode)
        love.graphics.ellipse(mode, cx, cy + s * 0.05, s * 0.32, s * 0.17)
    end, outline, lw)
    shape(function(mode)
        love.graphics.ellipse(mode, cx, cy - s * 0.17, s * 0.2, s * 0.15)
    end, outline, lw)
end

--- Draw the icon for a \p kind (MatBonus.KIND) bonus space centered at (cx, cy), \p size across
--- @param achieved boolean|nil the space is achieved: drawn with a gold outline
function MatBonusView.drawIcon(kind, cx, cy, size, achieved)
    local draw = DRAW[kind]
    assert(draw, "no icon for bonus kind " .. tostring(kind))
    local outline = achieved and ACHIEVED_OUTLINE_COLOR or OUTLINE_COLOR
    draw(cx, cy, size, outline, math.max(1, size * 0.07))
end

return MatBonusView
