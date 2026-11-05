--- Game action: top the bonus pool (GameState.bonusPool) up to GameRules.bonusSurrounds.numBonusTiles,
--- drawing randomly from the bag (see TileDraw: the tower refills the bag if it runs out. If both run
--- out the pool is left short).
--- Performed once at the start of the game. (Later: after every placement turn, to top it back up)
---
--- ctx.events records what happened, in order, so the view can animate it:
---     { pool = { TileType -> count } }   tiles put in the pool
---     { refill = { TileType -> count } } tower contents moved into the bag
local Action = require("cloudless_sky.action.action")
local TileDraw = require("cloudless_sky.action.tile_draw")

---@class FillBonusPoolAction : Action
local FillBonusPoolAction = Action:extend()
local ACTION_NAME = "FillBonusPool"

Action.register(ACTION_NAME, FillBonusPoolAction)

-- happens between turns: players can't undo it
FillBonusPoolAction.undoBarrier = true

function FillBonusPoolAction:new()
    FillBonusPoolAction.super.new(self, ACTION_NAME, {
        -- set by perform:
        -- rngStateBefore: rng state before any tiles were drawn
        -- events: see file header
    })
end

function FillBonusPoolAction.deserialize(ctx)
    local action = FillBonusPoolAction()
    if ctx then
        action.ctx.rngStateBefore = ctx.rngStateBefore
        action.ctx.events = ctx.events
    end
    return action
end

--- @return integer how many tiles the bonus pool holds when full
function FillBonusPoolAction.capacity(gameState)
    return gameState.rules.bonusSurrounds.numBonusTiles
end

function FillBonusPoolAction:validate(gameState)
    if gameState.bonusPool:total() >= FillBonusPoolAction.capacity(gameState) then
        return false, "the bonus pool is already full"
    end
    return true, nil
end

function FillBonusPoolAction:perform(gameState)
    local ctx = self.ctx
    ctx.rngStateBefore = gameState.rng:getState()
    ctx.events = {}

    local current = nil
    local needed = FillBonusPoolAction.capacity(gameState) - gameState.bonusPool:total()
    TileDraw.draw(gameState, needed, function(tileType)
        gameState.bonusPool:addTile(tileType)
        if not current then
            current = { pool = {} }
            table.insert(ctx.events, current)
        end
        current.pool[tileType] = (current.pool[tileType] or 0) + 1
    end, function(moved)
        table.insert(ctx.events, { refill = moved })
        -- tiles drawn after the refill go in a new event
        current = nil
    end)
    return {}
end

function FillBonusPoolAction:undo(gameState)
    local ctx = self.ctx
    for ii = #ctx.events, 1, -1 do
        local event = ctx.events[ii]
        if event.refill then
            TileDraw.undoRefill(gameState, event.refill)
        else
            for tileType, count in pairs(event.pool) do
                gameState.bonusPool:removeTiles(tileType, count)
                gameState.tileBag:addTiles(tileType, count)
            end
        end
    end
    gameState.rng:setState(ctx.rngStateBefore)
end

return FillBonusPoolAction
