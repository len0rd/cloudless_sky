--- Action to advance current player in the round by one
local Action = require("cloudless_sky.action.action")

---@class NextPlayerAction : Action
local NextPlayerAction = Action:extend()
local ACTION_NAME = "NextPlayer"

Action.register(ACTION_NAME, NextPlayerAction)

function NextPlayerAction:new()
    NextPlayerAction.super.new(self, ACTION_NAME, {})
end

function NextPlayerAction.deserialize(data)
    return NextPlayerAction()
end

function NextPlayerAction:perform(gameState)
    if gameState.currentRoundPhase == gameState.RoundPhase.TILE_PLACEMENT then
        -- during TilePlacement, players are allowed to pass. So ensure current
        -- turn player is always a non-passed player
        local startPlayer = gameState.currentTurnPlayer
        local numPlayers = #gameState.players
        local found = false

        for i = 1, numPlayers do
            local idx = ((startPlayer - 1 + i) % numPlayers) + 1
            --- if player has not passed and has some tiles remaining in their hand
            if not gameState.players[idx].passedForPhase and gameState.players[idx].hand:total() > 0 then
                gameState.currentTurnPlayer = idx
                found = true
                break
            end
        end

        if not found then
            --- all players have passed
            --- TODO: should be an action!
            return { "AdvanceRound" }
        end
    else
        gameState.currentTurnPlayer = (gameState.currentTurnPlayer % #gameState.players) + 1
    end
    return {}
end

function NextPlayerAction:undo(gameState)
    gameState.currentTurnPlayer = ((gameState.currentTurnPlayer - 2) % #gameState.players) + 1
end

return NextPlayerAction
