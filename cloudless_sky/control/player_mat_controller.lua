--- bring together view and model of PlayerMat
local Object = require("cloudless_sky.extern.classic")
local PlayerMatController = Object:extend()
local PlayerMat = require("cloudless_sky.model.player_mat")
local PlayerMatView = require("cloudless_sky.view.player_mat_view")
local TileType = require("cloudless_sky.model.tile_type")
local ScoreText = require("cloudless_sky.view.score_text")
local GameRules = require("cloudless_sky.model.game_rules")

--- @param playerMat PlayerMat Mat model this controller should use
--- @param x integer The leftmost X coordinate of the mat in world coords
--- @param y integer The topmost Y coordintate of the mat in world coords
--- @param size integer The overall size of the Mat in pixels
function PlayerMatController:new(playerMat, x, y, size)
    self.model = playerMat
    local sTypes = {}
    for _, star in ipairs(GameRules.currentRules().playerMat.stars) do
        table.insert(sTypes, star.type)
    end
    print("Star Types:", table.concat(sTypes, ", "))
    self.view = PlayerMatView(x, y, size, sTypes)
    self.scoreTexts = {}
end

function PlayerMatController:center()
    return self.view:center()
end

function PlayerMatController:topLeft()
    return self.view:topLeft()
end

function PlayerMatController:bottomRight()
    return self.view:bottomRight()
end

--- @return integer, integer actualSize. The actual width,height of the player mat (minimal padding around stars)
function PlayerMatController:size()
    return self.view:actualSize()
end

--- Place a tile (update visuals and model), then return the score the tile got.
--- @return table scoreTable The score as stated by PlayerMat:placeTile
function PlayerMatController:placeTile(starIndex, slotIndex)
    local score = { 0 }
    if starIndex ~= 0 and slotIndex ~= 0 then
        local starSlotX, starSlotY = self.view:centerOfSlot(starIndex, slotIndex)
        -- throwaway
        local leStar = self.model.stars[starIndex]
        local tileType = leStar.starType
        if leStar:isNonBasicType() then
            tileType = TileType.ORDERED[slotIndex]
        end
        score = self.model:placeTile(tileType, starIndex, slotIndex)
        if score[1] ~= nil and score[1] > 0 then
            local scoreText = ScoreText(score[1], starSlotX, starSlotY)
            table.insert(self.scoreTexts, scoreText)
        end
    end
    return score
end

function PlayerMatController:mousePressed(worldX, worldY, button, istouch)
    if button == 1 then
        local clickedStarIndex, clickedSlotIndex = self.view:coordStarSlotIndex(worldX, worldY)
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
