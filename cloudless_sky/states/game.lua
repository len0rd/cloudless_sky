-- Game state (game is being actively played)
local PlayerMatView = require("cloudless_sky.view.player_mat_view")

local game = {}

function game:init() end

-- runs every time the state is entered
function game:enter(gameSettings, gameState)
    myMat = PlayerMatView(200, 200, 900)
end

function game:update()
    local mouseX, mouseY = camera:worldCoords(love.mouse.getPosition())
    -- move camera if necessary
    -- if camera.x ~= CameraXDesired or camera.y ~= CameraYDesired then
    --     local dx, dy = CameraXDesired - camera.x, CameraYDesired - camera.y
    --     camera:move(dx / 2, dy / 2)
    -- end
    myMat:update(mouseX, mouseY)
end

function game:draw()
    camera:attach()
    do
        myMat:draw()
    end
    camera:detach()
end

-- events

function game:mousepressed(x, y, button, istouch)
    if button == 1 then
        local clickX, clickY = camera:worldCoords(x, y)
        local clickedStarIndex, clickedSlotIndex = myMat:coordStarSlotIndex(clickX, clickY)
        if clickedStarIndex ~= 0 and clickedSlotIndex ~= 0 then
            CameraXDesired, CameraYDesired = myMat:centerOfSlot(clickedStarIndex, clickedSlotIndex)
        end
    end
end

function game:keyreleased(key, code)
    if key == "escape" then
        love.event.quit(0)
    end
end

return game
