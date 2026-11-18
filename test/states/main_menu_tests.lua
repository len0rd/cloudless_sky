local cute = require("cloudless_sky.extern.cute")
local MainMenuState = require("cloudless_sky.states.main_menu_state")
local MenuBackground = require("cloudless_sky.view.menu_background")

notion("MainMenuState.breathScale: the title breathes gently around full size", function()
    check(MainMenuState.breathScale(0)).is(1)
    local low, high = math.huge, -math.huge
    for t = 0, 10, 0.05 do
        local s = MainMenuState.breathScale(t)
        low, high = math.min(low, s), math.max(high, s)
    end
    check(low < 1 and low > 0.9).is(true)
    check(high > 1 and high < 1.1).is(true)
end)

notion("MenuBackground.colorAt: blues that wrap around smoothly", function()
    for pos = -2, 2, 0.01 do
        local r, g, b = MenuBackground.colorAt(pos)
        -- blue is always the strongest
        check(b >= g and b >= r).is(true)
    end
    -- one full cycle later is the same color
    local r1, g1, b1 = MenuBackground.colorAt(0.3)
    local r2, g2, b2 = MenuBackground.colorAt(1.3)
    check(math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) < 1e-9).is(true)
    -- no jump where it wraps
    local ra, ga, ba = MenuBackground.colorAt(0.9999)
    local rb, gb, bb = MenuBackground.colorAt(0)
    check(math.abs(ra - rb) + math.abs(ga - gb) + math.abs(ba - bb) < 0.01).is(true)
end)
