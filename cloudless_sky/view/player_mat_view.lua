-- bring together multiple StarViews to create a player mat

local Object = require("cloudless_sky.extern.classic")
local PlayerMatView = Object:extend()
local StarView = require("cloudless_sky.view.star_view")
local StarType = require("cloudless_sky.model.star_type")

-- padding between each star in pixels. must be an even number
local STAR_PADDING = 2

--- Create a new PlayerMatView
--- @param size integer Square size of the mat. Width/Height will be equal
function PlayerMatView:new(x, y, size)
    self.mat_origin_x = x
    self.mat_origin_y = y
    self.size = size
    self.star_size = (self.size - STAR_PADDING) / 3

    local threeQuarterStarSize = 3 * self.star_size / 4

    -- relative star origins (not in world coords yet)
    local starOrigins = {}
    starOrigins[1] = { (self.star_size / 2) + (STAR_PADDING / 2), 0 }
    starOrigins[2] = { starOrigins[1][1] + self.star_size + STAR_PADDING, 0 }

    local middleRowY = starOrigins[1][2] + threeQuarterStarSize + STAR_PADDING
    -- leftmost middle star
    starOrigins[6] = { 0, middleRowY }
    -- middlemost middle star of middleness
    starOrigins[7] = { self.star_size + STAR_PADDING, middleRowY }
    -- right middle
    starOrigins[3] = { starOrigins[7][1] + self.star_size + STAR_PADDING, middleRowY }

    local bottomRowY = middleRowY + threeQuarterStarSize + STAR_PADDING
    -- bottom left
    starOrigins[5] = { starOrigins[1][1], bottomRowY }
    starOrigins[4] = { starOrigins[2][1], bottomRowY }

    -- transform all origins to be in world coords
    for ii, sOrigin in ipairs(starOrigins) do
        starOrigins[ii] = { sOrigin[1] + self.mat_origin_x, sOrigin[2] + self.mat_origin_y }
    end

    -- this table has indicies that correspond to the PlayerMat star index setup
    self.stars = {}
    for ii, origin in ipairs(starOrigins) do
        self.stars[ii] = StarView(StarType.RED, origin[1], origin[2], self.star_size)
    end
end

--- @return boolean inBounds. True if x,y are within the overall bounding box of this mat, otherwise false
---     Assume coords are in world frame
function PlayerMatView:coordInBoundingBox(x, y)
    if
        x < self.mat_origin_x
        or x > (self.mat_origin_x + self.size)
        or y < self.mat_origin_y
        or y > (self.mat_origin_y + self.size)
    then
        return false
    end
    return true
end

--- @return integer, integer starSlot: When not 0 this is the star index and the slot
---     index within that star that the given coordinates are within
function PlayerMatView:coordStarSlotIndex(worldX, worldY)
    -- quickly check if coords are even in our boundingBox
    if not self:coordInBoundingBox(worldX, worldY) then
        return 0, 0
    end
    for ii, star in ipairs(self.stars) do
        local slotIndex = star:coordSlotIndex(worldX, worldY)
        if slotIndex ~= 0 then
            return ii, slotIndex
        end
    end
    return 0, 0
end

function PlayerMatView:centerOfSlot(starIndex, slotIndex)
    if starIndex < 1 or starIndex > #self.stars then
        return false, false
    end
    return self.stars[starIndex]:centerOfSlot(slotIndex)
end

function PlayerMatView:centerOfStar(starIndex)
    if starIndex < 1 or starIndex > #self.stars then
        return false, false
    end
    return self.stars[starIndex]:center()
end

function PlayerMatView:update(mouseX, mouseY)
    for _, star in ipairs(self.stars) do
        star:update(mouseX, mouseY)
    end
end

function PlayerMatView:draw()
    for _, star in ipairs(self.stars) do
        star:draw()
    end

    local origR, origG, origB, origA = love.graphics.getColor()
    love.graphics.setColor(love.math.colorFromBytes(255, 0, 197))
    love.graphics.rectangle("line", self.mat_origin_x, self.mat_origin_y, self.size, self.size)
    love.graphics.setColor(origR, origG, origB, origA)
end

return PlayerMatView
