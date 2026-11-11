local cute = require("cloudless_sky.extern.cute")
local BotPlayer = require("cloudless_sky.bot.bot_player")
local GameFlow = require("cloudless_sky.model.game_flow")
local HeadlessMatch = require("cloudless_sky.bot.headless_match")
local SaveGame = require("cloudless_sky.model.save_game")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")

local NAMES = { "a", "b", "c", "d" }

local function names(n)
    return { unpack(NAMES, 1, n) }
end

notion("HeadlessMatch plays 2-4 player games to the end: every player scored, a winner", function()
    for numPlayers = 2, 4 do
        local result = HeadlessMatch.play({ seed = 500 + numPlayers, playerNames = names(numPlayers), checkInvariants = true })
        local gameState = result.gameState
        check(GameFlow.isGameOver(gameState)).is(true)
        check(GameFlow.nextToScore(gameState) == nil).is(true)
        check(#result.scores).is(numPlayers)
        check(#result.winners >= 1).is(true)
        for _, seat in ipairs(result.winners) do
            for _, score in ipairs(result.scores) do
                check(result.scores[seat] >= score).is(true)
            end
        end
        check(result.actions).is(#gameState.actionHistory)
    end
end)

notion("HeadlessMatch is repeatable: the same seed and bots give the same digest, checked or not", function()
    local a = HeadlessMatch.play({ seed = 77, playerNames = names(3), checkInvariants = true })
    local b = HeadlessMatch.play({ seed = 77, playerNames = names(3) })
    check(a.digest).is(b.digest)
    check(HeadlessMatch.play({ seed = 78, playerNames = names(3) }).digest ~= a.digest).is(true)
    -- names are part of the game
    check(HeadlessMatch.play({ seed = 77, playerNames = { "x", "y", "z" } }).digest ~= a.digest).is(true)
end)

notion("A HeadlessMatch game round-trips through SaveGame", function()
    local result = HeadlessMatch.play({ seed = 31, playerNames = names(2) })
    local restored, reason = SaveGame.decode(SaveGame.encode(result.gameState))
    check(reason == nil).is(true)
    check(HeadlessMatch.digest(restored)).is(result.digest)
end)

-- test bots: one that chooses an invalid action, one that changes the state while choosing
local BadBot = BotPlayer:extend()
function BadBot:chooseTake(gameState, playerIdx)
    -- the center is empty at the start of a round
    return TakeTilesAction(playerIdx, 0, "RED")
end

local MeddlingBot = BotPlayer:extend()
function MeddlingBot:chooseTake(gameState, playerIdx)
    gameState.players[playerIdx].score = gameState.players[playerIdx].score + 1
    return TakeTilesAction(playerIdx, 1, "RED")
end

notion("HeadlessMatch fails loudly on an invalid choice, or a bot changing the state", function()
    local rng = love.math.newRandomGenerator(1)
    local ok, err = pcall(HeadlessMatch.play, {
        seed = 1,
        playerNames = names(2),
        bots = { BadBot(rng, 1), BadBot(rng, 2) },
    })
    check(ok).is(false)
    check(tostring(err):find("invalid TakeTiles", 1, true) ~= nil).is(true)

    ok, err = pcall(HeadlessMatch.play, {
        seed = 1,
        playerNames = names(2),
        bots = { MeddlingBot(rng, 1), MeddlingBot(rng, 2) },
        checkInvariants = true,
    })
    check(ok).is(false)
    check(tostring(err):find("changed the game state", 1, true) ~= nil).is(true)
end)

notion("HeadlessMatch.parseArgs: --sim options, defaults and errors", function()
    check(HeadlessMatch.parseArgs({ "--seed", "5" }) == nil).is(true)
    local opts = HeadlessMatch.parseArgs({ "--sim", "--seed", "5", "--games", "3", "--players", "3" })
    check(opts.seed).is(5)
    check(opts.games).is(3)
    check(opts.players).is(3)
    check(table.concat(opts.bots, ",")).is("easy,easy,easy")
    check(opts.checks).is(true)
    check(HeadlessMatch.parseArgs({ "--sim", "--no-checks" }).checks).is(false)
    check(table.concat(HeadlessMatch.parseArgs({ "--sim", "--bots", "easy,easy" }).bots, ",")).is("easy,easy")

    local _, err = HeadlessMatch.parseArgs({ "--sim", "--players", "5" })
    check(err ~= nil).is(true)
    _, err = HeadlessMatch.parseArgs({ "--sim", "--bots", "nope" })
    check(err:find("unknown bot", 1, true) ~= nil).is(true)
    _, err = HeadlessMatch.parseArgs({ "--sim", "--players", "3", "--bots", "easy,easy" })
    check(err ~= nil).is(true)
end)
