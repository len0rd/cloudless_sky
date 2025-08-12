local Object = require("cloudless_sky.extern.classic")
local StarType = require("cloudless_sky.model.star_type")
local TileType = require("cloudless_sky.model.tile_type")
local Star = require("cloudless_sky.model.star")

local StarView = require("cloudless_sky.view.star_view")

---@class PlayerHandStarView : StarView special instance of star view that has static
---     tiles "placed"
local PlayerHandStarView = StarView:extend()

function PlayerHandStarView:new(x, y, size)
    self.super:new(StarType.MULTI_STATIC, x, y, size)
    self.star = Star({
        type = StarType.MULTI_STATIC,
        color = {
            TileType.RED,
            TileType.ORANGE,
            TileType.YELLOW,
            TileType.GREEN,
            TileType.BLUE,
            TileType.PURPLE,
        },
        cost = { 1, 1, 1, 1, 1, 1 },
    })

    for ii = 1, #self.star.occupiedSlots do
        self.star.occupiedSlots[ii] = true
    end
end

function PlayerHandStarView:update(dt)
    self.super:update(dt, 0)
end

function PlayerHandStarView:draw()
    self.super:draw(self.star)
end

return PlayerHandStarView
