-- Bring together view and model of a single player

local Object = require("cloudless_sky.extern.classic")
local PlayerController = Object:extend()
local Player = require("cloudless_sky.model.player")
local GameRules = require("cloudless_sky.model.game_rules")
local PlayerMatController = require("cloudless_sky.control.player_mat_controller")
local TileType = require("cloudless_sky.model.tile_type")
local PlayerHUD = require("cloudless_sky.view.player_hud")
local PlaceTilePromptController = require("cloudless_sky.control.place_tile_prompt_controller")

function PlayerController:new(name, x, y, size)
    self.model = Player(GameRules.currentRules().playerMat.stars, GameRules.currentRules().startScore, name)
    self.matControl = PlayerMatController(self.model.mat, x, y, size)
    self.playerHUD = PlayerHUD()
    self.cameraZoom = 1.0
    self:resize(love.graphics.getPixelDimensions())

    -- appears when the user clicks a rectangle: prompt to place a tile
    self.currentPlacePrompt = nil

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
    if self.currentPlacePrompt ~= nil and self.currentPlacePrompt:mousePressed(worldX, worldY, button, istouch) then
        -- mouse handled
        return
    end
    local clickedStarIndex, clickedSlotIndex = self.matControl.view:coordStarSlotIndex(worldX, worldY)
    if clickedStarIndex ~= 0 and clickedSlotIndex ~= 0 then
        -- only create a new prompt if its for a slot we're not already displaying a prompt for
        if
            self.currentPlacePrompt == nil
            or self.currentPlacePrompt.starIdx ~= clickedStarIndex
            or self.currentPlacePrompt.slotIdx ~= clickedSlotIndex
        then
            self.currentPlacePrompt = nil
            local starCenterX, starCenterY = self.matControl.view:centerOfSlot(clickedStarIndex, clickedSlotIndex)
            self.currentPlacePrompt = PlaceTilePromptController(
                self.matControl:getStar(clickedStarIndex),
                starCenterX,
                starCenterY,
                clickedStarIndex,
                clickedSlotIndex
            )
        end
        -- local score = self.matControl:placeTile(clickedStarIndex, clickedSlotIndex)
        -- if score[1] ~= nil and score[1] > 0 then
        --     -- FIX the whole tile selection stuff
        --     self.model:addScoreEvent(TileType.RED, clickedStarIndex, clickedSlotIndex, score)
        -- end
    else
        -- clicked outside of the a star/slot area. remove any place prompts
        if self.currentPlacePrompt ~= nil then
            self.currentPlacePrompt:close()
        end
        self.currentPlacePrompt = nil
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
    local placementSelection = nil
    local focusStarIdx = 0
    local focusSlotIdx = 0
    if self.currentPlacePrompt ~= nil then
        placementSelection = self.currentPlacePrompt:update(dt)
        if placementSelection ~= nil then
            print("CONTROLLER PLACEMENT!")
        else
            focusStarIdx = self.currentPlacePrompt.starIdx
            focusSlotIdx = self.currentPlacePrompt.slotIdx
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
        if self.currentPlacePrompt ~= nil then
            self.currentPlacePrompt:draw()
        end
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

    if self.currentPlacePrompt ~= nil then
        local tileWorldX, tileWorldY =
            self.matControl.view:centerOfSlot(self.currentPlacePrompt.starIdx, self.currentPlacePrompt.slotIdx)
        self.currentPlacePrompt:resize(w, h, tileWorldX, tileWorldY)
    end
end

return PlayerController
