local Object = require("cloudless_sky.extern.classic")
local PlaceTilePromptController = Object:extend()
local PlacePromptView = require("cloudless_sky.view.place_prompt_view")

function PlaceTilePromptController:new(star, slotCenterX, slotCenterY, starIdx, slotIdx)
    self.starIdx = starIdx
    self.slotIdx = slotIdx

    self.star = star

    local starCost = star:slotIndexToCost(slotIdx)

    self.view = PlacePromptView(slotCenterX, slotCenterY, starCost)
end

function PlaceTilePromptController:close()
    self.view:close()
end

function PlaceTilePromptController:update(dt)
    self.view:update(dt, self.star.starType)
end

function PlaceTilePromptController:draw()
    self.view:draw()
end

function PlaceTilePromptController:resize(w, h, tileWorldX, tileWorldY)
    self.view:resize(w, h, tileWorldX, tileWorldY)
end

return PlaceTilePromptController
