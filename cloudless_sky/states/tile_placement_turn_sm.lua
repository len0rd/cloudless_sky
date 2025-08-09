--- State machine for a single player turn during a TilePlacement phase
local Object = require("cloudless_sky.extern.classic")
local TilePlacementTurnStateMachine = Object:extend()

local BoxedViewSys = require("cloudless_sky.systems.boxed_view")

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
    print("entering PlacementTurnSM!")
end

function TilePlacementTurnStateMachine:update(dt)
    if self.state == self.STATES.IDLE then
        -- transition to players mat
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
    self.graphicsState.world:emit("mousePressed", x, y, button, istouch)
    self.mouseClicked = true
end

function TilePlacementTurnStateMachine:centerCamera()
    local matCenterX, matCenterY = BoxedViewSys.worldCenter(self.graphicsState.matEntities[self.playerIdx])

    camera:zoomTo(self.cameraZoom)
    camera:lockPosition(matCenterX, matCenterY)
end

return TilePlacementTurnStateMachine
