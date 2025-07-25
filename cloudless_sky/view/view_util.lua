-- Some utility functions geared towards the view/display code

local ViewUtil = {}

--- Given a table of RGB colors, return a table of those colors normallized from 0-1
ViewUtil.normalizeColorTable = function(colors)
    local normalized = {}
    for ii, color in pairs(colors) do
        r, g, b = love.math.colorFromBytes(color[1], color[2], color[3])
        normalized[ii] = { r, g, b }
    end
    return normalized
end

return ViewUtil
