--- Info for displaying tiles
local TileType = require("cloudless_sky.model.tile_type")
local ViewUtil = require("cloudless_sky.view.view_util")

local TileView = {}

TileView.TILE_COLOR = {
    [TileType.RED] = { 255, 15, 15 },
    [TileType.ORANGE] = { 255, 113, 66 },
    [TileType.YELLOW] = { 255, 210, 77 },
    [TileType.GREEN] = { 161, 215, 106 },
    [TileType.BLUE] = { 74, 161, 242 },
    [TileType.PURPLE] = { 153, 90, 181 },
}
TileView.TILE_COLOR = ViewUtil.normalizeColorTable(TileView.TILE_COLOR)

return TileView
