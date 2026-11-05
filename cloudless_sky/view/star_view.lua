-- Draw a tile star
local Object = require("cloudless_sky.extern.classic")
local Anim = require("cloudless_sky.anim")
local StarView = Object:extend()
local StarType = require("cloudless_sky.model.star_type")
local ViewUtil = require("cloudless_sky.view.view_util")
local TileView = require("cloudless_sky.view.tile_view")

local flux = require("cloudless_sky.extern.flux")

-- increase the size of a slot by this much when its selected/hovered on
local HOVER_SELECT_SCALE = 0.2

local transformScalerVertices = function(vertices, x, y, size)
    local scaledVertices = {}
    for ii = 1, #vertices, 2 do
        scaledVertices[ii] = (vertices[ii] * size) + x
        scaledVertices[ii + 1] = (vertices[ii + 1] * size) + y
    end
    return scaledVertices
end

-- RGB color for each star type when a tile is not in a slot
StarView.UNPLACED_SLOT_COLOR = {
    [StarType.RED] = { 255, 179, 186 },
    [StarType.ORANGE] = { 255, 222, 184 },
    [StarType.YELLOW] = { 255, 255, 184 },
    [StarType.GREEN] = { 184, 255, 187 },
    [StarType.BLUE] = { 184, 224, 255 },
    [StarType.PURPLE] = { 213, 184, 255 },
    [StarType.MULTI] = { 245, 243, 228 },
    [StarType.MONO] = { 245, 243, 228 },
    [StarType.MULTI_STATIC] = { 245, 243, 228 },
}
StarView.UNPLACED_SLOT_COLOR = ViewUtil.normalizeColorTables(StarView.UNPLACED_SLOT_COLOR)

-- slot cost labels are drawn in a darker variant of the star's color
local COST_LABEL_DARKEN = 0.55
-- color for slot cost labels on stars without a single color (MONO, MULTI)
local COST_LABEL_GRAY = { 0.35, 0.35, 0.35 }
-- how far (0 = outer tip, 1 = slot center) the cost label sits from the slot's outer tip
local COST_LABEL_TIP_INSET = 0.3
-- max cost label height as a fraction of the star's on-screen size. All slots in a star share
-- the same font so the labels are consistent
local COST_LABEL_MAX_HEIGHT = 0.1


-- stylua: ignore start
-- defines where the vertex for each slot in the star is placed as a scaler that can be
-- applied to the overall size to get exact coords
-- POINTS MUST BE ORDERED CLOCKWISE. To be consistent, start with Xmin,Ymin. Then move around each point clockwise
-- These should be ordered so the indices match the Star Slot indicies used in model/star.lua
StarView.SLOT_VERTEX_SCALARS = {
    [1] = {
        1/2, 0,
        4/6, 1/4,
        1/2, 1/2,
        2/6, 1/4,
    },
    [2] = {
        4/6, 1/4,
        1, 1/4,
        5/6, 1/2,
        1/2, 1/2,
    },
    [3] = {
        1/2, 1/2,
        5/6, 1/2,
        1, 3/4,
        4/6, 3/4,
    },
    [4] = {
        1/2, 1/2,
        4/6, 3/4,
        1/2, 1,
        2/6, 3/4,
    },
    [5] = {
        1/6, 1/2,
        1/2, 1/2,
        2/6, 3/4,
        0, 3/4,
    },
    [6] = {
        0, 1/4,
        2/6, 1/4,
        1/2, 1/2,
        1/6, 1/2
    }
}


-- defines the offset to apply to slots that are hovered or selected
-- offset needs to differ per-slot to look nice. {X, Y}
StarView.HOVER_SELECT_OFFSETS = {
    [1] = {-0.5 * HOVER_SELECT_SCALE, -0.4 * HOVER_SELECT_SCALE},
    [2] = {-0.6 * HOVER_SELECT_SCALE, -0.4 * HOVER_SELECT_SCALE},
    [3] = {-0.6 * HOVER_SELECT_SCALE, -0.6 * HOVER_SELECT_SCALE},
    [4] = {-0.5 * HOVER_SELECT_SCALE, -0.6 * HOVER_SELECT_SCALE},
    [5] = {-0.4 * HOVER_SELECT_SCALE, -0.6 * HOVER_SELECT_SCALE},
    [6] = {-0.4 * HOVER_SELECT_SCALE, -0.4 * HOVER_SELECT_SCALE},

}
-- stylua: ignore end

