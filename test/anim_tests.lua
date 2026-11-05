local cute = require("cloudless_sky.extern.cute")
local Anim = require("cloudless_sky.anim")

--- run \p fn at animation speed \p speed, restoring the previous speed afterwards
local withSpeed = function(speed, fn)
    local previous = Anim.getSpeed()
    Anim.setSpeed(speed)
    local ok, err = pcall(fn)
    Anim.setSpeed(previous)
    if not ok then
        error(err, 0)
    end
end

notion("Anim.time scales durations by the animation speed", function()
    withSpeed(1, function()
        check(Anim.time(0.5)).is(0.5)
        check(Anim.isOff()).is(false)
    end)
    withSpeed(2, function()
        check(Anim.time(0.5)).is(0.25)
    end)
    withSpeed(0.5, function()
        check(Anim.time(0.5)).is(1)
    end)
    withSpeed(0, function()
        check(Anim.time(0.5)).is(0)
        check(Anim.isOff()).is(true)
    end)
end)

notion("Anim rejects negative and non-number speeds", function()
    check(Anim.isValidSpeed(-1)).is(false)
    check(Anim.isValidSpeed("fast")).is(false)
    check(Anim.isValidSpeed(0)).is(true)
    check(Anim.isValidSpeed(2.5)).is(true)
end)

notion("Anim camera smoother jumps straight to the target when animations are off", function()
    local smoother = Anim.cameraSmoother(5)
    withSpeed(0, function()
        local dx, dy = smoother(100, -40)
        check(dx).is(100)
        check(dy).is(-40)
    end)
    withSpeed(1, function()
        -- eases: never moves further than the remaining distance
        local dx = smoother(100, 0)
        check(dx <= 100).is(true)
    end)
end)

notion("Anim join calls done once every callback has been called", function()
    local calls = 0
    local finish = Anim.join(3, function()
        calls = calls + 1
    end)
    finish()
    finish()
    check(calls).is(0)
    finish()
    check(calls).is(1)

    -- nothing to wait for: done right away
    Anim.join(0, function()
        calls = calls + 1
    end)
    check(calls).is(2)
end)
