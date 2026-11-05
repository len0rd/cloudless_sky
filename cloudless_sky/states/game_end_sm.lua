--- State machine for the end of the game, once the final round is over. Runs by itself:
---     1. TITLE:         large "Game Over" over the dimmed world
---     2. PLAYER_INTRO:  for each player: their turn begins (the HUD shows them) and the camera moves
---                       to their mat
---     3. PLAYER_BONUSES: their end-game bonuses appear one at a time in a panel beside the mat, while
---                       the stars/slots that earned each one pulse
---     4. PLAYER_TOTAL:  the total is scored (ScoreEndGameAction): the HUD score counts up. Then the
---                       next player, or:
---     5. FINAL_SCORES:  a table of every player's scores, the winner(s), and New Game / Exit buttons
--- The HUD's turn buttons are disabled throughout. The menu and the view toggle still work.
---
--- Where to start comes from the model, so a loaded save resumes where it was: players already scored
--- (Player.endGameBonus) aren't scored again (see GameEndStateMachine.resumePoint).
local WorldStateMachine = require("cloudless_sky.states.world_sm")
local Anim = require("cloudless_sky.anim")
local BeginTurnAction = require("cloudless_sky.action.begin_turn")
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local ScoreEndGameAction = require("cloudless_sky.action.score_end_game")
local BonusIconView = require("cloudless_sky.view.bonus_icon_view")
local UiStyle = require("cloudless_sky.view.ui_style")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")

---@class GameEndStateMachine : WorldStateMachine
local GameEndStateMachine = WorldStateMachine:extend()

GameEndStateMachine.STATES = {
    TITLE = 1,
    PLAYER_INTRO = 2,
    PLAYER_BONUSES = 3,
    PLAYER_TOTAL = 4,
    FINAL_SCORES = 5,
}

-- timing (seconds at normal speed, see Anim)
local TITLE_FADE_S = 0.5
local TITLE_S = 2.0
local INTRO_S = 0.9
local BONUS_S = 0.7
local TOTAL_S = 1.6

local DIM_COLOR = { 0, 0, 0, 0.6 }
local TITLE_COLOR = { 1, 0.82, 0.3, 1 }
-- "Game Over" is up to this share of the width right of the HUD
local TITLE_W = 0.7
local OUTLINE_COLOR = { 1, 1, 1, 0.5 }
local TOTAL_COLOR = { 1, 0.82, 0.3, 1 }
local WINNER_ROW_COLOR = { 1, 0.82, 0.3, 0.25 }
local HEADER_TEXT_COLOR = { 1, 1, 1, 0.7 }

-- bonus panel (fractions of the screen)
local BONUS_PANEL_W = 0.24
local BONUS_ROW_H = 0.075

--------------------------------------------------------------------------------
-- pure helpers (tested)
--------------------------------------------------------------------------------

--- @return integer|nil index of the first player whose end-game bonuses haven't been scored
local function firstUnscored(gameState)
    for ii, player in ipairs(gameState.players) do
        if player.endGameBonus == nil then
            return ii
        end
    end
    return nil
end

--- Where the sequence starts for \p gameState (a finished game)
--- @return integer state GameEndStateMachine.STATES value
--- @return integer|nil playerIdx the player to score next
function GameEndStateMachine.resumePoint(gameState)
    local nextPlayer = firstUnscored(gameState)
    if not nextPlayer then
        return GameEndStateMachine.STATES.FINAL_SCORES, nil
    end
    for _, player in ipairs(gameState.players) do
        if player.endGameBonus ~= nil then
            -- part way through: carry on with the next player, no title
            return GameEndStateMachine.STATES.PLAYER_INTRO, nextPlayer
        end
    end
    return GameEndStateMachine.STATES.TITLE, nextPlayer
end

--- @return table standings { rows = { {playerIdx, name, before, bonus, final, winner} }, headline }.
---     Rows are in player order. Winners have the highest final score (ties share the win)
function GameEndStateMachine.standings(gameState)
    local best = -math.huge
    for _, player in ipairs(gameState.players) do
        best = math.max(best, player.score)
    end
    local rows, winners = {}, {}
    for ii, player in ipairs(gameState.players) do
        local bonus = player.endGameBonus or 0
        local winner = player.score == best
        table.insert(rows, {
            playerIdx = ii,
            name = player.playerName,
            before = player.score - bonus,
            bonus = bonus,
            final = player.score,
            winner = winner,
        })
        if winner then
            table.insert(winners, player.playerName)
        end
    end
    local headline = #winners == 1 and (winners[1] .. " wins!") or ("Tie! " .. table.concat(winners, " & "))
    return { rows = rows, headline = headline }
end

--------------------------------------------------------------------------------
-- state machine
--------------------------------------------------------------------------------

