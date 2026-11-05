--- End-game bonus reference: a large screen-centered dialog, opened from the menu, showing every
--- end-game bonus (EndGameBonus.reference) as an icon with its points:
---     - completed stars: the star filled with its color (rainbow for multicolor) "= N"
---     - every space of a number covered: a tile with the number "= N"
--- Clicking a bonus shows a short explanation (EndGameBonus.describe) above it. Clicking it again or
--- anywhere else in the dialog hides it.
---
--- Pushed on top of the menu: it draws the menu (and the paused game) underneath, dimmed. Back,
--- Escape or a click outside the dialog return to the menu.
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local BonusIconView = require("cloudless_sky.view.bonus_icon_view")
local UiStyle = require("cloudless_sky.view.ui_style")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")

local BonusReferenceState = {}

local DIM_COLOR = { 0, 0, 0, 0.7 }
local OUTLINE_COLOR = { 1, 1, 1, 0.5 }
local HOVER_COLOR = { 1, 1, 1, 0.08 }
local SELECTED_COLOR = { 1, 1, 1, 0.16 }
local SECTION_TEXT_COLOR = { 1, 1, 1, 0.75 }
local EXPLAIN_BG_COLOR = { 0.96, 0.95, 0.89, 1 }
local EXPLAIN_TEXT_COLOR = { 0, 0, 0, 1 }

-- layout, as fractions of the screen
local PANEL_W = 0.6
local MIN_PANEL_W = 480
local ROW_H = 0.07
local COLUMNS = 4
-- a bonus cell is this many rows tall
local CELL_ROWS = 1.5

local STAR_SECTION = "Completed stars"
local NUMBER_SECTION = "Every space of a number covered"

--- Lay the dialog out for a \p w x \p h screen. Pure (no drawing), so it can be tested
--- @param bonuses table[] EndGameBonus.reference rows, stars first
--- @return table layout { panel, title, sections = { {text, rect} }, items = { {bonus, rect} }, back, rowH, pad }
function BonusReferenceState.computeLayout(bonuses, w, h)
    local panelW = math.min(w, math.max(MIN_PANEL_W, math.floor(w * PANEL_W)))
    local rowH = math.floor(h * ROW_H)
    local pad = math.max(6, math.floor(rowH * 0.3))
    local innerW = panelW - 2 * pad
    local cellW = math.floor((innerW - (COLUMNS - 1) * pad) / COLUMNS)
    local cellH = math.floor(rowH * CELL_ROWS)

    local stars, numbers = {}, {}
    for _, bonus in ipairs(bonuses) do
        table.insert(bonus.kind == EndGameBonus.KIND.STAR and stars or numbers, bonus)
    end

    -- positions relative to the panel's top-left, offset once the panel's height is known
    local layout = { rowH = rowH, pad = pad, sections = {}, items = {} }
    local y = pad
    layout.title = { x = pad, y = y, w = innerW, h = rowH }
    y = y + rowH + pad

    local function section(text, list)
        if #list == 0 then
            return
        end
        local sectionH = math.floor(rowH * 0.6)
        table.insert(layout.sections, { text = text, rect = { x = pad, y = y, w = innerW, h = sectionH } })
        y = y + sectionH + pad
        for ii, bonus in ipairs(list) do
            local col = (ii - 1) % COLUMNS
            local row = math.floor((ii - 1) / COLUMNS)
            table.insert(layout.items, {
                bonus = bonus,
                rect = { x = pad + col * (cellW + pad), y = y + row * (cellH + pad), w = cellW, h = cellH },
            })
        end
        y = y + math.ceil(#list / COLUMNS) * (cellH + pad)
    end
    section(STAR_SECTION, stars)
    section(NUMBER_SECTION, numbers)

    local backW = math.floor(innerW / 3)
    layout.back = { x = math.floor((panelW - backW) / 2), y = y, w = backW, h = rowH }
    y = y + rowH + pad

    local panelH = math.min(h, y)
    local panelX = math.floor((w - panelW) / 2)
    local panelY = math.floor((h - panelH) / 2)
    layout.panel = { x = panelX, y = panelY, w = panelW, h = panelH }
    local function offset(r)
        r.x = r.x + panelX
        r.y = r.y + panelY
    end
    offset(layout.title)
    offset(layout.back)
    for _, s in ipairs(layout.sections) do
        offset(s.rect)
    end
    for _, item in ipairs(layout.items) do
        offset(item.rect)
    end
    return layout
end

--- @return integer|nil index into layout.items of the bonus at screen point (x, y)
function BonusReferenceState.itemAt(layout, x, y)
    for ii, item in ipairs(layout.items) do
        local r = item.rect
        if ViewUtil.ptInRect(x, y, r.x, r.y, r.w, r.h) then
            return ii
        end
    end
    return nil
end

--- @param from table the state this was opened over (the menu), drawn underneath
--- @param rules table GameRules whose bonuses to show
function BonusReferenceState:enter(from, rules)
    self.from = from
    self.bonuses = EndGameBonus.reference(rules)
    self.ui = suit.new()
    -- index into layout.items of the bonus whose explanation is showing
    self.selected = nil
    self.hovered = nil
    self:resize(love.graphics.getPixelDimensions())
end

function BonusReferenceState:close()
    GameStateMachineMgr.pop()
end

function BonusReferenceState:update(dt)
    self.hovered = BonusReferenceState.itemAt(self.layout, love.mouse.getPosition())
    self.ui:enterFrame()
    local r = self.layout.back
    self.ui:Button("Back", {
        id = "bonusRefBack",
        draw = ViewUtil.suitButtonDraw,
        color = UiStyle.BUTTON_COLORS,
        cornerRadius = math.floor(r.h * 0.25),
        outline = 2,
    }, r.x, r.y, r.w, r.h)
end

--- Draw the selected bonus's explanation in a box above it (below if there's no room above)
function BonusReferenceState:_drawExplanation()
    local item = self.layout.items[self.selected]
    if not item then
        return
    end
    local text = EndGameBonus.describe(item.bonus)
    local rowH, pad = self.layout.rowH, self.layout.pad
    local font = ViewUtil.largestFontThatFits(text, self.layout.panel.w - 4 * pad, rowH * 0.6)
    local boxW = font:getWidth(text) + 2 * pad
    local boxH = rowH
    local r = item.rect
    local p = self.layout.panel
    local boxX = math.max(p.x + pad, math.min(r.x + r.w / 2 - boxW / 2, p.x + p.w - pad - boxW))
    local boxY = r.y - boxH - pad / 2
    if boxY < p.y then
        boxY = r.y + r.h + pad / 2
    end
    love.graphics.setColor(EXPLAIN_BG_COLOR)
    ViewUtil.drawOutlinedRectangle(boxX, boxY, boxW, boxH, math.floor(boxH * 0.2), 2, { 0, 0, 0, 1 })
    love.graphics.setColor(EXPLAIN_TEXT_COLOR)
    ViewUtil.printPixelText(text, font, boxX, boxY, boxW, boxH)
