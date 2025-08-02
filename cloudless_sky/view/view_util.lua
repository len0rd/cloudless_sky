-- Some utility functions geared towards the view/display code

local ViewUtil = {}

--- Given a table of RGB colors, return a table of those colors normallized from 0-1
function ViewUtil.normalizeColorTable(colors)
    local normalized = {}
    for ii, color in pairs(colors) do
        r, g, b = love.math.colorFromBytes(color[1], color[2], color[3])
        normalized[ii] = { r, g, b }
    end
    return normalized
end

-- calculate direct distance between 2 points
function ViewUtil.euclidianDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function ViewUtil.shiftVerticies(vertices, xShift, yShift)
    for ii = 1, #vertices, 2 do
        vertices[ii] = vertices[ii] + xShift
        vertices[ii + 1] = vertices[ii + 1] + yShift
    end
    return vertices
end

--- @return number, number, number, number BoundingBox. x,y,w,h of the bounding box
---     made by the provided vertices. x,y is the top left coordinate of the bounding box
function ViewUtil.boundingBoxOfVertices(vertices)
    local minX, minY = vertices[1], vertices[2]
    local maxX, maxY = vertices[1], vertices[2]
    for i = 3, #vertices, 2 do
        local x, y = vertices[i], vertices[i + 1]
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

return ViewUtil
