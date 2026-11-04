local cute = require("cloudless_sky.extern.cute")
local Action = require("cloudless_sky.action.action")
local AddScoreAction = require("cloudless_sky.action.add_score")
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")

local newGame = function()
    return GameState(GameRules.currentRules(), { "p1", "p2" })
end

notion("AddScoreAction perform adds and undo subtracts", function()
    local gameState = newGame()
    local startScore = gameState.players[2].score

    local action = AddScoreAction(2, 3)
    check(#action:perform(gameState)).is(0)
    check(gameState.players[2].score).is(startScore + 3)
    -- other players unaffected
    check(gameState.players[1].score).is(startScore)

    action:undo(gameState)
    check(gameState.players[2].score).is(startScore)
end)

notion("AddScoreAction serialize/deserialize roundtrip", function()
    local action = AddScoreAction(2, 7)
    local serialized = action:serialize()
    check(serialized.name).is("AddScore")
    check(serialized.ctx.playerIdx).is(2)
    check(serialized.ctx.score).is(7)

    local restored = Action.deserialize(serialized)
    check(restored.name).is("AddScore")
    check(restored.ctx.playerIdx).is(2)
    check(restored.ctx.score).is(7)
end)
