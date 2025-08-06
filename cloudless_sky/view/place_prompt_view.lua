-- small confirmation prompt for what tile to place
-- along with a selector of how many wilds to use
local Object = require("cloudless_sky.extern.classic")
local PlacePromptView = Object:extend()
local ViewUtil = require("cloudless_sky.view.view_util")
local TileView = require("cloudless_sky.view.tile_view")

local PlacementPossibility = require("cloudless_sky.model.placement_possibility")
local TileType = require("cloudless_sky.model.tile_type")
local StarView = require("cloudless_sky.view.star_view")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

local PROMPT_WIDTH = 120
local PROMPT_HEIGHT = 100

-- max scale the border box will be drawn at during transitionTween
local MAX_SCALE = 1.5

-- stuff for drawing arrows
local MAX_ARROW_SIZE = PROMPT_HEIGHT / 10
local PAD = 2
local CORNER_RADIUS_SCALER = 1 / 10

-- for debug
local WIDGET_BOUNDING_BOXES = false

PlacePromptView.STATES = {
    ACTIVE = "ACTIVE",
    CLOSING = "CLOSING",
    CLOSED = "CLOSED",
}

--- triangle vertices
---      1
---  3 <|
---     2
local leftArrowDraw = function(text, opt, x, y, w, h)
    local size = math.max(math.min(w, h), MAX_ARROW_SIZE)
    local wOffset = ((w - size) / 2) + PAD
    local hOffset = ((h - size) / 2) + PAD

    -- stylua: ignore start
    local vertices = {
        w - wOffset, hOffset,
        w - wOffset, h - hOffset,
        wOffset,     h / 2,
    }
    -- stylua: ignore end
    ViewUtil.shiftVerticies(vertices, x, y)
    love.graphics.setColor(love.math.colorFromBytes(30, 30, 30))
    love.graphics.polygon("fill", vertices)

    if WIDGET_BOUNDING_BOXES then
        love.graphics.setColor({ 0.5, 0, 0 })
        love.graphics.rectangle("line", x, y, w, h)
    end
end

--- triangle vertices
---  1
---  |> 2
---  3
local rightArrowDraw = function(text, opt, x, y, w, h)
    local size = math.max(math.min(w, h), MAX_ARROW_SIZE)
    local wOffset = ((w - size) / 2) + PAD
    local hOffset = ((h - size) / 2) + PAD

    -- stylua: ignore start
    local vertices = {
        wOffset, hOffset,
        w - wOffset, h / 2,
        wOffset,     h -hOffset,
    }
    -- stylua: ignore end
    ViewUtil.shiftVerticies(vertices, x, y)
    love.graphics.setColor(love.math.colorFromBytes(30, 30, 30))
    love.graphics.polygon("fill", vertices)

    if WIDGET_BOUNDING_BOXES then
        love.graphics.setColor({ 0.5, 0, 0 })
        love.graphics.rectangle("line", x, y, w, h)
    end
end

--- @param tileWorldX integer World X coordinate of the center of the tile the prompt is in relation to
--- @param tileWorldY integer World Y coordinate of the center of the tile the prompt is in relation tofs
--- @param tileCost integer Total number of tiles required to place here.
--- @param placementOptions PlacementPossibility[] List of PlacementPossibility objects for this slot
--- @param starType StarType what star is being played on
function PlacePromptView:new(tileWorldX, tileWorldY, tileCost, placementOptions, starType)
    self.tileWorldX = tileWorldX
    self.tileWorldY = tileWorldY
    self.tileCost = tileCost
    self.placementOptions = placementOptions
    self.placementOptIdx = 1
    self.state = self.STATES.ACTIVE

    self.placeBtnScale = 1.0

    self.scale = 0.1
    self.transitionTween = flux.group()
    self.transitionTween:to(self, 0.25, { scale = MAX_SCALE }):after(self, 0.25, { scale = 1.0 })

    self.placeHoverTween = nil

    self.ui = suit.new()
    self.ui.theme.color = {
        normal = { bg = StarView.UNPLACED_SLOT_COLOR[starType], fg = { 0, 0, 0 } },
        hovered = { bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType], fg = { 0, 0, 0 } },
        active = { bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType], fg = { 0, 0, 0 } },
    }
    self:resize(love.graphics.getWidth(), love.graphics.getHeight(), tileWorldX, tileWorldY)
end

--- @return boolean eventHandled. True if click is in prompt bounds and will be handled, else false
function PlacePromptView:mousePressed(worldX, worldY, button, istouch)
    if button == 1 then
        -- check if click is within the prompt:
        return ViewUtil.ptInRect(worldX, worldY, self.tileWorldX, self.tileWorldY, PROMPT_WIDTH, PROMPT_HEIGHT)
    end

    return false
end

function PlacePromptView:_btnHoverTween(tween)
    tween:to(self, 0.5, { placeBtnScale = 1.1 }):after(self, 0.5, { placeBtnScale = 1.0 }):oncomplete(function()
        self:_btnHoverTween(tween)
    end)
end

function PlacePromptView:close()
    -- self.state = self.STATES.CLOSING
    self.state = self.STATES.CLOSED
end

function PlacePromptView:closing()
    return self.state == self.STATES.CLOSING or self.state == self.STATES.CLOSED
end

function PlacePromptView:isClosed()
    return self.state == self.STATES.CLOSED
end

