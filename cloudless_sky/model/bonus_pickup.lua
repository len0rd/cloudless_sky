--- The bonus tiles a player owes a pickup for: placing a tile that completes bonus spaces on their mat
--- (MatBonus) earns tiles from the bonus pool (GameState.bonusPool), all bonuses of one placement
--- added together. The player must pick them up (TakeBonusTilesAction) before ending their turn.
---
--- Worked out from the current turn's history, so undo and loaded saves need nothing extra
local BonusPickup = {}

--- @param gameState GameState
--- @return table|nil owed { playerIdx, count, bonuses, bonusTiles } for the current turn's placement:
---     count = tiles to pick up now: the bonusTiles earned, or every tile left in the pool if it holds
---     fewer. bonuses = the completed bonus space indices. nil if no pickup is owed (no placement with a
---     bonus this turn, it's already been picked up, or the pool is empty)
function BonusPickup.owed(gameState)
    local history = gameState.actionHistory
    local placement = nil
    for ii = gameState:turnStartIndex() + 1, #history do
        local action = history[ii]
        if action.name == "PlaceTile" and (action.ctx.bonusTiles or 0) > 0 then
            placement = action
        elseif action.name == "TakeBonusTiles" then
            placement = nil
        end
    end
    if not placement then
        return nil
    end
    local count = math.min(placement.ctx.bonusTiles, gameState.bonusPool:total())
    if count <= 0 then
        return nil
    end
    return {
        playerIdx = placement.ctx.playerIdx,
        count = count,
        bonuses = placement.ctx.bonuses,
        bonusTiles = placement.ctx.bonusTiles,
    }
end

return BonusPickup
