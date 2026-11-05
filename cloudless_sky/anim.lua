--- Animation speed setting, shared by every animation in the game.
---
--- The speed is a multiplier: 1 = normal, 2 = twice as fast, 0.5 = half speed, 0 = off (every
--- animation finishes immediately and looping/idle animations don't run).
---
--- Animation code should:
---     - pass every duration and delay through Anim.time
---     - not start looping/idle animations (eg: hover pulses) when Anim.isOff()
---     - still call its completion callbacks when off (zero-length flux tweens complete on their
---       next update), so state machines waiting on them keep working unchanged
local Anim = {}

Anim.DEFAULT_SPEED = 1

local speed = Anim.DEFAULT_SPEED

--- @param newSpeed number animation speed multiplier. 0 turns animations off
function Anim.setSpeed(newSpeed)
    assert(type(newSpeed) == "number" and newSpeed >= 0, "animation speed must be a number >= 0")
    speed = newSpeed
end

--- @return number the current animation speed multiplier (0 = off)
function Anim.getSpeed()
    return speed
end

--- @return boolean True if animations are turned off
function Anim.isOff()
    return speed == 0
end

--- @param seconds number how long something takes at normal speed
--- @return number how long it takes at the current speed (0 when animations are off)
function Anim.time(seconds)
    if speed == 0 then
        return 0
    end
    return seconds / speed
end

--- A hump.camera smoother that eases the camera toward its target, faster or slower with the
--- animation speed, and jumps straight there when animations are off.
--- Like hump's Camera.smooth.damped(stiffness)
function Anim.cameraSmoother(stiffness)
    return function(dx, dy, s)
        if speed == 0 then
            return dx, dy
        end
        -- clamped so very high speeds don't overshoot the target
        local dts = math.min(1, love.timer.getDelta() * (s or stiffness) * speed)
        return dx * dts, dy * dts
    end
end

return Anim
