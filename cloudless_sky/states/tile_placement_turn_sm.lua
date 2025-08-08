--- State machine for a single player turn during a TilePlacement phase
local Object = require("cloudless_sky.extern.classic")
local TilePlacementTurnStateMachine = Object:extend()

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
end

function TilePlacementTurnStateMachine:enter(playerIdx, gameState)
    self.state = self.STATES.IDLE
    self.playerIdx = playerIdx
    self.gameState = gameState
end

function TilePlacementTurnStateMachine:update(dt)
    -- when blocking animations are in progress, dont run the state machine
    if not self.blockingAnimMgr:isEmpty() then
        self.blockingAnimMgr:update(dt)
        return
    end

    if self.state == self.STATES.IDLE then
        -- transition to players mat
    end
end

return TilePlacementTurnStateMachine
