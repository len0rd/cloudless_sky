--- Game action: start a new turn for a player.
local Action = require("cloudless_sky.action.action")

---@class BeginTurnAction : Action
local BeginTurnAction = Action:extend()
local ACTION_NAME = "BeginTurn"

Action.register(ACTION_NAME, BeginTurnAction)

--- Players cant go back a turn
BeginTurnAction.undoBarrier = true

--- @param playerIdx integer GameState index of the player whose turn it is
function BeginTurnAction:new(playerIdx)
    BeginTurnAction.super.new(self, ACTION_NAME, {
        playerIdx = playerIdx,
        -- set by perform (values before this action):
        -- previousPlayer, previousTurnIdx
    })
end

function BeginTurnAction.deserialize(ctx)
    local action = BeginTurnAction(ctx.playerIdx)
    action.ctx.previousPlayer = ctx.previousPlayer
    action.ctx.previousTurnIdx = ctx.previousTurnIdx
    return action
end

function BeginTurnAction:validate(gameState)
    if not gameState.players[self.ctx.playerIdx] then
        return false, "invalid playerIdx " .. tostring(self.ctx.playerIdx)
    end
    return true, nil
end

function BeginTurnAction:perform(gameState)
    self.ctx.previousPlayer = gameState.currentTurnPlayer
    self.ctx.previousTurnIdx = gameState.turnIdx
    gameState.currentTurnPlayer = self.ctx.playerIdx
    gameState.turnIdx = gameState.turnIdx + 1
    return {}
end

function BeginTurnAction:undo(gameState)
    gameState.currentTurnPlayer = self.ctx.previousPlayer
    gameState.turnIdx = self.ctx.previousTurnIdx
end

return BeginTurnAction
