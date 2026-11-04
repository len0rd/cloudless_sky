--- Action to add to a players score
local Action = require("cloudless_sky.action.action")

---@class AddScoreAction : Action
local AddScoreAction = Action:extend()
local ACTION_NAME = "AddScore"

Action.register(ACTION_NAME, AddScoreAction)

---@param playerIdx integer GameState index of the player to add the given score to
---@param score integer Number of points to add to player at playerIdx
function AddScoreAction:new(playerIdx, score)
    AddScoreAction.super.new(self, ACTION_NAME, { playerIdx = playerIdx, score = score })
end

function AddScoreAction.deserialize(ctx)
    return AddScoreAction(ctx.playerIdx, ctx.score)
end

function AddScoreAction:perform(gameState)
    local score = gameState.players[self.ctx.playerIdx].score
    gameState.players[self.ctx.playerIdx].score = score + self.ctx.score
    return {}
end

function AddScoreAction:undo(gameState)
    local score = gameState.players[self.ctx.playerIdx].score

    -- Undoing an added score should never result in a negative number
    assert(
        score - self.ctx.score >= 0,
        "Undoing an AddScoreAction ("
            .. tostring(score)
            .. " - "
            .. tostring(self.ctx.score)
            .. ") for player "
            .. tostring(self.ctx.playerIdx)
            .. " would result in a score < 0"
    )
    gameState.players[self.ctx.playerIdx].score = math.max(0, score - self.ctx.score)
end

return AddScoreAction
