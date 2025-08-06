local Object = require("cloudless_sky.extern.classic")
local PlaceTilePromptController = Object:extend()
local PlacePromptView = require("cloudless_sky.view.place_prompt_view")
local PlacePromptInsufficientView = require("cloudless_sky.view.place_prompt_insufficient_view")

--- @param star Star model class of the Star thats being placed on
function PlaceTilePromptController:new(star, slotCenterX, slotCenterY, starIdx, slotIdx, placementOptions)
    self.currentPromptCtx = {
        starIdx = 0,
        slotIdx = 0,
        view = nil,
    }
    self.lastPromptCtx = {
        starIdx = 0,
        slotIdx = 0,
        view = nil,
    }

    self.starIdx = starIdx
    self.slotIdx = slotIdx

    local starCost = star:slotIndexToCost(slotIdx)
end

function PlaceTilePromptController:newPrompt(star, slotCenterX, slotCenterY, starIdx, slotIdx, placementOptions)
    self.lastPrompt = self.currentPrompt

    local starCost = star:slotIndexToCost(slotIdx)
    local view = nil
    if #placementOptions == 0 then
        view = PlacePromptInsufficientView()
    else
        view = PlacePromptView(slotCenterX, slotCenterY, starCost, placementOptions, self.star.starType)
    end

    self.currentPromptCtx = {
        starIdx = starIdx,
        slotIdx = slotIdx,
        view = view,
    }
end

function PlaceTilePromptController:close()
    if self.currentPromptCtx.view ~= nil then
        self.currentPromptCtx.view:close()
    end
end

function PlaceTilePromptController:mousePressed(worldX, worldY, button, istouch)
    if self.currentPromptCtx.view ~= nil then
        return self.currentPromptCtx.view:mousePressed(worldX, worldY, button, istouch)
    end
end

function PlaceTilePromptController:update(dt)
    if self.currentPromptCtx.view ~= nil then
        self.currentPromptCtx.view:update(dt)
        if self.currentPromptCtx.view:closeDone() then
            self.currentPromptCtx.view = nil
        end
    end
    if self.lastPromptCtx.view ~= nil then
        self.lastPromptCtx.view:update(dt)
        if self.lastPromptCtx.view:closeDone() then
            self.lastPromptCtx.view = nil
        end
    end
end

function PlaceTilePromptController:draw()
    if self.currentPromptCtx.view ~= nil then
        self.currentPromptCtx.view:draw()
    end
    if self.lastPromptCtx.view ~= nil then
        self.lastPromptCtx.view:draw()
    end
end

function PlaceTilePromptController:resize(w, h, tileWorldX, tileWorldY)
    self.view:resize(w, h, tileWorldX, tileWorldY)
end

return PlaceTilePromptController
