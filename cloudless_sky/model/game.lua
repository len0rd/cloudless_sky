--- Container of the full state of the current game
local Object = require("cloudless_sky.extern.classic")
local TileBag = require("cloudless_sky.model.tile_bag")
local TileType = require("cloudless_sky.model.tile_type")

---@class Game : Object

local Game = Object:extend()

-- the phases that happen each round
Game.RoundPhase = {
    -- players take turns collecting tiles from the factory displays or floor
    "TileSelection",
    -- players take turns placing tiles on their mat
    "TilePlacement",
}

--- Start a new game!
--- @param gameRules GameRules ruleset for this game
--- @param playerNames table. List of play
function Game:new(gameRules, playerNames)
    local tilesPerType = math.floor(gameRules.totalTiles / #TileType.ORDERED)

    ---@field tileBag TileBag The bag of fresh tiles to draw from throughout the game
    self.tileBag = TileBag(tilesPerType)
    ---@field discard TileBag Contains all the tiles that have been discarded by players
    self.discard = TileBag()

    ---@field startPlayer integer Index of the current start player for the active round
    self.startPlayer = 1
    ---@field nextStartPlayer integer Player that will be the first player when the round is incremented
    self.nextStartPlayer = 1

    -- the player who's turn it is RIGHT NOW
    self.currentTurnPlayer = 1
    self.players = {}
    -- start at 0 so that everything gets populated when advanceRound is called
    self.currentRound = 1
    self.currentRoundPhase = Game.RoundPhase[1]
end

return Game
