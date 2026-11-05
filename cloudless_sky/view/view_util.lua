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

--- Set \p color (r, g, b[, a]) with its alpha scaled by \p alpha
function ViewUtil.setColorAlpha(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
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

--- @param verticies table flat {x1,y1, x2,y2, ...} list of a convex polygon's corners, in either
---     winding order
--- @return boolean True if (px, py) is inside (or on the edge of) the polygon
function ViewUtil.ptInConvexPoly(verticies, px, py)
    local numPts = #verticies / 2
    local sign = 0
    for ii = 0, numPts - 1 do
        local ax, ay = verticies[ii * 2 + 1], verticies[ii * 2 + 2]
        local jj = (ii + 1) % numPts
        local bx, by = verticies[jj * 2 + 1], verticies[jj * 2 + 2]
        local cross = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        if cross ~= 0 then
            local crossSign = cross > 0 and 1 or -1
            if sign == 0 then
                sign = crossSign
            elseif crossSign ~= sign then
                return false
            end
        end
    end
    return true
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

--- @return table[] \p n points {x, y, angle} evenly spaced around the circle at (cx, cy) of radius
---     \p r, clockwise (screen coordinates) starting at \p startAngle (radians, default 0 = right)
function ViewUtil.pointsOnCircle(cx, cy, r, n, startAngle)
    startAngle = startAngle or 0
    local points = {}
    for ii = 1, n do
        local angle = startAngle + (ii - 1) * 2 * math.pi / n
        points[ii] = { x = cx + r * math.cos(angle), y = cy + r * math.sin(angle), angle = angle }
    end
    return points
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


function ViewUtil.drawOutlinedRectangle(x, y, w, h, cornerRadius, lineWidth, outlineColor)
    lineWidth = lineWidth or 2
    outlineColor = outlineColor or { 0, 0, 0 }
    love.graphics.rectangle("fill", x, y, w, h, cornerRadius, cornerRadius)
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.rectangle("line", x, y, w, h, cornerRadius, cornerRadius)
end

--------------------------------------------------------------------------------
-- Pixel-font text helpers
-- Pixel fonts must be drawn in screen space (never under camera zoom) at whole-pixel
-- positions to stay crisp. These helpers do the rounding.
--------------------------------------------------------------------------------

--- @return love.Font font The largest pixel font (from fonts.ithacaBySize) whose rendering of
---     \p text fits within \p w x \p h. Falls back to the smallest font if none fit.
function ViewUtil.largestFontThatFits(text, w, h)
    for _, font in ipairs(fonts.ithacaBySize) do
        if font:getWidth(text) <= w and (h == nil or font:getHeight() <= h) then
            return font
        end
    end
    return fonts.ithacaBySize[#fonts.ithacaBySize]
end

--- Print \p text horizontally aligned within [x, x+w] and vertically centered in [y, y+h],
--- snapped to whole pixels. Color must be set by the caller.
--- @param align string|nil "left", "center" (default) or "right"
function ViewUtil.printPixelText(text, font, x, y, w, h, align)
    local textY = y + (h - font:getHeight()) / 2
    love.graphics.printf(text, font, math.floor(x + 0.5), math.floor(textY + 0.5), math.floor(w), align or "center")
end

--- Print \p text fitted into the world rect (worldX, worldY, worldW, worldH), in screen space so the
--- pixel font stays crisp (call from a drawScreen, see DrawSys). Uses the global camera
--- @param color table|nil defaults to white
function ViewUtil.drawWorldLabel(text, worldX, worldY, worldW, worldH, color)
    local x, y = camera:cameraCoords(worldX, worldY)
    local w, h = worldW * camera.scale, worldH * camera.scale
    love.graphics.setColor(color or { 1, 1, 1, 1 })
    ViewUtil.printPixelText(text, ViewUtil.largestFontThatFits(text, w, h), x, y, w, h)
end

--- suit draw function for Labels: vertically centered, pixel-snapped text.
--- If opt.font is not provided, the largest font that fits the cell is used.
function ViewUtil.suitLabelDraw(text, opt, x, y, w, h)
    local font = opt.fixedFont or ViewUtil.largestFontThatFits(text, w - 4, h)
    love.graphics.setColor((opt.color and opt.color.normal and opt.color.normal.fg) or { 0, 0, 0 })
    ViewUtil.printPixelText(text, font, x, y, w, h, opt.align)
end

--- suit draw function for Buttons. Like suit's theme.Button but keeps the label vertically
--- centered and pixel-snapped. The label text is not scaled with opt.scale (scaling a pixel font
--- by a non-integer amount blurs it), only the box is.
--- If opt.fixedFont is not provided, the largest font that fits the button is used.
function ViewUtil.suitButtonDraw(text, opt, x, y, w, h)
    local suitTheme = require("cloudless_sky.extern.suit.theme")
    local colors = (opt.color and opt.color[opt.state]) or (opt.color and opt.color.normal) or suitTheme.color.normal
    suitTheme.drawBox(x, y, w, h, colors, opt.cornerRadius, opt.outline, opt.scale or 1.0)

    local font = opt.fixedFont or ViewUtil.largestFontThatFits(text, w - 4, h)
    love.graphics.setColor(colors.fg)
    ViewUtil.printPixelText(text, font, x, y, w, h, "center")
end

return ViewUtil
