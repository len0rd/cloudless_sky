--- Every choice a player can legally make right now, from the model alone. Used by the UI (what
--- clicking a tile would take) and by anything choosing moves by itself (bots)
local BonusPickup = require("cloudless_sky.model.bonus_pickup")
local GameState = require("cloudless_sky.model.game_state")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")
local TileType = require("cloudless_sky.model.tile_type")

local LegalMoves = {}

--- @param source integer GameState.CENTER or a factory display index
--- @return table|nil take TileType -> count the current player would take by picking \p tileType at
---     \p source (TakeTilesAction.tilesToTake). nil if that pick isn't allowed
function LegalMoves.takeFor(gameState, source, tileType)
    local bag = gameState:tileSource(source)
    if not bag then
        return nil
    end
    return TakeTilesAction.tilesToTake(
        bag,
        tileType,
        gameState:getCurrentWildType(),
        gameState.rules.factoryDisplay.maxWildPerTurn
    )
end

--- @return table[] every legal tile selection pick: { source, tileType, take } (take: TileType ->
---     count), center first, then the displays in order, colors in TileType.ORDERED order
function LegalMoves.takes(gameState)
    local moves = {}
    for source = GameState.CENTER, gameState:numFactoryDisplays() do
        for _, tileType in ipairs(TileType.ORDERED) do
            local take = LegalMoves.takeFor(gameState, source, tileType)
            if take then
                table.insert(moves, { source = source, tileType = tileType, take = take })
            end
        end
    end
    return moves
end

--- @return table[] every legal tile placement for \p playerIdx: { starIdx, slotIdx, possibility }
---     (possibility: a PlacementPossibility), stars and slots in order
function LegalMoves.placements(gameState, playerIdx)
    local player = gameState.players[playerIdx]
    local wild = gameState:getCurrentWildType()
    local moves = {}
    for starIdx, star in ipairs(player.mat.stars) do
        for slotIdx = 1, star:numSlots() do
            if not star:isOccupied(slotIdx) then
                for _, possibility in ipairs(player:generatePlacementPossibilities(starIdx, slotIdx, wild)) do
                    table.insert(moves, { starIdx = starIdx, slotIdx = slotIdx, possibility = possibility })
                end
            end
        end
    end
    return moves
end

--- @return integer how many bonus tiles must be picked up now (BonusPickup.owed), 0 if none
function LegalMoves.bonusCount(gameState)
    local owed = BonusPickup.owed(gameState)
    return owed and owed.count or 0
end

return LegalMoves