end

function BonusReferenceState:draw()
    self.from:draw()
    local w, h = love.graphics.getPixelDimensions()
    love.graphics.setColor(DIM_COLOR)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local layout = self.layout
    local p = layout.panel
    love.graphics.setColor(UiStyle.PANEL_COLOR)
    ViewUtil.drawOutlinedRectangle(p.x, p.y, p.w, p.h, math.floor(p.w * 0.03), 2, OUTLINE_COLOR)

    love.graphics.setColor(UiStyle.TEXT_COLOR)
    local t = layout.title
    local title = "End Game Bonuses"
    ViewUtil.printPixelText(title, ViewUtil.largestFontThatFits(title, t.w, t.h), t.x, t.y, t.w, t.h)

    for _, s in ipairs(layout.sections) do
        local r = s.rect
        love.graphics.setColor(SECTION_TEXT_COLOR)
        ViewUtil.printPixelText(s.text, ViewUtil.largestFontThatFits(s.text, r.w, r.h), r.x, r.y, r.w, r.h, "left")
    end

    for ii, item in ipairs(layout.items) do
        local r = item.rect
        if ii == self.selected or ii == self.hovered then
            love.graphics.setColor(ii == self.selected and SELECTED_COLOR or HOVER_COLOR)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, r.h * 0.15, r.h * 0.15)
        end
        local inset = math.floor(r.h * 0.1)
        BonusIconView.drawBonus(item.bonus, r.x + inset, r.y + inset, r.w - 2 * inset, r.h - 2 * inset, UiStyle.TEXT_COLOR)
    end

    self.ui:draw()
    self:_drawExplanation()
    love.graphics.setColor(1, 1, 1, 1)
end

function BonusReferenceState:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    local p = self.layout.panel
    if not ViewUtil.ptInRect(x, y, p.x, p.y, p.w, p.h) then
        self:close()
        return
    end
    local b = self.layout.back
    if ViewUtil.ptInRect(x, y, b.x, b.y, b.w, b.h) then
        self:close()
        return
    end
    local item = BonusReferenceState.itemAt(self.layout, x, y)
    if item == self.selected then
        self.selected = nil
    else
        self.selected = item
    end
end

function BonusReferenceState:keyreleased(key)
    if key == "escape" then
        self:close()
    end
end

function BonusReferenceState:resize(w, h)
    if self.from and self.from.resize then
        self.from:resize(w, h)
    end
    self.layout = BonusReferenceState.computeLayout(self.bonuses, w, h)
end

return BonusReferenceState
