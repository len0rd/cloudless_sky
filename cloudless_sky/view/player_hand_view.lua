--- Display of the players hand
local Object = require("cloudless_sky.extern.classic")
local PlayerHandView = Object:extend()
local TileView = require("cloudless_sky.view.tile_view")
local TileType = require("cloudless_sky.model.tile_type")
local ViewUtil = require("cloudless_sky.view.view_util")

local flux = require("luis.3rdparty.flux")

local TILE_SIZE_PX = 50

-- easeInOutCubic

---  <- originX,Y
--- +------------...-----+
--- |                    |
--- |                    |    * <- animStartX
--- |                    |
--- +-------------...----* <- maxX, maxY
function PlayerHandView:new(originX, originY, maxX, maxY, animStartX)
    self.originX = originX
    self.originY = originY
    self.maxX = maxX
    self.maxY = maxY
    self.drawHand = false
    self.animStartX = animStartX
    self.tilesToShow = {}
    self:_resetTilesToShow()

    self.revealTweenGroup = nil
    self.hideTweenGroup = nil
end

function PlayerHandView:_resetTilesToShow()
    local centerY = ((self.maxY - self.originY) / 2) + self.originY

    local tileSeparation = (self.maxX - self.originX) / #TileType.ORDERED
    local destXOffset = self.originX + (tileSeparation / 2)

    for ii, name in ipairs(TileType.ORDERED) do
        self.tilesToShow[ii] = {
            type = name,
            x = self.animStartX,
            y = centerY - TILE_SIZE_PX / 10,
            alpha = 0.0,
            destinationX = destXOffset + (tileSeparation * (ii - 1)),
            labelX = self.animStartX,
            labelAlpha = 0.0,
        }
    end
end

function PlayerHandView:show()
    if not self.drawHand then
        -- hand not currently shown, kick off the reveal tweening
        self:_resetTilesToShow()
        self.revealTweenGroup = flux.group()
        for ii, animCtx in ipairs(self.tilesToShow) do
            -- adjust opacity quickly
            self.revealTweenGroup:to(self.tilesToShow[ii], 0.1, { alpha = 1.0 })
            -- move tile out then show how many the player has
            self.revealTweenGroup
                :to(self.tilesToShow[ii], 0.25, { x = animCtx.destinationX, labelX = animCtx.destinationX })
                :after(self.tilesToShow[ii], 0.1, { labelX = animCtx.destinationX + TILE_SIZE_PX, labelAlpha = 1.0 })
        end
    end

    self.drawHand = true
end

function PlayerHandView:hide()
    if self.drawHand then
        self.revealTweenGroup = nil
        self.hideTweenGroup = flux.group()
        local HIDE_TIME_S = 0.25
        for ii, animCtx in ipairs(self.tilesToShow) do
            local tween = self.hideTweenGroup
                :to(self.tilesToShow[ii], 0.1, { labelAlpha = 0.0 })
                :after(self.tilesToShow[ii], HIDE_TIME_S, { alpha = 0.0, x = self.animStartX })
            if ii == #self.tilesToShow then
                tween:oncomplete(function()
                    self.drawHand = false
                end)
                -- else
                --     self.hideTweenGroup:to(self.tilesToShow[ii], HIDE_TIME_S, { alpha = 0.0, x = self.animStartX })
            end
        end
    end
end

function PlayerHandView:resize(originX, originY, maxX, maxY, animStartX)
    local animationComplete = math.floor(self.tilesToShow[1].x) == math.floor(self.tilesToShow[1].destinationX)
        and self.tilesToShow[1].destinationX ~= 0
    self.originX = originX
    self.originY = originY
    self.maxX = maxX
    self.maxY = maxY
    self.animStartX = animStartX
    self:_resetTilesToShow()
    if animationComplete then
        print("resize on anim complete")
        for ii, animCtx in ipairs(self.tilesToShow) do
            self.tilesToShow[ii].x = animCtx.destinationX
            self.tilesToShow[ii].alpha = 1.0
            self.tilesToShow[ii].labelX = animCtx.destinationX + TILE_SIZE_PX
            self.tilesToShow[ii].labelAlpha = 1.0
        end
    end
end

function PlayerHandView:update(dt)
    if self.drawHand then
        if self.revealTweenGroup ~= nil then
            self.revealTweenGroup:update(dt)
        elseif self.hideTweenGroup ~= nil then
            self.hideTweenGroup:update(dt)
        end
    end
end

--- @param playerHand TileBag state of player hand to be drawn
function PlayerHandView:draw(playerHand)
    if self.drawHand then
        local origR, origG, origB, origA = love.graphics.getColor()

        for _, animCtx in ipairs(self.tilesToShow) do
            local color = TileView.TILE_COLOR[animCtx.type]
            local numInHand = playerHand:num(animCtx.type)
            local flooredX = math.floor(animCtx.x)
            local flooredY = math.floor(animCtx.y)

            love.graphics.setColor(1, 1, 1, animCtx.labelAlpha)
            love.graphics.print(tostring(numInHand), fonts.ithaca["16"], animCtx.labelX, flooredY)

            love.graphics.setColor(color[1], color[2], color[3], animCtx.alpha)
            local tileVertices = TileView.tilePolyVerticies(TILE_SIZE_PX, -math.pi / 8)
            tileVertices = ViewUtil.shiftVerticies(tileVertices, flooredX, flooredY)
            love.graphics.polygon("fill", tileVertices)
            love.graphics.setColor({ 0, 0, 0, animCtx.alpha })
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line", tileVertices)
        end

        love.graphics.setColor(origR, origG, origB, origA)
    end
end

return PlayerHandView
