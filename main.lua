if arg[2] == "debug" then
    require("lldebugger").start()
end
-- third-party requirements
local Camera = require("cloudless_sky.extern.hump.camera")
local Gamestate = require("cloudless_sky.extern.hump.gamestate")
local luis = require("luis.init")("luis/widgets")
luis.flux = require("luis.3rdparty.flux")
-- local
local game = require("cloudless_sky.states.game")

-- TODO: better storage/access method?
fonts = {}

-- global X,Y of where we want the camera centered
CameraXDesired, CameraYDesired = 400, 100

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

    love.graphics.setBackgroundColor(0.4, 0.88, 1.0, 0.5)

    -- fonts
    fonts.ithaca = {
        ["12"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 18),
        ["16"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 24),
    }

    -- GLOBAL CAMERA
    camera = Camera(CameraXDesired, CameraYDesired)
    camera.smoother = Camera.smooth.damped(5)

    -- luis
    -- run flux at 60hz
    local fluxUpdateTimer = tick.recur(function()
        luis.flux.update(1 / 60)
    end, 1 / 60)

    luis.setGridSize(20)

    luis.newLayer("main")
    luis.enableLayer("main")
    luis.setCurrentLayer("main")

    -- GAMESTATE
    Gamestate.registerEvents()
    Gamestate.switch(game)
end

function love.update(dt)
    -- local mouseX, mouseY = camera:worldCoords(love.mouse.getPosition())
    tick.update(dt)
    -- camera motion
    camera:lockPosition(CameraXDesired, CameraYDesired)
    -- ui updates
    luis.update(dt)
end

function love.draw()
    camera:attach()
    do
    end
    camera:detach()
    -- todo: luis handlers below need to be passed world coords, and this should be run in the camera
    --  except it would also be nice to use screen coords for hud elements... hmmm. can 2 simultaneous instances of luis exist??
    luis.draw()
end

-- events

function love.keypressed(key) end

function love.mousepressed(x, y, button, istouch)
    luis.mousepressed(x, y, button, istouch)
end

function love.mousereleased(x, y, button, istouch)
    luis.mousereleased(x, y, button, istouch)
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
