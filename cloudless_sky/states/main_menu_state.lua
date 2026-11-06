--- The main menu, shown when the app opens (see main.lua) and after leaving a game: "Cloudless Sky"
--- on a sky gradient, with Continue (only if there's a save), New Game and Quit.
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local GameSetup = require("cloudless_sky.model.game_setup")
local MenuBackground = require("cloudless_sky.view.menu_background")
local SaveGame = require("cloudless_sky.model.save_game")
local UiStyle = require("cloudless_sky.view.ui_style")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")

local MainMenuState = {}

-- proportions of the screen
local BUTTON_W = 0.28
local MIN_BUTTON_W = 240
local ROW_H = 0.08
local TITLE_Y = 0.1
local TITLE_H = 0.26
local TITLE_W = 0.8
local BUTTONS_Y = 0.46

local BUTTON_LABELS = {
    continue = "Continue",
    newGame = "New Game",
    quit = "Quit",
}

function MainMenuState:enter()
    self.ui = suit.new()
    -- error from the last Continue, shown under the buttons
    self.status = nil
    self.buttons = {}
    if SaveGame.exists() then
        table.insert(self.buttons, "continue")
    end
    table.insert(self.buttons, "newGame")
    table.insert(self.buttons, "quit")
    self:resize(love.graphics.getPixelDimensions())
end

function MainMenuState:_continue()
    local gameState, reason = SaveGame.readFile()
    if not gameState then
        Log.error("couldn't continue: " .. tostring(reason))
        self.status = "Couldn't load the save: " .. tostring(reason)
        return
    end
    Log.info("continuing: round " .. gameState.round.idx .. ", player " .. gameState.currentTurnPlayer .. "'s turn")
    GameStateMachineMgr.switch(game, gameState)
end

function MainMenuState:_newGame()
    -- TODO: the New Game menu
    GameStateMachineMgr.switch(game, GameSetup.newGameState({ playerNames = GameSetup.defaultNames(2) }))
end

function MainMenuState:update(dt)
    self.ui:enterFrame()
    for _, id in ipairs(self.buttons) do
        local r = self.buttonRects[id]
        self.ui:Button(BUTTON_LABELS[id], {
            id = "main_" .. id,
            draw = ViewUtil.suitButtonDraw,
            color = UiStyle.BUTTON_COLORS,
            cornerRadius = math.floor(r.h * 0.25),
            outline = 2,
        }, r.x, r.y, r.w, r.h)
    end
end

function MainMenuState:draw()
    local w, h = love.graphics.getPixelDimensions()
    MenuBackground.draw(w, h)
    local t = self.titleRect
    MenuBackground.drawTitle("Cloudless Sky", t.x, t.y, t.w, t.h)

    self.ui:draw()

    if self.status then
        local s = self.statusRect
        local font = fonts.ithacaBySize[#fonts.ithacaBySize]
        -- wraps onto more lines if needed (errors can be long). On a dark backing: red is hard to read
        -- on the sky
        local _, lines = font:getWrap(self.status, s.w)
        local pad = 6
        love.graphics.setColor(UiStyle.PANEL_COLOR)
        love.graphics.rectangle("fill", s.x - pad, s.y - pad, s.w + 2 * pad, #lines * font:getHeight() + 2 * pad, pad, pad)
        love.graphics.setColor(UiStyle.ERROR_TEXT_COLOR)
        love.graphics.printf(self.status, font, s.x, s.y, s.w, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MainMenuState:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    for _, id in ipairs(self.buttons) do
        local r = self.buttonRects[id]
        if ViewUtil.ptInRect(x, y, r.x, r.y, r.w, r.h) then
            if id == "continue" then
                self:_continue()
            elseif id == "newGame" then
                self:_newGame()
            elseif id == "quit" then
                love.event.quit(0)
            end
            return
        end
    end
end

function MainMenuState:resize(w, h)
    local titleW = math.floor(w * TITLE_W)
    self.titleRect = { x = math.floor((w - titleW) / 2), y = math.floor(h * TITLE_Y), w = titleW, h = math.floor(h * TITLE_H) }

    local buttonW = math.max(MIN_BUTTON_W, math.floor(w * BUTTON_W))
    local rowH = math.floor(h * ROW_H)
    local pad = math.max(6, math.floor(rowH * 0.3))
    local column = ViewUtil.buttonColumn(math.floor((w - buttonW) / 2), math.floor(h * BUTTONS_Y), buttonW, rowH, pad, #self.buttons)
    self.buttonRects = {}
    for ii, id in ipairs(self.buttons) do
        self.buttonRects[id] = column[ii]
    end
    local last = column[#column]
    local statusW = math.max(buttonW, math.floor(w * 0.5))
    self.statusRect = { x = math.floor((w - statusW) / 2), y = last.y + rowH + pad, w = statusW }
end

return MainMenuState
