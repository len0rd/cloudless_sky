--- In-game menu: a screen-centered dialog with Save, Load and Exit.
---
--- Pushed on top of whatever state machine is running (the HUD Menu button or Escape). The game is
--- paused while it's open: only the top state gets updates, so play, animations and tweens below it
--- freeze. It draws the paused game underneath, dimmed.
---
--- Closes on Escape or a click outside the dialog.
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local SaveGame = require("cloudless_sky.model.save_game")
local UiStyle = require("cloudless_sky.view.ui_style")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")

local MenuState = {}

local DIM_COLOR = { 0, 0, 0, 0.55 }
-- proportions of the screen
local PANEL_W = 0.25
local MIN_PANEL_W = 220
local ROW_H = 0.07

local BUTTONS = {
    { id = "save", label = "Save" },
    { id = "load", label = "Load" },
    { id = "exit", label = "Exit" },
}

--- @param from table the state the menu was opened over (drawn underneath)
--- @param gameState GameState the game to save
function MenuState:enter(from, gameState)
    self.from = from
    self.gameState = gameState
    self.ui = suit.new()
    -- result of the last Save/Load, shown under the buttons
    self.status = nil
    self.statusIsError = false
    self.canLoad = SaveGame.exists()
    self:resize(love.graphics.getPixelDimensions())
end

function MenuState:close()
    GameStateMachineMgr.pop()
end

function MenuState:_setStatus(text, isError)
    self.status = text
    self.statusIsError = isError
end

function MenuState:_save()
    local saved, reason = SaveGame.writeFile(self.gameState)
    if saved then
        self.canLoad = true
        self:_setStatus("Saved", false)
    else
        Log.error("save failed: " .. tostring(reason))
        self:_setStatus("Save failed: " .. tostring(reason), true)
    end
end

function MenuState:_load()
    local gameState, reason = SaveGame.readFile()
    if not gameState then
        Log.error("load failed: " .. tostring(reason))
        self:_setStatus("Load failed: " .. tostring(reason), true)
        return
    end
    -- replaces the running game. Pops every state machine (this menu included)
    game:loadGame(gameState)
end

function MenuState:_enabled(id)
    return id ~= "load" or self.canLoad
end

function MenuState:update(dt)
    self.ui:enterFrame()
    local cornerRadius = math.floor(self.rowH * 0.25)
    for _, button in ipairs(BUTTONS) do
        local r = self.buttonRects[button.id]
        self.ui:Button(button.label, {
            id = "menu_" .. button.id,
            draw = ViewUtil.suitButtonDraw,
            color = self:_enabled(button.id) and UiStyle.BUTTON_COLORS or UiStyle.DISABLED_BUTTON_COLORS,
            cornerRadius = cornerRadius,
            outline = 2,
        }, r.x, r.y, r.w, r.h)
    end
end

function MenuState:draw()
    -- the paused game, dimmed
    self.from:draw()
    local w, h = love.graphics.getPixelDimensions()
    love.graphics.setColor(DIM_COLOR)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local p = self.panel
    love.graphics.setColor(UiStyle.PANEL_COLOR)
    ViewUtil.drawOutlinedRectangle(p.x, p.y, p.w, p.h, math.floor(p.w * 0.05), 2, { 1, 1, 1, 0.5 })

    love.graphics.setColor(UiStyle.TEXT_COLOR)
    local t = self.titleRect
    ViewUtil.printPixelText("Menu", ViewUtil.largestFontThatFits("Menu", t.w, t.h), t.x, t.y, t.w, t.h)

    self.ui:draw()

    if self.status then
        local s = self.statusRect
        love.graphics.setColor(self.statusIsError and UiStyle.ERROR_TEXT_COLOR or UiStyle.TEXT_COLOR)
        local font = fonts.ithacaBySize[#fonts.ithacaBySize]
        -- wraps onto more lines if needed (errors can be long)
        love.graphics.printf(self.status, font, s.x, s.y, s.w, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    local p = self.panel
    if not ViewUtil.ptInRect(x, y, p.x, p.y, p.w, p.h) then
        self:close()
        return
    end
    for _, b in ipairs(BUTTONS) do
        local r = self.buttonRects[b.id]
        if self:_enabled(b.id) and ViewUtil.ptInRect(x, y, r.x, r.y, r.w, r.h) then
            if b.id == "save" then
                self:_save()
            elseif b.id == "load" then
                self:_load()
            elseif b.id == "exit" then
                love.event.quit(0)
            end
            return
        end
    end
end

function MenuState:keyreleased(key)
    if key == "escape" then
        self:close()
    end
end

function MenuState:resize(w, h)
    if self.from and self.from.resize then
        self.from:resize(w, h)
    end
    local panelW = math.max(MIN_PANEL_W, math.floor(w * PANEL_W))
    local rowH = math.floor(h * ROW_H)
    local pad = math.max(6, math.floor(rowH * 0.3))
    local innerW = panelW - 2 * pad
    -- title, buttons, then room for 2 lines of status
    local panelH = pad + rowH + pad + #BUTTONS * (rowH + pad) + 2 * rowH
    local x = math.floor((w - panelW) / 2)
    local y = math.floor((h - panelH) / 2)

    self.rowH = rowH
    self.panel = { x = x, y = y, w = panelW, h = panelH }
    self.titleRect = { x = x + pad, y = y + pad, w = innerW, h = rowH }
    local rowY = y + pad + rowH + pad
    self.buttonRects = {}
    for _, button in ipairs(BUTTONS) do
        self.buttonRects[button.id] = { x = x + pad, y = rowY, w = innerW, h = rowH }
        rowY = rowY + rowH + pad
    end
    self.statusRect = { x = x + pad, y = rowY, w = innerW, h = 2 * rowH - pad }
end

return MenuState
