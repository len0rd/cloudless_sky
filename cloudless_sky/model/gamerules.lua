-- Game rules that can be modified or tweaked on a per-game basis
--

local GameRules = {}

local DEFAULT_GAME_RULES = {
    bonusSurrounds = {
        circle = true,
        statue = true,
        window = true,
        fountain = false,
    },
    bonusValue = {
        circle = 1,
        statue = 2,
        window = 3,
        fountain = 0,
    },
    pointsPerAdjacentTile = 1,
    wildPerRound = {
        "PURPLE",
        "GREEN",
        "ORANGE",
        "YELLOW",
        "BLUE",
        "RED",
    },
    numBonusTiles = 10,
    startScore = 5,
    maxTileRoundCarryover = 4,
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
}
