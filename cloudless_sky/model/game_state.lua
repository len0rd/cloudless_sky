--- Container of the full state of the current game
local Object = require("cloudless_sky.extern.classic")
local TileBag = require("cloudless_sky.model.tile_bag")
local TileType = require("cloudless_sky.model.tile_type")
local Player = require("cloudless_sky.model.player")
local GameRules = require("cloudless_sky.model.game_rules")

---@class GameState : Object
---@field tileBag TileBag The bag of fresh tiles to draw from throughout the game
---@field discard TileBag Contains all the tiles that have been discarded by players
---@field startPlayer integer Index of the current start player for the active round
---@field nextStartPlayer integer Index of player that will be the first player when the round is incremented
---@field currentTurnPlayer integer Index of the player who is taking a turn right now
---@field players table[Player] Array containing each player in the game
---@field actionHistory Action[] Every action performed, oldest first
---@field turnIdx integer Increments every turn and is never reused. Identifies the current turn
---@field turnHistoryStart integer #actionHistory when the current turn started
---@field factoryDisplays TileBag[] The factory displays tiles are picked from during tile selection
---@field center TileBag The center of the table. Tiles left on a display after a pick are moved here
---@field startTokenHolder integer|nil Index of the player holding the start player token.
---     nil while the token is in the center of the table
---@field seed integer Seed \p rng was created from. Saved so a game can be recreated exactly
---@field rng GameRng The only source of randomness for game logic. Actions that draw from it
---     record its state (rng:getState()) before drawing so they can be undone/replayed exactly
local GameState = Object:extend()

--- Tile sources (where tiles are taken from during tile selection) are integers:
--- GameState.CENTER for the center of the table, 1..numFactoryDisplays() for a factory display
GameState.CENTER = 0

