--- The overview: the camera zoomed out to show the whole game, the table and every player's mat. Its
--- bounding box covers all of them (so the camera can fit it, see WorldStateMachine.focusEntity).
---
--- While active (graphicsState.viewFocus is VIEW.OVERVIEW) each mat is dimmed with its player's name
--- over it in large text (the current player's in gold), and the area under the pointer is lit up.
--- Clicking the table or a mat claims the click (so nothing on them is picked) and reports which:
---     { type = viewAreaClicked, area = "table" }
---     { type = viewAreaClicked, area = "mat", playerIdx = integer }
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local BoxedViewSys = require("cloudless_sky.systems.boxed_view")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class OverviewEntity
---@field active boolean the camera is on the overview (set by WorldStateMachine)
local OverviewEntity = {}
OverviewEntity.__index = OverviewEntity

local MAT_DIM = { 0, 0, 0, 0.55 }
-- the area under the pointer is dimmed this much less (mats), or lightly washed (the table)
local HOVER_LIGHTEN = 0.3
local TABLE_HOVER = { 1, 1, 1, 0.08 }
local NAME_COLOR = { 1, 1, 1, 1 }
local CURRENT_NAME_COLOR = { 1, 0.84, 0.3, 1 }
local NAME_SHADOW = { 0, 0, 0, 0.6 }
-- the name's box: this share of the mat's width, centered
local NAME_W = 0.8
local NAME_H = 0.25

--- @param tableEntity table TableAreaEntity
--- @param matEntities table[] PlayerMatEntity by player index
function OverviewEntity.new(tableEntity, matEntities)
    local entity = Concord.entity()
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local function include(e)
        minX = math.min(minX, e.worldPos.x)
        minY = math.min(minY, e.worldPos.y)
        maxX = math.max(maxX, e.worldPos.x + e.boundingBox.w)
        maxY = math.max(maxY, e.worldPos.y + e.boundingBox.h)
    end
    include(tableEntity)
    for _, mat in ipairs(matEntities) do
        include(mat)
    end
    entity
        :give(Components.names.worldPos, minX, minY)
        :give(Components.names.boundingBox, maxX - minX, maxY - minY)
        :give(Components.names.drawable, Constants.drawPriority.overview)
        :give(Components.names.mouseHandler, Constants.drawPriority.overview)
    EUtil.extendEntity(entity, OverviewEntity)
    entity.tableEntity = tableEntity
    entity.matEntities = matEntities
    entity.active = false
    return entity
end

--- @return string|nil area "table" or "mat" under the world point, nil if neither
--- @return integer|nil playerIdx the mat's player
function OverviewEntity:areaAt(worldX, worldY)
    if BoxedViewSys.worldCoordInEntity(self.tableEntity, worldX, worldY) then
        return "table", nil
    end
    for ii, mat in ipairs(self.matEntities) do
        if BoxedViewSys.worldCoordInEntity(mat, worldX, worldY) then
            return "mat", ii
        end
    end
    return nil, nil
end

--- While active, every press is claimed (nothing in the world is clicked through the overview).
--- A press on the table or a mat reports it
function OverviewEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    if not self.active then
        return false
    end
    if button == 1 then
        local area, playerIdx = self:areaAt(worldX, worldY)
        if area then
            self.mouseHandler.clickEvent = {
                type = Components.mouseHandler.eventTypes.viewAreaClicked,
                area = area,
                playerIdx = playerIdx,
            }
        end
    end
    return true
end

function OverviewEntity:update(dt, gameState) end

--- @return number x, number y, number w, number h. Screen rect of world entity \p e
local function screenRect(e)
    local x1, y1 = camera:cameraCoords(e.worldPos.x, e.worldPos.y)
    local x2, y2 = camera:cameraCoords(e.worldPos.x + e.boundingBox.w, e.worldPos.y + e.boundingBox.h)
    return x1, y1, x2 - x1, y2 - y1
end

--- Screen space (DrawSys), so the names' pixel font stays crisp
function OverviewEntity:drawScreen(gameState)
    if not self.active then
        return
    end
    local hoverArea, hoverIdx = self:areaAt(camera:mousePosition())
    if hoverArea == "table" then
        local x, y, w, h = screenRect(self.tableEntity)
        love.graphics.setColor(TABLE_HOVER)
        love.graphics.rectangle("fill", x, y, w, h, h * 0.05, h * 0.05)
    end
    for ii, mat in ipairs(self.matEntities) do
        local x, y, w, h = screenRect(mat)
        local dim = MAT_DIM[4] - ((hoverArea == "mat" and hoverIdx == ii) and HOVER_LIGHTEN or 0)
        love.graphics.setColor(MAT_DIM[1], MAT_DIM[2], MAT_DIM[3], dim)
        love.graphics.rectangle("fill", x, y, w, h, w * 0.04, w * 0.04)

        local name = gameState.players[ii].playerName
        local nameW, nameH = w * NAME_W, h * NAME_H
        local nx, ny = x + (w - nameW) / 2, y + (h - nameH) / 2
        local shadow = math.max(2, math.floor(nameH * 0.05))
        love.graphics.setColor(NAME_SHADOW)
        ViewUtil.printScaledPixelText(name, nx + shadow, ny + shadow, nameW, nameH)
        love.graphics.setColor(ii == gameState.currentTurnPlayer and CURRENT_NAME_COLOR or NAME_COLOR)
        ViewUtil.printScaledPixelText(name, nx, ny, nameW, nameH)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return OverviewEntity