function StarView:_runBreathTween(tween)
    tween:to(self.polys[1], Anim.time(0.5), { scale = 1.25 }):after(self.polys[1], Anim.time(0.25), { scale = 1.0 }):oncomplete(function()
        self:_runBreathTween(tween)
    end)
end

--- @param x integer Left-most X world coord of the stars rectangular bounding box
--- @param y integer Top-most Y world coord of the stars rectangular bounding box
--- @param size integer Overall width and height of stars rectangular bounding box. Always square
function StarView:new(starType, x, y, size)
    self.starType = starType
    self.starOriginX = x
    self.starOriginY = y
    self.size = size
    -- rotate the star this many radians when drawing
    self.rotation = 0
    -- define the vertices of the 6 polygons that compose the star
    self.polys = {}
    -- set to the slot index that a pointer is hovering over on update
    self.hovered_slot = 0
    for ii, vertices in ipairs(StarView.SLOT_VERTEX_SCALARS) do
        self.polys[ii] = {
            verticies = transformScalerVertices(vertices, self.starOriginX, self.starOriginY, self.size),
            scale = 1.0,
        }
    end

    self.breathTween = flux.group()
    -- self:_runBreathTween(self.breathTween)

    -- tween for tile being placed
    self.placeTween = flux.group()
    -- tween for slots pulsing to draw attention to them (pulseSlots)
    self.pulseTween = flux.group()
    -- which star-slots are being animated. slotIdx -> { removing = bool, tileType = TileType|nil }
    -- tileType is only set when removing (model may no longer know removed tile color)
    self.animatingSlots = {}
end

-- tile removal (undo) animation settings
local REMOVE_END_SCALE = 0.2
local REMOVE_DURATION_S = 0.25

-- tile placement animation settings
local PLACE_START_SCALE = 0.2
local PLACE_DURATION_S = 0.6

--- "shrink out" animation for a tile that was just removed from \p slotIndex
--- @param tileType TileType color of the removed tile. The model no longer knows it
--- @param onComplete function|nil called once the animation finishes
function StarView:playRemoveAnimation(slotIndex, tileType, onComplete)
    local poly = self.polys[slotIndex]
    if not poly then
        if onComplete then
            onComplete()
        end
        return
    end
    self.animatingSlots[slotIndex] = { removing = true, tileType = tileType }
    poly.scale = 1.0
    self.placeTween
        :to(poly, Anim.time(REMOVE_DURATION_S), { scale = REMOVE_END_SCALE })
        :ease("backin")
        :oncomplete(function()
            self.animatingSlots[slotIndex] = nil
            poly.scale = 1.0
            if onComplete then
                onComplete()
            end
        end)
end

--- "bounce in" animation for a tile that was just placed in \p slotIndex
--- @param onComplete function|nil called once the animation finishes
function StarView:playPlaceAnimation(slotIndex, onComplete)
    local poly = self.polys[slotIndex]
    if not poly then
        if onComplete then
            onComplete()
        end
        return
    end
    self.animatingSlots[slotIndex] = { removing = false }
    poly.scale = PLACE_START_SCALE
    self.placeTween
        :to(poly, Anim.time(PLACE_DURATION_S), { scale = 1.0 })
        :ease("backout")
        :oncomplete(function()
            self.animatingSlots[slotIndex] = nil
            if onComplete then
                onComplete()
            end
        end)
end

-- pulse (pulseSlots) settings
local PULSE_SCALE = 1.25
local PULSE_GROW_S = 0.2
local PULSE_SHRINK_S = 0.3

--- Briefly enlarge the slots in \p slotIdxs, then shrink them back. Draws attention to them (eg: the
--- slots that earned an end-game bonus). Nothing happens when animations are off
--- @param slotIdxs integer[] slot indices of this star
--- @param onComplete function|nil called once every slot is back to normal size
function StarView:pulseSlots(slotIdxs, onComplete)
    local remaining = 0
    local function finished()
        remaining = remaining - 1
        if remaining == 0 and onComplete then
            onComplete()
        end
    end
    for _, slotIdx in ipairs(slotIdxs) do
        local poly = self.polys[slotIdx]
        if poly and not Anim.isOff() then
            remaining = remaining + 1
            poly.scale = 1.0
            self.pulseTween
                :to(poly, Anim.time(PULSE_GROW_S), { scale = PULSE_SCALE })
                :ease("quadout")
                :after(poly, Anim.time(PULSE_SHRINK_S), { scale = 1.0 })
                :ease("quadin")
                :oncomplete(finished)
        end
    end
    if remaining == 0 and onComplete then
        onComplete()
    end
