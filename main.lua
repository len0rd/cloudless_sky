if arg[2] == "debug" then
    require("lldebugger").start()
end

function love.conf(t)
    t.version = "11.5"
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
