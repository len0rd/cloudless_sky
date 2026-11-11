-- Game state (game is being actively played). Entered with the game to play:
--     GameStateMachineMgr.switch(game, gameState)
-- (from main.lua at launch, the main menu's Continue or the New Game menu). game:leaveTo goes back
-- to the menus
local GameFlow = require("cloudless_sky.model.game_flow")
local GameRules = require("cloudless_sky.model.game_rules")

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

local GameEndStateMachine = require("cloudless_sky.states.game_end_sm")
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
        graphicsState.matEntities[ii] = PlayerMatEntity.new(ii, 600, starTypes, gameState.rules)
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
    self.gameEndSm = GameEndStateMachine()
    self.gameOver = false
    self:_checkGameOver()
end

--- @param newGameState GameState the game to play (new, or part way through: a loaded save)
function game:enter(from, newGameState)
    assert(newGameState, "the game state needs a game to play")
    self:_setup(newGameState)
end

--- Pop every state machine above this one (from any of them), abandoning the running game's round
function game:_popToGame()
    -- the old round mustn't move its (discarded) game on as its turn is popped
    self.roundSm.abandoned = true
    while GameStateMachineMgr.current() ~= self do
        GameStateMachineMgr.pop()
    end
end

--- Replace the running game with \p newGameState. Call from any state on top of this one: they are all
--- popped, then the game carries on from \p newGameState
function game:_replaceGame(newGameState)
    self:_popToGame()
    self:_setup(newGameState)
end

--- Leave the game for \p state (eg: the main menu). Call from any state on top of this one: they are
--- all popped first. Extra arguments go to \p state's enter
function game:leaveTo(state, ...)
    self:_popToGame()
    GameStateMachineMgr.switch(state, ...)
end

--- Replace the running game with \p loadedGameState (from SaveGame)
function game:loadGame(loadedGameState)
    self:_replaceGame(loadedGameState)
    Log.info("loaded game: round " .. gameState.round.idx .. ", player " .. gameState.currentTurnPlayer .. "'s turn")
end

function game:_checkGameOver()
    if GameFlow.isGameOver(gameState) then
        -- end-game bonuses and final scores (GameEndStateMachine)
        Log.info("game over")
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
        GameStateMachineMgr.push(self.gameEndSm, gameState, graphicsState)
        return
    end
    GameStateMachineMgr.push(self.roundSm, gameState, graphicsState)
end

function game:draw()
    graphicsState.world:emit("draw", gameState)
end

return game
