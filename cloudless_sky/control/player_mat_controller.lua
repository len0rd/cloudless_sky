--- bring together view and model of PlayerMat
local Object = require("cloudless_sky.extern.classic")
local PlayerMatController = Object:extend()
local PlayerMat = require("cloudless_sky.model.player_mat")
local PlayerMatView = require("cloudless_sky.view.player_mat_view")
local TileType = require("cloudless_sky.model.tile_type")

--- @param starTypes table List of StarTypes this mat is composed of. In PlayerMat index order
--- @param x integer The leftmost X coordinate of the mat in world coords
--- @param y integer The topmost Y coordintate of the mat in world coords
--- @param size integer The overall size of the Mat in pixels
function PlayerMatController:new(starTypes, x, y, size)
    self.model = PlayerMat(starTypes)
    self.view = PlayerMatView(x, y, size, starTypes)
end

function PlayerMatController:serialize()
    return self.model:serialize()
end

function PlayerMatController:placeTile(starIndex, slotIndex)
    local placeResult = self.model:placeTile(starIndex, slotIndex)
end

function PlayerMatController:mousePressed(worldX, worldY, button, istouch)
    if button == 1 then
        local clickedStarIndex, clickedSlotIndex = self.view:coordStarSlotIndex(worldX, worldY)
        if clickedStarIndex ~= 0 and clickedSlotIndex ~= 0 then
            CameraXDesired, CameraYDesired = self.view:centerOfSlot(clickedStarIndex, clickedSlotIndex)
            -- throwaway
            local leStar = self.model.stars[clickedStarIndex]
            local tileType = leStar.starType
            if leStar:isNonBasicType() then
                tileType = TileType.RED
            end
            self.model:placeTile(tileType, clickedStarIndex, clickedSlotIndex)
        end
    end
end

function PlayerMatController:update(mouseX, mouseY)
    self.view:update(mouseX, mouseY)
end

function PlayerMatController:draw()
    self.view:draw(self.model)
end

return PlayerMatController
