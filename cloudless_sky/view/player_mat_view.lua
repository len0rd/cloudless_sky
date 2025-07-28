-- bring together multiple StarViews to create a player mat

local Object = require("cloudless_sky.extern.classic")
local PlayerMatView = Object:extend()
local StarView = require("cloudless_sky.view.star_view")
local StarType = require("cloudless_sky.model.star_type")

-- padding between each star in pixels. must be an even number
local STAR_PADDING = 2

--- Create a new PlayerMatView
--- @param size integer Square size of the mat. Width/Height will be equal
--- @param starTypes table List of each star's type in mat-index order
function PlayerMatView:new(x, y, size, starTypes)
    self.matOriginX = x
    self.matOriginY = y
    self.size = size
    self.star_size = (self.size - STAR_PADDING) / 3
    stypes = starTypes
    if stypes == nil then
        local PlayerMat = require("cloudless_sky.model.player_mat")
        stypes = PlayerMat.BASE_GAME_DEFAULT_MAT
    end

    local threeQuarterStarSize = 3 * self.star_size / 4

    -- relative star origins (not in world coords yet)
    local starOrigins = {}
    starOrigins[1] = { (self.star_size / 2) + (STAR_PADDING / 2), self.star_size / 4 }
    starOrigins[2] = { starOrigins[1][1] + self.star_size + STAR_PADDING, self.star_size / 4 }

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
        starOrigins[ii] = { sOrigin[1] + self.matOriginX, sOrigin[2] + self.matOriginY }
    end

    -- this table has indicies that correspond to the PlayerMat star index setup
    self.stars = {}
    for ii, origin in ipairs(starOrigins) do
        self.stars[ii] = StarView(stypes[ii], origin[1], origin[2], self.star_size)
    end
end

--- @return boolean inBounds. True if x,y are within the overall bounding box of this mat, otherwise false
---     Assume coords are in world frame
function PlayerMatView:coordInBoundingBox(x, y)
    if
        x < self.matOriginX
        or x > (self.matOriginX + self.size)
        or y < self.matOriginY
        or y > (self.matOriginY + self.size)
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

--- @return integer, integer centerCoords. The center of this mat in world coords
function PlayerMatView:center()
    local centerX = self.matOriginX + (self.size / 2)
    local centerY = self.matOriginY + (self.size / 2)
    return centerX, centerY
end

function PlayerMatView:topLeft()
    return self.matOriginX, self.matOriginY
end

function PlayerMatView:bottomRight()
    return self.matOriginX + self.size, self.matOriginY + self.size
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

--- @param playerMat PlayerMat PlayerMat model class instance that corresponds to this mat
function PlayerMatView:draw(playerMat)
    local hoveredStarIndex = 0 -- draw star currently hovered on by mouse last for correct layering
    for ii, star in ipairs(self.stars) do
        if not star:isHovered() then
            star:draw(playerMat.stars[ii])
        else
            hoveredStarIndex = ii
        end
    end
    if hoveredStarIndex ~= 0 then
        self.stars[hoveredStarIndex]:draw(playerMat.stars[hoveredStarIndex])
    end

    -- bounding box
    -- local origR, origG, origB, origA = love.graphics.getColor()
    -- love.graphics.setColor(love.math.colorFromBytes(255, 0, 197))
    -- love.graphics.rectangle("line", self.matOriginX, self.matOriginY, self.size, self.size)
    -- love.graphics.setColor(origR, origG, origB, origA)
end

return PlayerMatView
