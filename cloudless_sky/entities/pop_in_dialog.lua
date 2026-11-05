--- Shared behavior for small dialogs that pop in next to something in the world
---     - pop-in scale tween
---     - screen-space frame + suit UI
---     - ephemeral, disappears on click outside of it
---     - an optional action button with a hover pulse. Pressing it sets the entity's clickEvent to
---     - a "tile xN (+ wild xN)" row
---
--- Dialogs "inherit" with setmetatable(Child, { __index = PopInDialog }), call PopInDialog.init
--- from their constructor and implement:
---     layoutContent(dt, w, h) lay out the dialog's suit widgets (layout already reset at the origin)
---     actionEvent()           (optional) clickEvent for the action button
local Concord = require("cloudless_sky.extern.concord")
local Anim = require("cloudless_sky.anim")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local BoxedViewSys = require("cloudless_sky.systems.boxed_view")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

---@class PopInDialog
---@field scale number Scale of the entire entity (pop-in tween)
---@field ui table suit instance for the dialog's widgets
local PopInDialog = {}
PopInDialog.__index = PopInDialog

-- max scale the border box will be drawn at during the pop-in
local MAX_SCALE = 1.5
local POP_IN_S = 0.25
PopInDialog.CORNER_RADIUS_SCALER = 1 / 10
PopInDialog.LAYOUT_PAD = 1

-- for debug
PopInDialog.WIDGET_BOUNDING_BOXES = false

--- Create a pop-in dialog entity
--- @param child table the dialog's method table (inherits from PopInDialog)
--- @param w integer width in screen pixels
--- @param h integer height in screen pixels
--- @return table entity
function PopInDialog.create(child, w, h)
    local entity = Concord.entity()
    entity
        :give(Components.names.boundingBox, w, h)
        :give(Components.names.mouseHandler, Constants.drawPriority.tilePlacePrompt)
        :give(Components.names.drawable, Constants.drawPriority.tilePlacePrompt)
        :give(Components.names.worldPos, 0, 0)
        -- only one pop-in dialog at a time
        :give(Components.names.uniqueGroup, "popInDialogs")
        :give(Components.names.ephemeral)
        :give(Components.names.dismissOnClickOutside)

    EUtil.extendEntity(entity, child)

    entity.scale = 0.1
    entity.transitionTween = flux.group()
    entity.transitionTween
        :to(entity, Anim.time(POP_IN_S), { scale = MAX_SCALE })
        :after(entity, Anim.time(POP_IN_S), { scale = 1.0 })

    entity.actionBtnScale = 1.0
    entity.actionHoverTween = nil
    entity.actionButton = nil

    local theme = table.copy(require("cloudless_sky.extern.suit.theme"))
    theme.color.normal.fg = { 0, 0, 0 }
    entity.ui = suit.new(theme)
    return entity
end

--- Place the dialog at the world point (worldX, worldY), flipped so it stays on screen
function PopInDialog:placeNear(worldX, worldY)
    local w, h = love.graphics.getPixelDimensions()
    BoxedViewSys.placeOnScreenNear(self, worldX, worldY, w, h)
end

--- @return integer screenX, integer screenY. Top-left of the dialog in screen coordinates,
---     snapped to whole pixels
function PopInDialog:screenOrigin()
    local x, y = camera:cameraCoords(self.worldPos.x, self.worldPos.y)
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

--- Claims any press inside the dialog. Presses outside it dismiss the dialog
--- (dismissOnClickOutside, see MousePressedSys)
function PopInDialog:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    local originX, originY = self:screenOrigin()
    if not ViewUtil.ptInRect(cameraX, cameraY, originX, originY, self.boundingBox.w, self.boundingBox.h) then
        return false
    end

    local btn = self.actionButton
    if button == 1 and btn and self.actionEvent and ViewUtil.ptInRect(cameraX, cameraY, btn.x, btn.y, btn.w, btn.h) then
        self.mouseHandler.clickEvent = self:actionEvent()
    end
    return true
end

--- @return integer w, integer h current (pop-in scaled) size of the dialog in screen pixels
function PopInDialog:scaledSize()
    return math.floor(self.boundingBox.w * self.scale), math.floor(self.boundingBox.h * self.scale)
end

function PopInDialog:update(dt, gameState)
    self.transitionTween:update(dt)
    local w, h = self:scaledSize()

    -- dialog is laid out in screen space, so the default (screen) mouse position is correct
    self.ui:enterFrame()
    local originX, originY = self:screenOrigin()
    self.ui.layout:reset(originX, originY, PopInDialog.LAYOUT_PAD, PopInDialog.LAYOUT_PAD)
    self:layoutContent(dt, w, h)
end

function PopInDialog:_actionHoverLoop(tween)
    tween:to(self, Anim.time(0.5), { actionBtnScale = 1.1 }):after(self, Anim.time(0.5), { actionBtnScale = 1.0 }):oncomplete(function()
        self:_actionHoverLoop(tween)
    end)
end

--- Add the action button as a new layout column. Pulses while hovered
--- @param colors table suit colors { normal = {bg, fg}, hovered = ..., active = ... }
function PopInDialog:actionButtonCol(label, colors, w, h, dt)
    local dialogW = self:scaledSize()
    self.actionButton = self.ui:Button(label, {
        id = "popInAction",
        draw = ViewUtil.suitButtonDraw,
        color = colors,
        cornerRadius = dialogW * PopInDialog.CORNER_RADIUS_SCALER - 3,
        outline = 2,
        scale = self.actionBtnScale,
    }, self.ui.layout:col(w, h))

    -- hover pulse is a looping idle animation: none when animations are off
    if self.actionButton.entered and not Anim.isOff() then
        self.actionHoverTween = flux.group()
        self:_actionHoverLoop(self.actionHoverTween)
    end
    if self.actionButton.hovered and self.actionHoverTween then
        self.actionHoverTween:update(dt)
    elseif self.actionButton.left then
        self.actionBtnScale = 1.0
        self.actionHoverTween = nil
    end
    return self.actionButton
end

--- Add a "tile xN" (and "wild xN" if wildCount > 0) group of columns to the current layout row.
--- Each tile and count gets \p cellW of width
function PopInDialog:tileCountCols(tileType, count, wildType, wildCount, cellW, cellH)
    local bbox = PopInDialog.WIDGET_BOUNDING_BOXES
    self.ui:Label(
        nil,
        { draw = TileView.suitDrawTile, tileType = tileType, boundingBox = bbox },
        self.ui.layout:col(cellW, cellH)
    )
    self.ui:Label(tostring(count), { draw = ViewUtil.suitLabelDraw }, self.ui.layout:col(cellW, cellH))
    if wildCount and wildCount > 0 then
        self.ui:Label(
            nil,
            { draw = TileView.suitDrawTile, tileType = wildType, boundingBox = bbox },
            self.ui.layout:col(cellW, cellH)
        )
        self.ui:Label(tostring(wildCount), { draw = ViewUtil.suitLabelDraw }, self.ui.layout:col(cellW, cellH))
    end
end

--- drawn in screen space (see DrawSys)
function PopInDialog:drawScreen(gameState)
    love.graphics.push()
    do
        local width, height = self:scaledSize()
        local cornerR = width * PopInDialog.CORNER_RADIUS_SCALER
        local originX, originY = self:screenOrigin()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", originX, originY, width, height, cornerR, cornerR)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", originX, originY, width, height, cornerR, cornerR)

        self.ui:draw()
    end
    love.graphics.pop()
end

return PopInDialog
