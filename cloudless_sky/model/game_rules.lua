-- Game rules that can be modified or tweaked on a per-game basis
-- This is setup as a singleton to simplify access across the game
require("cloudless_sky.util")

-- class returned for interacting with the game rules instance
---@class GameRules
---@field bonusSurrounds table Settings for the playmat features players earn bonuses for surrounding
---@field wildPerRound table Ordered list of the TileType that will be the wild each round
---@field startScore integer How many points each player starts with
---@field endGameBonus table Bonuses added to a players score at the end of the game for various play mat conditions
---@field factoryDisplay table Rules for the factory display/tile selection area
---@field totalTiles integer Total number of tiles in play during a game
---@field playerMat table Rules and configuration of the player mat
local GameRules = {}

GameRules.DEFAULTS = {}

-- the current game rules. access via
local CurrentGameRules = nil

GameRules.DEFAULTS.BASE_GAME_RULES = {
    bonusSurrounds = {
        enabled = {
            pillar = true,
            statue = true,
            window = true,
            fountain = false,
        },
        bonusValueTiles = {
            pillar = 1,
            statue = 2,
            window = 3,
            fountain = 0,
        },
        -- number of tiles in the center display to pick from when bonus is received
        numBonusTiles = 10,
    },
    wildPerRound = {
        "PURPLE",
        "GREEN",
        "ORANGE",
        "YELLOW",
        "BLUE",
        "RED",
    },
    startScore = 5,
    endGameBonus = {
        starCompletion = {
            RED = 14,
            ORANGE = 17,
            YELLOW = 16,
            GREEN = 18,
            BLUE = 15,
            PURPLE = 20,
        },
        -- completing all slots of a given number
        slotCompletion = {
            [1] = 4,
            [2] = 8,
            [3] = 12,
            [4] = 16,
        },
        -- any tiles left over at the end of the game are negative points
        leftoverPenalty = true,
    },
    factoryDisplay = {
        displaysPerPlayerCount = {
            ["2"] = 5,
            ["3"] = 7,
            ["4"] = 9,
        },
        tilesPerDisplay = 4,
        -- Player can take at most this many wild tiles per turn
        maxWildPerTurn = 1,
    },
    totalTiles = 132,
    playerMat = {
        maxTileCarryoverPerRound = 4,
        stars = {
            [1] = {
                type = "ORANGE",
                cost = { 6, 1, 2, 3, 4, 5 },
            },
            [2] = {
                type = "RED",
                cost = { 5, 6, 1, 2, 3, 4 },
            },
            [3] = {
                type = "BLUE",
                cost = { 4, 5, 6, 1, 2, 3 },
            },
            [4] = {
                type = "YELLOW",
                cost = { 3, 4, 5, 6, 1, 2 },
            },
            [5] = {
                type = "GREEN",
                cost = { 2, 3, 4, 5, 6, 1 },
            },
            [6] = {
                type = "PURPLE",
                cost = { 1, 2, 3, 4, 5, 6 },
            },
            [7] = {
                type = "MULTI",
                cost = { 1, 2, 3, 4, 5, 6 },
            },
        },
    },
}

GameRules.DEFAULTS.BASE_GAME_MONO_RULES = table.copy(GameRules.DEFAULTS.BASE_GAME_RULES)
GameRules.DEFAULTS.BASE_GAME_MONO_RULES.playerMat.stars = {
    [1] = {
        type = "MONO",
        cost = { 6, 3, 2, 1, 4, 5 },
    },
    [2] = {
        type = "MONO",
        cost = { 5, 6, 3, 2, 1, 4 },
    },
    [3] = {
        type = "MONO",
        cost = { 4, 5, 6, 3, 2, 1 },
    },
    [4] = {
        type = "MONO",
        cost = { 1, 4, 5, 6, 3, 2 },
    },
    [5] = {
        type = "MONO",
        cost = { 2, 1, 4, 5, 6, 3 },
    },
    [6] = {
        type = "MONO",
        cost = { 3, 2, 1, 4, 5, 6 },
    },
    [7] = {
        type = "MULTI",
        cost = { 3, 3, 3, 3, 3, 3 },
    },
}

function GameRules.currentRules()
    if not CurrentGameRules then
        CurrentGameRules = GameRules.DEFAULTS.BASE_GAME_RULES
    end
    return CurrentGameRules
end

function GameRules.setRules(rules)
    CurrentGameRules = rules
end

function GameRules.serialize()
    return GameRules.currentRules()
end

--- Get the mat-indexed list of star types for the provided rules. if rules is nil, current is used
function GameRules.matStarTypes(rules)
    local ruleset = rules
    if not ruleset then
        ruleset = GameRules.currentRules()
    end
    local sTypes = {}
    for _, star in ipairs(ruleset.playerMat.stars) do
        table.insert(sTypes, star.type)
    end
    return sTypes
end

return GameRules
