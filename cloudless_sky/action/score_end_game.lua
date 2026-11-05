--- Game action: score a player's end-game bonuses once the final round is over
---
--- Per the rules (see EndGameBonus): completed stars and numbers covered across the board earn points.
--- Each player is scored once (Player.endGameBonus is set when they have been).
---
--- Follow-up actions:
---     - AddScoreAction with the bonus total, if there is one
local Action = require("cloudless_sky.action.action")
local AddScoreAction = require("cloudless_sky.action.add_score")
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")

---@class ScoreEndGameAction : Action
local ScoreEndGameAction = Action:extend()
local ACTION_NAME = "ScoreEndGame"

Action.register(ACTION_NAME, ScoreEndGameAction)

-- the game is over: final scoring can't be undone
ScoreEndGameAction.undoBarrier = true

--- @param playerIdx integer GameState index of the player to score
function ScoreEndGameAction:new(playerIdx)
    ScoreEndGameAction.super.new(self, ACTION_NAME, {
        playerIdx = playerIdx,
        -- set by perform:
        -- bonuses: the bonuses earned (see EndGameBonus)
        -- total: points they add up to
    })
end

function ScoreEndGameAction.deserialize(ctx)
    local action = ScoreEndGameAction(ctx.playerIdx)
    action.ctx.bonuses = ctx.bonuses
    action.ctx.total = ctx.total
    return action
end

function ScoreEndGameAction:validate(gameState)
    local player = gameState.players[self.ctx.playerIdx]
    if not player then
        return false, "invalid playerIdx " .. tostring(self.ctx.playerIdx)
    end
    if not gameState:isFinalRound() or not gameState:allPlayersPassed() then
        return false, "the game isn't over yet"
    end
    if player.endGameBonus ~= nil then
        return false, "player " .. self.ctx.playerIdx .. " has already been scored"
    end
    return true, nil
end

function ScoreEndGameAction:perform(gameState)
    local ctx = self.ctx
    local player = gameState.players[ctx.playerIdx]
    ctx.bonuses = EndGameBonus.forPlayer(gameState.rules, player)
    ctx.total = EndGameBonus.total(ctx.bonuses)
    player.endGameBonus = ctx.total

    if ctx.total > 0 then
        return { AddScoreAction(ctx.playerIdx, ctx.total) }
    end
    return {}
end

function ScoreEndGameAction:undo(gameState)
    gameState.players[self.ctx.playerIdx].endGameBonus = nil
end

return ScoreEndGameAction
