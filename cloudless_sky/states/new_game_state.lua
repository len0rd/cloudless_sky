--- The New Game menu: how many players (2-4) with a name box for each, the rule preset
--- (GameRules.PRESETS) and Back / Start Game. Reached from the main menu and the final scores.
---
--- Name boxes: click one (or Tab) to type in it, Backspace deletes, Enter starts the game, Escape goes
--- back. A blank name becomes "Player N". The setup is remembered for the next New Game while the app
--- is open.
local utf8 = require("utf8")
local GameRules = require("cloudless_sky.model.game_rules")
local GameSetup = require("cloudless_sky.model.game_setup")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local MenuBackground = require("cloudless_sky.view.menu_background")
local UiStyle = require("cloudless_sky.view.ui_style")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")

local NewGameState = {}

--- longest name, in characters (so it fits the HUD)
NewGameState.MAX_NAME_LENGTH = 16

-- layout, in proportions of the screen
local TITLE_Y = 0.03
local TITLE_H = 0.15
local TITLE_W = 0.5
local PANEL_TOP = 0.2
local PANEL_W = 0.46
local MIN_PANEL_W = 480
local ROW_H = 0.07
-- share of the panel's inner width for the labels on the left
local LABEL_SHARE = 0.34

local OUTLINE_COLOR = { 1, 1, 1, 0.5 }
local LABEL_COLOR = { 1, 1, 1, 0.8 }
local FIELD_COLOR = { 0.08, 0.08, 0.12, 1 }
local FIELD_OUTLINE_COLOR = { 1, 1, 1, 0.35 }
local FIELD_FOCUS_COLOR = { 1, 0.82, 0.3, 1 }
local CURSOR_BLINK_S = 0.5

-- the last setup, so the next New Game starts from it (this session only)
local remembered = {
    count = GameSetup.MIN_PLAYERS,
    names = GameSetup.defaultNames(GameSetup.MAX_PLAYERS),
    presetId = GameSetup.DEFAULT_PRESET,
}

--------------------------------------------------------------------------------
-- pure helpers (tested)
--------------------------------------------------------------------------------

--- @return string \p text with \p typed added, cut to MAX_NAME_LENGTH characters
function NewGameState.appendText(text, typed)
    local joined = text .. typed
    if utf8.len(joined) <= NewGameState.MAX_NAME_LENGTH then
        return joined
    end
    return joined:sub(1, utf8.offset(joined, NewGameState.MAX_NAME_LENGTH + 1) - 1)
end

--- @return string \p text without its last character
function NewGameState.backspace(text)
    local last = utf8.offset(text, -1)
    return last and text:sub(1, last - 1) or text
end

--- @param texts string[] what's in the name boxes
--- @return string[] the first \p count names, trimmed and cut to MAX_NAME_LENGTH. A blank one becomes
---     "Player N"
function NewGameState.playerNames(texts, count)
    local names = {}
    for ii = 1, count do
        local name = NewGameState.appendText("", ((texts[ii] or ""):gsub("^%s+", ""):gsub("%s+$", "")))
        names[ii] = name ~= "" and name or GameSetup.defaultName(ii)
    end
    return names
end

