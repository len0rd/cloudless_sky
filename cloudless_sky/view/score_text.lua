-- Animate text for scoring
local Object = require("cloudless_sky.extern.classic")
local Text = require("cloudless_sky.extern.slog-text")
local ScoreText = Object:extend()

function ScoreText:new(text, worldX, worldY, opts)
    self.textbox = Text.new("center", {
        color = { 1, 1, 1, 1 },
        font = fonts.ithaca["16"],
    })
    local pointText = "Points!"
    if text == "1" or text == 1 then
        pointText = "Point!"
    end
    self.textbox:send("[dropshadow=3][bounce]" .. text .. " " .. pointText .. "[/bounce][/dropshadow]")
    self.worldX = worldX
    self.worldY = worldY
end

--- @return boolean isDone. True if the text is done displaying/rendering. otherwise falsefs
function ScoreText:update(dt)
    self.textbox:update(dt)
    return self.textbox:is_finished()
end

function ScoreText:draw()
    self.textbox:draw(self.worldX, self.worldY)
end

return ScoreText
