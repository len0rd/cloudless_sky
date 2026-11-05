--- Game action: tile selection is over. Move the round on to the tile placement phase
local Action = require("cloudless_sky.action.action")

---@class StartPlacementPhaseAction : Action
local StartPlacementPhaseAction = Action:extend()
local ACTION_NAME = "StartPlacementPhase"

Action.register(ACTION_NAME, StartPlacementPhaseAction)

-- happens between turns: players can't undo it
StartPlacementPhaseAction.undoBarrier = true

function StartPlacementPhaseAction:new()
    StartPlacementPhaseAction.super.new(self, ACTION_NAME, {
        -- set by perform:
        -- previousPhase: round phase before this action
    })
end

function StartPlacementPhaseAction.deserialize(ctx)
    local action = StartPlacementPhaseAction()
    if ctx then
        action.ctx.previousPhase = ctx.previousPhase
    end
    return action
end

function StartPlacementPhaseAction:validate(gameState)
    if not gameState:allTileSourcesEmpty() then
        return false, "tile selection isn't over: tiles remain on the displays or in the center"
    end
    return true, nil
end

function StartPlacementPhaseAction:perform(gameState)
    self.ctx.previousPhase = gameState.round.phase
    gameState.round.phase = gameState.RoundPhase.TILE_PLACEMENT
    return {}
end

function StartPlacementPhaseAction:undo(gameState)
    gameState.round.phase = self.ctx.previousPhase
end

return StartPlacementPhaseAction
