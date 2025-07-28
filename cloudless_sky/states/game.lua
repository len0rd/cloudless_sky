-- Game state (game is being actively played)
local PlayerController = require("cloudless_sky.control.player_controller")
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
    playerControl = PlayerController("lenord", 200, 200, 600)
end

function game:update(dt)
    local mouseX, mouseY = camera:mousePosition()

    playerControl:update(dt, mouseX, mouseY)
end

function game:draw()
    playerControl:draw()
end

-- events

function game:onSave()
    local serialized = {
        rules = GameRules.currentRules(),
        players = {
            playerControl:serialize(),
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
    playerControl:mousePressed(clickX, clickY, button, istouch)
end

function game:keyreleased(key, code)
    if key == "escape" then
        love.event.quit(0)
    end
end

function game:resize(w, h)
    playerControl:resize(w, h)
end

return game