--- @return table rects for a \p w x \p h window with \p count players: title, panel, and per row
---     { label, controls... }: players = { label, [2], [3], [4] }, names[ii] = { label, field },
---     preset = { label, [presetIdx]... }, back, start. Plus rowH and pad
function NewGameState.layout(w, h, count)
    local rowH = math.floor(h * ROW_H)
    local pad = math.max(6, math.floor(rowH * 0.25))
    -- players, names, preset, buttons
    local numRows = 1 + count + 1 + 1
    local panelW = math.min(w, math.max(MIN_PANEL_W, math.floor(w * PANEL_W)))
    local panelH = pad + numRows * (rowH + pad)
    local titleW = math.floor(w * TITLE_W)
    local L = {
        rowH = rowH,
        pad = pad,
        title = { x = math.floor((w - titleW) / 2), y = math.floor(h * TITLE_Y), w = titleW, h = math.floor(h * TITLE_H) },
        panel = { x = math.floor((w - panelW) / 2), y = math.floor(h * PANEL_TOP), w = panelW, h = panelH },
    }
    local innerX = L.panel.x + pad
    local innerW = panelW - 2 * pad
    local labelW = math.floor(innerW * LABEL_SHARE)
    local controlsX = innerX + labelW + pad
    local controlsW = innerX + innerW - controlsX
    local rowY = L.panel.y + pad
    --- a row: label on the left, \p n equal controls on the right
    local function row(n)
        local r = { label = { x = innerX, y = rowY, w = labelW, h = rowH } }
        local cellW = math.floor((controlsW - (n - 1) * pad) / n)
        for ii = 1, n do
            r[ii] = { x = controlsX + (ii - 1) * (cellW + pad), y = rowY, w = cellW, h = rowH }
        end
        rowY = rowY + rowH + pad
        return r
    end
    L.players = row(GameSetup.MAX_PLAYERS - GameSetup.MIN_PLAYERS + 1)
    L.names = {}
    for ii = 1, count do
        L.names[ii] = row(1)
    end
    L.preset = row(#GameRules.PRESETS)
    local buttonW = math.floor((innerW - pad) / 2)
    L.back = { x = innerX, y = rowY, w = buttonW, h = rowH }
    L.start = { x = innerX + buttonW + pad, y = rowY, w = innerW - buttonW - pad, h = rowH }
    return L
end

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

function NewGameState:enter()
    self.ui = suit.new()
    self.count = remembered.count
    self.texts = {}
    for ii = 1, GameSetup.MAX_PLAYERS do
        self.texts[ii] = remembered.names[ii]
    end
    self.presetId = remembered.presetId
    self.time = 0
    self.keyRepeat = love.keyboard.hasKeyRepeat()
    love.keyboard.setKeyRepeat(true)
    self:_setFocus(nil)
    self:resize(love.graphics.getPixelDimensions())
end

function NewGameState:leave()
    love.keyboard.setKeyRepeat(self.keyRepeat)
    love.keyboard.setTextInput(false)
end

--- Type into name box \p idx (nil: none)
function NewGameState:_setFocus(idx)
    self.focus = idx
    self.time = 0
    -- the on-screen keyboard (touch devices)
    love.keyboard.setTextInput(idx ~= nil)
end

function NewGameState:_setCount(count)
    self.count = count
    if self.focus and self.focus > count then
        self:_setFocus(nil)
    end
    self:resize(love.graphics.getPixelDimensions())
end

function NewGameState:_back()
    GameStateMachineMgr.switch(require("cloudless_sky.states.main_menu_state"))
end

function NewGameState:_start()
    remembered.count = self.count
    remembered.names = self.texts
    remembered.presetId = self.presetId
    local gameState = GameSetup.newGameState({
        playerNames = NewGameState.playerNames(self.texts, self.count),
        presetId = self.presetId,
    })
    GameStateMachineMgr.switch(game, gameState)
end

function NewGameState:update(dt)
    self.time = self.time + dt
    local L = self.rects
    self.ui:enterFrame()
    local function button(label, id, r, selected)
        self.ui:Button(label, {
            id = id,
            draw = ViewUtil.suitButtonDraw,
            color = selected and UiStyle.SELECTED_BUTTON_COLORS or UiStyle.BUTTON_COLORS,
            cornerRadius = math.floor(r.h * 0.25),
            outline = 2,
        }, r.x, r.y, r.w, r.h)
    end
    for ii = 1, GameSetup.MAX_PLAYERS - GameSetup.MIN_PLAYERS + 1 do
        local count = GameSetup.MIN_PLAYERS + ii - 1
        button(tostring(count), "count" .. count, L.players[ii], count == self.count)
    end
    for ii, preset in ipairs(GameRules.PRESETS) do
        button(preset.label, "preset_" .. preset.id, L.preset[ii], preset.id == self.presetId)
    end
    button("Back", "back", L.back, false)
    button("Start Game", "start", L.start, false)
end

function NewGameState:_drawLabel(text, r)
    love.graphics.setColor(LABEL_COLOR)
    ViewUtil.printPixelText(text, ViewUtil.largestFontThatFits(text, r.w, r.h * 0.7), r.x, r.y, r.w, r.h, "left")
end

function NewGameState:_drawField(idx, r)
    local focused = self.focus == idx
    love.graphics.setColor(FIELD_COLOR)
    ViewUtil.drawOutlinedRectangle(r.x, r.y, r.w, r.h, math.floor(r.h * 0.2), 2, focused and FIELD_FOCUS_COLOR or FIELD_OUTLINE_COLOR)
    local text = self.texts[idx]
    local font = ViewUtil.largestFontThatFits("Wy", r.w, r.h * 0.7)
    local inset = math.floor(r.h * 0.25)
    if text == "" and not focused then
        -- what a blank name becomes
        love.graphics.setColor(1, 1, 1, 0.35)
        ViewUtil.printPixelText(GameSetup.defaultName(idx), font, r.x + inset, r.y, r.w - 2 * inset, r.h, "left")
    else
        love.graphics.setColor(UiStyle.TEXT_COLOR)
        ViewUtil.printPixelText(text, font, r.x + inset, r.y, r.w - 2 * inset, r.h, "left")
    end
    if focused and math.floor(self.time / CURSOR_BLINK_S) % 2 == 0 then
        local cx = math.floor(r.x + inset + font:getWidth(text) + 2)
        local ch = font:getHeight()
        love.graphics.setColor(FIELD_FOCUS_COLOR)
        love.graphics.rectangle("fill", cx, math.floor(r.y + (r.h - ch) / 2), 2, ch)
    end
end

function NewGameState:draw()
    local w, h = love.graphics.getPixelDimensions()
    local L = self.rects
    MenuBackground.draw(w, h)
    MenuBackground.drawTitle("New Game", L.title.x, L.title.y, L.title.w, L.title.h)

    local p = L.panel
    love.graphics.setColor(UiStyle.PANEL_COLOR)
    ViewUtil.drawOutlinedRectangle(p.x, p.y, p.w, p.h, math.floor(L.rowH * 0.3), 2, OUTLINE_COLOR)
    self:_drawLabel("Players", L.players.label)
    for ii = 1, self.count do
        self:_drawLabel("Player " .. ii, L.names[ii].label)
        self:_drawField(ii, L.names[ii][1])
    end
    self:_drawLabel("Rule Preset", L.preset.label)

    self.ui:draw()
    love.graphics.setColor(1, 1, 1, 1)
end

function NewGameState:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    local L = self.rects
    local function hit(r)
        return ViewUtil.ptInRect(x, y, r.x, r.y, r.w, r.h)
    end
    for ii = 1, self.count do
        if hit(L.names[ii][1]) then
            self:_setFocus(ii)
            return
        end
    end
    self:_setFocus(nil)
    for ii = 1, GameSetup.MAX_PLAYERS - GameSetup.MIN_PLAYERS + 1 do
        if hit(L.players[ii]) then
            self:_setCount(GameSetup.MIN_PLAYERS + ii - 1)
            return
        end
    end
    for ii, preset in ipairs(GameRules.PRESETS) do
        if hit(L.preset[ii]) then
            self.presetId = preset.id
            return
        end
    end
    if hit(L.back) then
        self:_back()
    elseif hit(L.start) then
        self:_start()
    end
end

function NewGameState:textinput(typed)
    if self.focus then
        self.texts[self.focus] = NewGameState.appendText(self.texts[self.focus], typed)
        self.time = 0
    end
end

function NewGameState:keypressed(key)
    if key == "backspace" and self.focus then
        self.texts[self.focus] = NewGameState.backspace(self.texts[self.focus])
        self.time = 0
    elseif key == "tab" then
        -- next name box (shift+tab: previous)
        local step = love.keyboard.isDown("lshift", "rshift") and -1 or 1
        self:_setFocus(((self.focus or (step > 0 and 0 or 1)) - 1 + step) % self.count + 1)
    elseif key == "return" or key == "kpenter" then
        self:_start()
    elseif key == "escape" then
        self:_back()
    end
end

function NewGameState:resize(w, h)
    self.rects = NewGameState.layout(w, h, self.count)
end

return NewGameState
