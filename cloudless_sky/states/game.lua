-- Game state (game is being actively played)
local PlayerController = require("cloudless_sky.control.player_controller")
local json = require("cloudless_sky.extern.json")
local GameRules = require("cloudless_sky.model.game_rules")

local game = {}

function game:init() end

-- runs every time the state is entered
function game:enter(gameSettings, gameState)
    playerControl = PlayerController("lenord", 200, 200, 600)
    if saveGame ~= nil then
        playerControl:deserialize(saveGame["players"][1])
    end
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
    playerControl:mousePressed(clickX, clickY, button, istouch)
end

function game:keyreleased(key, code)
    if key == "escape" then
        self:onSave()
        love.event.quit(0)
    end
end

function game:resize(w, h)
    playerControl:resize(w, h)
end

return game