function GameEndStateMachine:enter(fromState, gameState, graphicsState)
    self:_bind(gameState, graphicsState)
    local hud = graphicsState.hud.container
    hud:setDoneEnabled(false)
    hud:setPassEnabled(false)
    hud:setUndoEnabled(false)
    self.ui = suit.new()

    local state, playerIdx = GameEndStateMachine.resumePoint(gameState)
    self.playerIdx = playerIdx
    if state == self.STATES.FINAL_SCORES then
        self:_enterFinalScores()
    elseif state == self.STATES.TITLE then
        self:setViewFocus(graphicsState.viewFocus)
        self:_setState(state)
    else
        self:_enterPlayer(playerIdx)
    end
end

function GameEndStateMachine:_setState(state)
    self.state = state
    self.timer = 0
end

--- Start scoring \p playerIdx: their turn begins (unless it already has, eg: a save made mid-way)
function GameEndStateMachine:_enterPlayer(playerIdx)
    self.playerIdx = playerIdx
    local history = self.gameState.actionHistory
    local last = history[#history]
    if not (last and last.name == "BeginTurn" and last.ctx.playerIdx == playerIdx) then
        local performed, reason = self.gameState:performAction(BeginTurnAction(playerIdx))
        if not performed then
            error("game end: BeginTurn failed: " .. tostring(reason))
        end
    end
    self.bonuses = EndGameBonus.forPlayer(self.gameState.rules, self.gameState.players[playerIdx])
    -- how many of self.bonuses are showing
    self.shown = 0
    self.scoredTotal = nil
    self:setViewFocus(WorldStateMachine.VIEW.MAT)
    self:_setState(self.STATES.PLAYER_INTRO)
end

function GameEndStateMachine:_enterFinalScores()
    self.playerIdx = nil
    self.standings = GameEndStateMachine.standings(self.gameState)
    self:setViewFocus(WorldStateMachine.VIEW.TABLE)
    self:_setState(self.STATES.FINAL_SCORES)
    self:resize(love.graphics.getPixelDimensions())
end

--- Pulse the mat slots that earned \p bonus
function GameEndStateMachine:_pulseBonus(bonus)
    local mat = self.graphicsState.matEntities[self.playerIdx]
    if not mat then
        return
    end
    if bonus.kind == EndGameBonus.KIND.STAR then
        mat.stars[bonus.starIdx]:pulseSlots({ 1, 2, 3, 4, 5, 6 })
    else
        local perStar = {}
        for _, slot in ipairs(bonus.slots) do
            perStar[slot[1]] = perStar[slot[1]] or {}
            table.insert(perStar[slot[1]], slot[2])
        end
        for starIdx, slotIdxs in pairs(perStar) do
            mat.stars[starIdx]:pulseSlots(slotIdxs)
        end
    end
end

--- Advance the automatic sequence
function GameEndStateMachine:_step(dt)
    self.timer = self.timer + dt
    local states = self.STATES
    if self.state == states.TITLE then
        if self.timer >= Anim.time(TITLE_S) then
            self:_enterPlayer(self.playerIdx)
        end
    elseif self.state == states.PLAYER_INTRO then
        if self.timer >= Anim.time(INTRO_S) then
            self:_setState(states.PLAYER_BONUSES)
        end
    elseif self.state == states.PLAYER_BONUSES then
        -- one bonus (or the "No bonuses" line) every BONUS_S, then a pause before the total
        if self.timer >= Anim.time(BONUS_S) then
            self.timer = 0
            if self.shown < math.max(1, #self.bonuses) then
                self.shown = self.shown + 1
                if self.bonuses[self.shown] then
                    self:_pulseBonus(self.bonuses[self.shown])
                end
            else
                self:_scorePlayer()
            end
        end
    elseif self.state == states.PLAYER_TOTAL then
        if self.timer >= Anim.time(TOTAL_S) then
            local nextPlayer = firstUnscored(self.gameState)
            if nextPlayer then
                self:_enterPlayer(nextPlayer)
            else
                self:_enterFinalScores()
            end
        end
    end
end

function GameEndStateMachine:_scorePlayer()
    local performed, reason = self.gameState:performAction(ScoreEndGameAction(self.playerIdx))
    if not performed then
        error("game end: ScoreEndGame failed: " .. tostring(reason))
    end
    self.scoredTotal = performed[1].ctx.total
    self:_setState(self.STATES.PLAYER_TOTAL)
end

function GameEndStateMachine:update(dt)
    local pressCtx = self:pendingClick()
    if pressCtx then
        self:handleCommonClick(pressCtx)
    end
    self:_step(dt)
    if self.state == self.STATES.FINAL_SCORES then
        self:_updateFinalButtons()
    end
    self:updateWorld(dt)
end

--- @return number screen pixels on the right the camera leaves free (the bonus panel while scoring)
function GameEndStateMachine:rightInset()
    if self.playerIdx then
        local w = love.graphics.getPixelDimensions()
        return math.floor(w * BONUS_PANEL_W) + self:_pad()
    end
    return 0
end

function GameEndStateMachine:_pad()
    local _, h = love.graphics.getPixelDimensions()
    return math.max(6, math.floor(h * 0.02))
end

--------------------------------------------------------------------------------
-- drawing
--------------------------------------------------------------------------------

function GameEndStateMachine:_drawTitle()
    local w, h = love.graphics.getPixelDimensions()
    local fade = Anim.time(TITLE_FADE_S)
    local alpha = fade > 0 and math.min(1, self.timer / fade) or 1
    love.graphics.setColor(DIM_COLOR[1], DIM_COLOR[2], DIM_COLOR[3], DIM_COLOR[4] * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- centered in the space right of the HUD
    local left = self.graphicsState.hud.container.boundingBox.w
    local text = "Game Over"
    local boxW, boxH = (w - left) * TITLE_W, h * 0.3
    -- larger than the biggest pixel font: scale it up by a whole number so it stays crisp (fonts use
    -- nearest filtering)
    local font = fonts.ithacaBySize[1]
    local scale = math.max(1, math.floor(math.min(boxW / font:getWidth(text), boxH / font:getHeight())))
    local textW, textH = font:getWidth(text) * scale, font:getHeight() * scale
    local x = math.floor(left + ((w - left) - textW) / 2)
    local y = math.floor((h - textH) / 2)
    love.graphics.setColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3], alpha)
    love.graphics.print(text, font, x, y, 0, scale, scale)
end

function GameEndStateMachine:_drawBonusPanel()
    local w, h = love.graphics.getPixelDimensions()
    local pad = self:_pad()
    local panelW = math.floor(w * BONUS_PANEL_W)
    local rowH = math.floor(h * BONUS_ROW_H)
    local x = w - panelW - pad
    local innerW = panelW - 2 * pad
    local numRows = math.max(1, #self.bonuses)
    -- title, rows, total
    local panelH = pad + rowH + pad + numRows * rowH + pad + rowH + pad
    local y = math.max(pad, math.floor((h - panelH) / 2))

    love.graphics.setColor(UiStyle.PANEL_COLOR)
    ViewUtil.drawOutlinedRectangle(x, y, panelW, panelH, math.floor(panelW * 0.05), 2, OUTLINE_COLOR)

    local player = self.gameState.players[self.playerIdx]
    local title = player.playerName .. "'s bonuses"
    love.graphics.setColor(UiStyle.TEXT_COLOR)
    ViewUtil.printPixelText(title, ViewUtil.largestFontThatFits(title, innerW, rowH * 0.7), x + pad, y + pad, innerW, rowH)

    local rowY = y + pad + rowH + pad
    if #self.bonuses == 0 then
        if self.shown > 0 then
            local text = "No bonuses"
            love.graphics.setColor(HEADER_TEXT_COLOR)
            ViewUtil.printPixelText(text, ViewUtil.largestFontThatFits(text, innerW, rowH * 0.6), x + pad, rowY, innerW, rowH)
        end
    else
        for ii = 1, self.shown do
            local inset = math.floor(rowH * 0.1)
            BonusIconView.drawBonus(self.bonuses[ii], x + pad, rowY + (ii - 1) * rowH + inset, innerW, rowH - 2 * inset, UiStyle.TEXT_COLOR)
        end
    end

    if self.scoredTotal then
        local totalY = y + panelH - pad - rowH
        local text = "Total +" .. self.scoredTotal
        love.graphics.setColor(TOTAL_COLOR)
        ViewUtil.printPixelText(text, ViewUtil.largestFontThatFits(text, innerW, rowH * 0.8), x + pad, totalY, innerW, rowH)
    end
end

--- Lay out the final scores panel (screen-centered)
function GameEndStateMachine:resize(w, h)
    WorldStateMachine.resize(self, w, h)
    if self.state ~= self.STATES.FINAL_SCORES or not self.standings then
        return
    end
    local rowH = math.floor(h * 0.07)
    local pad = math.max(6, math.floor(rowH * 0.3))
    local panelW = math.min(w, math.max(520, math.floor(w * 0.5)))
    local innerW = panelW - 2 * pad
    local numRows = #self.standings.rows
    -- title, headline, column header, player rows, buttons
    local panelH = pad + rowH + rowH + pad + rowH + numRows * rowH + pad + rowH + pad
    local x = math.floor((w - panelW) / 2)
    local y = math.floor((h - panelH) / 2)
    local final = { rowH = rowH, pad = pad }
    final.panel = { x = x, y = y, w = panelW, h = panelH }
    final.title = { x = x + pad, y = y + pad, w = innerW, h = rowH }
    final.headline = { x = x + pad, y = y + pad + rowH, w = innerW, h = rowH }
    final.tableY = y + pad + 2 * rowH + pad
    final.innerX = x + pad
    final.innerW = innerW
    local buttonW = math.floor((innerW - pad) / 2)
    local buttonY = y + panelH - pad - rowH
    final.newGame = { x = x + pad, y = buttonY, w = buttonW, h = rowH }
    final.exit = { x = x + pad + buttonW + pad, y = buttonY, w = buttonW, h = rowH }
    self.final = final
end

-- final scores table columns: label and share of the width
local COLUMNS = {
    { label = "Player", share = 0.34, key = "name", align = "left" },
    { label = "Score", share = 0.22, key = "before" },
    { label = "Bonuses", share = 0.22, key = "bonus" },
    { label = "Final", share = 0.22, key = "final" },
}

function GameEndStateMachine:_updateFinalButtons()
    local f = self.final
    if not f then
        return
    end
    self.ui:enterFrame()
    for _, b in ipairs({ { "New Game", f.newGame, "finalNewGame" }, { "Exit", f.exit, "finalExit" } }) do
        local r = b[2]
        self.ui:Button(b[1], {
            id = b[3],
            draw = ViewUtil.suitButtonDraw,
            color = UiStyle.BUTTON_COLORS,
            cornerRadius = math.floor(r.h * 0.25),
            outline = 2,
        }, r.x, r.y, r.w, r.h)
    end
end

function GameEndStateMachine:_drawFinalScores()
    local w, h = love.graphics.getPixelDimensions()
    love.graphics.setColor(DIM_COLOR)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local f = self.final
    local p = f.panel
    love.graphics.setColor(UiStyle.PANEL_COLOR)
    ViewUtil.drawOutlinedRectangle(p.x, p.y, p.w, p.h, math.floor(p.w * 0.04), 2, OUTLINE_COLOR)

    local title = "Final Scores"
    love.graphics.setColor(UiStyle.TEXT_COLOR)
    ViewUtil.printPixelText(title, ViewUtil.largestFontThatFits(title, f.title.w, f.title.h), f.title.x, f.title.y, f.title.w, f.title.h)
    local headline = self.standings.headline
    love.graphics.setColor(TITLE_COLOR)
    ViewUtil.printPixelText(headline, ViewUtil.largestFontThatFits(headline, f.headline.w, f.headline.h * 0.8), f.headline.x, f.headline.y, f.headline.w, f.headline.h)

    local rowH = f.rowH
    local cellFont = ViewUtil.largestFontThatFits("Bonuses", f.innerW * 0.2, rowH * 0.6)
    local function drawRow(y, values, color)
        local cx = f.innerX
        for _, col in ipairs(COLUMNS) do
            local colW = f.innerW * col.share
            love.graphics.setColor(color)
            ViewUtil.printPixelText(tostring(values[col.key] or col.label), cellFont, cx + f.pad / 2, y, colW - f.pad, rowH, col.align or "center")
            cx = cx + colW
        end
    end
    local header = {}
    drawRow(f.tableY, header, HEADER_TEXT_COLOR)
    for ii, row in ipairs(self.standings.rows) do
        local y = f.tableY + ii * rowH
        if row.winner then
            love.graphics.setColor(WINNER_ROW_COLOR)
            love.graphics.rectangle("fill", f.innerX, y, f.innerW, rowH, rowH * 0.2, rowH * 0.2)
        end
        drawRow(y, { name = row.name, before = row.before, bonus = "+" .. row.bonus, final = row.final }, UiStyle.TEXT_COLOR)
    end

    self.ui:draw()
end

function GameEndStateMachine:draw()
    WorldStateMachine.draw(self)
    local origR, origG, origB, origA = love.graphics.getColor()
    if self.state == self.STATES.TITLE then
        self:_drawTitle()
    elseif self.state == self.STATES.FINAL_SCORES then
        self:_drawFinalScores()
    elseif self.playerIdx then
        self:_drawBonusPanel()
    end
    love.graphics.setColor(origR, origG, origB, origA)
end

function GameEndStateMachine:mousepressed(x, y, button, istouch)
    if self.state == self.STATES.FINAL_SCORES and button == 1 and self.final then
        local f = self.final
        if ViewUtil.ptInRect(x, y, f.newGame.x, f.newGame.y, f.newGame.w, f.newGame.h) then
            game:newGame()
            return
        elseif ViewUtil.ptInRect(x, y, f.exit.x, f.exit.y, f.exit.w, f.exit.h) then
            love.event.quit(0)
            return
        end
    end
    WorldStateMachine.mousepressed(self, x, y, button, istouch)
end

return GameEndStateMachine
