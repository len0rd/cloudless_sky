--- Base class for state machines that drive the ECS world: updating/drawing it, routing mouse
--- presses, and pointing the camera at the current view (the table or the current player's mat).
--- Only the top state machine on the GameStateMachineMgr stack gets love callbacks, so each one
--- drives the world itself through these helpers.
local Object = require("cloudless_sky.extern.classic")
local Components = require("cloudless_sky.components")
local BoxedViewSys = require("cloudless_sky.systems.boxed_view")
local MousePressedSys = require("cloudless_sky.systems.mouse_pressed")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local MenuState = require("cloudless_sky.states.menu_state")

---@class WorldStateMachine : Object
---@field gameState GameState
---@field graphicsState table
local WorldStateMachine = Object:extend()

--- graphicsState.viewFocus values
WorldStateMachine.VIEW = {
    TABLE = "table",
    MAT = "mat",
}

function WorldStateMachine:_bind(gameState, graphicsState)
    self.gameState = gameState
    self.graphicsState = graphicsState
    self.mouseClicked = false
end

--- Point the camera at \p focus (WorldStateMachine.VIEW) and update the HUD's view toggle button
function WorldStateMachine:setViewFocus(focus)
    self.graphicsState.viewFocus = focus
    local label = focus == WorldStateMachine.VIEW.TABLE and "Mat" or "Table"
    self.graphicsState.hud.container:setViewToggle(label, true)
end

function WorldStateMachine:toggleViewFocus()
    if self.graphicsState.viewFocus == WorldStateMachine.VIEW.TABLE then
        self:setViewFocus(WorldStateMachine.VIEW.MAT)
    else
        self:setViewFocus(WorldStateMachine.VIEW.TABLE)
    end
end

--- @return table entity the world entity the camera is focused on
function WorldStateMachine:focusEntity()
    if self.graphicsState.viewFocus == WorldStateMachine.VIEW.TABLE then
        return self.graphicsState.table
    end
    return self.graphicsState.matEntities[self.gameState.currentTurnPlayer]
end

function WorldStateMachine:focusCamera()
    -- fit and center the focused entity in the space right of the HUD (and left of rightInset)
    local hudW = self.graphicsState.hud.container.boundingBox.w
    local screenW = love.graphics.getPixelDimensions()
    local centerX, centerY, zoom = BoxedViewSys.worldFocus(self:focusEntity(), hudW, screenW - self:rightInset())

    camera:zoomTo(zoom)
    camera:lockPosition(centerX, centerY)
    -- where the camera is heading (it eases there). Lets automation wait for it to settle
    self.graphicsState.cameraTarget = { x = centerX, y = centerY }
end

--- @return number screen pixels on the right the camera leaves free (eg: for a panel). 0 by default
function WorldStateMachine:rightInset()
    return 0
end

--- @return table|nil clickEvent, table|nil entity. The click event (and the entity that produced it)
---     from a mouse press since the last update, if any
function WorldStateMachine:pendingClick()
    if not self.mouseClicked then
        return nil, nil
    end
    local mousePressSys = self.graphicsState.world:getSystem(MousePressedSys)
    local entity = mousePressSys and mousePressSys.lastPressedEntity
    if not entity then
        return nil, nil
    end
    return entity.mouseHandler.clickEvent, entity
end

--- Open the in-game menu on top of this state machine (pausing it)
function WorldStateMachine:openMenu()
    GameStateMachineMgr.push(MenuState, self.gameState)
end

--- Handle click events every world state machine treats the same way
--- @return boolean handled
function WorldStateMachine:handleCommonClick(pressCtx)
    local eventTypes = Components.mouseHandler.eventTypes
    if pressCtx.type == eventTypes.toggleViewClicked then
        self:toggleViewFocus()
        return true
    elseif pressCtx.type == eventTypes.menuClicked then
        self:openMenu()
        return true
    end
    return false
end

--- Move the camera, update every entity, and clear this update's click events
function WorldStateMachine:updateWorld(dt)
    self:focusCamera()
    self.graphicsState.world:emit("update", dt, self.gameState)
    if self.mouseClicked then
        self.mouseClicked = false
        self.graphicsState.world:emit("leaveUpdate")
    end
end

function WorldStateMachine:draw()
    self.graphicsState.world:emit("draw", self.gameState)
end

function WorldStateMachine:mousepressed(x, y, button, istouch)
    self.graphicsState.world:emit("mousepressed", x, y, button, istouch)
    self.mouseClicked = true
end

function WorldStateMachine:keyreleased(key, code)
    if key == "escape" then
        self:openMenu()
    end
end

function WorldStateMachine:resize(w, h)
    self.graphicsState.world:emit("resize", w, h, self.graphicsState)
end

return WorldStateMachine