--- Interface for the random generator passed to GameState. The model doesn't depend on any
--- particular implementation
---@class GameRng
---@field random fun(self, min: integer, max: integer): integer random integer in [min, max]
---@field getState fun(self): any serializable state
---@field setState fun(self, state: any) restore a state returned by getState

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
--- @param rng GameRng random generator for all game logic randomness, already seeded with \p seed
--- @param seed integer the seed \p rng was created from. Saved with the game so it can be recreated
function GameState:new(gameRules, playerNames, rng, seed)
    assert(
        rng and rng.random and rng.getState and rng.setState,
        "GameState requires a random generator with random, getState and setState"
    )
    assert(type(seed) == "number", "GameState requires the seed its random generator was created from")
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

    local numDisplays = gameRules.factoryDisplay.displaysPerPlayerCount[tostring(#playerNames)]
    assert(numDisplays, "rules don't define a factory display count for " .. #playerNames .. " players")
    self.factoryDisplays = {}
    for ii = 1, numDisplays do
        self.factoryDisplays[ii] = TileBag()
    end
    self.center = TileBag()
    self.startTokenHolder = nil

    self.round = {
        idx = 1,
        phase = GameState.RoundPhase.TILE_SELECTION,
    }

    self.actionQueue = {}
    self.actionHistory = {}

    self.turnIdx = 1
    self.turnHistoryStart = 0

    self.rng = rng
    self.seed = seed
end

function GameState:serialize()
    local serialized = {
        rules = self.rules,
        tileBag = self.tileBag:serialize(),
        discard = self.discard:serialize(),
        players = {},
        round = self.round,
        factoryDisplays = {},
        center = self.center:serialize(),
        startTokenHolder = self.startTokenHolder,
        startPlayer = self.startPlayer,
        currentTurnPlayer = self.currentTurnPlayer,
        -- TODO: restore with self.rng:setState(data.rngState) once GameState deserialization exists
        seed = self.seed,
        rngState = self.rng:getState(),
    }
    for ii, player in ipairs(self.players) do
        serialized.players[ii] = player:serialize()
    end
    for ii, display in ipairs(self.factoryDisplays) do
        serialized.factoryDisplays[ii] = display:serialize()
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

--- @return TileType|nil wild The wild TileType for the next round, or nil if this is the final round
function GameState:getNextRoundWildType()
    return self.rules.wildPerRound[self.round.idx + 1]
end

--- @return boolean True if the current round is the last round of the game
function GameState:isFinalRound()
    return self.round.idx >= #self.rules.wildPerRound
end

--- @return integer limit How many tiles a player may keep when passing this round.
---     Comes from the rules (clamped to GameRules.MAX_TILE_CARRYOVER). 0 in the final round as
---     there is no next round to keep tiles for
function GameState:tileCarryoverLimit()
    if self:isFinalRound() then
        return 0
    end
    local limit = self.rules.playerMat.maxTileCarryoverPerRound or 0
    return math.max(0, math.min(limit, GameRules.MAX_TILE_CARRYOVER))
end

--- @return boolean True if every player has passed for the current phase
function GameState:allPlayersPassed()
    for _, player in ipairs(self.players) do
        if not player.passedForPhase then
            return false
        end
    end
    return true
end

function GameState:numFactoryDisplays()
    return #self.factoryDisplays
end

--- @param source integer GameState.CENTER or a factory display index
--- @return TileBag|nil bag The tiles at \p source, or nil if \p source isn't valid
function GameState:tileSource(source)
    if source == GameState.CENTER then
        return self.center
    end
    return self.factoryDisplays[source]
end

--- @return boolean True when every factory display and the center are empty (tile selection is over)
function GameState:allTileSourcesEmpty()
    if not self.center:isEmpty() then
        return false
    end
    for _, display in ipairs(self.factoryDisplays) do
        if not display:isEmpty() then
            return false
        end
    end
    return true
end

function GameState:getMatSlotCost(starIdx, slotIdx)
    return self.rules.playerMat.stars[starIdx].cost[slotIdx]
end

--- Perform an action on this game state and record it in actionHistory.
--- Any follow-up actions it returns are performed (and recorded) immediately after it,
--- depth-first, in the order they were returned.
--- The action is validated first (Action:validate). An invalid action is rejected without
--- changing any state (no error is raised).
--- @param action Action the action to perform
--- @return Action[]|nil performed Every action performed, in order (\p action first). Useful for
---     the UI to decide what to animate. nil if \p action was invalid
--- @return string|nil reason Why \p action was invalid
function GameState:performAction(action)
    local valid, reason = action:validate(self)
    if not valid then
        return nil, reason
    end

    local performed = {}
    local function performRecursive(a, isFollowUp)
        a.isFollowUp = isFollowUp
        local followUps = a:perform(self) or {}
        table.insert(self.actionHistory, a)
        table.insert(performed, a)
        for _, followUp in ipairs(followUps) do
            performRecursive(followUp, true)
        end
    end
    -- the action passed in is a player choice. Everything it triggers is a follow-up
    performRecursive(action, false)
    return performed
end

--- @return boolean True if the current turn has a player choice that can be undone
function GameState:canUndoChoice()
    return #self.actionHistory > self.turnHistoryStart
end

--- Undo the most recent player choice made this turn: its follow-up actions (newest first), then
--- the choice itself (the most recent action with isFollowUp == false).
--- Never undoes actions from before the current turn (see turnHistoryStart)
--- @return Action[]|nil undone. The actions undone, newest first. nil if there is nothing to undo this turn
function GameState:undoLastChoice()
    if not self:canUndoChoice() then
        return nil
    end
    local undone = {}
    while #self.actionHistory > self.turnHistoryStart do
        local action = self:undoLastAction()
        table.insert(undone, action)
        if not action.isFollowUp then
            break
        end
    end
    return undone
end

--- Undo the most recently performed action and remove it from actionHistory.
--- This is a single step: it ignores choice grouping and turn boundaries. For player-facing undo
--- use undoLastChoice
--- @return Action|nil undone. The action that was undone, or nil if there is no history
function GameState:undoLastAction()
    local action = table.remove(self.actionHistory)
    if action then
        action:undo(self)
    end
    return action
end

--- Advance to the next player's turn. The current turn's actions can no longer be undone
-- TODO: should be moved into an action (its perform/undo would then update turnIdx/turnHistoryStart)
--- Players who have passed this phase are skipped. If every player has passed, the next player
--- in order is selected (ending the round is not implemented yet. see allPlayersPassed)
function GameState:incrementTurn()
    local numPlayers = #self.players
    local nextPlayer = (self.currentTurnPlayer % numPlayers) + 1
    for _ = 1, numPlayers do
        if not self.players[nextPlayer].passedForPhase then
            break
        end
        nextPlayer = (nextPlayer % numPlayers) + 1
    end
    self:beginTurn(nextPlayer)
end

--- Start a new turn for \p playerIdx. Nothing performed before this can be undone by the player
--- (see undoLastChoice)
-- TODO: should be moved into an action (see incrementTurn)
function GameState:beginTurn(playerIdx)
    assert(self.players[playerIdx], "invalid playerIdx " .. tostring(playerIdx))
    self.currentTurnPlayer = playerIdx
    self.turnIdx = self.turnIdx + 1
    self.turnHistoryStart = #self.actionHistory
end

return GameState
