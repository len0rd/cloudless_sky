local cute = require("cloudless_sky.extern.cute")
local Canonical = require("cloudless_sky.model.canonical")
local GameRules = require("cloudless_sky.model.game_rules")
local GameSetup = require("cloudless_sky.model.game_setup")
local Invariants = require("cloudless_sky.model.invariants")

--- run \p fn, then put the current rules back (GameSetup sets them)
local keepingRules = function(fn)
    local before = GameRules.currentRules()
    local ok, err = pcall(fn)
    GameRules.setRules(before)
    if not ok then
        error(err, 0)
    end
end

notion("GameSetup builds a valid game for every preset and 2-4 players", function()
    keepingRules(function()
        for _, preset in ipairs(GameRules.PRESETS) do
            for numPlayers = GameSetup.MIN_PLAYERS, GameSetup.MAX_PLAYERS do
                local gameState = GameSetup.newGameState({
                    playerNames = GameSetup.defaultNames(numPlayers),
                    presetId = preset.id,
                    seed = 7,
                })
                check(gameState:numPlayers()).is(numPlayers)
                check(gameState.rules == preset.rules).is(true)
                check(GameRules.currentRules() == preset.rules).is(true)
                check(gameState.players[numPlayers].playerName).is("Player " .. numPlayers)
                check(#Invariants.check(gameState)).is(0)
            end
        end
    end)
end)

notion("GameSetup defaults to the Base rules, and the same seed gives the same game", function()
    keepingRules(function()
        local a = GameSetup.newGameState({ playerNames = { "a", "b" }, seed = 99 })
        local b = GameSetup.newGameState({ playerNames = { "a", "b" }, seed = 99 })
        check(a.rules == GameRules.preset("base").rules).is(true)
        check(a.seed).is(99)
        check(Canonical.encode(a:serialize()) == Canonical.encode(b:serialize())).is(true)
    end)
end)

notion("GameRules presets: Base and Mono Stars, looked up by id", function()
    check(#GameRules.PRESETS).is(2)
    check(GameRules.preset("base").label).is("Base")
    check(GameRules.preset("mono").label).is("Mono Stars")
    check(GameRules.preset("mono").rules.playerMat.stars[1].type).is("MONO")
    check(GameRules.preset("nope") == nil).is(true)
end)

notion("GameSetup rejects too few or too many players", function()
    check(pcall(GameSetup.newGameState, { playerNames = { "solo" } })).is(false)
    check(pcall(GameSetup.newGameState, { playerNames = { "a", "b", "c", "d", "e" } })).is(false)
end)
