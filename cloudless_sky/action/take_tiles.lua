--- Player choice during tile selection: take tiles of one color from a factory display or the center
---
--- Per the rules:
---     - take all tiles of one color. The color may not be the current wild color
---       unless the source holds only wild tiles, then take one wild tile
---     - if a display holds any wild tiles, take exactly GameRules.factoryDisplay.maxWildPerTurn (default 1)
---     - from a display: all remaining tiles on it move to the center
---     - from the center: the first player to do so this round takes the start player token and
---       (if GameRules.factoryDisplay.centerFirstPickPenalty) loses 1 point per tile taken (score
---       can't go below 1)
---
--- Follow-up actions:
---     - AddScoreAction with the (negative) penalty, if there is one
local Action = require("cloudless_sky.action.action")
local AddScoreAction = require("cloudless_sky.action.add_score")
local Player = require("cloudless_sky.model.player")
local TileType = require("cloudless_sky.model.tile_type")

---@class TakeTilesAction : Action
local TakeTilesAction = Action:extend()
local ACTION_NAME = "TakeTiles"

Action.register(ACTION_NAME, TakeTilesAction)

-- GameState.CENTER. Not required from GameState to avoid a circular require
local CENTER = 0

--- @param playerIdx integer GameState index of the player taking tiles
--- @param source integer GameState.CENTER or the index of a factory display
--- @param tileType TileType color to take
function TakeTilesAction:new(playerIdx, source, tileType)
    TakeTilesAction.super.new(self, ACTION_NAME, {
        playerIdx = playerIdx,
        source = source,
        tileType = tileType,
        -- set by perform:
        -- taken: TileType -> count moved to the player's hand
        -- toCenter: TileType -> count moved from the display to the center
        -- tookToken: true if the player took the start player token
        -- penalty: points actually lost (after the score floor)
    })
end

function TakeTilesAction.deserialize(ctx)
    local action = TakeTilesAction(ctx.playerIdx, ctx.source, ctx.tileType)
    action.ctx.taken = ctx.taken
    action.ctx.toCenter = ctx.toCenter
    action.ctx.tookToken = ctx.tookToken
    action.ctx.penalty = ctx.penalty
    return action
end

--- Which tiles a player gets for picking \p tileType from \p bag
--- @param bag TileBag the source's tiles
--- @param tileType TileType the color picked
--- @param wildType TileType the current wild color
--- @param maxWild integer most wild tiles that can be taken per turn
--- @return table|nil take TileType -> count. nil if the pick isn't allowed
--- @return string|nil reason why the pick isn't allowed
function TakeTilesAction.tilesToTake(bag, tileType, wildType, maxWild)
    if not TileType[tileType] then
        return nil, "unknown tile type " .. tostring(tileType)
    end
    local count = bag:num(tileType)
    if count == 0 then
        return nil, "no " .. tileType .. " tiles there"
    end
    if tileType == wildType then
        if bag:total() ~= count then
            return nil, "can't take the wild color while other colors are there"
        end
        return { [tileType] = math.min(maxWild, count) }, nil
    end

    local take = { [tileType] = count }
    local wilds = wildType and math.min(maxWild, bag:num(wildType)) or 0
    if wilds > 0 then
        take[wildType] = wilds
    end
    return take, nil
end

--- @return integer total number of tiles in a TileType -> count table
local function total(counts)
    local sum = 0
    for _, count in pairs(counts) do
        sum = sum + count
    end
    return sum
end

--- @return TileType -> count. What this action would take from the current game state, or nil
function TakeTilesAction:_tilesToTake(gameState)
    local bag = gameState:tileSource(self.ctx.source)
    if not bag then
        return nil, "invalid tile source " .. tostring(self.ctx.source)
    end
    return TakeTilesAction.tilesToTake(
        bag,
        self.ctx.tileType,
        gameState:getCurrentWildType(),
        gameState.rules.factoryDisplay.maxWildPerTurn
    )
end

--- @return integer penalty points the player at \p playerIdx would lose for taking \p numTaken tiles
---     from \p source right now (0 unless it's the first pick from the center and the rule is on)
function TakeTilesAction.penaltyFor(gameState, playerIdx, source, numTaken)
    if source ~= CENTER or gameState.startTokenHolder ~= nil then
        return 0
    end
    if not gameState.rules.factoryDisplay.centerFirstPickPenalty then
        return 0
    end
    return Player.clampedPenalty(gameState.players[playerIdx].score, numTaken)
end

function TakeTilesAction:validate(gameState)
    local ctx = self.ctx
    if gameState.round.phase ~= gameState.RoundPhase.TILE_SELECTION then
        return false, "tiles can only be taken during tile selection"
    end
    if not gameState.players[ctx.playerIdx] then
        return false, "invalid playerIdx " .. tostring(ctx.playerIdx)
    end
    local take, reason = self:_tilesToTake(gameState)
    if not take then
        return false, reason
    end
    return true, nil
end

function TakeTilesAction:perform(gameState)
    local ctx = self.ctx
    local take = assert(self:_tilesToTake(gameState))
    local bag = gameState:tileSource(ctx.source)
    local player = gameState.players[ctx.playerIdx]

    ctx.taken = take
    for tileType, count in pairs(take) do
        bag:removeTiles(tileType, count)
        player.hand:addTiles(tileType, count)
    end

    ctx.toCenter = {}
    ctx.tookToken = false
    ctx.penalty = 0
    if ctx.source ~= CENTER then
        for _, tileType in ipairs(TileType.ORDERED) do
            local count = bag:num(tileType)
            if count > 0 then
                bag:removeTiles(tileType, count)
                gameState.center:addTiles(tileType, count)
                ctx.toCenter[tileType] = count
            end
        end
    elseif gameState.startTokenHolder == nil then
        ctx.penalty = TakeTilesAction.penaltyFor(gameState, ctx.playerIdx, ctx.source, total(take))
        ctx.tookToken = true
        gameState.startTokenHolder = ctx.playerIdx
    end

    if ctx.penalty > 0 then
        return { AddScoreAction(ctx.playerIdx, -ctx.penalty) }
    end
    return {}
end

function TakeTilesAction:undo(gameState)
    local ctx = self.ctx
    local bag = gameState:tileSource(ctx.source)
    local player = gameState.players[ctx.playerIdx]

    if ctx.tookToken then
        gameState.startTokenHolder = nil
    end
    for tileType, count in pairs(ctx.toCenter) do
        gameState.center:removeTiles(tileType, count)
        bag:addTiles(tileType, count)
    end
    for tileType, count in pairs(ctx.taken) do
        player.hand:removeTiles(tileType, count)
        bag:addTiles(tileType, count)
    end
end

return TakeTilesAction
