local cute = require("cloudless_sky.extern.cute")
local ViewUtil = require("cloudless_sky.view.view_util")

notion("ViewUtil pointsOnCircle spaces points evenly, clockwise from the start angle", function()
    local points = ViewUtil.pointsOnCircle(10, 20, 5, 4, -math.pi / 2)
    check(#points).is(4)
    -- top, then right (screen y grows down, so clockwise goes top -> right -> bottom -> left)
    local expected = { { 10, 15 }, { 15, 20 }, { 10, 25 }, { 5, 20 } }
    for ii, point in ipairs(points) do
        check(math.abs(point.x - expected[ii][1]) < 1e-9).is(true)
        check(math.abs(point.y - expected[ii][2]) < 1e-9).is(true)
        check(math.abs(ViewUtil.euclidianDistance(point.x, point.y, 10, 20) - 5) < 1e-9).is(true)
    end
end)

notion("ViewUtil.buttonColumn stacks equal rects pad apart", function()
    local rects = ViewUtil.buttonColumn(10, 20, 200, 40, 8, 3)
    check(#rects).is(3)
    for ii, r in ipairs(rects) do
        check(r.x).is(10)
        check(r.w).is(200)
        check(r.h).is(40)
        check(r.y).is(20 + (ii - 1) * 48)
    end
    check(#ViewUtil.buttonColumn(0, 0, 1, 1, 1, 0)).is(0)
end)
