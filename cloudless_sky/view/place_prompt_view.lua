-- small confirmation prompt for what tile to place
-- along with a selector of how many wilds to use
local Object = require("cloudless_sky.extern.classic")
local PlacePromptView = Object:extend()
local ViewUtil = require("cloudless_sky.view.view_util")
local TileView = require("cloudless_sky.view.tile_view")

local PlacementPossibility = require("cloudless_sky.model.placement_possibility")
local TileType = require("cloudless_sky.model.tile_type")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

local PROMPT_WIDTH = 120
local PROMPT_HEIGHT = 100

-- max scale the border box will be drawn at during transitionTween
local MAX_SCALE = 1.5

-- stuff for drawing arrows
local MAX_ARROW_SIZE = PROMPT_HEIGHT / 10
local PAD = 2

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

    love.graphics.setColor({ 0.5, 0, 0 })
    love.graphics.rectangle("line", x, y, w, h)
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

    love.graphics.setColor({ 0.5, 0, 0 })
    love.graphics.rectangle("line", x, y, w, h)
end

local placementCostDraw = function(text, opt, x, y, w, h)
    local numTiles = 1

    local tileSize = h - (2 * PAD)

    if opt["wildCount"] ~= nil and opt["wildCount"] > 0 then
        -- need to draw base tile + wild
    else
        -- draw just a tile
        local tileVertices = TileView.tilePolyVerticies(tileSize, -math.pi / 6)
        ViewUtil.shiftVerticies(tileVertices, x + (w / 2) - tileSize - PAD, y + h / 2)
        local color = TileView.TILE_COLOR[opt.tileType]
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.polygon("fill", tileVertices)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", tileVertices)

        love.graphics.print(tostring(opt.tileCount), fonts.ithaca["16"], x + (w / 2) + PAD, y + PAD)
    end

    love.graphics.setColor({ 0, 0.5, 0 })
    love.graphics.rectangle("line", x, y, w, h)
end

--- @param tileWorldX integer World X coordinate of the center of the tile the prompt is in relation to
---@param tileWorldY integer World Y coordinate of the center of the tile the prompt is in relation tofs
---@
function PlacePromptView:new(tileWorldX, tileWorldY, tileCost)
    self.tileWorldX = tileWorldX
    self.tileWorldY = tileWorldY
    self.tileCost = tileCost

    self.scale = 0.1
    self.transitionTween = flux.to(self, 0.25, { scale = MAX_SCALE }):after(self, 0.25, { scale = 1.0 })
    self.ui = suit.new()
    self.ui.theme.color = {
        normal = { bg = ViewUtil.normalizeColor({ 94, 94, 94 }), fg = { 0, 0, 0 } },
        hovered = { bg = ViewUtil.normalizeColor({ 94, 94, 94 }), fg = { 0, 0, 0 } },
        active = { bg = ViewUtil.normalizeColor({ 94, 94, 94 }), fg = { 0, 0, 0 } },
    }
    self:resize(love.graphics.getWidth(), love.graphics.getHeight(), tileWorldX, tileWorldY)
    self.placeButton = nil
end

function PlacePromptView:mousePressed(worldX, worldY, button, istouch)
    if button == 1 then
        -- check if click is within the prompt:
        return ViewUtil.ptInRect(worldX, worldY, self.tileWorldX, self.tileWorldY, PROMPT_WIDTH, PROMPT_HEIGHT)
    end

    return false
end

function PlacePromptView:close() end

--- @return PlacementPossibility? selected. If the player has just hit the "place" button, the currently selected placement.
---     Otherwise nil
function PlacePromptView:update(dt)
    flux.update(dt)

    local promptW = PROMPT_WIDTH * self.scale
    local promptH = PROMPT_HEIGHT * self.scale
    local NUM_ROWS = 3
    local cellHeight = promptH / NUM_ROWS

    local mouseWorldX, mouseWorldY = camera:mousePosition()
    self.ui:enterFrame(mouseWorldX, mouseWorldY)

    local LAYOUT_PAD = 0
    self.ui.layout:reset(self.tileWorldX, self.tileWorldY, LAYOUT_PAD, LAYOUT_PAD)
    self.ui:Label("Cost: " .. self.tileCost, { font = fonts.ithaca["16"] }, self.ui.layout:row(promptW, cellHeight))
    -- spacing
    -- self.ui.layout:row()
    local placementCost = PlacementPossibility(TileType.RED, 5, TileType.PURPLE, 1)
    placementCost["draw"] = TileView.suitDrawTile
    placementCost["boundingBox"] = true

    local cellWidth = (promptW - 2 * LAYOUT_PAD) / 3

    self.ui:Button(nil, { draw = leftArrowDraw }, self.ui.layout:row(cellWidth / 2, cellHeight))
    local tileCellWidth = cellWidth
    if placementCost.wildCount > 0 then
        tileCellWidth = tileCellWidth / 2
    end
    self.ui:Label(nil, placementCost, self.ui.layout:col(tileCellWidth, cellHeight))
    self.ui:Label(tostring(placementCost.tileCount), {}, self.ui.layout:col(tileCellWidth, cellHeight))
    if placementCost.wildCount > 0 then
        self.ui:Label(
            nil,
            { draw = TileView.suitDrawTile, tileType = placementCost.wildType, boundingBox = true },
            self.ui.layout:col(tileCellWidth, cellHeight)
        )
        self.ui:Label(tostring(placementCost.tileCount), {}, self.ui.layout:col(tileCellWidth, cellHeight))
    end
    self.ui:Button(nil, { draw = rightArrowDraw }, self.ui.layout:col(cellWidth / 2, cellHeight))

    -- when row is called, SUIT goes straight down from the current column... well i want the next row to start at the
    -- layouts X origin, so just need to do manually..
    local _, y, w, h = self.ui.layout:row(promptW, cellHeight)
    self.placeButton = self.ui:Button("Place", { font = fonts.ithaca["16"] }, self.tileWorldX, y, w, h)
    if self.placeButton.hit then
        print("Placement pressed!!")
    end
end

function PlacePromptView:draw()
    love.graphics.push()
    do
        local width = PROMPT_WIDTH * self.scale
        local height = PROMPT_HEIGHT * self.scale
        local rx = width / 10
        local ry = height / 10

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", self.tileWorldX, self.tileWorldY, width, height, rx, ry)
        love.graphics.setColor({ 0, 0, 0 })
        love.graphics.rectangle("line", self.tileWorldX, self.tileWorldY, width, height, rx, ry)

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
