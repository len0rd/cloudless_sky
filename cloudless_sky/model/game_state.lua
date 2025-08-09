--- Container of the full state of the current game
local Object = require("cloudless_sky.extern.classic")
local TileBag = require("cloudless_sky.model.tile_bag")
local TileType = require("cloudless_sky.model.tile_type")
local Player = require("cloudless_sky.model.player")

---@class GameState : Object
---@field tileBag TileBag The bag of fresh tiles to draw from throughout the game
---@field discard TileBag Contains all the tiles that have been discarded by players
---@field startPlayer integer Index of the current start player for the active round
---@field nextStartPlayer integer Index of player that will be the first player when the round is incremented
---@field currentTurnPlayer integer Index of the player who is taking a turn right now
---@field players table[Player] Array containing each player in the game
local GameState = Object:extend()

-- the phases that happen each round
GameState.RoundPhase = {
    -- players take turns collecting tiles from the factory displays or floor
    TILE_SELECTION = 1,
    -- players take turns placing tiles on their mat
    TILE_PLACEMENT = 2,
}

GameState.RoundPhaseOrdered = {
    GameState.RoundPhase.TILE_SELECTION,
    GameState.RoundPhase.TILE_PLACEMENT,
}

--- Start a new game!
--- @param gameRules GameRules ruleset for this game
--- @param playerNames table[string] List of player names. Length of list is used to determine number of players
function GameState:new(gameRules, playerNames)
    local tilesPerType = math.floor(gameRules.totalTiles / #TileType.ORDERED)

    self.rules = gameRules

    self.tileBag = TileBag(tilesPerType)
    self.discard = TileBag()

    self.startPlayer = 1
    self.nextStartPlayer = 1
    self.currentTurnPlayer = 1

    self.players = {}
    for ii = 1, #playerNames do
        local newPlayer = Player(gameRules.playerMat.stars, gameRules.startScore, playerNames[ii])
        table.insert(self.players, newPlayer)
    end

    self.round = {
        idx = 1,
        phase = GameState.RoundPhase.TILE_SELECTION,
    }

    self.actionQueue = {}
    self.actionHistory = {}
end

function GameState:serialize()
    local serialized = {
        rules = self.rules,
        tileBag = self.tileBag:serialize(),
        discard = self.discard:serialize(),
        players = {},
        round = self.round,
    }
    for ii, player in ipairs(self.players) do
        serialized.players[ii] = player:serialize()
    end
    return serialized
end

function GameState:numPlayers()
    return #self.players
end

--- convenience access functions:

function GameState:getStar(playerIdx, starIdx)
    assert(playerIdx > 0 and playerIdx <= #self.players, "playerIdx is out of range")
    assert(starIdx > 0 and starIdx <= #self.players[playerIdx].mat.stars, "starIdx is out of range")
    return self.players[playerIdx].mat.stars[starIdx]
end

function GameState:getStarType(starIdx)
    return self.rules.playerMat.stars[starIdx].type
end

function GameState:getCurrentWildType()
    return self.rules.wildPerRound[self.round.idx]
end

function GameState:getMatSlotCost(starIdx, slotIdx)
    return self.rules.playerMat.stars[starIdx].cost[slotIdx]
end

-- TODO: should be moved into an action
function GameState:incrementTurn()
    self.currentTurnPlayer = (self.currentTurnPlayer % #self.players) + 1
end

return GameState
