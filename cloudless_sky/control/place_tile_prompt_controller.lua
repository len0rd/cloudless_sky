local Object = require("cloudless_sky.extern.classic")
local PlaceTilePromptController = Object:extend()
local PlacePromptView = require("cloudless_sky.view.place_prompt_view")

function PlaceTilePromptController:new(star, slotCenterX, slotCenterY, starIdx, slotIdx)
    self.starIdx = starIdx
    self.slotIdx = slotIdx

    self.view = PlacePromptView(slotCenterX, slotCenterY)
end

function PlaceTilePromptController:close()
    self.view:close()
end

function PlaceTilePromptController:update(dt)
    self.view:update(dt)
end

function PlaceTilePromptController:draw()
    self.view:draw()
end

return PlaceTilePromptController
