--- State machine for a single player turn during a TilePlacement phase
local Object = require("cloudless_sky.extern.classic")
local TilePlacementTurnStateMachine = Object:extend()

local BoxedViewSys = require("cloudless_sky.systems.boxed_view")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local MousePressedSys = require("cloudless_sky.systems.mouse_pressed")
local PlaceTileDialogEntity = require("cloudless_sky.entities.place_tile_dialog_entity")
local PlayerMatTileAnchorSys = require("cloudless_sky.systems.player_mat_tile_anchor")

TilePlacementTurnStateMachine.STATES = {
    IDLE = 1,
    SELECTING_TILE = 2,
    WAITING_TO_PLACE = 3,
    SCORING = 4,
    GETTING_BONUS = 5,
}

function TilePlacementTurnStateMachine:new()
    -- nah
    self.state = self.STATES.IDLE
    self.mouseClicked = false
    self.cameraZoom = 1.0
end

function TilePlacementTurnStateMachine:enter(fromState, playerIdx, gameState, graphicsState)
    self.state = self.STATES.IDLE
    self.playerIdx = playerIdx
    self.gameState = gameState
    self.graphicsState = graphicsState
    self.spacePressed = false
    print("entering PlacementTurnSM for " .. tostring(playerIdx))
end

function TilePlacementTurnStateMachine:update(dt)
    if self.state == self.STATES.IDLE then
        -- transition to players mat
    end
    if self.spacePressed then
        GameStateMachineMgr.pop()
        return
    end
    local mousePressSys = self.graphicsState.world:getSystem(MousePressedSys)
    if self.mouseClicked and mousePressSys and mousePressSys.lastPressedEntity then
        -- TODO: hacky hacky hacky hacky hacky hacky hacky hacky hacky hacky hacky hacky

        local pressCtx = mousePressSys.lastPressedEntity.mouseHandler.clickEvent
        print("looks like a button press was handled!: " .. table.shallowPrint(pressCtx))
        local placementOpts = self.gameState.players[pressCtx.playerIdx]:generatePlacementPossibilities(
            pressCtx.starIdx,
            pressCtx.slotIdx,
            self.gameState:getCurrentWildType()
        )
        local prompt = PlaceTileDialogEntity.new(
            pressCtx.playerIdx,
            pressCtx.starIdx,
            pressCtx.slotIdx,
            self.gameState:getMatSlotCost(pressCtx.starIdx, pressCtx.slotIdx),
            placementOpts,
            self.gameState:getStarType(pressCtx.starIdx)
        )
        self.graphicsState.world:addEntity(prompt)

        local w, h = love.graphics.getPixelDimensions()
        PlayerMatTileAnchorSys.ensureEntityFullyVisible(prompt, w, h, self.graphicsState.matEntities)
    end

    self:centerCamera()

    self.graphicsState.world:emit("update", dt, self.gameState)

    if self.mouseClicked then
        self.graphicsState.world:emit("leaveUpdate")
    end
end

function TilePlacementTurnStateMachine:draw()
    self.graphicsState.world:emit("draw", self.gameState)
end

function TilePlacementTurnStateMachine:mousepressed(x, y, button, istouch)
    print("emit mouse press!")
    self.graphicsState.world:emit("mousepressed", x, y, button, istouch)
    self.mouseClicked = true
end

function TilePlacementTurnStateMachine:keyreleased(key, code)
    if key == "space" then
        self.spacePressed = true
    end
end

function TilePlacementTurnStateMachine:resize(w, h)
    self.graphicsState.world:emit("resize", w, h, self.graphicsState)
end

function TilePlacementTurnStateMachine:centerCamera()
    local matCenterX, matCenterY = BoxedViewSys.worldCenter(self.graphicsState.matEntities[self.playerIdx])

    camera:zoomTo(self.cameraZoom)
    camera:lockPosition(matCenterX, matCenterY)
end

return TilePlacementTurnStateMachine
