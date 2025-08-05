local Object = require("cloudless_sky.extern.classic")
local PlaceTilePromptController = Object:extend()
local PlacePromptView = require("cloudless_sky.view.place_prompt_view")
local PlacePromptInsufficientView = require("cloudless_sky.view.place_prompt_insufficient_view")

function PlaceTilePromptController:new(star, slotCenterX, slotCenterY, starIdx, slotIdx, placementOptions)
    self.starIdx = starIdx
    self.slotIdx = slotIdx

    self.star = star

    local starCost = star:slotIndexToCost(slotIdx)

    if #placementOptions == 0 then
        self.view = PlacePromptInsufficientView()
    else
        self.view = PlacePromptView(slotCenterX, slotCenterY, starCost, placementOptions)
    end
end

function PlaceTilePromptController:close()
    self.view:close()
end

function PlaceTilePromptController:mousePressed(worldX, worldY, button, istouch)
    return self.view:mousePressed(worldX, worldY, button, istouch)
end

function PlaceTilePromptController:update(dt)
    return self.view:update(dt, self.star.starType)
end

function PlaceTilePromptController:draw()
    self.view:draw()
end

function PlaceTilePromptController:resize(w, h, tileWorldX, tileWorldY)
    self.view:resize(w, h, tileWorldX, tileWorldY)
end

return PlaceTilePromptController
