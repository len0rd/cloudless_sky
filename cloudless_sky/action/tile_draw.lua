--- Drawing tiles from the bag (GameState.tileBag) for actions that fill something (factory displays,
--- the bonus pool). Not an action itself.
---
--- Per the rules:
---     - if the bag empties, refill it with every tile from the tower (GameState.discard) and continue
---     - if the bag and tower are both empty, stop: fewer tiles are drawn than asked for
---
--- Every draw comes from the game's rng, so callers record gameState.rng:getState() before drawing to
--- be undoable/replayable
local TileDraw = {}

--- Draw up to \p count random tiles from the bag
--- @param onTile function(tileType) called for each tile drawn, in order. The tile has already been
---     taken out of the bag: the caller puts it somewhere
--- @param onRefill function(moved) called when the tower is emptied into the bag, before the next tile
---     is drawn. \p moved is TileType -> count. Undo it with TileDraw.undoRefill
--- @return integer drawn how many tiles were drawn
function TileDraw.draw(gameState, count, onTile, onRefill)
    local bag = gameState.tileBag
    for ii = 1, count do
        if bag:isEmpty() then
            if gameState.discard:isEmpty() then
                -- nothing left anywhere
                return ii - 1
            end
            onRefill(gameState.discard:moveAllTo(bag))
        end
        onTile(bag:takeRandomTile(gameState.rng))
    end
    return count
end

--- Undo a refill reported by TileDraw.draw: put \p moved (TileType -> count) back in the tower
function TileDraw.undoRefill(gameState, moved)
    for tileType, count in pairs(moved) do
        gameState.tileBag:removeTiles(tileType, count)
        gameState.discard:addTiles(tileType, count)
    end
end

return TileDraw
