--- Base class for state machines that drive the ECS world: updating/drawing it, routing mouse
--- presses, and pointing the camera at the current view.
---
--- Views: each phase has a home view (setViewFocus: the table while selecting, the current player's mat
--- while placing). The HUD's view button zooms out from it to the overview (the whole game: table and
--- every mat). There, clicking the table or any mat shows that area; the button (named after the home
--- view) goes back home.
--- Only the top state machine on the GameStateMachineMgr stack gets love callbacks, so each one
--- drives the world itself through these helpers.
local Object = require("cloudless_sky.extern.classic")
local Components = require("cloudless_sky.components")
local Anim = require("cloudless_sky.anim")
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
    OVERVIEW = "overview",
}

-- the view button's label when it leads to each view
local VIEW_LABEL = {
    table = "Table",
    mat = "Mat",
    overview = "Overview",
}

function WorldStateMachine:_bind(gameState, graphicsState)
    self.gameState = gameState
    self.graphicsState = graphicsState
    self.mouseClicked = false
end

--- Make \p focus (WorldStateMachine.VIEW.TABLE or MAT: the current player's) the phase's home view,
--- and show it
function WorldStateMachine:setViewFocus(focus)
    self.graphicsState.homeView = focus
    self:showView(focus, nil)
end

--- Point the camera at \p focus (WorldStateMachine.VIEW), and update the HUD's view button
--- @param matIdx integer|nil for VIEW.MAT: whose mat. nil: the current player's
function WorldStateMachine:showView(focus, matIdx)
    local gs = self.graphicsState
    gs.viewFocus = focus
    gs.viewMatIdx = matIdx
    if gs.overview then
        gs.overview.active = focus == WorldStateMachine.VIEW.OVERVIEW
    end
    local target = self:atHome() and WorldStateMachine.VIEW.OVERVIEW or gs.homeView
    gs.hud.container:setViewToggle(VIEW_LABEL[target], true)
end

--- @return boolean True if the camera is on the phase's home view
function WorldStateMachine:atHome()
    local gs = self.graphicsState
    if gs.viewFocus ~= gs.homeView then
        return false
    end
    return gs.viewFocus ~= WorldStateMachine.VIEW.MAT
        or gs.viewMatIdx == nil
        or gs.viewMatIdx == self.gameState.currentTurnPlayer
end

--- The HUD's view button: from the home view, zoom out to the overview. Anywhere else, back home
function WorldStateMachine:toggleViewFocus()
    if self:atHome() then
        self:showView(WorldStateMachine.VIEW.OVERVIEW, nil)
    else
        self:showView(self.graphicsState.homeView, nil)
    end
end

--- @return table entity the world entity the camera is focused on
function WorldStateMachine:focusEntity()
    local gs = self.graphicsState
    if gs.viewFocus == WorldStateMachine.VIEW.TABLE then
        return gs.table
    elseif gs.viewFocus == WorldStateMachine.VIEW.OVERVIEW and gs.overview then
        return gs.overview
    end
    return gs.matEntities[gs.viewMatIdx or self.gameState.currentTurnPlayer]
end

-- how quickly the camera eases to a new view (see Anim.cameraStep)
local CAMERA_STIFFNESS = 5
-- close enough to the target to stop easing: world units, and zoom ratio
local CAMERA_SNAP_DIST = 0.25
local CAMERA_SNAP_ZOOM = 1e-4

--- Ease the camera toward the focused view: the focused entity fitted and centered in the space right
--- of the HUD (and left of rightInset).
---
--- The world point on the area's center and the zoom ease together, by the same share each frame (the
--- zoom in log space, so zooming in and out feel alike), so a change of view is one smooth zoom + pan.
--- The camera itself is placed from those each frame, keeping the eased point on the area's center at
--- any zoom
--- @param dt number|nil seconds since the last frame. nil: jump straight there
function WorldStateMachine:focusCamera(dt)
    local gs = self.graphicsState
    local hudW = gs.hud.container.boundingBox.w
    local screenW = love.graphics.getPixelDimensions()
    local areaLeft, areaRight = hudW, screenW - self:rightInset()
    local centerX, centerY, zoom = BoxedViewSys.worldFocus(self:focusEntity(), areaLeft, areaRight)
    -- the world point to put on the area's center: undo worldFocus's shift for the HUD
    local offset = (areaLeft + areaRight) / 2 - screenW / 2
    local targetX = centerX + offset / zoom

    local view = gs.cameraView
    local step = dt and Anim.cameraStep(CAMERA_STIFFNESS, dt) or 1
    if not view then
        view = { x = targetX, y = centerY, zoom = zoom }
        gs.cameraView = view
    else
        view.x = view.x + (targetX - view.x) * step
        view.y = view.y + (centerY - view.y) * step
        view.zoom = math.exp(math.log(view.zoom) + (math.log(zoom) - math.log(view.zoom)) * step)
    end
    if math.abs(view.x - targetX) < CAMERA_SNAP_DIST
        and math.abs(view.y - centerY) < CAMERA_SNAP_DIST
        and math.abs(view.zoom / zoom - 1) < CAMERA_SNAP_ZOOM
    then
        view.x, view.y, view.zoom = targetX, centerY, zoom
    end

    camera:zoomTo(view.zoom)
    camera:lookAt(view.x - offset / view.zoom, view.y)
    -- where the camera is heading. Lets automation wait for it to settle
    gs.cameraTarget = { x = centerX, y = centerY }
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
    elseif pressCtx.type == eventTypes.viewAreaClicked then
        -- an area picked in the overview
        if pressCtx.area == "table" then
            self:showView(WorldStateMachine.VIEW.TABLE, nil)
        else
            self:showView(WorldStateMachine.VIEW.MAT, pressCtx.playerIdx)
        end
        return true
    elseif pressCtx.type == eventTypes.matBonusClicked then
        self:showBonusInfo(pressCtx.playerIdx, pressCtx.bonusIdx, pressCtx.x, pressCtx.y)
        return true
    end
    return false
