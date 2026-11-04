local cute = require("cloudless_sky.extern.cute")
local TileGroupView = require("cloudless_sky.view.tile_group_view")
local TileType = require("cloudless_sky.model.tile_type")
local ViewUtil = require("cloudless_sky.view.view_util")

notion("TileGroupView add/remove keeps counts and positions inside the circle", function()
    local group = TileGroupView(100, 200, 80, 40)
    group:addTile(TileType.RED)
    group:addTile(TileType.RED)
    local blue = group:addTile(TileType.BLUE)
    check(group:counts()[TileType.RED]).is(2)
    check(group:counts()[TileType.BLUE]).is(1)
    check(group:counts()[TileType.GREEN]).is(0)
    for _, tile in ipairs(group.tiles) do
        check(ViewUtil.ptInCircle(tile.x, tile.y, 100, 200, 80)).is(true)
    end

    -- asking for more than there are removes what there is
    check(#group:removeTiles(TileType.RED, 5)).is(2)
    check(group:counts()[TileType.RED]).is(0)

    -- prefer removes that tile first
    group:addTile(TileType.BLUE)
    local removed = group:removeTiles(TileType.BLUE, 1, blue)
    check(removed[1] == blue).is(true)
    check(#group.tiles).is(1)
end)

notion("TileGroupView tileAt finds the topmost tile under a point", function()
    local group = TileGroupView(0, 0, 100, 40)
    local bottom = group:addTile(TileType.RED)
    bottom.x, bottom.y, bottom.rot = 0, 0, 0
    local top = group:addTile(TileType.BLUE)
    top.x, top.y, top.rot = 5, 0, 0

    -- overlapping point: the later (top) tile wins
    check(group:tileAt(3, 0) == top).is(true)
    -- only under the bottom tile
    check(group:tileAt(-11, 0) == bottom).is(true)
    -- tiles are diamonds: their bounding box corners are empty
    check(group:tileAt(-19, -19)).is(nil)
    check(group:tileAt(500, 500)).is(nil)
end)

notion("ViewUtil.ptInConvexPoly works for either winding", function()
    local cw = { 0, 0, 10, 0, 10, 10, 0, 10 }
    local ccw = { 0, 0, 0, 10, 10, 10, 10, 0 }
    check(ViewUtil.ptInConvexPoly(cw, 5, 5)).is(true)
    check(ViewUtil.ptInConvexPoly(ccw, 5, 5)).is(true)
    check(ViewUtil.ptInConvexPoly(cw, 15, 5)).is(false)
    check(ViewUtil.ptInConvexPoly(ccw, -1, 5)).is(false)
end)
