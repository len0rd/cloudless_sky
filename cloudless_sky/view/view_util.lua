-- Some utility functions geared towards the view/display code

local ViewUtil = {}

--- Given a table of RGB colors, return a table of those colors normallized from 0-1
function ViewUtil.normalizeColorTables(colors)
    local normalized = {}
    for ii, color in pairs(colors) do
        local r, g, b = love.math.colorFromBytes(color[1], color[2], color[3])
        normalized[ii] = { r, g, b }
    end
    return normalized
end

function ViewUtil.normalizeColor(color)
    local r, g, b = love.math.colorFromBytes(color[1], color[2], color[3])
    return { r, g, b }
end

function ViewUtil.ptInRect(x, y, rectX, rectY, w, h)
    return x >= rectX and x <= rectX + w and y >= rectY and y <= rectY + h
end

--- Checks if a point (x, y) is inside a circle defined by center (centerX, centerY) and radius
function ViewUtil.ptInCircle(x, y, centerX, centerY, radius)
    local dx = x - centerX
    local dy = y - centerY
    return (dx * dx + dy * dy) <= (radius * radius)
end

-- calculate direct distance between 2 points
function ViewUtil.euclidianDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- Transform X,Y verticies in a flat table by xShift, yShift
--- @param verticies table. List of verticies formatted {x1,y1, x2,y2, x3,y3, ...}
function ViewUtil.shiftVerticies(verticies, xShift, yShift)
    for ii = 1, #verticies, 2 do
        verticies[ii] = verticies[ii] + xShift
        verticies[ii + 1] = verticies[ii + 1] + yShift
    end
    return verticies
end

--- @return number, number, number, number BoundingBox. x,y,w,h of the bounding box
---     made by the provided verticies. x,y is the top left coordinate of the bounding box
function ViewUtil.boundingBoxOfVerticies(verticies)
    local minX, minY = verticies[1], verticies[2]
    local maxX, maxY = verticies[1], verticies[2]
    for i = 3, #verticies, 2 do
        local x, y = verticies[i], verticies[i + 1]
        if x < minX then
            minX = x
        end
        if y < minY then
            minY = y
        end
        if x > maxX then
            maxX = x
        end
        if y > maxY then
            maxY = y
        end
    end
    return minX, minY, maxX - minX, maxY - minY
end

--- @param verticies table. List points that make up the polygon. Rotating between X and Y.
--- @return number centerX, number centerY Center of the provided verticies in x and y
function ViewUtil.centerOfConvexPoly(verticies)
    local minX, minY = verticies[1], verticies[2]
    local maxX, maxY = verticies[1], verticies[2]
    for ii = 3, #verticies, 2 do
        local x, y = verticies[ii], verticies[ii + 1]
        if x < minX then
            minX = x
        end
        if y < minY then
            minY = y
        end
        if x > maxX then
            maxX = x
        end
        if y > maxY then
            maxY = y
        end
    end
    return (minX + maxX) / 2, (minY + maxY) / 2
end

--- Scales a convex polygon from its center point.
--- @param verticies table. List of verticies formatted {x1, y1, x2, y2, ...}
--- @param scale number. Scale factor (>1 to enlarge, <1 to shrink)
--- @return table. New table of scaled verticies
function ViewUtil.scaleConvexPolyFromCenter(verticies, scale)
    local cx, cy = ViewUtil.centerOfConvexPoly(verticies)
    local scaled = {}
    for ii = 1, #verticies, 2 do
        local x, y = verticies[ii], verticies[ii + 1]
        local dx, dy = x - cx, y - cy
        scaled[ii] = cx + dx * scale
        scaled[ii + 1] = cy + dy * scale
    end
    return scaled
end

--- Rotates a list of verticies about a provided center point.
--- @param verticies table List of verticies formatted {x1, y1, x2, y2, ...}
--- @param centerX number X coordinate of the center point
--- @param centerY number Y coordinate of the center point
--- @param angle number Rotation angle in radians
--- @return table New table of rotated verticies
function ViewUtil.rotateVerticies(verticies, centerX, centerY, angle)
    if angle == 0 then
        return verticies
    end
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)
    local rotated = {}
    for ii = 1, #verticies, 2 do
        local x, y = verticies[ii], verticies[ii + 1]
        local dx, dy = x - centerX, y - centerY
        local rx = dx * cosA - dy * sinA
        local ry = dx * sinA + dy * cosA
        rotated[ii] = centerX + rx
        rotated[ii + 1] = centerY + ry
    end
    return rotated
end

--- Calculates a new point given a starting point, distance, and direction in radians.
--- @param x number Starting x coordinate
--- @param y number Starting y coordinate
--- @param distance number Distance to move
--- @param angle number Direction in radians
--- @return number newX, number newY
function ViewUtil.pointFromDistanceAndAngle(x, y, distance, angle)
    local newX = x + math.cos(angle) * distance
    local newY = y + math.sin(angle) * distance
    return newX, newY
end

--- multiply the points defined in vertexScalers by size and translate
--- them to be relative to x,y
function ViewUtil.transformVertexScalers(vertexScalers, size, x, y)
    local scaledVertices = {}
    for ii = 1, #vertexScalers, 2 do
        scaledVertices[ii] = (vertexScalers[ii] * size) + x
        scaledVertices[ii + 1] = (vertexScalers[ii + 1] * size) + y
    end
    return scaledVertices
end

return ViewUtil
