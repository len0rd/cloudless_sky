--- A bot "player": something that makes a player's choices by itself. Implementations (eg: EasyBot)
--- extend this class and register themselves under an id ("easy"), so a runner can create one by name.
---
--- The contract: given the game state, a bot returns the action it wants to take. It must not change
--- the state (a bot that looks ahead may perform and undo actions, as long as the state ends exactly
--- as it was). The runner performs the action (GameState:performAction), so an invalid one is caught
--- there rather than trusted.
---
--- A bot makes random choices only with its own rng (never the game's), seeded from the game's seed and
--- its seat, so a game with the same seed and bots plays out the same every time.
---
--- The choices, by phase (see GameFlow for the order):
---     tile selection:  chooseTake        -> TakeTilesAction
---     tile placement:  choosePlacement   -> PlaceTileAction, or PassAction (with the tiles to keep)
---                      chooseBonusTiles  -> TakeBonusTilesAction, after a placement that owes bonus
---                                           tiles (LegalMoves.bonusPickup)
local Object = require("cloudless_sky.extern.classic")

---@class BotPlayer : Object
---@field id string the id it was registered under
---@field rng table love RandomGenerator for the bot's own random choices
---@field seat integer the player index it plays for
local BotPlayer = Object:extend()

--- id -> BotPlayer subclass
BotPlayer.known = {}
--- ids in the order they were registered (eg: for a menu)
BotPlayer.ids = {}

--- Make \p class creatable by \p id (BotPlayer.create)
function BotPlayer.register(id, class)
    assert(BotPlayer.known[id] == nil, "bot '" .. id .. "' is already registered")
    BotPlayer.known[id] = class
    class.id = id
    table.insert(BotPlayer.ids, id)
end

--- @param gameSeed integer the game's seed
--- @param seat integer the player index the bot plays for
--- @return integer the seed for the bot's own rng: differs per seat, and from the game's own rng seed
function BotPlayer.seedFor(gameSeed, seat)
    return gameSeed + 1000 * seat + 1
end

--- @param id string a registered bot id (eg: "easy")
--- @param gameSeed integer the game's seed
--- @param seat integer the player index it plays for
--- @return BotPlayer
function BotPlayer.create(id, gameSeed, seat)
    local class = BotPlayer.known[id]
    assert(class, "unknown bot '" .. tostring(id) .. "'")
    return class(love.math.newRandomGenerator(BotPlayer.seedFor(gameSeed, seat)), seat)
end

--- @param rng table love RandomGenerator for the bot's own choices
--- @param seat integer the player index it plays for
function BotPlayer:new(rng, seat)
    self.rng = rng
    self.seat = seat
end

--- @return any a random element of \p list (nil if it's empty)
function BotPlayer:pick(list)
    if #list == 0 then
        return nil
    end
    return list[self.rng:random(1, #list)]
end

--- Tile selection: which tiles to take
--- @param gameState GameState
--- @param playerIdx integer
--- @return TakeTilesAction
function BotPlayer:chooseTake(gameState, playerIdx)
    error("bot '" .. tostring(self.id) .. "' must implement chooseTake")
end

--- Tile placement: where to place a tile, or to pass
--- @return PlaceTileAction|PassAction
function BotPlayer:choosePlacement(gameState, playerIdx)
    error("bot '" .. tostring(self.id) .. "' must implement choosePlacement")
end

--- After a placement that completed bonus spaces: which \p count tiles to pick up from the bonus pool
--- @return TakeBonusTilesAction
function BotPlayer:chooseBonusTiles(gameState, playerIdx, count)
    error("bot '" .. tostring(self.id) .. "' must implement chooseBonusTiles")
end

return BotPlayer
