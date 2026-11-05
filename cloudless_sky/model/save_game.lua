--- Saving and restoring a game.
---
--- Single save should have all data needed to restore a game:
---     - GameRules
---     - player names
---     - rand-seed
---     - full action history
---
--- Loading a save uses the seed +  action history to rebuild the entire GameState
---
--- The save also holds a snapshot (GameState:serialize()) for now. Restoring checks
--- the replayed game against it, so a save that doesn't replay exactly (eg: made by an older version
--- of the game with different rules logic) is rejected rather than loaded wrong.
---
--- build/restore are pure. The *File functions use love.filesystem (the save directory)
local Action = require("cloudless_sky.action.action")
local Canonical = require("cloudless_sky.model.canonical")
local GameState = require("cloudless_sky.model.game_state")
local json = require("cloudless_sky.extern.json")

-- every action type must be registered before Action.deserialize sees it. Most are required by
-- GameState or the state machines already; require them all here so restore doesn't depend on that
require("cloudless_sky.action.add_score")
require("cloudless_sky.action.begin_turn")
require("cloudless_sky.action.end_round")
require("cloudless_sky.action.fill_bonus_pool")
require("cloudless_sky.action.fill_factory_displays")
require("cloudless_sky.action.pass")
require("cloudless_sky.action.place_tile")
require("cloudless_sky.action.score_end_game")
require("cloudless_sky.action.start_placement_phase")
require("cloudless_sky.action.take_tiles")

local SaveGame = {}

-- 2: the bonus pool (GameState.bonusPool, FillBonusPoolAction)
SaveGame.VERSION = 2
--- file name in the LÖVE save directory (love.filesystem.getSaveDirectory())
SaveGame.FILE = "savegame.json"

--- @param gameState GameState
--- @return table save plain data (json-encodable) that SaveGame.restore turns back into the game
function SaveGame.build(gameState)
    local playerNames = {}
    for ii, player in ipairs(gameState.players) do
        playerNames[ii] = player.playerName
    end
    local history = {}
    for ii, action in ipairs(gameState.actionHistory) do
        history[ii] = action:serialize()
    end
    return {
        version = SaveGame.VERSION,
        rules = gameState.rules,
        playerNames = playerNames,
        seed = gameState.seed,
        history = history,
        snapshot = gameState:serialize(),
    }
end

--- Recreate a game from a save made by SaveGame.build
--- @param data table the save
--- @param rngFactory function|nil function(seed) -> GameRng. Defaults to love.math.newRandomGenerator
--- @return GameState|nil gameState the restored game. nil if it couldn't be restored
--- @return string|nil reason why the save couldn't be restored
function SaveGame.restore(data, rngFactory)
    rngFactory = rngFactory or love.math.newRandomGenerator
    if type(data) ~= "table" then
        return nil, "not a save game"
    end
    if data.version ~= SaveGame.VERSION then
        return nil, "unsupported save version " .. tostring(data.version) .. " (expected " .. SaveGame.VERSION .. ")"
    end
    if type(data.seed) ~= "number" or type(data.rules) ~= "table" or type(data.history) ~= "table" then
        return nil, "save is missing its seed, rules or history"
    end

    local ok, result = pcall(function()
        local gameState = GameState(data.rules, data.playerNames, rngFactory(data.seed), data.seed)
        for ii, entry in ipairs(data.history) do
            -- follow-ups are performed again by their parent action
            if not entry.isFollowUp then
                if not Action.known[entry.name] then
                    error({ reason = "history " .. ii .. ": unknown action " .. tostring(entry.name) }, 0)
                end
                local action = Action.deserialize(entry)
                local performed, reason = gameState:performAction(action)
                if not performed then
                    error({ reason = "history " .. ii .. ": " .. entry.name .. " is invalid: " .. tostring(reason) }, 0)
                end
            end
        end
        return gameState
    end)
    if not ok then
        return nil, type(result) == "table" and result.reason or ("replay failed: " .. tostring(result))
    end
    local gameState = result

    -- the replay must match the save exactly
    if #gameState.actionHistory ~= #data.history then
        return nil, "replay has " .. #gameState.actionHistory .. " actions, the save has " .. #data.history
    end
    for ii, action in ipairs(gameState.actionHistory) do
        local diff = Canonical.diff(action:serialize(), data.history[ii], "history." .. ii)
        if diff then
            return nil, "replay differs from the save: " .. diff
        end
    end
    if data.snapshot then
        local diff = Canonical.diff(gameState:serialize(), data.snapshot)
        if diff then
            return nil, "replay differs from the save: " .. diff
        end
    end
    return gameState, nil
end

--- @return string json the save for \p gameState
function SaveGame.encode(gameState)
    return json.encode(SaveGame.build(gameState))
end

--- @return GameState|nil gameState, string|nil reason. See SaveGame.restore
function SaveGame.decode(str, rngFactory)
    local ok, data = pcall(json.decode, str)
    if not ok then
        return nil, "save file isn't valid json: " .. tostring(data)
    end
    return SaveGame.restore(data, rngFactory)
end

--- Save \p gameState to SaveGame.FILE in the save directory
--- @return boolean saved
--- @return string|nil reason why it wasn't saved
function SaveGame.writeFile(gameState)
    local ok, encoded = pcall(SaveGame.encode, gameState)
    if not ok then
        return false, "couldn't encode the game: " .. tostring(encoded)
    end
    local written, reason = love.filesystem.write(SaveGame.FILE, encoded)
    if not written then
        return false, tostring(reason)
    end
    Log.info("game saved to " .. love.filesystem.getSaveDirectory() .. "/" .. SaveGame.FILE)
    return true, nil
end

--- @return boolean True if there is a save in the save directory
function SaveGame.exists()
    return love.filesystem.getInfo(SaveGame.FILE, "file") ~= nil
end

--- Read and restore a save
--- @param path string|nil a file path (eg: from the command line). nil for SaveGame.FILE in the save
---     directory
--- @return GameState|nil gameState, string|nil reason. See SaveGame.restore
function SaveGame.readFile(path)
    local contents
    if path then
        local file = io.open(path, "r")
        if not file then
            return nil, "couldn't open " .. path
        end
        contents = file:read("*a")
        file:close()
    else
        local reason
        contents, reason = love.filesystem.read(SaveGame.FILE)
        if not contents then
            return nil, "couldn't read the save: " .. tostring(reason)
        end
    end
    return SaveGame.decode(contents)
end

return SaveGame
