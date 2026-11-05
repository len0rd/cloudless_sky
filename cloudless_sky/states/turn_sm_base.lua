--- Base class for a single player's turn (tile selection or tile placement).
--- Handles what every turn does the same way:
---     - ending the turn (HUD Done, or space as a debug shortcut) pops back to the GameRound
---     - Undo reverts the player's most recent choice this turn (GameState:undoLastChoice)
---     - the view toggle button
---     - keeping the HUD's Done/Pass/Undo buttons in sync with the turn state
---
--- Subclasses implement:
---     onEnter()                    set up the turn and its initial state (call self:_setState)
---     hudButtons(state)            -> doneEnabled, passEnabled, undoEnabled for a turn state
---     stateFromHistory()           turn state implied by the actions taken so far this turn
---     onClickEvent(pressCtx, e)    any other click event
--- and optionally:
---     onUpdate(dt)                 called at the start of every update
---     onUndone(undoneActions)      animate an undo
---     onLeave()                    clean up before the turn ends
local WorldStateMachine = require("cloudless_sky.states.world_sm")
local Components = require("cloudless_sky.components")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

---@class TurnStateMachine : WorldStateMachine
local TurnStateMachine = WorldStateMachine:extend()

function TurnStateMachine:enter(fromState, playerIdx, gameState, graphicsState)
    self:_bind(gameState, graphicsState)
    self.playerIdx = playerIdx
    self.endTurnRequested = false
    self.undoEnabled = false
    self:onEnter()
end

--- Set the turn state and keep the HUD buttons in sync with it
function TurnStateMachine:_setState(newState)
    self.state = newState
    local done, pass, undo = self:hudButtons(newState)
    local hud = self.graphicsState.hud.container
    hud:setDoneEnabled(done)
    hud:setPassEnabled(pass)
    self.undoEnabled = undo
    hud:setUndoEnabled(undo)
end

--- Undo the player's most recent choice this turn
function TurnStateMachine:_undo()
    local undone = self.gameState:undoLastChoice()
    if not undone then
        return
    end
    self:onUndone(undone)
    self:_setState(self:stateFromHistory())
end

function TurnStateMachine:onUpdate(dt) end

function TurnStateMachine:onUndone(undoneActions) end

function TurnStateMachine:onLeave() end

function TurnStateMachine:handleUserInput()
    local pressCtx, entity = self:pendingClick()
    if not pressCtx then
        -- no click, or the entity handled a click that doesnt need state machine interaction
        return
    end
    local eventTypes = Components.mouseHandler.eventTypes
    if self:handleCommonClick(pressCtx) then
        return
    elseif pressCtx.type == eventTypes.endTurnClicked then
        self.endTurnRequested = true
    elseif pressCtx.type == eventTypes.undoClicked then
        if self.undoEnabled then
            self:_undo()
        end
    else
        self:onClickEvent(pressCtx, entity)
    end
end

function TurnStateMachine:update(dt)
    self:onUpdate(dt)

    if self.endTurnRequested then
        self:onLeave()
        GameStateMachineMgr.pop()
        return
    end

    self:handleUserInput()
    self:updateWorld(dt)
end

function TurnStateMachine:keyreleased(key, code)
    if key == "space" then
        self.endTurnRequested = true
    else
        WorldStateMachine.keyreleased(self, key, code)
    end
end

return TurnStateMachine
