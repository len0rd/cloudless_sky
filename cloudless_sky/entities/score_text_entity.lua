--- Animated text to display points earned when a tile is placed
local Concord = require("cloudless_sky.extern.concord")
local Text = require("cloudless_sky.extern.slog-text")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")

local ScoreTextEntity = {}
ScoreTextEntity.__index = ScoreTextEntity

-- estimated max width of the text box
local ESTIMATED_TEXT_WIDTH = 100
local ESTIMATED_TEXT_HEIGHT = 30

function ScoreTextEntity.new(playerIdx, starIdx, slotIdx, scorePts)
    local entity = Concord.entity()

    entity
        :give(Components.names.playerMatTileAnchor, starIdx, slotIdx)
        :give(Components.names.boundingBox, ESTIMATED_TEXT_WIDTH, ESTIMATED_TEXT_HEIGHT)
        :give(Components.names.playerEntity, playerIdx)
        :give(Components.names.drawable, Constants.drawPriority.tileScoreAnimations)
        :give(Components.names.worldPos, 0, 0)
        :give(Components.names.killOffCamera) -- ensure it gets removed from world when off camera
        :give(Components.names.ephemeral)

    entity.textbox = Text.new("center", {
        color = { 1, 1, 1, 1 },
        font = fonts.ithaca["32"],
    })
    local pointText = "Points!"
    if scorePts == 1 then
        pointText = "Point!"
    end
    entity.textbox:send(
        "[dropshadow=3][bounce]" .. tostring(math.floor(scorePts)) .. " " .. pointText .. "[/bounce][/dropshadow]"
    )

    EUtil.extendEntity(entity, ScoreTextEntity)

    return entity
end

function ScoreTextEntity:update(dt, gameState)
    self.textbox:update(dt)
    self.ephemeral.done = self.textbox:is_finished()
end

--- drawn in screen space (see DrawSys) so the pixel font isn't scaled by camera zoom
function ScoreTextEntity:drawScreen(gameState)
    local x, y = camera:cameraCoords(self.worldPos.x, self.worldPos.y)
    self.textbox:draw(math.floor(x + 0.5), math.floor(y + 0.5))
end

return ScoreTextEntity
