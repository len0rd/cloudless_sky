local cute = require("cloudless_sky.extern.cute")
local BonusPickup = require("cloudless_sky.model.bonus_pickup")
local Canonical = require("cloudless_sky.model.canonical")
local GameFlow = require("cloudless_sky.model.game_flow")
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")
local Invariants = require("cloudless_sky.model.invariants")
local LegalMoves = require("cloudless_sky.model.legal_moves")
local PassAction = require("cloudless_sky.action.pass")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local SaveGame = require("cloudless_sky.model.save_game")
local TakeBonusTilesAction = require("cloudless_sky.action.take_bonus_tiles")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")
local TileType = require("cloudless_sky.model.tile_type")

--- Perform a player's choice, failing the test if it's invalid
local function choose(gameState, action)
    local performed, reason = gameState:performAction(action)
    if not performed then
        error(action.name .. " was invalid: " .. tostring(reason))
    end
end

local function checkInvariants(gameState, when)
    local failures = Invariants.check(gameState)
    if #failures > 0 then
        error(when .. ": " .. failures[1])
    end
end

--- Play a whole game with random legal choices, driven by GameFlow alone (no view)
--- @return GameState the finished, scored game
local function playRandomGame(numPlayers, seed)
    local names = {}
    for ii = 1, numPlayers do
        names[ii] = "p" .. ii
    end
    local gameState = GameState(GameRules.DEFAULTS.BASE_GAME_RULES, names, love.math.newRandomGenerator(seed), seed)
    local rng = love.math.newRandomGenerator(seed + 1)
    local function pick(list)
        return list[rng:random(1, #list)]
    end

    while not GameFlow.isGameOver(gameState) do
        GameFlow.startRound(gameState)
        GameFlow.beginRound(gameState)
        while not GameFlow.selectionOver(gameState) do
            local move = pick(LegalMoves.takes(gameState))
            choose(gameState, TakeTilesAction(gameState.currentTurnPlayer, move.source, move.tileType))
            checkInvariants(gameState, "after a take")
            GameFlow.endTurn(gameState, false)
        end
        GameFlow.startPlacement(gameState)
        while not GameFlow.placementOver(gameState) do
            if not GameFlow.passEmptyHand(gameState) then
                local playerIdx = gameState.currentTurnPlayer
                local moves = LegalMoves.placements(gameState, playerIdx)
                if #moves == 0 or rng:random() < 0.1 then
                    local hand = gameState.players[playerIdx].hand
                    local keep = PassAction.suggestKeep(hand, gameState:tileCarryoverLimit(), gameState:getNextRoundWildType())
                    choose(gameState, PassAction(playerIdx, keep))
                else
                    local move = pick(moves)
                    choose(gameState, PlaceTileAction(playerIdx, move.starIdx, move.slotIdx, move.possibility))
                    local count = LegalMoves.bonusCount(gameState)
                    if count > 0 then
                        -- the first tiles in the pool, in color order
                        local take = {}
                        for _, tileType in ipairs(TileType.ORDERED) do
                            local n = math.min(count, gameState.bonusPool:num(tileType))
                            if n > 0 then
                                take[tileType] = n
                                count = count - n
                            end
                        end
                        choose(gameState, TakeBonusTilesAction(playerIdx, take))
                    end
                end
                checkInvariants(gameState, "after a placement turn")
                GameFlow.endTurn(gameState, true)
            end
        end
        GameFlow.endRound(gameState)
        checkInvariants(gameState, "after round " .. gameState.round.idx)
    end
    local playerIdx = GameFlow.nextToScore(gameState)
    while playerIdx do
        GameFlow.beginScoring(gameState, playerIdx)
        GameFlow.scorePlayer(gameState, playerIdx)
        playerIdx = GameFlow.nextToScore(gameState)
    end
    return gameState
end

notion("GameFlow alone plays whole games (2-4 players): every round, every player scored, invariants hold", function()
    for numPlayers = 2, 4 do
        for seed = 1, 3 do
            local gameState = playRandomGame(numPlayers, seed * 100 + numPlayers)
            check(gameState.round.idx).is(#gameState.rules.wildPerRound)
            check(GameFlow.isGameOver(gameState)).is(true)
            check(GameFlow.nextToScore(gameState) == nil).is(true)
            for _, player in ipairs(gameState.players) do
                check(player.endGameBonus ~= nil).is(true)
            end
            checkInvariants(gameState, "at the end")
        end
    end
end)

notion("A GameFlow game is repeatable from its seed and round-trips through SaveGame", function()
    local a = playRandomGame(3, 77)
    local b = playRandomGame(3, 77)
    local digest = function(gameState)
        local parts = { Canonical.encode(gameState:serialize()) }
        for _, action in ipairs(gameState.actionHistory) do
            table.insert(parts, Canonical.encode(action:serialize()))
        end
        return Canonical.hash(table.concat(parts))
    end
    check(digest(a)).is(digest(b))
    local restored, reason = SaveGame.decode(SaveGame.encode(a))
    check(reason == nil).is(true)
    check(digest(restored)).is(digest(a))
end)

notion("GameFlow.endTurn tops up the bonus pool only after a turn that picked bonus tiles up", function()
    local gameState = playRandomGame(2, 5)
    local history = gameState.actionHistory
    local topUps = 0
    for ii, action in ipairs(history) do
        -- the first fill is the start of the game; every later one ends a turn with a pickup
        if action.name == "FillBonusPool" and ii > 1 then
            topUps = topUps + 1
            local hadPickup = false
            for jj = ii - 1, 1, -1 do
                if history[jj].undoBarrier then
                    break
                end
                hadPickup = hadPickup or history[jj].name == "TakeBonusTiles"
            end
            check(hadPickup).is(true)
        end
    end
    check(topUps > 0).is(true)
    check(BonusPickup.owed(gameState) == nil).is(true)
end)

notion("GameFlow.passEmptyHand passes only for a player with no tiles", function()
    local gameState = GameState(GameRules.DEFAULTS.BASE_GAME_RULES, { "a", "b" }, love.math.newRandomGenerator(9), 9)
    GameFlow.startRound(gameState)
    GameFlow.beginRound(gameState)
    -- nobody has tiles at the start
    local before = #gameState.actionHistory
    local performed = GameFlow.passEmptyHand(gameState)
    check(performed ~= nil and performed[1].name == "Pass").is(true)
    check(gameState.players[1].passedForPhase).is(true)
    check(#gameState.actionHistory > before).is(true)
    -- player 2 has tiles: no pass
    gameState.players[2].hand:addTiles(TileType.RED, 1)
    check(GameFlow.passEmptyHand(gameState) == nil).is(true)
end)

notion("LegalMoves: every listed take and placement is valid, and none are missing", function()
    local gameState = GameState(GameRules.DEFAULTS.BASE_GAME_RULES, { "a", "b" }, love.math.newRandomGenerator(12), 12)
    GameFlow.startRound(gameState)
    GameFlow.beginRound(gameState)
    local takes = LegalMoves.takes(gameState)
    check(#takes > 0).is(true)
    local listed = {}
    for _, move in ipairs(takes) do
        listed[move.source .. move.tileType] = true
        check(TakeTilesAction(1, move.source, move.tileType):validate(gameState)).is(true)
    end
    for source = GameState.CENTER, gameState:numFactoryDisplays() do
        for _, tileType in ipairs(TileType.ORDERED) do
            local valid = TakeTilesAction(1, source, tileType):validate(gameState)
            check(valid == (listed[source .. tileType] == true)).is(true)
        end
    end

    -- placements: give player 1 a handful of tiles
    for _, tileType in ipairs(TileType.ORDERED) do
        gameState.players[1].hand:addTiles(tileType, 3)
    end
    local placements = LegalMoves.placements(gameState, 1)
    check(#placements > 0).is(true)
    for _, move in ipairs(placements) do
        check(PlaceTileAction(1, move.starIdx, move.slotIdx, move.possibility):validate(gameState)).is(true)
    end
    check(LegalMoves.bonusCount(gameState)).is(0)
end)

notion("LegalMoves.placeableSlots and placementsAt agree with placements", function()
    local gameState = GameState(GameRules.DEFAULTS.BASE_GAME_RULES, { "a", "b" }, love.math.newRandomGenerator(13), 13)
    GameFlow.startRound(gameState)
    GameFlow.beginRound(gameState)
    gameState.players[1].hand:addTiles(TileType.RED, 2)
    gameState.players[1].hand:addTiles(TileType.BLUE, 4)

    local fromSlots = 0
    for _, slot in ipairs(LegalMoves.placeableSlots(gameState, 1)) do
        local at = LegalMoves.placementsAt(gameState, 1, slot.starIdx, slot.slotIdx)
        check(#at).is(#slot.possibilities)
        check(#at > 0).is(true)
        fromSlots = fromSlots + #at
    end
    check(fromSlots).is(#LegalMoves.placements(gameState, 1))

    -- an occupied slot has none
    local move = LegalMoves.placements(gameState, 1)[1]
    choose(gameState, PlaceTileAction(1, move.starIdx, move.slotIdx, move.possibility))
    check(#LegalMoves.placementsAt(gameState, 1, move.starIdx, move.slotIdx)).is(0)
    check(LegalMoves.bonusPickup(gameState) == nil).is(true)
end)
