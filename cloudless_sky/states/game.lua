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

local PlayerMatEntity = require("cloudless_sky.entities.player_mat_entity")

local TilePlacementTurnStateMachine = require("cloudless_sky.states.tile_placement_turn_sm")

local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

local game = {}

local spacePressed = false

function game:init()
    local playerNames = { "lenord", "karoty" }
    local rules = GameRules.currentRules()

    gameState = GameState(rules, playerNames)

    graphicsState = {
        world = Concord.world(),
        -- make player mat entities easily accessible
        matEntities = {},
    }
    for ii = 1, #playerNames do
        graphicsState.matEntities[ii] = PlayerMatEntity.new(ii, 600, GameRules.matStarTypes(rules))
        graphicsState.world:addEntity(graphicsState.matEntities[ii])
    end

    --- REMEMBER: systems are called in the order they are added
    graphicsState.world:addSystems(MousePressedSys, DrawSys, PlayerMatTileAnchorSys, EnforceUniqueGroupSys)
    function graphicsState.world:onEntityAdded(e)
        if e:has(Components.names.uniqueGroup) then
            -- right now this is the only situation where systems care about new entities
            self:emit("entityAdded", e)
        end
    end

    turnSm = TilePlacementTurnStateMachine()
end

-- runs every time the state is entered
function game:enter(from)
    -- turn finished

    -- if saveGame ~= nil then
    --     playerControl:deserialize(saveGame["players"][1])
    -- end
end

function game:resume(from)
    print("increment turn!")
    gameState:incrementTurn()
end

function game:update(dt)
    -- if spacePressed then
    --     spacePressed = false
    GameStateMachineMgr.push(turnSm, gameState.currentTurnPlayer, gameState, graphicsState)
    -- end
end

function game:draw() end

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