end

--- Open the info dialog for bonus space \p bonusIdx of player \p playerIdx's mat and outline the slots it
--- needs. The dialog goes below the outlined slots (so it doesn't cover them), at the icon's x
--- (\p x, \p y: the bottom of its icon)
function WorldStateMachine:showBonusInfo(playerIdx, bonusIdx, x, y)
    local BonusInfoDialogEntity = require("cloudless_sky.entities.bonus_info_dialog_entity")
    local GameRules = require("cloudless_sky.model.game_rules")
    local mat = self.gameState.players[playerIdx].mat
    local bonus = mat:bonusAt(bonusIdx)
    local filled = 0
    for _, slot in ipairs(bonus.slots) do
        if mat:isOccupied(slot[1], slot[2]) then
            filled = filled + 1
        end
    end
    local dialog = BonusInfoDialogEntity.new({
        kind = bonus.kind,
        tiles = GameRules.bonusTiles(self.gameState.rules, bonus.kind),
        filled = filled,
        total = #bonus.slots,
    })
    local matEntity = self.graphicsState.matEntities[playerIdx]
    local bottom = y
    for _, slot in ipairs(bonus.slots) do
        local verts = matEntity.stars[slot[1]].polys[slot[2]].verticies
        for ii = 2, #verts, 2 do
            bottom = math.max(bottom, verts[ii])
        end
    end
    dialog:placeNear(x, bottom)
    self.graphicsState.world:addEntity(dialog)
    self.graphicsState.matEntities[playerIdx]:selectBonus(bonusIdx, dialog)
end

--- Move the camera, update every entity, and clear this update's click events
function WorldStateMachine:updateWorld(dt)
    self:focusCamera(dt)
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
