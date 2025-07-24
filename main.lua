if arg[2] == "debug" then
    require("lldebugger").start()
end
-- third-party requirements
local Camera = require("cloudless_sky.extern.hump.camera")
-- local
-- local StarView = require("cloudless_sky.view.star_view")
local TileType = require("cloudless_sky.model.tile_type")
local PlayerMatView = require("cloudless_sky.view.player_mat_view")

local cameraX, cameraY = 400, 100

---------------
-- setup window
---------------
-- TODO: make more intelligent, or make fullscreen
love.window.setMode(1280, 720, { resizable = true })
love.window.setTitle("Cloudless Sky")

function love.conf(t)
    t.version = "11.5"
end

function love.load(args)
    tick = require("cloudless_sky.extern.tick")

    -- run unit tests if --cute arg is passed in
    local cute = require("cloudless_sky.extern.cute")
    cute.go(args)
    -- end unit testing

    camera = Camera(cameraX, cameraY)
    love.graphics.setBackgroundColor(0.4, 0.88, 1.0)

    -- myStar = StarView(TileType.RED, 400, 100, 300)
    myMat = PlayerMatView(200, 200, 900)
end

function love.update(dt)
    local mouseX, mouseY = camera:worldCoords(love.mouse.getPosition())
    tick.update(dt)
    myMat:update(mouseX, mouseY)
    -- move camera if necessary
    if camera.x ~= cameraX or camera.y ~= cameraY then
        local dx, dy = cameraX - camera.x, cameraY - camera.y
        camera:move(dx / 2, dy / 2)
    end
end

function love.draw()
    camera:attach()
    do
        love.graphics.print("howdy")

        myMat:draw()
    end
    camera:detach()
end

-- events

function love.keypressed(key) end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then
        local clickX, clickY = camera:worldCoords(x, y)
        local clickedStarIndex, clickedSlotIndex = myMat:coordStarSlotIndex(clickX, clickY)
        if clickedStarIndex ~= 0 and clickedSlotIndex ~= 0 then
            cameraX, cameraY = myMat:centerOfSlot(clickedStarIndex, clickedSlotIndex)
        end
    end
end

-- error handling
local love_errorhandler = love.errorhandler

function love.errorhandler(msg)
    if lldebugger then
        error(msg, 2)
    else
        return love_errorhandler(msg)
    end
end
