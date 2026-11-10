--- Icons for the bonus spaces on a player mat (MatBonus: pillars, statues, windows, fountains). See
--- docs/bonus_icons.drawio.png for the look.
---
--- Where each icon goes comes from the star polygons (StarView.SLOT_VERTEX_SCALARS), not hand placed
--- coordinates. Two neighboring slots of one star share two vertices: the star's center and one point
--- on the star's outline, its "notch" (the inside corner between the two star points).
---     - a window (2 slots of one star) sits in the V between that star's two points, its flat end
---       toward the notch and its arch pointing away from the star, pushed out just far enough to clear
---       both points
---     - a pillar, statue or fountain (2 slots on each of 2 stars) sits midway between the two stars'
---       notches: in the gap between the stars. A fountain's midpoint is where two outer stars' tips
---       touch, so its icon is pushed out from the mat's center into the open area past them
local ViewUtil = require("cloudless_sky.view.view_util")

local MatBonusView = {}

-- icon sizes and the fountain's offset out of its stars' gap, as a share of the star size
MatBonusView.ICON_SHARE = 0.13
MatBonusView.WINDOW_ICON_SHARE = 0.11
local FOUNTAIN_OUT_SHARE = 0.12
-- the window's pane, as a share of its icon size
local WINDOW_W = 0.6
local WINDOW_H = 0.85
-- gap between the window's flat end and the star's points, as a share of the pane's height
local WINDOW_CLEARANCE = 0.12

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

--- @return number x, number y. The vertex next to the notch (nx, ny) around \p poly that isn't the
---     star's center (cx, cy): the tip of that slot's star point
local function tipBeside(poly, nx, ny, cx, cy)
    local pts = points(poly)
    for ii, p in ipairs(pts) do
        if math.abs(p[1] - nx) < EPSILON and math.abs(p[2] - ny) < EPSILON then
            for _, jj in ipairs({ (ii - 2) % #pts + 1, ii % #pts + 1 }) do
                local q = pts[jj]
                if not (math.abs(q[1] - cx) < EPSILON and math.abs(q[2] - cy) < EPSILON) then
                    return q[1], q[2]
                end
            end
        end
    end
    error("notch isn't a vertex of the slot")
end

--- @return number radians between the vectors (ax, ay) and (bx, by)
local function angleBetween(ax, ay, bx, by)
    local dot = (ax * bx + ay * by) / (math.sqrt(ax * ax + ay * ay) * math.sqrt(bx * bx + by * by))
    return math.acos(math.max(-1, math.min(1, dot)))
end

--- Where a window goes: in the V at the notch between \p starView's slots \p slotA and \p slotB, its
--- flat end toward the notch, pushed out until the pane's bottom corners clear both star points
--- @return number x, number y, number rot. The pane's center and rotation (0 = arch pointing up)
function MatBonusView.windowPlacement(starView, slotA, slotB, size)
    local nx, ny = MatBonusView.notch(starView, slotA, slotB)
    local cx, cy = starView:center()
    local dist = ViewUtil.euclidianDistance(cx, cy, nx, ny)
    local dx, dy = (nx - cx) / dist, (ny - cy) / dist
    -- the V's half angle: the narrower side between the outward direction and either point's edge
    local half = math.huge
    for _, slot in ipairs({ slotA, slotB }) do
        local tx, ty = tipBeside(starView.polys[slot].verticies, nx, ny, cx, cy)
        half = math.min(half, angleBetween(dx, dy, tx - nx, ty - ny))
    end
    local w, h = size * WINDOW_W, size * WINDOW_H
    local out = (w / 2) / math.tan(half) + h * WINDOW_CLEARANCE + h / 2
    -- rotate the pane's "up" (0, -1) onto (dx, dy)
    return nx + dx * out, ny + dy * out, math.atan2(dx, -dy)
end

--- @return table[] {x, y} corners of a window pane drawn at (x, y), \p size, rotated \p rot: bottom
---     left, bottom right, top right, top left (top = the arch's ends)
function MatBonusView.windowCorners(x, y, size, rot)
    local w, h = size * WINDOW_W, size * WINDOW_H
    local corners = {}
    for _, c in ipairs({ { -w / 2, h / 2 }, { w / 2, h / 2 }, { w / 2, -h / 2 }, { -w / 2, -h / 2 } }) do
        local cosR, sinR = math.cos(rot), math.sin(rot)
        table.insert(corners, { x + c[1] * cosR - c[2] * sinR, y + c[1] * sinR + c[2] * cosR })
    end
    return corners
end

--- @param bonus MatBonus the space
--- @param starViews StarView[] the mat's stars, by star index
--- @return number x, number y, number size, number rot. Where the space's icon goes (its center), its
---     size in world units and its rotation (windows face out from their star; 0 for the rest)
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
        local slots = byStar[order[1]]
        local size = starSize * MatBonusView.WINDOW_ICON_SHARE
        local x, y, rot = MatBonusView.windowPlacement(notches[1].star, slots[1], slots[2], size)
        return x, y, size, rot
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
    return x, y, starSize * MatBonusView.ICON_SHARE, 0
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
    local w, h = s * WINDOW_W, s * WINDOW_H
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
    -- an upright block
    shape(function(mode)
        love.graphics.rectangle(mode, cx - s * 0.18, cy - s * 0.42, s * 0.36, s * 0.84)
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
--- @param outlineColor table|nil outline when not achieved (eg: darker, on a light background)
--- @param rot number|nil rotation in radians about the center (0 = upright)
function MatBonusView.drawIcon(kind, cx, cy, size, achieved, outlineColor, rot)
    local draw = DRAW[kind]
    assert(draw, "no icon for bonus kind " .. tostring(kind))
    local outline = achieved and ACHIEVED_OUTLINE_COLOR or outlineColor or OUTLINE_COLOR
    local lineWidth = math.max(1, size * 0.07)
    if rot and rot ~= 0 then
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(rot)
        draw(0, 0, size, outline, lineWidth)
        love.graphics.pop()
    else
        draw(cx, cy, size, outline, lineWidth)
    end
end

return MatBonusView
