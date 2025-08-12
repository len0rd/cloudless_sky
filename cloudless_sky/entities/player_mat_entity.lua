--- Entity for a the player mat visual (state of mat is in model.player_mat)
local Object = require("cloudless_sky.extern.classic")
local Concord = require("cloudless_sky.extern.concord")

local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local StarView = require("cloudless_sky.view.star_view")
local BoxedViewSys = require("cloudless_sky.systems.boxed_view")
local EUtil = require("cloudless_sky.entities.e_util")

---@class PlayerMatEntity
---@field stars table[StarView] Mat-index-ordered list of star view objects
local PlayerMatEntity = {}
PlayerMatEntity.__index = PlayerMatEntity

-- padding between each star in pixels. must be an even number
local STAR_PADDING = 2

PlayerMatEntity.DEFAULT_Y_PX = 100

--- Based on the PlayerMatView bounding box and the playerIndex, decide on an origin X,Y for the mat to go
--- assumes all player mats have the same width and height
local function determineWorldCoords(playerIdx, sizePx)
    return (2 * (playerIdx - 1) * sizePx), PlayerMatEntity.DEFAULT_Y_PX
end

function PlayerMatEntity.new(playerIdx, sizePx, starTypes)
    local entity = Concord.entity()
    assert(starTypes, "PlayerMatEntity must know what star types it has")
    local x, y = determineWorldCoords(playerIdx, sizePx)

    EUtil.extendEntity(entity, PlayerMatEntity)

    entity
        :give(Components.names.worldPos, x, y)
        :give(Components.names.boundingBox, sizePx, sizePx)
        :give(Components.names.drawable, Constants.drawPriority.playerMat)
        :give(Components.names.mouseHandler, Constants.drawPriority.playerMat)
        :give(Components.names.playerEntity, playerIdx)

    -- get StarViews initialized
    entity.star_size = (entity.boundingBox.w - STAR_PADDING) / 3

    local threeQuarterStarSize = 3 * entity.star_size / 4

    -- relative star origins (not in world coords yet)
    local starOrigins = {}
    starOrigins[1] = { (entity.star_size / 2) + (STAR_PADDING / 2), entity.star_size / 4 }
    starOrigins[2] = { starOrigins[1][1] + entity.star_size + STAR_PADDING, entity.star_size / 4 }

    local middleRowY = starOrigins[1][2] + threeQuarterStarSize + STAR_PADDING
    -- leftmost middle star
    starOrigins[6] = { 0, middleRowY }
    -- middlemost middle star of middleness
    starOrigins[7] = { entity.star_size + STAR_PADDING, middleRowY }
    -- right middle
    starOrigins[3] = { starOrigins[7][1] + entity.star_size + STAR_PADDING, middleRowY }

    local bottomRowY = middleRowY + threeQuarterStarSize + STAR_PADDING
    -- bottom left
    starOrigins[5] = { starOrigins[1][1], bottomRowY }
    starOrigins[4] = { starOrigins[2][1], bottomRowY }

    -- transform all origins to be in world coords
    for ii, sOrigin in ipairs(starOrigins) do
        starOrigins[ii] = { sOrigin[1] + entity.worldPos.x, sOrigin[2] + entity.worldPos.y }
    end

    -- this table has indicies that correspond to the PlayerMat star index setup
    entity.stars = {}
    for ii, origin in ipairs(starOrigins) do
        entity.stars[ii] = StarView(starTypes[ii], origin[1], origin[2], entity.star_size)
    end

    entity.focusStarIdx = 0
    entity.focusSlotIdx = 0

    return entity
end

--- @return integer, integer starSlot: When not 0 this is the star index and the slot
---     index within that star that the given coordinates are within
function PlayerMatEntity:coordStarSlotIndex(worldX, worldY)
    -- quickly check if coords are even in our boundingBox
    if not BoxedViewSys.worldCoordInEntity(self, worldX, worldY) then
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

function PlayerMatEntity:centerOfSlot(starIdx, slotIdx)
    assert(starIdx and starIdx > 0 and starIdx <= #self.stars, "Invalid star index!")
    return self.stars[starIdx]:centerOfSlot(slotIdx)
end

function PlayerMatEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    local starIdx, slotIdx = self:coordStarSlotIndex(worldX, worldY)
    if starIdx ~= 0 and slotIdx ~= 0 then
        -- we done been clicked!
        self.mouseHandler.clickEvent = {
            type = Components.mouseHandler.eventTypes.matSlotClicked,
            playerIdx = self.playerEntity.idx,
            starIdx = starIdx,
            slotIdx = slotIdx,
        }
        return true
    end
    return false
end

function PlayerMatEntity:update(dt, gameState)
    self.focusStarIdx, self.focusSlotIdx = self:coordStarSlotIndex(camera:mousePosition())
    for ii, star in ipairs(self.stars) do
        if ii ~= self.focusStarIdx then
            star:update(dt, 0)
        end
    end
    if self.focusStarIdx ~= 0 then
        self.stars[self.focusStarIdx]:update(dt, self.focusSlotIdx)
    end
end

function PlayerMatEntity:draw(gameState)
    local numStars = #self.stars
    local startIdx = (self.focusStarIdx % numStars) + 1

    for ii = startIdx, startIdx + numStars - 1 do
        local starIdx = ((ii - 1) % numStars) + 1
        self.stars[starIdx]:draw(gameState:getStar(self.playerEntity.idx, starIdx))
    end
end

return PlayerMatEntity
