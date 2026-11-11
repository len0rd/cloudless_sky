local cute = require("cloudless_sky.extern.cute")
local BotPlayer = require("cloudless_sky.bot.bot_player")
local EasyBot = require("cloudless_sky.bot.players.easy_bot")
local GameFlow = require("cloudless_sky.model.game_flow")
local HeadlessMatch = require("cloudless_sky.bot.headless_match")

--- Play a whole game with Easy bots in every seat (checking invariants, and that the bots never change
--- the state while choosing: HeadlessMatch raises an error otherwise)
--- @return GameState gameState the finished, scored game
--- @return table chosen action name -> how many times a player chose it (not follow-ups)
local function playGame(numPlayers, seed)
    local names = {}
    for ii = 1, numPlayers do
        names[ii] = "p" .. ii
    end
    local result = HeadlessMatch.play({ seed = seed, playerNames = names, bots = { "easy" }, checkInvariants = true })
    local chosen = {}
    for _, action in ipairs(result.gameState.actionHistory) do
        if not action.isFollowUp and not action.undoBarrier then
            chosen[action.name] = (chosen[action.name] or 0) + 1
        end
    end
    return result.gameState, chosen
end

notion("BotPlayer: bots register by id and are created with their own seeded rng per seat", function()
    check(BotPlayer.known.easy == EasyBot).is(true)
    check(EasyBot.id).is("easy")
    local a, b = BotPlayer.create("easy", 42, 1), BotPlayer.create("easy", 42, 2)
    check(a.seat).is(1)
    check(b.seat).is(2)
    check(BotPlayer.seedFor(42, 1) ~= BotPlayer.seedFor(42, 2)).is(true)
    check(BotPlayer.seedFor(42, 1) ~= 42).is(true)
    -- the same seat and seed gives the same choices
    local c = BotPlayer.create("easy", 42, 1)
    check(a.rng:random(1, 1000000)).is(c.rng:random(1, 1000000))
    check(pcall(BotPlayer.create, "nope", 1, 1)).is(false)
end)

notion("BotPlayer: the base class has no choices of its own", function()
    local bot = BotPlayer(love.math.newRandomGenerator(1), 1)
    check(pcall(bot.chooseTake, bot, nil, 1)).is(false)
    check(pcall(bot.choosePlacement, bot, nil, 1)).is(false)
    check(pcall(bot.chooseBonusTiles, bot, nil, 1, 1)).is(false)
end)

notion("EasyBot plays whole games (2-4 players): takes, places and passes", function()
    for numPlayers = 2, 4 do
        for seed = 1, 3 do
            local gameState, chosen = playGame(numPlayers, seed * 10 + numPlayers)
            check(GameFlow.isGameOver(gameState)).is(true)
            check((chosen.TakeTiles or 0) > 0).is(true)
            check((chosen.PlaceTile or 0) > 0).is(true)
            check((chosen.Pass or 0) > 0).is(true)
        end
    end
end)

notion("EasyBot picks up bonus tiles when it earns them", function()
    local pickups = 0
    for seed = 1, 5 do
        local _, chosen = playGame(2, seed)
        pickups = pickups + (chosen.TakeBonusTiles or 0)
    end
    check(pickups > 0).is(true)
end)
