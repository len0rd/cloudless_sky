local cute = require("cloudless_sky.extern.cute")
local StarType = require("cloudless_sky.model.star_type")
local StarView = require("cloudless_sky.view.star_view")

--- run \p view's tweens for \p seconds in small steps
local function advance(view, seconds)
    for _ = 1, math.ceil(seconds / 0.05) do
        view:update(0.05, 0)
    end
end

notion("StarView:pulseSlots grows the slots, then returns them to normal size", function()
    local view = StarView(StarType.RED, 0, 0, 100)
    local done = false
    view:pulseSlots({ 2, 5 }, function()
        done = true
    end)

    advance(view, 0.2)
    check(view.polys[2].scale > 1.1).is(true)
    check(view.polys[5].scale > 1.1).is(true)
    -- other slots are untouched
    check(view.polys[1].scale).is(1.0)
    check(done).is(false)

    advance(view, 1)
    check(view.polys[2].scale).is(1.0)
    check(view.polys[5].scale).is(1.0)
    check(done).is(true)
end)

notion("StarView:pulseSlots with no slots completes straight away", function()
    local view = StarView(StarType.MULTI, 0, 0, 100)
    local done = false
    view:pulseSlots({}, function()
        done = true
    end)
    check(done).is(true)
end)