--- @return PlacementPossibility? selected. If the player has just hit the "place" button, the currently selected placement.
---     Otherwise nil
function PlacePromptView:update(dt)
    self.transitionTween:update(dt)

    local promptW = PROMPT_WIDTH * self.scale
    local promptH = PROMPT_HEIGHT * self.scale
    local NUM_ROWS = 3
    local cellHeight = promptH / NUM_ROWS

    local mouseWorldX, mouseWorldY = camera:mousePosition()
    self.ui:enterFrame(mouseWorldX, mouseWorldY)

    local LAYOUT_PAD = 1

    self.ui.layout:reset(self.tileWorldX, self.tileWorldY, LAYOUT_PAD, LAYOUT_PAD)
    self.ui:Label("Cost: " .. self.tileCost, { font = fonts.ithaca["16"] }, self.ui.layout:row(promptW, cellHeight))

    -- cost option row --
    local currentPromptCtx = self.placementOptions[self.placementOptIdx]
    currentPromptCtx["draw"] = TileView.suitDrawTile
    currentPromptCtx["boundingBox"] = WIDGET_BOUNDING_BOXES

    local displayOptionSelectBtns = #self.placementOptions > 1
    local displayWildTile = self.placementOptions[self.placementOptIdx].wildCount > 0

    -- L/R arrow buttons take up 1/6 each. Tile display takes up the other 2/3
    -- decide how much X-space each element gets based on the placement options
    local cellWidth = (promptW - 2 * LAYOUT_PAD) / 3
    if not displayOptionSelectBtns then
        cellWidth = (promptW - 2 * LAYOUT_PAD) / 2
    end
    local tileCellWidth = cellWidth
    if displayWildTile then
        tileCellWidth = tileCellWidth / 2
    end

    self.ui.layout:newRow()
    if displayOptionSelectBtns then
        local lArr =
            self.ui:Button("placeOptLArr", { draw = leftArrowDraw }, self.ui.layout:col(cellWidth / 2, cellHeight))
        if lArr.hit then
            self.placementOptIdx = self.placementOptIdx - 1
            if self.placementOptIdx <= 0 then
                self.placementOptIdx = #self.placementOptions
            end
        end
    end

    self.ui:Label(nil, currentPromptCtx, self.ui.layout:col(tileCellWidth, cellHeight))
    self.ui:Label(tostring(currentPromptCtx.tileCount), {}, self.ui.layout:col(tileCellWidth, cellHeight))
    if displayWildTile then
        self.ui:Label(
            nil,
            { draw = TileView.suitDrawTile, tileType = currentPromptCtx.wildType, boundingBox = WIDGET_BOUNDING_BOXES },
            self.ui.layout:col(tileCellWidth, cellHeight)
        )
        self.ui:Label(tostring(currentPromptCtx.wildCount), {}, self.ui.layout:col(tileCellWidth, cellHeight))
    end

    if displayOptionSelectBtns then
        local rArr =
            self.ui:Button("placeOptRArr", { draw = rightArrowDraw }, self.ui.layout:col(cellWidth / 2, cellHeight))
        if rArr.hit then
            self.placementOptIdx = self.placementOptIdx + 1
            if self.placementOptIdx > #self.placementOptions then
                self.placementOptIdx = 1
            end
        end
    end

    self.ui.layout:newRow()

    local placeW = (promptW - 2 * LAYOUT_PAD) * self.placeBtnScale
    local placeH = (cellHeight - NUM_ROWS * LAYOUT_PAD) * self.placeBtnScale
    local placeX, placeY, placeW, placeH = self.ui.layout:col(placeW, placeH)
    placeX = placeX - math.max((placeW - promptW) / 2, 0)

    -- also update the color
    self.ui.theme.color.active.bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType]
    self.ui.theme.color.hovered.bg = TileView.TILE_COLOR[self.placementOptions[self.placementOptIdx].tileType]

    local placeButton = self.ui:Button("Place", {
        font = fonts.ithaca["16"],
        cornerRadius = promptW * CORNER_RADIUS_SCALER - 3,
        outline = 2,
        scale = self.placeBtnScale,
    }, placeX, placeY, placeW, placeH)
    -- handle tweening animation
    if placeButton.entered then
        -- start new animation
        print("enter place btn!")
        self.placeHoverTween = nil
        self.placeHoverTween = flux.group()
        self:_btnHoverTween(self.placeHoverTween)
    end
    if placeButton.hovered then
        self.placeHoverTween:update(dt)
    elseif placeButton.left then
        self.placeBtnScale = 1.0
        self.placeHoverTween = nil
    end

    if placeButton.hit then
        return self.placementOptions[self.placementOptIdx]
    end
    return nil
end

function PlacePromptView:draw()
    love.graphics.push()
    if self.state ~= self.STATES.CLOSED then
        local width = PROMPT_WIDTH * self.scale
        local height = PROMPT_HEIGHT * self.scale
        local cornerR = width * CORNER_RADIUS_SCALER

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", self.tileWorldX, self.tileWorldY, width, height, cornerR, cornerR)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.tileWorldX, self.tileWorldY, width, height, cornerR, cornerR)

        self.ui:draw()
    end
    love.graphics.pop()
end

--- events

--- Call when the window is resized
--- TODO: need to know the HUD margin for this decision
function PlacePromptView:resize(w, h, tileWorldX, tileWorldY)
    self.tileWorldX = tileWorldX
    self.tileWorldY = tileWorldY
    local promptWindowX, promptWindowY = camera:cameraCoords(self.tileWorldX, self.tileWorldY)
    if promptWindowY + PROMPT_HEIGHT > h - 100 then
        self.tileWorldY = self.tileWorldY - PROMPT_HEIGHT
    end
    if promptWindowX + PROMPT_WIDTH > w - 100 then
        self.tileWorldX = self.tileWorldX - PROMPT_WIDTH
    end
end

return PlacePromptView
