--- Modal overlay for picking up bonus tiles (BonusPickup): the bonus pool tweens in at full size in
--- the middle of the screen over the dimmed game, with what the player earned and how many tiles to
--- pick up. Clicking a tile selects or deselects it. Once exactly that many are selected the Take
--- button turns on.
---
--- Only clicks on the overlay's panel are claimed, so the HUD (Undo, Menu, view toggle) still
--- works underneath. The overlay never reads the game state. It reports back through
--- mouseHandler.clickEvent:
---     { type = bonusTilesTaken, tiles = { TileType -> count } }
local Concord = require("cloudless_sky.extern.concord")
local Anim = require("cloudless_sky.anim")
local BonusPoolView = require("cloudless_sky.view.bonus_pool_view")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local UiStyle = require("cloudless_sky.view.ui_style")
local ViewUtil = require("cloudless_sky.view.view_util")

local flux = require("cloudless_sky.extern.flux")
local suit = require("cloudless_sky.extern.suit")

---@class BonusPickupEntity
---@field pool BonusPoolView the pool's tiles, in screen pixels
---@field selected table set of VisualTile -> true
---@field appear number 0 (hidden) to 1 (in place). Tweened
local BonusPickupEntity = {}
BonusPickupEntity.__index = BonusPickupEntity

local APPEAR_S = 0.35
local DIM_ALPHA = 0.6
-- the pool's disc is this share of the screen height
local DISC_SHARE = 0.55
-- the most a tile is drawn, in screen pixels
local MAX_TILE_PX = 96
local TEXT_COLOR = { 1, 1, 1, 1 }
local HEADER_COLOR = { 1, 0.82, 0.3, 1 }
local SUBTLE_TEXT_COLOR = { 1, 1, 1, 0.75 }

--- @param opts table {
---     tiles = { {tileType, slot|nil}, ... } the pool's tiles (slot: where the table's pool shows it),
---     numSlots = integer the pool's size, count = integer tiles to pick up,
---     title = string eg: "Pillar + Statue bonus", short = boolean the pool has fewer than earned }
function BonusPickupEntity.new(opts)
    local entity = Concord.entity()
    entity
        :give(Components.names.drawable, Constants.drawPriority.modal)
        :give(Components.names.cameraPos, 0, 0)
        :give(Components.names.mouseHandler, Constants.drawPriority.modal)
        :give(Components.names.boundingBox, 1, 1) -- sized in :resize
    EUtil.extendEntity(entity, BonusPickupEntity)

    entity.count = opts.count
    entity.title = opts.title
    entity.short = opts.short
    -- tile size 1: setPlacement's scale is the tile size in pixels
    entity.pool = BonusPoolView(opts.numSlots, 1)
    for _, t in ipairs(opts.tiles) do
        entity.pool:addTileAt(t.tileType, t.slot)
    end
    entity.selected = {}
    entity.ui = suit.new()
    entity.tweens = flux.group()
    entity.appear = 0
    if Anim.isOff() then
        entity.appear = 1
    else
        entity.tweens:to(entity, Anim.time(APPEAR_S), { appear = 1 }):ease("backout")
    end
    entity:resize(love.graphics.getPixelDimensions())
    return entity
end

--- @return integer how many tiles are selected
function BonusPickupEntity:numSelected()
    local n = 0
    for _ in pairs(self.selected) do
        n = n + 1
    end
    return n
end

--- @return table TileType -> count of the selected tiles
function BonusPickupEntity:selectedTiles()
    local tiles = {}
    for tile in pairs(self.selected) do
        tiles[tile.tileType] = (tiles[tile.tileType] or 0) + 1
    end
    return tiles
end

--- @return boolean True once the right number of tiles is selected
function BonusPickupEntity:canTake()
    return self:numSelected() == self.count
end

--- @return boolean True once the overlay has finished tweening in
function BonusPickupEntity:settled()
    return self.appear >= 1 and #self.tweens == 0
end

function BonusPickupEntity:_place()
    -- scale overshoots with the backout ease; positions follow
    self.pool:setPlacement(self.cx, self.cy, self.tilePx * math.max(0, self.appear))
end

function BonusPickupEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    if button ~= 1 then
        return false
    end
    if ViewUtil.ptInRect(cameraX, cameraY, self.takeRect.x, self.takeRect.y, self.takeRect.w, self.takeRect.h) then
        if self:canTake() then
            self.mouseHandler.clickEvent = {
                type = Components.mouseHandler.eventTypes.bonusTilesTaken,
                tiles = self:selectedTiles(),
            }
        end
        return true
    end
    local tile = self.pool:tileAt(cameraX, cameraY)
    if tile then
        if self.selected[tile] then
            self.selected[tile] = nil
        elseif self:numSelected() < self.count then
            self.selected[tile] = true
        end
        return true
    end
    local p = self.panel
    return ViewUtil.ptInRect(cameraX, cameraY, p.x, p.y, p.w, p.h)
end

function BonusPickupEntity:update(dt, gameState)
    self.tweens:update(dt)
    self:_place()
    self.ui:enterFrame()
    local r = self.takeRect
    self.ui:Button(self:_takeLabel(), {
        id = "bonusTake",
        draw = ViewUtil.suitButtonDraw,
        color = self:canTake() and UiStyle.BUTTON_COLORS or UiStyle.DISABLED_BUTTON_COLORS,
        cornerRadius = math.floor(r.h * 0.25),
        outline = 2,
    }, r.x, r.y, r.w, r.h)
end

function BonusPickupEntity:_takeLabel()
    return self.count == 1 and "Take 1 tile" or ("Take " .. self.count .. " tiles")
end

function BonusPickupEntity:draw(gameState)
    local w, h = love.graphics.getPixelDimensions()
    local a = math.min(1, math.max(0, self.appear))
    love.graphics.setColor(0, 0, 0, DIM_ALPHA * a)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- a panel behind the text and the pool, so they read clearly over the mat
    local p = self.panel
    love.graphics.setColor(UiStyle.PANEL_COLOR[1], UiStyle.PANEL_COLOR[2], UiStyle.PANEL_COLOR[3], UiStyle.PANEL_COLOR[4] * a)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, p.r, p.r)
    love.graphics.setColor(1, 1, 1, 0.5 * a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, p.r, p.r)

    if self.appear > 0 then
        self.pool:drawBase()
        self.pool:drawTiles(self.selected)
    end

    local function line(text, rect, color, share)
        love.graphics.setColor(color[1], color[2], color[3], color[4] * a)
        ViewUtil.printPixelText(text, ViewUtil.largestFontThatFits(text, rect.w, rect.h * (share or 0.8)), rect.x, rect.y, rect.w, rect.h)
    end
    line(self.title, self.titleRect, HEADER_COLOR)
    local pickText = self.count == 1 and "Pick up 1 tile" or ("Pick up " .. self.count .. " tiles")
    if self.short then
        pickText = pickText .. " (all that's left)"
    end
    line(pickText, self.subtitleRect, TEXT_COLOR)
    line(self:numSelected() .. " / " .. self.count .. " selected", self.countRect, SUBTLE_TEXT_COLOR, 0.7)

    if a >= 1 then
        self.ui:draw()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function BonusPickupEntity:resize(w, h)
    local discR = h * DISC_SHARE / 2
    -- tile size so the disc (at scale 1) has that radius
    self.tilePx = math.min(MAX_TILE_PX, discR / self.pool:radiusAt(1))
    discR = self.pool:radiusAt(self.tilePx)
    local rowH = math.floor(h * 0.065)
    local pad = math.floor(rowH * 0.4)
    local buttonW = math.max(200, math.floor(w * 0.2))
    local panelW = math.min(w, math.max(2 * discR + 2 * rowH, buttonW + 2 * pad))
    local textW = panelW - 2 * pad
    local textX = math.floor((w - textW) / 2)
    -- title, subtitle, disc, count, button: centered as a block, on a panel
    local blockH = 2 * rowH + 2 * discR + rowH + rowH
    local top = math.floor((h - blockH) / 2)
    self.panel = {
        x = math.floor((w - panelW) / 2),
        y = top - pad,
        w = panelW,
        h = math.floor(blockH + 2 * pad),
        r = math.floor(rowH * 0.3),
    }
    self.titleRect = { x = textX, y = top, w = textW, h = rowH }
    self.subtitleRect = { x = textX, y = top + rowH, w = textW, h = rowH }
    self.cx = math.floor(w / 2)
    self.cy = math.floor(top + 2 * rowH + discR)
    self.countRect = { x = textX, y = math.floor(self.cy + discR), w = textW, h = rowH }
    self.takeRect = { x = math.floor((w - buttonW) / 2), y = self.countRect.y + rowH, w = buttonW, h = math.floor(rowH * 0.95) }
    self:_place()
end

return BonusPickupEntity
