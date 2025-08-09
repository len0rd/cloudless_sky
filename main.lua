if arg[2] == "debug" then
    require("lldebugger").start()
end
-- third-party requirements
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

-- TODO: better storage/access method?
fonts = {}

saveGame = nil

-- global X,Y of where we want the camera centered
CameraXDesired, CameraYDesired = 400, 100

---------------
-- setup window
---------------
-- TODO: make more intelligent, or make fullscreen
love.window.setMode(1280, 720, { resizable = true })
love.window.setTitle("Cloudless Sky")

function love.load(args)
    -- run unit tests if --cute arg is passed in
    local cute = require("cloudless_sky.extern.cute")
    cute.go(args)
    -- end unit testing

    -- load save game if passed as an arg
    for _, v in ipairs(args) do
        if string.find(v, "%.json") then
            local json = require("cloudless_sky.extern.json")
            local file = io.open(v, "r")
            if file then
                local contents = file:read("*a")
                file:close()
                saveGame = json.decode(contents)
                if err then
                    print("Error decoding JSON:", err)
                end
            else
                print("Could not open JSON file:", v)
            end
            break
        end
    end

    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)

    -- fonts
    fonts.ithaca = {
        ["12"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 18),
        ["16"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 24),
    }
    for size, _ in pairs(fonts.ithaca) do
        fonts.ithaca[size]:setFilter("linear", "nearest")
    end

    -- GLOBAL CAMERA
    local Camera = require("cloudless_sky.extern.hump.camera")
    camera = Camera(CameraXDesired, CameraYDesired)
    camera.smoother = Camera.smooth.damped(5)

    -- GAMESTATE
    game = require("cloudless_sky.states.game")
    GameStateMachineMgr.registerEvents()
    GameStateMachineMgr.switch(game)
end

function love.update(dt)
    -- local mouseX, mouseY = camera:worldCoords(love.mouse.getPosition())
    -- camera motion
    -- camera:lockPosition(CameraXDesired, CameraYDesired)
    -- ui updates
end

function love.draw() end

-- events

function love.keypressed(key) end

function love.mousepressed(x, y, button, istouch) end

function love.mousereleased(x, y, button, istouch) end

function love.resize(w, h)
    -- Gamestate.current():resize(w, h)
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
