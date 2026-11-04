--- Action for a player passing for the rest of the tile placement phase
---
--- Per the rules (see docs/reference/rulebooks/azul-summer-pavilion.md "Passing"):
---     - the player keeps up to GameState:tileCarryoverLimit() tiles for the next round
---     - all other tiles in their hand are discarded to the tower (GameState.discard)
---     - they lose 1 point per discarded tile (the score can't go below 1)
---     - they take no more turns this round (Player.passedForPhase)
---
--- Kept tiles stay in the player's hand: the rules move them back next to the board before the
--- next round's tile pickup anyway, and a player who passed takes no more turns this round.
---
--- Follow-up actions:
---     - AddScoreAction with the (negative) penalty, if there is one
local Action = require("cloudless_sky.action.action")
local AddScoreAction = require("cloudless_sky.action.add_score")
local TileType = require("cloudless_sky.model.tile_type")

---@class PassAction : Action
local PassAction = Action:extend()
local ACTION_NAME = "Pass"

Action.register(ACTION_NAME, PassAction)

-- lowest score a pass penalty can bring a player to
local MIN_SCORE_AFTER_PENALTY = 1

--- @param playerIdx integer GameState index of the player passing
--- @param keep table TileType -> count of tiles from the player's hand to keep for the next round.
---     Missing types keep 0
function PassAction:new(playerIdx, keep)
    local keepCopy = {}
    for tileType, count in pairs(keep or {}) do
        keepCopy[tileType] = count
    end
    PassAction.super.new(self, ACTION_NAME, {
        playerIdx = playerIdx,
        keep = keepCopy,
        -- set by perform:
        -- discarded: TileType -> count of tiles discarded to the tower
        -- penalty: points actually lost (after the score floor)
    })
end

function PassAction.deserialize(ctx)
    local action = PassAction(ctx.playerIdx, ctx.keep)
    action.ctx.discarded = ctx.discarded
    action.ctx.penalty = ctx.penalty
    return action
end

--- @return integer total number of tiles in a TileType -> count table
local function total(counts)
    local sum = 0
    for _, count in pairs(counts) do
        sum = sum + count
    end
    return sum
end

function PassAction:validate(gameState)
    local ctx = self.ctx
    local player = gameState.players[ctx.playerIdx]
    if not player then
        return false, "invalid playerIdx " .. tostring(ctx.playerIdx)
    end
    if player.passedForPhase then
        return false, "player " .. ctx.playerIdx .. " has already passed"
    end
    for tileType, count in pairs(ctx.keep) do
        if not TileType[tileType] then
            return false, "unknown tile type " .. tostring(tileType)
        end
        if type(count) ~= "number" or count < 0 or count ~= math.floor(count) then
            return false, "invalid keep count " .. tostring(count) .. " for " .. tileType
        end
        if count > player.hand:num(tileType) then
            return false, "can't keep " .. count .. " " .. tileType .. ", only " .. player.hand:num(tileType) .. " in hand"
        end
    end
    local limit = gameState:tileCarryoverLimit()
    if total(ctx.keep) > limit then
        return false, "can't keep " .. total(ctx.keep) .. " tiles, the limit is " .. limit
    end
    return true, nil
end

--- @return integer penalty Points a player with \p score loses for discarding \p numDiscarded tiles
---     (the score can't go below MIN_SCORE_AFTER_PENALTY)
function PassAction.penaltyFor(score, numDiscarded)
    return math.max(0, math.min(numDiscarded, score - MIN_SCORE_AFTER_PENALTY))
end

function PassAction:perform(gameState)
    local valid, reason = self:validate(gameState)
    assert(valid, "Invalid PassAction: " .. tostring(reason))

    local ctx = self.ctx
    local player = gameState.players[ctx.playerIdx]

    ctx.discarded = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        local discard = player.hand:num(tileType) - (ctx.keep[tileType] or 0)
        if discard > 0 then
            player.hand:removeTiles(tileType, discard)
            gameState.discard:addTiles(tileType, discard)
            ctx.discarded[tileType] = discard
        end
    end
    player.passedForPhase = true

    ctx.penalty = PassAction.penaltyFor(player.score, total(ctx.discarded))
    if ctx.penalty > 0 then
        return { AddScoreAction(ctx.playerIdx, -ctx.penalty) }
    end
    return {}
end

--- Reverse perform. The penalty is undone by its AddScoreAction (GameState undoes follow-ups individually)
function PassAction:undo(gameState)
    local ctx = self.ctx
    local player = gameState.players[ctx.playerIdx]
    for tileType, count in pairs(ctx.discarded or {}) do
        gameState.discard:removeTiles(tileType, count)
        player.hand:addTiles(tileType, count)
    end
    player.passedForPhase = false
end

--- Suggest which tiles to keep when passing:
---     1. as many of next round's wild color as possible (wilds are most flexible)
---     2. then fill from the most plentiful remaining colors, taking as many of each as fit before
---        moving to the next (ties broken by TileType.ORDERED)
--- @param hand TileBag the player's hand
--- @param limit integer max tiles that may be kept
--- @param nextWildType TileType|nil next round's wild color. nil in the final round
--- @return table keep TileType -> count. Only types with count > 0 are present
function PassAction.suggestKeep(hand, limit, nextWildType)
    local keep = {}
    local remaining = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        remaining[tileType] = hand:num(tileType)
    end

    local slotsLeft = limit
    if nextWildType and slotsLeft > 0 and remaining[nextWildType] > 0 then
        local take = math.min(slotsLeft, remaining[nextWildType])
        keep[nextWildType] = take
        remaining[nextWildType] = remaining[nextWildType] - take
        slotsLeft = slotsLeft - take
    end

    -- most plentiful first. ties keep TileType.ORDERED order
    local byCount = {}
    for ii, tileType in ipairs(TileType.ORDERED) do
        byCount[ii] = { tileType = tileType, order = ii }
    end
    table.sort(byCount, function(x, y)
        if remaining[x.tileType] ~= remaining[y.tileType] then
            return remaining[x.tileType] > remaining[y.tileType]
        end
        return x.order < y.order
    end)
    for _, entry in ipairs(byCount) do
        if slotsLeft <= 0 then
            break
        end
        local take = math.min(slotsLeft, remaining[entry.tileType])
        if take > 0 then
            keep[entry.tileType] = (keep[entry.tileType] or 0) + take
            slotsLeft = slotsLeft - take
        end
    end
    return keep
end

return PassAction
