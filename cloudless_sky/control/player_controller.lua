-- Bring together view and model of a single player
---@class Object
local Object = require("cloudless_sky.extern.classic")
local Player = require("cloudless_sky.model.player")
local GameRules = require("cloudless_sky.model.game_rules")
local PlayerMatController = require("cloudless_sky.control.player_mat_controller")
local TileType = require("cloudless_sky.model.tile_type")
local PlayerHUD = require("cloudless_sky.view.player_hud")
local PlaceTilePromptController = require("cloudless_sky.control.place_tile_prompt_controller")

---@class PlayerController : Object
---@field model Player
---@field placePromptController PlaceTilePromptController
local PlayerController = Object:extend()

function PlayerController:new(name, x, y, size)
    self.model = Player(GameRules.currentRules().playerMat.stars, GameRules.currentRules().startScore, name)
    self.matControl = PlayerMatController(self.model.mat, x, y, size)
    self.playerHUD = PlayerHUD()
    self.cameraZoom = 1.0
    self.placePromptController = PlaceTilePromptController()
    self:resize(love.graphics.getPixelDimensions())

    self.playerHUD:show()
end

function PlayerController:serialize()
    return self.model:serialize()
end

function PlayerController:deserialize(data)
    self.model:deserialize(data)
end

function PlayerController:mousePressed(worldX, worldY, button, istouch)
    if self.playerHUD:mousePressed() then
        -- mouse handled
        return
    end
    if self.placePromptController:mousePressed(worldX, worldY, button, istouch) then
        -- mouse handled
        return
    end
    local clickedStarIndex, clickedSlotIndex = self.matControl.view:coordStarSlotIndex(worldX, worldY)
    if
        clickedStarIndex ~= 0
        and clickedSlotIndex ~= 0
        and not self.model:slotOccupied(clickedStarIndex, clickedSlotIndex)
    then
        -- only create a new prompt if its for a slot we're not already displaying a prompt for
        if not self.placePromptController:promptExists(clickedStarIndex, clickedSlotIndex) then
            local starCenterX, starCenterY = self.matControl.view:centerOfSlot(clickedStarIndex, clickedSlotIndex)

            local placementOptions =
                self.model:generatePlacementPossibilities(clickedStarIndex, clickedSlotIndex, TileType.PURPLE)
            self.placePromptController:newPrompt(
                self.matControl:getStar(clickedStarIndex),
                starCenterX,
                starCenterY,
                clickedStarIndex,
                clickedSlotIndex,
                placementOptions
            )
        end
    else
        -- clicked outside of the a star/slot area. remove any place prompts
        if self.placePromptController:promptActive() then
            self.placePromptController:close()
        end
    end
end

--- Move the global Camera to center on this player
function PlayerController:moveCamera()
    -- center x,y of the player mat in world coords
    local matCenterX, matCenterY = self.matControl:center()

    camera:zoomTo(self.cameraZoom)
    camera:lockPosition(matCenterX, matCenterY)
end

function PlayerController:update(dt, mouseWorldX, mouseWorldY)
    self:moveCamera()
    local focusStarIdx = 0
    local focusSlotIdx = 0
    if self.placePromptController:promptActive() then
        local placementSelection = self.placePromptController:update(dt)
        focusStarIdx, focusSlotIdx = self.placePromptController:activePromptStarSlot()
        if placementSelection ~= nil then
            local scoreEvents = self.model:performPlacement(focusStarIdx, focusSlotIdx, placementSelection)
        end
    else
        focusStarIdx, focusSlotIdx = self.matControl.view:coordStarSlotIndex(mouseWorldX, mouseWorldY)
    end
    self.matControl:update(dt, focusStarIdx, focusSlotIdx)
    self.playerHUD:update(dt, self.model.score, 1, TileType.PURPLE)
end

function PlayerController:draw()
    camera:attach()
    do
        self.matControl:draw()
        self.placePromptController:draw()
    end
    camera:detach()
    self.playerHUD:draw(self.model.hand)
end

function PlayerController:resize(w, h)
    self.playerHUD:resize(w, h)

    -- Solve correct zoom level based on player mat size vs screen size
    local hudMarginTop, hudMarginLeft, hudMarginBottom, hudMarginRight = self.playerHUD:marginsNeeded()

    local matWidth, matHeight = self.matControl:size()
    local maxMatWidth = w - hudMarginLeft - (w - hudMarginRight)
    local maxMatHeight = h - hudMarginTop - (h - hudMarginBottom)
    local widthZoomFactor = maxMatWidth / matWidth
    local heightZoomFactor = maxMatHeight / matHeight

    self.cameraZoom = math.min(widthZoomFactor, heightZoomFactor)
    self:moveCamera()

    self.placePromptController:resize(w, h, self.matControl.view)
end

return PlayerController
