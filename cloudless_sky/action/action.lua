--- Base class for all actions that can be taken in-game
--- - Actions are steps in the game. Performed automatically as part of the
---     game structure (advancing rounds/turns) or by Players.
--- - All actions will extend this base class
--- - Actions are serializable to support game saving
--- - All actions provide an undo method
--- - Actions may trigger additional actions
local Object = require("cloudless_sky.extern.classic")

---@class Action : Object
---@field name string Name of this action. corresponds to its type
---@field isFollowUp boolean False if this action was a player choice (passed to GameState:performAction).
---     True if it was performed automatically as a consequence of another action.
---     GameState:undoLastChoice undoes history up to and including the most recent non-follow-up action
local Action = Object:extend()

--- List of all known actions. Action implementations add their name to this list
Action.known = {}

function Action.register(name, type)
    assert(Action.known[name] == nil, "Action '" .. name .. "' is already registered")
    Action.known[name] = type
end

function Action:new(name, ctx)
    self.name = name
    self.ctx = ctx
    self.isFollowUp = false
end

--- Check if this action can be performed on the given game state. Actions with preconditions
--- should override this.
--- @param gameState GameState current state of the game
--- @return boolean valid
--- @return string|nil reason Why the action is invalid
function Action:validate(gameState)
    return true, nil
end

--- Perform this action
--- @param gameState GameState current state of the game on which the action will be performed
--- @return table[Action] List of actions that have resulted from this action
function Action:perform(gameState)
    assert(false, "Actions must implement perform! Action " .. self.name .. " hasnt")
end

--- Given the current game state and action context, reverse this action
function Action:undo(gameState)
    assert(false, "Actions must implement undo! Action " .. self.name .. " hasnt")
end

function Action:serialize()
    local serialized = {
        name = self.name,
    }
    if self.ctx ~= nil and next(self.ctx) ~= nil then
        serialized.ctx = self.ctx
    end
    if self.isFollowUp then
        serialized.isFollowUp = true
    end

    return serialized
end

function Action.deserialize(data)
    assert(Action.known[data.name], "Action '" .. data.name .. "' has not been registered for Action.deserialize")
    local action = Action.known[data.name].deserialize(data.ctx)
    action.isFollowUp = data.isFollowUp == true
    return action
end

return Action
