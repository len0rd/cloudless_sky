if arg[2] == "debug" then
    require("lldebugger").start()
end

local StarView = require("cloudless_sky.view.star_view")
local TileType = require("cloudless_sky.model.tile_type")

function love.conf(t)
    t.version = "11.5"
end

function love.load(args)
    tick = require("cloudless_sky.extern.tick")

    -- run unit tests if --cute arg is passed in
    local cute = require("cloudless_sky.extern.cute")
    cute.go(args)
    -- end unit testing

    myStar = StarView(TileType.RED, 400, 100, 300)
end

function love.update(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    tick.update(dt)
    myStar:update(mouseX, mouseY)
end

function love.draw()
    love.graphics.print("howdy")

    myStar:draw()
end

-- events

function love.keypressed(key) end

-- error handling
local love_errorhandler = love.errorhandler

function love.errorhandler(msg)
    if lldebugger then
        error(msg, 2)
    else
        return love_errorhandler(msg)
    end
end
