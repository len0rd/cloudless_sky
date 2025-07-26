--- bring together view and model of PlayerMat
local Object = require("cloudless_sky.extern.classic")
local PlayerMatController = Object:extend()
local PlayerMat = require("cloudless_sky.model.player_mat")
local PlayerMatView = require("cloudless_sky.view.player_mat_view")
local TileType = require("cloudless_sky.model.tile_type")
local ScoreText = require("cloudless_sky.view.score_text")
local GameRules = require("cloudless_sky.model.game_rules")

--- @param starTypes table List of StarTypes this mat is composed of. In PlayerMat index order
--- @param x integer The leftmost X coordinate of the mat in world coords
--- @param y integer The topmost Y coordintate of the mat in world coords
--- @param size integer The overall size of the Mat in pixels
function PlayerMatController:new(x, y, size)
    self.model = PlayerMat(GameRules.currentRules().playerMat.stars)
    local sTypes = {}
    for _, star in ipairs(GameRules.currentRules().playerMat.stars) do
        table.insert(sTypes, star.type)
    end
    print("Star Types:", table.concat(sTypes, ", "))
    self.view = PlayerMatView(x, y, size, sTypes)
    self.scoreTexts = {}
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
            local starSlotX, starSlotY = self.view:centerOfSlot(clickedStarIndex, clickedSlotIndex)
            CameraXDesired, CameraYDesired = starSlotX, starSlotY
            -- throwaway
            local leStar = self.model.stars[clickedStarIndex]
            local tileType = leStar.starType
            if leStar:isNonBasicType() then
                tileType = TileType.ORDERED[clickedSlotIndex]
            end
            local score = self.model:placeTile(tileType, clickedStarIndex, clickedSlotIndex)
            if score[1] ~= nil and score[1] > 0 then
                local scoreText = ScoreText(score[1], starSlotX, starSlotY)
                table.insert(self.scoreTexts, scoreText)
            end
            return true
        end
    end
    return false
end

function PlayerMatController:update(dt, mouseX, mouseY)
    self.view:update(mouseX, mouseY)
    for ii = #self.scoreTexts, 1, -1 do
        if self.scoreTexts[ii]:update(dt) then
            -- score text animation finished
            table.remove(self.scoreTexts, ii)
        end
    end
end

function PlayerMatController:draw()
    self.view:draw(self.model)
    for _, scoreText in ipairs(self.scoreTexts) do
        scoreText:draw()
    end
end

return PlayerMatController
