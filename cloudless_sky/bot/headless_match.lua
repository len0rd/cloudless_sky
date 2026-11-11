--- Plays whole games with bots in every seat, instantly and without any graphics: the game's own flow
--- (GameFlow) plus each seat's BotPlayer choices. For testing the game logic at scale and comparing bots.
---
--- Each turn: tile selection -> the bot's take; tile placement -> the bot's placement (then its bonus
--- pickup if the placement earned one) or pass. The same seed and bots play the same game as the UI bot
--- (love . --bot) does, so the two can be compared by their digest.
---
--- Command line (see HeadlessMatch.runCli):
---     love . --sim [--seed N] [--games K] [--players 2-4] [--bots ID,ID,...] [--no-checks]
local BotPlayer = require("cloudless_sky.bot.bot_player")
local Canonical = require("cloudless_sky.model.canonical")
local GameFlow = require("cloudless_sky.model.game_flow")
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")
local Invariants = require("cloudless_sky.model.invariants")
local LegalMoves = require("cloudless_sky.model.legal_moves")
-- registers the bots BotPlayer.create can make
require("cloudless_sky.bot.players.easy_bot")

local HeadlessMatch = {}

HeadlessMatch.DEFAULT_BOT = "easy"
--- player names for games started from the command line, by seat (the UI bot's game uses the first two)
HeadlessMatch.LAUNCH_NAMES = { "lenord", "karoty", "p3", "p4" }

--- @return string hex digest of everything serialized for \p gameState, plus its action history. The
---     same game played twice (same seed, rules, names and choices) gives the same digest
function HeadlessMatch.digest(gameState)
    local parts = { Canonical.encode(gameState:serialize()) }
    for _, action in ipairs(gameState.actionHistory) do
        table.insert(parts, Canonical.encode(action:serialize()))
    end
    return Canonical.hash(table.concat(parts))
end

--- @return string the game state, its history's length and the last action, exactly (to check a bot
---     left them unchanged: actions in the history are never changed once performed, so a bot that
---     performs and undoes (or leaves extra actions) shows up in the length or the last action)
local function snapshot(gameState)
    local history = gameState.actionHistory
    local last = history[#history]
    return Canonical.encode(gameState:serialize()) .. "|" .. #history .. "|" .. (last and Canonical.encode(last:serialize()) or "")
end

--- Play one game to the end (every player's end-game bonuses scored).
--- Raises an error if a bot chooses an invalid action, changes the state while choosing (checked when
--- \p opts.checkInvariants), or the invariants break (likewise)
--- @param opts table {
---     seed = integer,
---     playerNames = string[] (2-4),
---     bots = string[] a BotPlayer id per seat, or BotPlayer[] (default: "easy" for every seat),
---     rules = table|nil (default: the Base rules),
---     checkInvariants = boolean|nil: check the invariants after every action, and that bots don't
---         change the state while choosing (slower) }
--- @return table result { gameState, digest, scores = integer[], winners = integer[] (seats with the
---     highest score), actions = integer (history length) }
function HeadlessMatch.play(opts)
    local rules = opts.rules or GameRules.DEFAULTS.BASE_GAME_RULES
    local gameState = GameState(rules, opts.playerNames, love.math.newRandomGenerator(opts.seed), opts.seed)
    local bots = {}
    for seat = 1, gameState:numPlayers() do
        local bot = opts.bots and opts.bots[seat] or HeadlessMatch.DEFAULT_BOT
        bots[seat] = type(bot) == "string" and BotPlayer.create(bot, opts.seed, seat) or bot
    end
    local checking = opts.checkInvariants

    local function checkState(when)
        if checking then
            local failures = Invariants.check(gameState)
            if #failures > 0 then
                error("invariant broken " .. when .. ": " .. failures[1], 0)
            end
        end
    end

    --- ask the current player's bot (\p choose: its method name), then perform what it chose
    local function decide(choose, ...)
        local playerIdx = gameState.currentTurnPlayer
        local bot = bots[playerIdx]
        local before = checking and snapshot(gameState)
        local action = bot[choose](bot, gameState, playerIdx, ...)
        if checking and snapshot(gameState) ~= before then
            error("bot '" .. tostring(bot.id) .. "' changed the game state in " .. choose, 0)
        end
        local performed, reason = gameState:performAction(action)
        if not performed then
            error("bot '" .. tostring(bot.id) .. "' chose an invalid " .. tostring(action and action.name) .. ": " .. tostring(reason), 0)
        end
        checkState("after " .. action.name)
    end

    while not GameFlow.isGameOver(gameState) do
        GameFlow.startRound(gameState)
        GameFlow.beginRound(gameState)
        while not GameFlow.selectionOver(gameState) do
            decide("chooseTake")
            GameFlow.endTurn(gameState, false)
        end
        GameFlow.startPlacement(gameState)
        while not GameFlow.placementOver(gameState) do
            if not GameFlow.passEmptyHand(gameState) then
                decide("choosePlacement")
                local owed = LegalMoves.bonusCount(gameState)
                if owed > 0 then
                    decide("chooseBonusTiles", owed)
                end
                GameFlow.endTurn(gameState, true)
            end
        end
        GameFlow.endRound(gameState)
        checkState("after round " .. gameState.round.idx)
    end
    local playerIdx = GameFlow.nextToScore(gameState)
    while playerIdx do
        GameFlow.beginScoring(gameState, playerIdx)
        GameFlow.scorePlayer(gameState, playerIdx)
        playerIdx = GameFlow.nextToScore(gameState)
    end
    checkState("at the end")

    local scores, best, winners = {}, -math.huge, {}
    for ii, player in ipairs(gameState.players) do
        scores[ii] = player.score
        best = math.max(best, player.score)
    end
    for ii, score in ipairs(scores) do
        if score == best then
            table.insert(winners, ii)
        end
    end
    return {
        gameState = gameState,
        digest = HeadlessMatch.digest(gameState),
        scores = scores,
        winners = winners,
        actions = #gameState.actionHistory,
    }
end

--------------------------------------------------------------------------------
-- command line
--------------------------------------------------------------------------------

--- @return table|nil options from \p args when they ask for --sim: { seed, games, players, bots, checks }.
---     nil without --sim
--- @return string|nil error a bad option
function HeadlessMatch.parseArgs(args)
    local sim = false
    local options = { games = 1, players = 2, checks = true }
    for ii, v in ipairs(args) do
        local nextArg = args[ii + 1]
        if v == "--sim" then
            sim = true
        elseif v == "--seed" then
            options.seed = tonumber(nextArg)
        elseif v == "--games" then
            options.games = tonumber(nextArg)
            if not options.games or options.games < 1 then
                return nil, "--games needs a number of games"
            end
        elseif v == "--players" then
            options.players = tonumber(nextArg)
            if not options.players or options.players < 2 or options.players > 4 then
                return nil, "--players needs 2, 3 or 4"
            end
        elseif v == "--no-checks" then
            -- skip the invariant and bot checks after every action (faster)
            options.checks = false
        elseif v == "--bots" then
            options.bots = {}
            for id in tostring(nextArg):gmatch("[^,]+") do
                table.insert(options.bots, id)
            end
        end
    end
    if not sim then
        return nil
    end
    -- one bot id for every seat, or one each
    local bots = options.bots or { HeadlessMatch.DEFAULT_BOT }
    if #bots == 1 then
        for seat = 2, options.players do
            bots[seat] = bots[1]
        end
    end
    if #bots ~= options.players then
        return nil, "--bots needs 1 bot id or one per player (" .. options.players .. ")"
    end
    for _, id in ipairs(bots) do
        if not BotPlayer.known[id] then
            return nil, "unknown bot '" .. id .. "'. bots: " .. table.concat(BotPlayer.ids, ", ")
        end
    end
    options.bots = bots
    options.seed = options.seed or os.time()
    return options
end

local function out(msg)
    print("SIM " .. msg)
    io.stdout:flush()
end

--- Run --sim: play options.games games (seeds options.seed, +1, ...), one line each, then a summary
--- @param options table from HeadlessMatch.parseArgs
--- @return integer exit code: 0 = every game finished cleanly, 1 = a game failed
function HeadlessMatch.runCli(options)
    local names = {}
    for seat = 1, options.players do
        names[seat] = HeadlessMatch.LAUNCH_NAMES[seat]
    end
    out(string.format("%d game(s), %d players, bots %s, seeds %d..%d",
        options.games, options.players, table.concat(options.bots, ","), options.seed, options.seed + options.games - 1))

    local wins, totals, failures = {}, {}, 0
    for seat = 1, options.players do
        wins[seat], totals[seat] = 0, 0
    end
    local start = love.timer.getTime()
    for game = 0, options.games - 1 do
        local seed = options.seed + game
        local ok, result = pcall(HeadlessMatch.play, {
            seed = seed,
            playerNames = names,
            bots = options.bots,
            checkInvariants = options.checks,
        })
        if ok then
            for _, seat in ipairs(result.winners) do
                -- a tie shares the win
                wins[seat] = wins[seat] + 1 / #result.winners
            end
            for seat, score in ipairs(result.scores) do
                totals[seat] = totals[seat] + score
            end
            out(string.format("seed=%d scores=[%s] winner=%s actions=%d digest=%s",
                seed, table.concat(result.scores, " "), table.concat(result.winners, "&"), result.actions, result.digest))
        else
            failures = failures + 1
            out(string.format("FAIL seed=%d: %s", seed, tostring(result)))
            out("replay with: love . --sim --seed " .. seed .. " --players " .. options.players .. " --bots " .. table.concat(options.bots, ","))
        end
    end
    local elapsed = love.timer.getTime() - start
    local played = options.games - failures
    local summary = {}
    for seat = 1, options.players do
        table.insert(summary, string.format("%s(%s) wins=%.1f avg=%.1f", names[seat], options.bots[seat], wins[seat],
            played > 0 and totals[seat] / played or 0))
    end
    out(string.format("%s %d/%d games in %.2fs (%.0f games/s): %s",
        failures == 0 and "PASS" or "FAIL", played, options.games, elapsed, options.games / math.max(elapsed, 1e-6), table.concat(summary, "; ")))
    return failures == 0 and 0 or 1
end

return HeadlessMatch
