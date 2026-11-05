--- State machine once the game is over: the world keeps running (animations, hover) so the final
--- state can be looked at, and the view toggle and menu still work. Every turn button is disabled
local WorldStateMachine = require("cloudless_sky.states.world_sm")

---@class GameOverStateMachine : WorldStateMachine
local GameOverStateMachine = WorldStateMachine:extend()

function GameOverStateMachine:enter(fromState, gameState, graphicsState)
    self:_bind(gameState, graphicsState)
    local hud = graphicsState.hud.container
    hud:setDoneEnabled(false)
    hud:setPassEnabled(false)
    hud:setUndoEnabled(false)
    self:setViewFocus(graphicsState.viewFocus)
end

function GameOverStateMachine:update(dt)
    local pressCtx = self:pendingClick()
    if pressCtx then
        self:handleCommonClick(pressCtx)
    end
    self:updateWorld(dt)
end

return GameOverStateMachine
