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

--- Hard upper limit on how many tiles a player may keep between rounds when passing.
--- playerMat.maxTileCarryoverPerRound may not exceed this (it is clamped if it does)
GameRules.MAX_TILE_CARRYOVER = 10

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
        -- the bonus spaces on the mat (MatBonus), in index order, and the {star, slot} pairs around
        -- each. Stars sit as     1   2       star slots: 1 at the top, then clockwise
        --                      6   7   3
        --                        5   4
        spaces = {
            -- pillars: between star 7 and each outer star
            { kind = "pillar", slots = { { 7, 1 }, { 7, 6 }, { 1, 3 }, { 1, 4 } } },
            { kind = "pillar", slots = { { 7, 1 }, { 7, 2 }, { 2, 4 }, { 2, 5 } } },
            { kind = "pillar", slots = { { 7, 2 }, { 7, 3 }, { 3, 5 }, { 3, 6 } } },
            { kind = "pillar", slots = { { 7, 3 }, { 7, 4 }, { 4, 1 }, { 4, 6 } } },
            { kind = "pillar", slots = { { 7, 4 }, { 7, 5 }, { 5, 1 }, { 5, 2 } } },
            { kind = "pillar", slots = { { 7, 5 }, { 7, 6 }, { 6, 2 }, { 6, 3 } } },
            -- statues: between neighboring outer stars (1-2, 2-3, ... 6-1)
            { kind = "statue", slots = { { 1, 2 }, { 1, 3 }, { 2, 5 }, { 2, 6 } } },
            { kind = "statue", slots = { { 2, 3 }, { 2, 4 }, { 3, 1 }, { 3, 6 } } },
            { kind = "statue", slots = { { 3, 4 }, { 3, 5 }, { 4, 1 }, { 4, 2 } } },
            { kind = "statue", slots = { { 4, 5 }, { 4, 6 }, { 5, 2 }, { 5, 3 } } },
            { kind = "statue", slots = { { 5, 1 }, { 5, 6 }, { 6, 3 }, { 6, 4 } } },
            { kind = "statue", slots = { { 6, 1 }, { 6, 2 }, { 1, 4 }, { 1, 5 } } },
            -- windows: on the outside of each outer star, between its cost 5 and 6 slots
            { kind = "window", slots = { { 1, 1 }, { 1, 6 } } },
            { kind = "window", slots = { { 2, 1 }, { 2, 2 } } },
            { kind = "window", slots = { { 3, 2 }, { 3, 3 } } },
            { kind = "window", slots = { { 4, 3 }, { 4, 4 } } },
            { kind = "window", slots = { { 5, 4 }, { 5, 5 } } },
            { kind = "window", slots = { { 6, 5 }, { 6, 6 } } },
            -- fountains: the outer area between neighboring outer stars (1-2, ... 6-1): cost 6 and 1
            -- of the first, cost 4 and 5 of the next
            { kind = "fountain", slots = { { 1, 1 }, { 1, 2 }, { 2, 1 }, { 2, 6 } } },
            { kind = "fountain", slots = { { 2, 2 }, { 2, 3 }, { 3, 1 }, { 3, 2 } } },
            { kind = "fountain", slots = { { 3, 3 }, { 3, 4 }, { 4, 2 }, { 4, 3 } } },
            { kind = "fountain", slots = { { 4, 4 }, { 4, 5 }, { 5, 3 }, { 5, 4 } } },
            { kind = "fountain", slots = { { 5, 5 }, { 5, 6 }, { 6, 4 }, { 6, 5 } } },
            { kind = "fountain", slots = { { 6, 6 }, { 6, 1 }, { 1, 6 }, { 1, 5 } } },
        },
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
            MULTI = 12,
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
        -- taking first-player tile from the center applies a penalty equal to num tiles taken
        centerFirstPickPenalty = true,
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

--- @param kind string MatBonus.KIND
--- @return integer tiles a player picks from the bonus pool for achieving a \p kind bonus space.
---     0 if that kind is disabled
function GameRules.bonusTiles(rules, kind)
    local surrounds = rules.bonusSurrounds
    if not (surrounds and surrounds.enabled and surrounds.enabled[kind]) then
        return 0
    end
    return (surrounds.bonusValueTiles and surrounds.bonusValueTiles[kind]) or 0
end

--- Rule sets a new game can be started with (the New Game menu), in display order
GameRules.PRESETS = {
    { id = "base", label = "Base", rules = GameRules.DEFAULTS.BASE_GAME_RULES },
    { id = "mono", label = "Mono Stars", rules = GameRules.DEFAULTS.BASE_GAME_MONO_RULES },
}

--- @return table|nil preset the entry of GameRules.PRESETS with id \p id
function GameRules.preset(id)
    for _, preset in ipairs(GameRules.PRESETS) do
        if preset.id == id then
            return preset
        end
    end
    return nil
end

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
