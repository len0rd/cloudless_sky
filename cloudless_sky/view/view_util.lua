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

return ViewUtil
