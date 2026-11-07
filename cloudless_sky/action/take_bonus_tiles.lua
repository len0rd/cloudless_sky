--- Action for a player picking up the bonus tiles they earned (see BonusPickup) from the bonus pool
--- into their hand. Any colors, including several of the round's wild color.
---
--- A player choice, so it can be undone (before the turn ends). The pool isn't topped back up until
--- the turn ends (GameRoundStateMachine), so undoing puts the very same tiles back
local Action = require("cloudless_sky.action.action")
local BonusPickup = require("cloudless_sky.model.bonus_pickup")
local TileType = require("cloudless_sky.model.tile_type")

---@class TakeBonusTilesAction : Action
local TakeBonusTilesAction = Action:extend()
local ACTION_NAME = "TakeBonusTiles"

Action.register(ACTION_NAME, TakeBonusTilesAction)

--- @param playerIdx integer GameState index of the player picking up
--- @param tiles table TileType -> count to take from the bonus pool
function TakeBonusTilesAction:new(playerIdx, tiles)
    local copy = {}
    for tileType, count in pairs(tiles or {}) do
        if count > 0 then
            copy[tileType] = count
        end
    end
    TakeBonusTilesAction.super.new(self, ACTION_NAME, {
        playerIdx = playerIdx,
        tiles = copy,
    })
end

function TakeBonusTilesAction.deserialize(ctx)
    return TakeBonusTilesAction(ctx.playerIdx, ctx.tiles)
end

function TakeBonusTilesAction:validate(gameState)
    local ctx = self.ctx
    local owed = BonusPickup.owed(gameState)
    if not owed then
        return false, "no bonus tiles are owed"
    end
    if owed.playerIdx ~= ctx.playerIdx then
        return false, "bonus tiles are owed to player " .. owed.playerIdx .. ", not " .. tostring(ctx.playerIdx)
    end
    local total = 0
    for tileType, count in pairs(ctx.tiles) do
        if not TileType[tileType] then
            return false, "unknown tile type " .. tostring(tileType)
        end
        if math.floor(count) ~= count or count < 0 then
            return false, "bad count " .. tostring(count) .. " of " .. tileType
        end
        if gameState.bonusPool:num(tileType) < count then
            return false, "the bonus pool has " .. gameState.bonusPool:num(tileType) .. " " .. tileType .. ", not " .. count
        end
        total = total + count
    end
    if total ~= owed.count then
        return false, "must pick up " .. owed.count .. " bonus tiles, not " .. total
    end
    return true, nil
end

function TakeBonusTilesAction:perform(gameState)
    local valid, reason = self:validate(gameState)
    assert(valid, "Invalid TakeBonusTilesAction: " .. tostring(reason))
    local hand = gameState.players[self.ctx.playerIdx].hand
    for tileType, count in pairs(self.ctx.tiles) do
        gameState.bonusPool:removeTiles(tileType, count)
        hand:addTiles(tileType, count)
    end
    return {}
end

function TakeBonusTilesAction:undo(gameState)
    local hand = gameState.players[self.ctx.playerIdx].hand
    for tileType, count in pairs(self.ctx.tiles) do
        hand:removeTiles(tileType, count)
        gameState.bonusPool:addTiles(tileType, count)
    end
end

return TakeBonusTilesAction
