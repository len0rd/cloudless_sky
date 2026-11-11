local cute = require("cloudless_sky.extern.cute")
local BotPlayer = require("cloudless_sky.bot.bot_player")
local Canonical = require("cloudless_sky.model.canonical")
local EasyBot = require("cloudless_sky.bot.players.easy_bot")
local GameFlow = require("cloudless_sky.model.game_flow")
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")
local Invariants = require("cloudless_sky.model.invariants")
local LegalMoves = require("cloudless_sky.model.legal_moves")

--- @return string the whole game state and its history, to check a bot left it unchanged
local function snapshot(gameState)
    local parts = { Canonical.encode(gameState:serialize()) }
    for _, action in ipairs(gameState.actionHistory) do
        table.insert(parts, Canonical.encode(action:serialize()))
    end
    return table.concat(parts)
end

--- Ask \p bot via \p ask, check it didn't change the state, then perform what it chose
local function decide(gameState, ask)
    local before = snapshot(gameState)
    local action = ask()
    if snapshot(gameState) ~= before then
        error("the bot changed the game state while choosing")
    end
    local performed, reason = gameState:performAction(action)
    if not performed then
        error("the bot chose an invalid " .. action.name .. ": " .. tostring(reason))
    end
    local failures = Invariants.check(gameState)
    if #failures > 0 then
        error("after " .. action.name .. ": " .. failures[1])
    end
    return action
end

--- Play a whole game with bot \p botId in every seat
--- @return GameState gameState the finished, scored game
--- @return table chosen action name -> how many times the bots chose it
local function playGame(botId, numPlayers, seed)
    local names = {}
    for ii = 1, numPlayers do
        names[ii] = "p" .. ii
    end
    local gameState = GameState(GameRules.DEFAULTS.BASE_GAME_RULES, names, love.math.newRandomGenerator(seed), seed)
    local bots = {}
    for seat = 1, numPlayers do
        bots[seat] = BotPlayer.create(botId, seed, seat)
    end
    local chosen = {}
    local function count(action)
        chosen[action.name] = (chosen[action.name] or 0) + 1
    end

    while not GameFlow.isGameOver(gameState) do
        GameFlow.startRound(gameState)
        GameFlow.beginRound(gameState)
        while not GameFlow.selectionOver(gameState) do
            local p = gameState.currentTurnPlayer
            count(decide(gameState, function()
                return bots[p]:chooseTake(gameState, p)
            end))
            GameFlow.endTurn(gameState, false)
        end
        GameFlow.startPlacement(gameState)
        while not GameFlow.placementOver(gameState) do
            if not GameFlow.passEmptyHand(gameState) then
                local p = gameState.currentTurnPlayer
                count(decide(gameState, function()
                    return bots[p]:choosePlacement(gameState, p)
                end))
                local owed = LegalMoves.bonusCount(gameState)
                if owed > 0 then
                    count(decide(gameState, function()
                        return bots[p]:chooseBonusTiles(gameState, p, owed)
                    end))
                end
                GameFlow.endTurn(gameState, true)
            end
        end
        GameFlow.endRound(gameState)
    end
    local p = GameFlow.nextToScore(gameState)
    while p do
        GameFlow.beginScoring(gameState, p)
        GameFlow.scorePlayer(gameState, p)
        p = GameFlow.nextToScore(gameState)
    end
    return gameState, chosen
end

notion("BotPlayer: bots register by id and are created with their own seeded rng per seat", function()
    check(BotPlayer.known.easy == EasyBot).is(true)
    check(EasyBot.id).is("easy")
    local a, b = BotPlayer.create("easy", 42, 1), BotPlayer.create("easy", 42, 2)
    check(a.seat).is(1)
    check(BotPlayer.seedFor(42, 1) ~= BotPlayer.seedFor(42, 2)).is(true)
    check(BotPlayer.seedFor(42, 1) ~= 42).is(true)
    -- the same seat and seed gives the same choices
    local c = BotPlayer.create("easy", 42, 1)
    check(a.rng:random(1, 1000000)).is(c.rng:random(1, 1000000))
    check(b ~= nil).is(true)
    check(pcall(BotPlayer.create, "nope", 1, 1)).is(false)
end)

notion("BotPlayer: the base class has no choices of its own", function()
    local bot = BotPlayer(love.math.newRandomGenerator(1), 1)
    check(pcall(bot.chooseTake, bot, nil, 1)).is(false)
    check(pcall(bot.choosePlacement, bot, nil, 1)).is(false)
    check(pcall(bot.chooseBonusTiles, bot, nil, 1, 1)).is(false)
end)

notion("EasyBot plays whole games (2-4 players): only valid choices, never changing the state", function()
    for numPlayers = 2, 4 do
        for seed = 1, 3 do
            local gameState, chosen = playGame("easy", numPlayers, seed * 10 + numPlayers)
            check(GameFlow.isGameOver(gameState)).is(true)
            check(GameFlow.nextToScore(gameState) == nil).is(true)
            check((chosen.TakeTiles or 0) > 0).is(true)
            check((chosen.PlaceTile or 0) > 0).is(true)
            check((chosen.Pass or 0) > 0).is(true)
        end
    end
end)

notion("EasyBot picks up bonus tiles when it earns them", function()
    local pickups = 0
    for seed = 1, 5 do
        local _, chosen = playGame("easy", 2, seed)
        pickups = pickups + (chosen.TakeBonusTiles or 0)
    end
    check(pickups > 0).is(true)
end)

notion("EasyBot games are repeatable: the same seed gives the same game", function()
    local a = playGame("easy", 3, 99)
    local b = playGame("easy", 3, 99)
    check(snapshot(a) == snapshot(b)).is(true)
    local c = playGame("easy", 3, 100)
    check(snapshot(a) ~= snapshot(c)).is(true)
end)