end

--- @return table boundingBox. Bounding box of the star in world coords. Formatted x1,y1, x2,y2
---     Where x1,y1 is the top left of the star and x2,y2 is the bottom right
function StarView:boundingBox()
    return { self.starOriginX, self.starOriginY, self.starOriginX + self.size, self.starOriginY + self.size }
end

--- @return number, number centerCoords. The center of this star in world coords
function StarView:center()
    local centerX = self.starOriginX + (self.size / 2)
    local centerY = self.starOriginY + (self.size / 2)
    return centerX, centerY
end

--- Given an x,y coordinate, return what star slot index the coordinate is in
--- Or 0 if it is not in one
function StarView:coordSlotIndex(x, y)
    if not self:coordInBoundingBox(x, y) then
        return 0
    end
    for ii, poly in ipairs(self.polys) do
        if ViewUtil.ptInConvexPoly(poly.verticies, x, y) then
            return ii
        end
    end
    -- point is within the overall bounding box, but not in a specific Slot's poly
    return 0
end

--- Get the x,y world coordinate of the center of the given slot
function StarView:centerOfSlot(slotIndex)
    if slotIndex < 1 or slotIndex > #self.polys then
        return false, false
    end
    return ViewUtil.centerOfConvexPoly(self.polys[slotIndex].verticies)
end

function StarView:isHovered()
    return self.hovered_slot ~= 0
end

--- @return boolean inBounds. True if x,y are within the overall bounding box of this star, otherwise false
function StarView:coordInBoundingBox(x, y)
    if
        x < self.starOriginX
        or x > (self.starOriginX + self.size)
        or y < self.starOriginY
        or y > (self.starOriginY + self.size)
    then
        return false
    end
    return true
end

function StarView:update(dt, focusSlotIdx)
    -- reset hovered state
    self.hovered_slot = focusSlotIdx
    self.breathTween:update(dt)
    self.placeTween:update(dt)
    self.pulseTween:update(dt)
end

local drawPoly = function(vertices, color)
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.polygon("fill", vertices)
    love.graphics.setColor({ 0, 0, 0 })
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", vertices)
end

--- @return table vertices World-space vertices of \p slotIdx as drawn (accounts for hover enlargement and
---     star rotation, but not placement animation scale)
function StarView:_drawnSlotVertices(slotIdx, hoveredSlot)
    local centerX, centerY = self:center()
    local vertices
    if slotIdx == hoveredSlot then
        vertices = transformScalerVertices(
            StarView.SLOT_VERTEX_SCALARS[slotIdx],
            self.starOriginX + (self.size * StarView.HOVER_SELECT_OFFSETS[slotIdx][1]),
            self.starOriginY + (self.size * StarView.HOVER_SELECT_OFFSETS[slotIdx][2]),
            self.size * (1.0 + HOVER_SELECT_SCALE)
        )
    else
        vertices = self.polys[slotIdx].verticies
    end
    return ViewUtil.rotateVerticies(vertices, centerX, centerY, self.rotation)
end

--- @return table color RGB color for slot cost labels: a darker variant of the slot's color,
---     or gray for stars without a single color
function StarView:_costLabelColor(star, slotIdx)
    local baseColor = nil
    if star.starType == StarType.MULTI_STATIC then
        baseColor = TileView.TILE_COLOR[star.slotColorOrder[slotIdx]]
    else
        -- MONO stars take on a color once a tile is placed, so use the model's current type
        baseColor = TileView.TILE_COLOR[star.starType]
    end
    if not baseColor then
        return COST_LABEL_GRAY
    end
    return { baseColor[1] * COST_LABEL_DARKEN, baseColor[2] * COST_LABEL_DARKEN, baseColor[3] * COST_LABEL_DARKEN }
end

