--- Game action: Phase 3 upkeep between rounds
---
--- Per the rules:
---     - advance to the next round (new wild color)
---     - the start player token holder starts the next round. The token returns to the center
---     - kept tiles go back next to the board. They already stay in the player's hand (see PassAction)
local Action = require("cloudless_sky.action.action")

---@class EndRoundAction : Action
local EndRoundAction = Action:extend()
local ACTION_NAME = "EndRound"

Action.register(ACTION_NAME, EndRoundAction)

-- happens between turns: players can't undo it
EndRoundAction.undoBarrier = true

function EndRoundAction:new()
    EndRoundAction.super.new(self, ACTION_NAME, {
        -- set by perform (values before this action, for undo):
        -- roundIdx, phase, startPlayer, startTokenHolder, passed (playerIdx -> passedForPhase)
    })
end

function EndRoundAction.deserialize(ctx)
    local action = EndRoundAction()
    for key, value in pairs(ctx or {}) do
        action.ctx[key] = value
    end
    return action
end

function EndRoundAction:validate(gameState)
    if gameState:isFinalRound() then
        return false, "the final round has no round end upkeep"
    end
    if not gameState:allPlayersPassed() then
        return false, "not every player has passed"
    end
    return true, nil
end

function EndRoundAction:perform(gameState)
    local ctx = self.ctx
    ctx.roundIdx = gameState.round.idx
    ctx.phase = gameState.round.phase
    ctx.startPlayer = gameState.startPlayer
    ctx.startTokenHolder = gameState.startTokenHolder
    ctx.passed = {}
    for ii, player in ipairs(gameState.players) do
        ctx.passed[ii] = player.passedForPhase
        player.passedForPhase = false
    end

    gameState.round.idx = gameState.round.idx + 1
    gameState.round.phase = gameState.RoundPhase.TILE_SELECTION
    gameState.startPlayer = gameState.startTokenHolder or gameState.startPlayer
    gameState.startTokenHolder = nil
    return {}
end

function EndRoundAction:undo(gameState)
    local ctx = self.ctx
    gameState.round.idx = ctx.roundIdx
    gameState.round.phase = ctx.phase
    gameState.startPlayer = ctx.startPlayer
    gameState.startTokenHolder = ctx.startTokenHolder
    for ii, player in ipairs(gameState.players) do
        player.passedForPhase = ctx.passed[ii]
    end
end

return EndRoundAction
