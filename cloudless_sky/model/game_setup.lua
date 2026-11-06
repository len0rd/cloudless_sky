--- Starting a new game from a setup (player names, rule preset, seed): used at launch (main.lua) and
--- by the New Game menu
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")

local GameSetup = {}

GameSetup.MIN_PLAYERS = 2
GameSetup.MAX_PLAYERS = 4
GameSetup.DEFAULT_PRESET = "base"

--- @return string the name player \p idx gets when none is given
function GameSetup.defaultName(idx)
    return "Player " .. idx
end

--- @return string[] default names for \p count players
function GameSetup.defaultNames(count)
    local names = {}
    for ii = 1, count do
        names[ii] = GameSetup.defaultName(ii)
    end
    return names
end

--- @param setup table { playerNames = string[], presetId = string|nil (default "base"),
---     seed = integer|nil (default: the time) }
--- @return GameState a new game. Its rules also become the current rules (GameRules.setRules)
function GameSetup.newGameState(setup)
    local preset = GameRules.preset(setup.presetId or GameSetup.DEFAULT_PRESET)
    assert(preset, "unknown rule preset " .. tostring(setup.presetId))
    local numPlayers = #setup.playerNames
    assert(numPlayers >= GameSetup.MIN_PLAYERS and numPlayers <= GameSetup.MAX_PLAYERS, "a game needs 2-4 players")
    local seed = setup.seed or os.time()
    Log.info("game seed: " .. tostring(seed) .. " (replay with --seed " .. tostring(seed) .. "), rules: " .. preset.label)
    GameRules.setRules(preset.rules)
    return GameState(preset.rules, setup.playerNames, love.math.newRandomGenerator(seed), seed)
end

return GameSetup
