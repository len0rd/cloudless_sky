if arg[2] == "debug" then
    require("lldebugger").start()
end
local cute = require("cloudless_sky.extern.cute")

function love.conf(t)
    t.version = "11.5"
end

function love.load(args)
    Tile = require("cloudless_sky.tile")
    tick = require("cloudless_sky.extern.tick")
    -- run unit tests if --cute arg is passed in
    cute.go(args)
end


function love.draw()
    love.graphics.print("howdy")
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
