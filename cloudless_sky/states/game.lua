-- Game state (game is being actively played)
-- local PlayerController = require("cloudless_sky.control.player_controller")
local json = require("cloudless_sky.extern.json")
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")

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

local GameRoundStateMachine = require("cloudless_sky.states.game_round_sm")
local WorldStateMachine = require("cloudless_sky.states.world_sm")

local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

local game = {}

function game:init()
    local playerNames = { "lenord", "karoty" }
    local rules = GameRules.currentRules()

    gameState = GameState(rules, playerNames, love.math.newRandomGenerator(os.time()))

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
    for ii = 1, #playerNames do
        graphicsState.matEntities[ii] = PlayerMatEntity.new(ii, 600, GameRules.matStarTypes(rules))
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
    self.gameOver = false
end

-- runs every time the state is entered
function game:enter(from)
    -- turn finished

    -- if saveGame ~= nil then
    --     playerControl:deserialize(saveGame["players"][1])
    -- end
end

function game:resume(from)
    -- a round just ended
    if gameState:isFinalRound() and gameState:allPlayersPassed() then
        -- TODO: final scoring (star completion, number bonuses, leftover tile penalty)
        Log.info("game over! final scoring is not implemented yet")
        self.gameOver = true
    end
end

function game:update(dt)
    if self.gameOver then
        -- keep the world running (animations, hover) so the final state can be looked at
        graphicsState.world:emit("update", dt, gameState)
        return
    end
    GameStateMachineMgr.push(self.roundSm, gameState, graphicsState)
end

function game:draw()
    graphicsState.world:emit("draw", gameState)
end

-- events

function game:onSave()
    local serialized = gameState:serialize()
    local encoded = json.encode(serialized)
    local file = io.open("savegamelatest.json", "w")
    if file then
        file:write(encoded)
        file:close()
        print("Game saved to savegame.json")
    else
        print("Failed to save game!")
    end
end

function game:mousepressed(x, y, button, istouch)
    local clickX, clickY = camera:worldCoords(x, y)
    -- playerControl:mousePressed(clickX, clickY, button, istouch)
end

function game:keyreleased(key, code)
    if key == "escape" then
        self:onSave()
        love.event.quit(0)
    elseif key == "space" then
        spacePressed = true
    end
end

function game:resize(w, h)
    -- playerControl:resize(w, h)
end

return game
