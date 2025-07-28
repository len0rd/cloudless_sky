-- Bring together view and model of a single player

local Object = require("cloudless_sky.extern.classic")
local PlayerController = Object:extend()
local Player = require("cloudless_sky.model.player")
local GameRules = require("cloudless_sky.model.game_rules")
local PlayerMatController = require("cloudless_sky.control.player_mat_controller")
local TileType = require("cloudless_sky.model.tile_type")
local PlayerHUD = require("cloudless_sky.view.player_hud")

function PlayerController:new(name, x, y, size)
    self.model = Player(GameRules.currentRules().playerMat.stars, GameRules.currentRules().startScore, name)
    self.matControl = PlayerMatController(self.model.mat, x, y, size)
    self.playerHUD = PlayerHUD()

    self.playerHUD:show()
end

function PlayerController:serialize()
    return self.model:serialize()
end

function PlayerController:mousePressed(worldX, worldY, button, istouch)
    if self.playerHUD:mousePressed() then
        -- mouse handled
        return
    end
    local clickedStarIndex, clickedSlotIndex = self.matControl.view:coordStarSlotIndex(worldX, worldY)
    if clickedStarIndex ~= 0 and clickedSlotIndex ~= 0 then
        local score = self.matControl:placeTile(clickedStarIndex, clickedSlotIndex)
        if score[1] ~= nil and score[1] > 0 then
            -- FIX the whole tile selection stuff
            self.model:addScoreEvent(TileType.RED, clickedStarIndex, clickedSlotIndex, score)
        end
    end
end

--- Move the global Camera to center on this player
function PlayerController:moveCamera()
    -- center x,y of the player mat in world coords
    local matCenterX, matCenterY = self.matControl:center()

    -- TODO: auto zoom/adjust window so the player mat is nicely sized/centered
    local hudMarginTop, hudMarginLeft, hudMarginBottom, hudMarginRight = self.playerHUD:marginsNeeded()

    local matWidth, matHeight = self.matControl:size()
    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    local maxMatWidth = screenWidth - hudMarginLeft - (screenWidth - hudMarginRight)
    local maxMatHeight = screenHeight - hudMarginTop - (screenHeight - hudMarginBottom)

    local widthZoomFactor = maxMatWidth / matWidth
    local heightZoomFactor = maxMatHeight / matHeight

    print(
        "max: ["
            .. maxMatWidth
            .. ", "
            .. maxMatHeight
            .. "]. Actual: ["
            .. matWidth
            .. ", "
            .. matHeight
            .. "]. Factors: ["
            .. widthZoomFactor
            .. ", "
            .. heightZoomFactor
            .. "]"
    )

    local zoomFactor = math.min(widthZoomFactor, heightZoomFactor)
    camera:zoomTo(zoomFactor)
    -- local matMinX, matMinY = self.matControl:topLeft()
    -- local matMaxX, matMaxY = self.matControl:bottomRight()
    -- local screenRect = {
    --     matMinX - hudMarginLeft,
    --     matMaxX + hudMarginRight,
    --     matMinY - hudMarginTop,
    --     matMaxY + hudMarginBottom,
    -- }
    -- local minCameraX, minCameraY = camera:cameraCoords(matMinX - hudMarginLeft, matMinY - hudMarginTop)
    -- local maxCameraX, maxCameraY = camera:cameraCoords(matMaxX + hudMarginRight, matMaxY + hudMarginBottom)
    -- print("move camera window! [" .. table.concat(screenRect, ", ") .. "]")
    -- camera:lockWindow(matCenterX, matCenterY, minCameraX, maxCameraX, minCameraY, maxCameraY)
    camera:lockPosition(matCenterX, matCenterY)
end

function PlayerController:update(dt, mouseX, mouseY)
    self:moveCamera()
    self.matControl:update(dt, mouseX, mouseY)
    self.playerHUD:update(dt, self.model.score, 1, TileType.PURPLE)
end

function PlayerController:draw()
    camera:attach()
    do
        self.matControl:draw()
    end
    camera:detach()
    self.playerHUD:draw()
end

function PlayerController:resize(w, h)
    self.playerHUD:resize(w, h)
end

return PlayerController
