--- Control class for displaying tile placement prompts for a player

local Object = require("cloudless_sky.extern.classic")
local PlacePromptView = require("cloudless_sky.view.place_prompt_view")
local PlacePromptInsufficientView = require("cloudless_sky.view.place_prompt_insufficient_view")

---@class PlaceTilePromptController : Object
local PlaceTilePromptController = Object:extend()

local OLDEST_PROMPT_IDX = 1
local LATEST_PROMPT_IDX = 2

function PlaceTilePromptController:new()
    self.prompts = {
        {
            starIdx = 0,
            slotIdx = 0,
            view = nil,
        },
        {
            starIdx = 0,
            slotIdx = 0,
            view = nil,
        },
    }
end

--- @param star Star model class of the Star thats being placed on
function PlaceTilePromptController:newPrompt(star, slotCenterX, slotCenterY, starIdx, slotIdx, placementOptions)
    self.prompts[OLDEST_PROMPT_IDX] = self.prompts[LATEST_PROMPT_IDX]
    if self.prompts[OLDEST_PROMPT_IDX].view then
        self.prompts[OLDEST_PROMPT_IDX].view:close()
    end

    local starCost = star:slotIndexToCost(slotIdx)
    local view = nil
    if #placementOptions == 0 then
        view = PlacePromptInsufficientView()
    else
        view = PlacePromptView(slotCenterX, slotCenterY, starCost, placementOptions, star.starType)
    end
    self.prompts[LATEST_PROMPT_IDX] = {
        starIdx = starIdx,
        slotIdx = slotIdx,
        view = view,
    }
end

---@return boolean alreadyExists. True if a prompt dialog for the given star+slot already exists, otherwise false
function PlaceTilePromptController:promptExists(starIdx, slotIdx)
    for _, promptCtx in ipairs(self.prompts) do
        if starIdx == promptCtx.starIdx and slotIdx == promptCtx.slotIdx then
            return true
        end
    end
    return false
end

---@return boolean anyExist. True if there is a active prompt on the screen, otherwise false
function PlaceTilePromptController:promptActive()
    local active = self.prompts[LATEST_PROMPT_IDX].view ~= nil and not self.prompts[LATEST_PROMPT_IDX].view:closing()
    return active
end

---@return number, number StarSlotIdx. If a prompt is currently active, the star then slot index that the prompt is attached to, otherwise 0,0
function PlaceTilePromptController:activePromptStarSlot()
    if self:promptActive() then
        return self.prompts[LATEST_PROMPT_IDX].starIdx, self.prompts[LATEST_PROMPT_IDX].slotIdx
    end
    return 0, 0
end

function PlaceTilePromptController:close()
    if self.prompts[LATEST_PROMPT_IDX].view ~= nil then
        self.prompts[LATEST_PROMPT_IDX].view:close()
    end
end

function PlaceTilePromptController:mousePressed(worldX, worldY, button, istouch)
    if self.prompts[LATEST_PROMPT_IDX].view then
        return self.prompts[LATEST_PROMPT_IDX].view:mousePressed(worldX, worldY, button, istouch)
    end
    return false
end

function PlaceTilePromptController:update(dt)
    local result = nil
    for ii, promptCtx in ipairs(self.prompts) do
        if promptCtx.view ~= nil then
            local thisPromptResult = promptCtx.view:update(dt)
            if promptCtx.view:isClosed() then
                self.prompts[ii].view = nil
            elseif ii == LATEST_PROMPT_IDX then
                result = thisPromptResult
            end
        end
    end
    return result
end

function PlaceTilePromptController:draw()
    for ii, promptCtx in ipairs(self.prompts) do
        if promptCtx.view ~= nil then
            promptCtx.view:draw()
        end
    end
end

---@param matView PlayerMatView. Current player mat view, used to find the new origins of each and StarSlots that are currently prompts
function PlaceTilePromptController:resize(w, h, matView)
    for _, promptCtx in ipairs(self.prompts) do
        if promptCtx.view ~= nil then
            local tileWorldX, tileWorldY = matView:centerOfSlot(promptCtx.starIdx, promptCtx.slotIdx)
            promptCtx.view:resize(w, h, tileWorldX, tileWorldY)
        end
    end
end

return PlaceTilePromptController
