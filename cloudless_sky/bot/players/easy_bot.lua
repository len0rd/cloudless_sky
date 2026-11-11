--- Easy bot: random legal choices (what the --bot test harness has always done)
---     take:   a random legal pick (LegalMoves.takes)
---     place:  sometimes passes anyway (VOLUNTARY_PASS_CHANCE); otherwise a random slot it can place in
---             and a random way to pay for it. Passes when it can't place
---     pass:   keeps PassAction.suggestKeep's tiles
---     bonus:  random tiles from the bonus pool
local BotPlayer = require("cloudless_sky.bot.bot_player")
local LegalMoves = require("cloudless_sky.model.legal_moves")
local PassAction = require("cloudless_sky.action.pass")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local TakeBonusTilesAction = require("cloudless_sky.action.take_bonus_tiles")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")
local TileType = require("cloudless_sky.model.tile_type")

---@class EasyBot : BotPlayer
local EasyBot = BotPlayer:extend()

-- chance of passing even when a tile could be placed
EasyBot.VOLUNTARY_PASS_CHANCE = 0.1

function EasyBot:chooseTake(gameState, playerIdx)
    local move = self:pick(LegalMoves.takes(gameState))
    assert(move, "no legal pick during tile selection")
    return TakeTilesAction(playerIdx, move.source, move.tileType)
end

function EasyBot:choosePlacement(gameState, playerIdx)
    local slots = LegalMoves.placeableSlots(gameState, playerIdx)
    if #slots == 0 or self.rng:random() < EasyBot.VOLUNTARY_PASS_CHANCE then
        local hand = gameState.players[playerIdx].hand
        local keep = PassAction.suggestKeep(hand, gameState:tileCarryoverLimit(), gameState:getNextRoundWildType())
        return PassAction(playerIdx, keep)
    end
    local slot = self:pick(slots)
    return PlaceTileAction(playerIdx, slot.starIdx, slot.slotIdx, self:pick(slot.possibilities))
end

function EasyBot:chooseBonusTiles(gameState, playerIdx, count)
    -- every tile in the pool, then draw from them without replacement
    local tiles = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        for _ = 1, gameState.bonusPool:num(tileType) do
            table.insert(tiles, tileType)
        end
    end
    local take = {}
    for _ = 1, math.min(count, #tiles) do
        local tileType = table.remove(tiles, self.rng:random(1, #tiles))
        take[tileType] = (take[tileType] or 0) + 1
    end
    return TakeBonusTilesAction(playerIdx, take)
end

BotPlayer.register("easy", EasyBot)

return EasyBot
