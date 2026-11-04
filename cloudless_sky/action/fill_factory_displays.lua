--- Game action: fill every factory display with GameRules.factoryDisplay.tilesPerDisplay tiles.
--- Draw randomly from the bag (GameState.tileBag)
---
--- Per the rules:
---     - if tileBag empties, refill it with all tiles from the tower (GameState.discard) and continue
---     - if tileBag and tower are both empty, start the round anyway, even if not all displays are full
---
--- ctx.events records what happened, in order, so the view can animate it:
---     { display = i, tiles = { TileType -> count } }  tiles put on display i
---     { refill = { TileType -> count } }              tower contents moved into the bag
--- If the bag runs out partway through a display, that display's tiles are split into two display
--- events with the refill event between them
local Action = require("cloudless_sky.action.action")
local TileType = require("cloudless_sky.model.tile_type")

---@class FillFactoryDisplaysAction : Action
local FillFactoryDisplaysAction = Action:extend()
local ACTION_NAME = "FillFactoryDisplays"

Action.register(ACTION_NAME, FillFactoryDisplaysAction)

function FillFactoryDisplaysAction:new()
    FillFactoryDisplaysAction.super.new(self, ACTION_NAME, {
        -- set by perform:
        -- rngStateBefore: rng state before any tiles were drawn
        -- events: see file header
    })
end

function FillFactoryDisplaysAction.deserialize(ctx)
    local action = FillFactoryDisplaysAction()
    if ctx then
        action.ctx.rngStateBefore = ctx.rngStateBefore
        action.ctx.events = ctx.events
    end
    return action
end

function FillFactoryDisplaysAction:validate(gameState)
    for ii, display in ipairs(gameState.factoryDisplays) do
        if not display:isEmpty() then
            return false, "factory display " .. ii .. " is not empty"
        end
    end
    return true, nil
end

--- Move every tile in \p from into \p to
--- @return table TileType -> count of tiles moved
local function moveAll(from, to)
    local moved = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        local count = from:num(tileType)
        if count > 0 then
            from:removeTiles(tileType, count)
            to:addTiles(tileType, count)
            moved[tileType] = count
        end
    end
    return moved
end

function FillFactoryDisplaysAction:perform(gameState)
    local ctx = self.ctx
    ctx.rngStateBefore = gameState.rng:getState()
    ctx.events = {}

    local bag = gameState.tileBag
    local perDisplay = gameState.rules.factoryDisplay.tilesPerDisplay

    for displayIdx, display in ipairs(gameState.factoryDisplays) do
        local current = nil
        for _ = 1, perDisplay do
            if bag:isEmpty() then
                if gameState.discard:isEmpty() then
                    -- nothing left anywhere. start the round with what we have
                    break
                end
                table.insert(ctx.events, { refill = moveAll(gameState.discard, bag) })
                -- tiles drawn after the refill go in a new event for this display
                current = nil
            end
            local tileType = bag:takeRandomTile(gameState.rng)
            display:addTile(tileType)
            if not current then
                current = { display = displayIdx, tiles = {} }
                table.insert(ctx.events, current)
            end
            current.tiles[tileType] = (current.tiles[tileType] or 0) + 1
        end
    end
    return {}
end

function FillFactoryDisplaysAction:undo(gameState)
    local ctx = self.ctx
    for ii = #ctx.events, 1, -1 do
        local event = ctx.events[ii]
        if event.refill then
            for tileType, count in pairs(event.refill) do
                gameState.tileBag:removeTiles(tileType, count)
                gameState.discard:addTiles(tileType, count)
            end
        else
            local display = gameState.factoryDisplays[event.display]
            for tileType, count in pairs(event.tiles) do
                display:removeTiles(tileType, count)
                gameState.tileBag:addTiles(tileType, count)
            end
        end
    end
    gameState.rng:setState(ctx.rngStateBefore)
end

return FillFactoryDisplaysAction
