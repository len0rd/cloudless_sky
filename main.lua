if arg[2] == "debug" then
    require("lldebugger").start()
end

function love.draw()
    love.graphics.print("howdy")
end
