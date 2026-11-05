-- Game state (game is being actively played)
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")
local SaveGame = require("cloudless_sky.model.save_game")

local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local MousePressedSys = require("cloudless_sky.systems.mouse_pressed")
local DrawSys = require("cloudless_sky.systems.draw")
local PlayerMatTileAnchorSys = require("cloudless_sky.systems.player_mat_tile_anchor")
local EnforceUniqueGroupSys = require("cloudless_sky.systems.enforce_unique_group")
local EnforceEphemeralSys = require("cloudless_sky.systems.enforce_ephemeral")

local PlayerMatEntity = require("cloudless_sky.entities.player_mat_entity")
local PlayerHudContainerEntity = require("cloudless_sky.entities.player_hud_container")
local TableAreaEntity = require("cloudless_sky.entities.table_area_entity")

local GameOverStateMachine = require("cloudless_sky.states.game_over_sm")
local GameRoundStateMachine = require("cloudless_sky.states.game_round_sm")
local WorldStateMachine = require("cloudless_sky.states.world_sm")

local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

local game = {}

--- Build everything for playing \p newGameState: the ECS world and its entities (all drawn from the
--- model, so this works for a game part way through) and a fresh GameRound state machine
function game:_setup(newGameState)
    gameState = newGameState

    graphicsState = {
        world = Concord.world(),
        -- make player mat entities easily accessible
        matEntities = {},
        hud = {
            container = PlayerHudContainerEntity.new(),
        },
        -- factory displays, center of the table, bag and tower
        table = nil,
        -- what the camera is looking at (WorldStateMachine.VIEW)
        viewFocus = WorldStateMachine.VIEW.TABLE,
    }
    local starTypes = GameRules.matStarTypes(gameState.rules)
    for ii = 1, gameState:numPlayers() do
        graphicsState.matEntities[ii] = PlayerMatEntity.new(ii, 600, starTypes)
        graphicsState.world:addEntity(graphicsState.matEntities[ii])
    end
    graphicsState.table = TableAreaEntity.new(gameState, graphicsState.matEntities)
    graphicsState.world:addEntity(graphicsState.table)
    graphicsState.world:addEntity(graphicsState.hud.container)

    --- REMEMBER: systems are called in the order they are added
    graphicsState.world:addSystems(
        MousePressedSys,
        EnforceEphemeralSys,
        DrawSys,
        PlayerMatTileAnchorSys,
        EnforceUniqueGroupSys
    )
    function graphicsState.world:onEntityAdded(e)
        if e:has(Components.names.uniqueGroup) then
            -- right now this is the only situation where systems care about new entities
            self:emit("entityAdded", e)
        end
    end

    self.roundSm = GameRoundStateMachine()
    self.gameOverSm = GameOverStateMachine()
    self.gameOver = false
    self:_checkGameOver()
end

--- @return GameState a new game
local function newGame()
    local playerNames = { "lenord", "karoty" }
    local rules = GameRules.currentRules()
    local seed = (launchOptions and launchOptions.seed) or os.time()
    Log.info("game seed: " .. tostring(seed) .. " (replay with --seed " .. tostring(seed) .. ")")
    return GameState(rules, playerNames, love.math.newRandomGenerator(seed), seed)
end

function game:init()
    local loaded = nil
    if launchOptions and launchOptions.savePath then
        local reason
        loaded, reason = SaveGame.readFile(launchOptions.savePath)
        if loaded then
            Log.info("loaded " .. launchOptions.savePath)
        else
            Log.error("couldn't load " .. launchOptions.savePath .. ": " .. tostring(reason) .. ". starting a new game")
        end
    end
    self:_setup(loaded or newGame())
end

--- Replace the running game with \p loadedGameState (from SaveGame). Call from any state on top of
--- this one: they are all popped, then the game carries on from the loaded state
function game:loadGame(loadedGameState)
    -- the old round mustn't move its (discarded) game on as its turn is popped
    self.roundSm.abandoned = true
    while GameStateMachineMgr.current() ~= self do
        GameStateMachineMgr.pop()
    end
    self:_setup(loadedGameState)
    Log.info("loaded game: round " .. gameState.round.idx .. ", player " .. gameState.currentTurnPlayer .. "'s turn")
end

function game:_checkGameOver()
    if gameState:isFinalRound() and gameState:allPlayersPassed() then
        -- TODO: final scoring (star completion, number bonuses, leftover tile penalty)
        Log.info("game over! final scoring is not implemented yet")
        self.gameOver = true
    end
end

function game:resume(from)
    if from == self.roundSm then
        -- a round just ended
        self:_checkGameOver()
    end
end

function game:update(dt)
    if self.gameOver then
        GameStateMachineMgr.push(self.gameOverSm, gameState, graphicsState)
        return
    end
    GameStateMachineMgr.push(self.roundSm, gameState, graphicsState)
end

function game:draw()
    graphicsState.world:emit("draw", gameState)
end

return game