--- Draw the cost of each empty slot just inside its outer tip. Drawn in screen space so the
--- pixel font isn't scaled by camera zoom.
--- @param star Star model instance that corresponds to this view
--- @param worldToScreen function (worldX, worldY) -> screenX, screenY
--- @param worldScale number screen pixels per world unit (camera zoom)
function StarView:drawCostLabels(star, worldToScreen, worldScale)
    local starCenterX, starCenterY = self:center()
    local hoveredSlot = self.hovered_slot
    if self.animatingSlots[hoveredSlot] then
        hoveredSlot = 0
    end

    local boxSize = math.floor(self.size * worldScale * COST_LABEL_MAX_HEIGHT)
    -- costs are single digits, so any digit gives the font's footprint
    local font = ViewUtil.largestFontThatFits("6", boxSize, boxSize)

    for ii = 1, #StarView.SLOT_VERTEX_SCALARS do
        local removing = self.animatingSlots[ii] and self.animatingSlots[ii].removing
        -- hide cost under placed tiles, and under tiles still shrinking away after an undo
        if not star:isOccupied(ii) and not removing then
            local vertices = self:_drawnSlotVertices(ii, hoveredSlot)

            -- the outer tip is the vertex farthest from the star's center
            local tipX, tipY, tipDist = 0, 0, -1
            for v = 1, #vertices, 2 do
                local dist = ViewUtil.euclidianDistance(starCenterX, starCenterY, vertices[v], vertices[v + 1])
                if dist > tipDist then
                    tipX, tipY, tipDist = vertices[v], vertices[v + 1], dist
                end
            end
            local slotCenterX, slotCenterY = ViewUtil.centerOfConvexPoly(vertices)
            local labelX = tipX + (slotCenterX - tipX) * COST_LABEL_TIP_INSET
            local labelY = tipY + (slotCenterY - tipY) * COST_LABEL_TIP_INSET

            local text = tostring(star:slotIndexToCost(ii))

            local screenX, screenY = worldToScreen(labelX, labelY)
            love.graphics.setColor(self:_costLabelColor(star, ii))
            ViewUtil.printPixelText(text, font, screenX - boxSize / 2, screenY - boxSize / 2, boxSize, boxSize)
        end
    end
end

--- @param star Star. Star model class instance that corresponds to this view
function StarView:draw(star)
    local origR, origG, origB, origA = love.graphics.getColor()
    local origLineWidth = love.graphics.getLineWidth()

    local centerX, centerY = self:center()

    -- slots animating a tile placement ignore hover so the animation is visible
    local hoveredSlot = self.hovered_slot
    if self.animatingSlots[hoveredSlot] then
        hoveredSlot = 0
    end

    for ii = 1, #StarView.SLOT_VERTEX_SCALARS do
        if ii ~= hoveredSlot then
            local unplacedColor = StarView.UNPLACED_SLOT_COLOR[self.starType]
            local anim = self.animatingSlots[ii]
            if anim then
                -- draw empty slots underneath the tile thats bouncing in/shrinking out
                local baseVertices = ViewUtil.rotateVerticies(self.polys[ii].verticies, centerX, centerY, self.rotation)
                drawPoly(baseVertices, unplacedColor)
            end
            local scaledVertices = ViewUtil.scaleConvexPolyFromCenter(self.polys[ii].verticies, self.polys[ii].scale)
            scaledVertices = ViewUtil.rotateVerticies(scaledVertices, centerX, centerY, self.rotation)
            local color = unplacedColor
            if star:isOccupied(ii) then
                color = TileView.TILE_COLOR[star:tileAtSlot(ii)]
            elseif anim and anim.removing then
                color = TileView.TILE_COLOR[anim.tileType]
            end
            drawPoly(scaledVertices, color)
        end
    end
    if hoveredSlot ~= 0 then
        -- slot is currently being hovered over. draw last for layering
        local color = StarView.UNPLACED_SLOT_COLOR[self.starType]
        if star:isOccupied(hoveredSlot) then
            color = TileView.TILE_COLOR[star:tileAtSlot(hoveredSlot)]
        end
        local scaledVertices = transformScalerVertices(
            StarView.SLOT_VERTEX_SCALARS[hoveredSlot],
            self.starOriginX + (self.size * StarView.HOVER_SELECT_OFFSETS[hoveredSlot][1]),
            self.starOriginY + (self.size * StarView.HOVER_SELECT_OFFSETS[hoveredSlot][2]),
            self.size * (1.0 + HOVER_SELECT_SCALE)
        )
        scaledVertices = ViewUtil.rotateVerticies(scaledVertices, centerX, centerY, self.rotation)
        drawPoly(scaledVertices, color)
    end

    -- reset color at the end
    love.graphics.setLineWidth(origLineWidth)
    love.graphics.setColor(origR, origG, origB, origA)
end

return StarView
