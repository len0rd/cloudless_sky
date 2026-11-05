--- Shared helpers for unit tests (not a test file itself: cute only runs *_tests.lua)
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")
local TileType = require("cloudless_sky.model.tile_type")

local TestUtil = {}

-- fixed seed so tests are repeatable
TestUtil.SEED = 0xdeadbeef

--- @param rules table|nil rules to use. Defaults to the current rules. Use TestUtil.copyRules() to
---     get a modifiable copy rather than changing the shared rules table
--- @return GameState a new 2 player game
function TestUtil.newGame(rules)
    return GameState(rules or GameRules.currentRules(), { "p1", "p2" }, love.math.newRandomGenerator(TestUtil.SEED), TestUtil.SEED)
end

--- @return table a deep copy of the current rules that a test can modify freely
function TestUtil.copyRules()
    return table.copy(GameRules.currentRules())
end

--- @return string snapshot of the game state a player's actions may touch: their score, hand and
---     mat, the tower (discard), bag, factory displays, center, start token, round phase and the
---     history length. Compare two snapshots to check state is unchanged
function TestUtil.snapshot(gameState, playerIdx)
    playerIdx = playerIdx or 1
    local player = gameState.players[playerIdx]
    local parts = { "score=" .. player.score }
    for _, tileType in ipairs(TileType.ORDERED) do
        table.insert(parts, "hand." .. tileType .. "=" .. player.hand:num(tileType))
        table.insert(parts, "discard." .. tileType .. "=" .. gameState.discard:num(tileType))
    end
    for starIdx, star in ipairs(player.mat.stars) do
        for slotIdx = 1, star:numSlots() do
            table.insert(parts, starIdx .. "." .. slotIdx .. "=" .. tostring(star:tileAtSlot(slotIdx)))
        end
    end
    for _, tileType in ipairs(TileType.ORDERED) do
        table.insert(parts, "bag." .. tileType .. "=" .. gameState.tileBag:num(tileType))
        table.insert(parts, "center." .. tileType .. "=" .. gameState.center:num(tileType))
        for displayIdx, display in ipairs(gameState.factoryDisplays) do
            table.insert(parts, "display" .. displayIdx .. "." .. tileType .. "=" .. display:num(tileType))
        end
    end
    table.insert(parts, "token=" .. tostring(gameState.startTokenHolder))
    table.insert(parts, "phase=" .. tostring(gameState.round.phase))
    table.insert(parts, "history=" .. #gameState.actionHistory)
    return table.concat(parts, ",")
end

--- @return TileBag a bag with the given TileType -> count contents
function TestUtil.bagOf(counts)
    local TileBag = require("cloudless_sky.model.tile_bag")
    local bag = TileBag()
    for tileType, count in pairs(counts) do
        bag:addTiles(tileType, count)
    end
    return bag
end

--- Set \p bag's contents to exactly the given TileType -> count table (missing types become 0)
function TestUtil.setBag(bag, counts)
    for _, tileType in ipairs(TileType.ORDERED) do
        bag:setCountForTileType(tileType, counts[tileType] or 0)
    end
end

--- Play \p gameState (a new game) through every round the way the state machines do, until the final
--- round's placement phase is over and every player has passed: the game is over, but end-game bonuses
--- haven't been scored. Picks are the first legal take; placements the first slot that fits, else pass
function TestUtil.playToGameEnd(gameState)
    local EndRoundAction = require("cloudless_sky.action.end_round")
    local FillFactoryDisplaysAction = require("cloudless_sky.action.fill_factory_displays")
    local PassAction = require("cloudless_sky.action.pass")
    local PlaceTileAction = require("cloudless_sky.action.place_tile")
    local StartPlacementPhaseAction = require("cloudless_sky.action.start_placement_phase")
    local TakeTilesAction = require("cloudless_sky.action.take_tiles")

    local function perform(action)
        local performed, reason = gameState:performAction(action)
        assert(performed, tostring(action.name) .. " failed: " .. tostring(reason))
    end
    local function take()
        for source = GameState.CENTER, gameState:numFactoryDisplays() do
            for _, tileType in ipairs(TileType.ORDERED) do
                if gameState:performAction(TakeTilesAction(gameState.currentTurnPlayer, source, tileType)) then
                    return
                end
            end
        end
        error("no legal pick")
    end
    local function placeOrPass()
        local playerIdx = gameState.currentTurnPlayer
        local player = gameState.players[playerIdx]
        for starIdx, star in ipairs(player.mat.stars) do
            for slotIdx = 1, star:numSlots() do
                if not star:isOccupied(slotIdx) then
                    local options = player:generatePlacementPossibilities(starIdx, slotIdx, gameState:getCurrentWildType())
                    if #options > 0 then
                        perform(PlaceTileAction(playerIdx, starIdx, slotIdx, options[1]))
                        return
                    end
                end
            end
        end
        perform(PassAction(playerIdx, {}))
    end

    perform(require("cloudless_sky.action.fill_bonus_pool")())
    while true do
        perform(FillFactoryDisplaysAction())
        gameState:beginTurn(gameState.startPlayer)
        while not gameState:allTileSourcesEmpty() do
            take()
            gameState:incrementTurn()
        end
        perform(StartPlacementPhaseAction())
        gameState:beginTurn(gameState.startTokenHolder or gameState.startPlayer)
        while not gameState:allPlayersPassed() do
            placeOrPass()
            if not gameState:allPlayersPassed() then
                gameState:incrementTurn()
            end
        end
        if gameState:isFinalRound() then
            return gameState
        end
        perform(EndRoundAction())
    end
end

return TestUtil
