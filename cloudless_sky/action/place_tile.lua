--- Action for a player placing a tile from their hand onto their player mat
---
--- Follow-up actions:
---     - AddScoreAction for the placement's adjacency score
---     - TODO: placement bonuses (surrounding statues,windows, etc). PlayerMat:placeTile will
---       report these as additional events which should be turned into follow-up actions.
---       Bonuses require player input (choosing tiles), so they will need to be actions that the
---       turn state machine waits on rather than ones performed automatically.
local Action = require("cloudless_sky.action.action")
local AddScoreAction = require("cloudless_sky.action.add_score")

---@class PlaceTileAction : Action
---@field score integer|nil Adjacency score of the placement. Set once performed
local PlaceTileAction = Action:extend()
local ACTION_NAME = "PlaceTile"

Action.register(ACTION_NAME, PlaceTileAction)

--- @param playerIdx integer GameState index of the player placing the tile
--- @param starIdx integer Index of the star on the player's mat
--- @param slotIdx integer Index of the slot within the star
--- @param placement table PlacementPossibility (or its :toTable()) describing the tiles used to pay for the slot
function PlaceTileAction:new(playerIdx, starIdx, slotIdx, placement)
    PlaceTileAction.super.new(self, ACTION_NAME, {
        playerIdx = playerIdx,
        starIdx = starIdx,
        slotIdx = slotIdx,
        -- store as a plain table so the action is serializable
        placement = {
            tileType = placement.tileType,
            tileCount = placement.tileCount,
            wildType = placement.wildType,
            wildCount = placement.wildCount or 0,
        },
    })
    self.score = nil
end

function PlaceTileAction.deserialize(ctx)
    return PlaceTileAction(ctx.playerIdx, ctx.starIdx, ctx.slotIdx, ctx.placement)
end

--- Check if this placement can be performed on the given game state.
--- Model class is source of truth for placement validity.
--- @return boolean valid
--- @return string|nil reason Why the placement is invalid
function PlaceTileAction:validate(gameState)
    local ctx = self.ctx
    local p = ctx.placement
    local player = gameState.players[ctx.playerIdx]
    if not player then
        return false, "invalid playerIdx " .. tostring(ctx.playerIdx)
    end

    local wildType = gameState:getCurrentWildType()
    for _, possibility in ipairs(player:generatePlacementPossibilities(ctx.starIdx, ctx.slotIdx, wildType)) do
        -- possibilities that use no wilds may or may not set wildType, so only compare it when wilds are used
        if
            possibility.tileType == p.tileType
            and possibility.tileCount == p.tileCount
            and possibility.wildCount == p.wildCount
            and (p.wildCount == 0 or possibility.wildType == p.wildType)
        then
            return true, nil
        end
    end
    return false,
        string.format(
            "%d %s + %d %s is not a possible placement for player %d star %d slot %d (round wild is %s)",
            p.tileCount,
            tostring(p.tileType),
            p.wildCount,
            tostring(p.wildType),
            ctx.playerIdx,
            ctx.starIdx,
            ctx.slotIdx,
            tostring(wildType)
        )
end

--- Prefer GameState:performAction, which validates first and rejects invalid placements without
--- raising an error. The assert here is a safety net for direct calls and should never fire
function PlaceTileAction:perform(gameState)
    local valid, reason = self:validate(gameState)
    assert(valid, "Invalid PlaceTileAction: " .. tostring(reason))

    local ctx = self.ctx
    local p = ctx.placement
    local player = gameState.players[ctx.playerIdx]

    -- pay for the slot
    player.hand:removeTiles(p.tileType, p.tileCount)
    if p.wildCount > 0 then
        player.hand:removeTiles(p.wildType, p.wildCount)
    end

    -- one tile goes on the mat, the rest of the payment goes to the tower
    gameState.discard:addTiles(p.tileType, p.tileCount - 1)
    if p.wildCount > 0 then
        gameState.discard:addTiles(p.wildType, p.wildCount)
    end

    local events = player.mat:placeTile(p.tileType, ctx.starIdx, ctx.slotIdx)
    assert(#events > 0, "PlayerMat:placeTile failed after validation passed")
    self.score = events[1]

    -- TODO: events[2..n] will be placement bonuses. convert them into follow-up actions
    return { AddScoreAction(ctx.playerIdx, self.score) }
end

--- Reverse perform. Does not undo follow-up actions (GameState undoes those individually)
function PlaceTileAction:undo(gameState)
    local ctx = self.ctx
    local p = ctx.placement
    local player = gameState.players[ctx.playerIdx]

    player.mat:removeTile(ctx.starIdx, ctx.slotIdx)

    gameState.discard:removeTiles(p.tileType, p.tileCount - 1)
    if p.wildCount > 0 then
        gameState.discard:removeTiles(p.wildType, p.wildCount)
    end

    player.hand:addTiles(p.tileType, p.tileCount)
    if p.wildCount > 0 then
        player.hand:addTiles(p.wildType, p.wildCount)
    end
end

return PlaceTileAction
