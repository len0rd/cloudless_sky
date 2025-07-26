-- Game state (game is being actively played)
local PlayerMatController = require("cloudless_sky.control.player_mat_controller")
local luis = require("luis.init")("luis/widgets")
local json = require("cloudless_sky.extern.json")
local GameRules = require("cloudless_sky.model.game_rules")

local game = {}

function game:init()
    local button1 = luis.createElement(luis.currentLayer, "Button", "Save", 4, 2, function()
        print("save pressed")
    end, function()
        game:onSave()
    end, 1, 1)
    -- button1:setDecorator("GlassmorphismDecorator", {})
end

-- runs every time the state is entered
function game:enter(gameSettings, gameState)
    myMat = PlayerMatController(200, 200, 600)
end

function game:update(dt)
    local mouseX, mouseY = camera:mousePosition()
    -- move camera if necessary
    -- if camera.x ~= CameraXDesired or camera.y ~= CameraYDesired then
    --     local dx, dy = CameraXDesired - camera.x, CameraYDesired - camera.y
    --     camera:move(dx / 2, dy / 2)
    -- end
    myMat:update(dt, mouseX, mouseY)
end

function game:draw()
    camera:attach()
    do
        myMat:draw()
    end
    camera:detach()
end

-- events

function game:onSave()
    local serialized = {
        rules = GameRules.currentRules(),
        players = {
            myMat:serialize(),
        },
    }
    local encoded = json.encode(serialized)
    local file = io.open("savegame.json", "w")
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
    myMat:mousePressed(clickX, clickY, button, istouch)
end

function game:keyreleased(key, code)
    if key == "escape" then
        love.event.quit(0)
    end
end

return game
