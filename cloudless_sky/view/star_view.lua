-- Draw a tile star
local Object = require("cloudless_sky.extern.classic")
local StarView = Object:extend()
local StarType = require("cloudless_sky.model.star_type")

local transformScalerVertices = function(vertices, x, y, size)
    local scaledVertices = {}
    for ii = 1, #vertices, 2 do
        scaledVertices[ii] = (vertices[ii] * size) + x
        scaledVertices[ii + 1] = (vertices[ii + 1] * size) + y
    end
    return scaledVertices
end

-- Helper: checks if point (px, py) is on the left side of the edge (ax, ay) -> (bx, by)
local function isLeft(ax, ay, bx, by, px, py)
    return ((bx - ax) * (py - ay) - (by - ay) * (px - ax)) >= 0
end

--- @param vertices table A table of alternating between the 4 x,y points that make up the quadrilateral
---     Should start with the minx,miny point (preference to minY), then rotate clockwise to the other points
--- @return boolean pointInQuad true if (px, py) is inside the convex quadrilateral
local function isPointInConvexQuad(vertices, px, py)
    return isLeft(vertices[1], vertices[2], vertices[3], vertices[4], px, py)
        and isLeft(vertices[3], vertices[4], vertices[5], vertices[6], px, py)
        and isLeft(vertices[5], vertices[6], vertices[7], vertices[8], px, py)
        and isLeft(vertices[7], vertices[8], vertices[1], vertices[2], px, py)
end

-- stylua: ignore start
-- defines where the vertex for each slot in the star is placed as a scaler that can be
-- applied to the overall size to get exact coords
-- POINTS MUST BE ORDERED CLOCKWISE. To be consistent, start with Xmin,Ymin. Then move around each point clockwise
-- These should be ordered so the indices match the Star Slot indicies used in model/star.lua
StarView.SLOT_VERTEX_SCALARS = {
    [1] = {
        1/2, 0,
        4/6, 1/4,
        1/2, 1/2,
        2/6, 1/4,
    },
    [2] = {
        4/6, 1/4,
        1, 1/4,
        5/6, 1/2,
        1/2, 1/2,
    },
    [3] = {
        1/2, 1/2,
        5/6, 1/2,
        1, 3/4,
        4/6, 3/4,
    },
    [4] = {
        1/2, 1/2,
        4/6, 3/4,
        1/2, 1,
        2/6, 3/4,
    },
    [5] = {
        1/6, 1/2,
        1/2, 1/2,
        2/6, 3/4,
        0, 3/4,
    },
    [6] = {
        0, 1/4,
        2/6, 1/4,
        1/2, 1/2,
        1/6, 1/2
    }
}
-- stylua: ignore end

--- @param x integer Left-most X coord of the stars rectangular bounding box
--- @param y integer Top-most Y coord of the stars rectangular bounding box
--- @param size integer Overall width and height of stars rectangular bounding box. Always square
function StarView:new(starType, x, y, size)
    self.star_origin_x = x
    self.star_origin_y = y
    self.size = size
    -- define the vertices of the 6 polygons that compose the star
    self.polys = {}
    -- set to the slot index that a pointer is hovering over on update
    self.hovered_slot = 0
    for ii, vertices in ipairs(StarView.SLOT_VERTEX_SCALARS) do
        self.polys[ii] = transformScalerVertices(vertices, self.star_origin_x, self.star_origin_y, self.size)
    end
end

--- Given an x,y coordinate, return what star slot index the coordinate is in
--- Or 0 if it is not in one
function StarView:coordSlotIndex(x, y)
    if not self:coordInBoundingBox(x, y) then
        return 0
    end
    for ii, vertices in ipairs(self.polys) do
        if isPointInConvexQuad(vertices, x, y) then
            return ii
        end
    end
    -- point is within the overall bounding box, but not in a specific Slot's poly
    return 0
end

--- @return boolean inBounds. True if x,y are within the overall bounding box of this star, otherwise false
function StarView:coordInBoundingBox(x, y)
    if
        x < self.star_origin_x
        or x > (self.star_origin_x + self.size)
        or y < self.star_origin_y
        or y > (self.star_origin_y + self.size)
    then
        return false
    end
    return true
end

function StarView:isOnStar(x, y) end

function StarView:update(mouseX, mouseY)
    -- reset hovered state
    self.hovered_slot = self:coordSlotIndex(mouseX, mouseY)
end

function StarView:draw()
    local origR, origG, origB, origA = love.graphics.getColor()

    local colors = {
        [1] = { 255, 255, 255 },
        [2] = { 255, 0, 0 },
        [3] = { 0, 255, 0 },
        [4] = { 0, 0, 255 },
        [5] = { 255, 255, 255 },
        [6] = { 28, 94, 83 },
    }

    for ii, vertices in ipairs(StarView.SLOT_VERTEX_SCALARS) do
        local scaledVertices = transformScalerVertices(vertices, self.star_origin_x, self.star_origin_y, self.size)
        local color = colors[ii]
        if self.hovered_slot == ii then
            -- slot is currently being hovered over.
            color = { 255, 251, 0 }
        end
        love.graphics.setColor(love.math.colorFromBytes(color[1], color[2], color[3]))
        love.graphics.polygon("fill", scaledVertices)
    end

    -- reset color at the end
    love.graphics.setColor(origR, origG, origB, origA)
end

--- Draw a star as one big polygon instead of multiple individual
function drawOverallStar(x, y, size)
    local half = size / 2
    local oneQuarter = size / 4
    local oneSixth = size / 6
    local twoSixth = 2 * oneSixth
    local fourSixth = 4 * oneSixth
    local fiveSixth = 5 * oneSixth
    local threeQuarter = half + oneQuarter

    local origR, origG, origB, origA = love.graphics.getColor()

    -- stylua: ignore start
    local vertices = {
        0, oneQuarter,
        twoSixth, oneQuarter,
        half, 0,
        fourSixth, oneQuarter,
        size, oneQuarter,
        fiveSixth, half,
        size, threeQuarter,
        fourSixth, threeQuarter,
        half, size,
        twoSixth, threeQuarter,
        0, threeQuarter,
        oneSixth, half,
    }
    -- stylua: ignore end
    vertices = makeRelativeTo(x, y, vertices)

    love.graphics.setColor(love.math.colorFromBytes(28, 94, 83))
    -- note the star shape is not convex, so it will not render correctly in "fill" mode
    -- TODO: is there another option for drawing/filling more complex polygons like this?
    love.graphics.polygon("line", vertices)

    -- reset color at the end
    love.graphics.setColor(origR, origG, origB, origA)
end

return StarView
