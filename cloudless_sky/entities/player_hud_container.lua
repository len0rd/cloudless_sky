--- HUD container element that occupies full height and 15% width of screen
--- Displays (top to bottom): player name, score, hand, done button, pass button
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local TileType = require("cloudless_sky.model.tile_type")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")
local flux = require("cloudless_sky.extern.flux")

---@class PlayerHudContainerEntity
---@field ui table Suit UI instance used for the done/pass buttons
---@field doneEnabled boolean Whether the done button can be pressed (controlled by turn state machine)
local PlayerHudContainerEntity = {}
PlayerHudContainerEntity.__index = PlayerHudContainerEntity

-- layout proportions (fractions of screen height unless noted)
local NAME_ROW_H = 0.06
local SCORE_ROW_H = 0.05
local MAX_HAND_CELL_H = 0.10
local BUTTON_ROW_H = 0.07
local HAND_COLS = 2
local EMPTY_SLOT_ALPHA = 0.35

local BG_COLOR = { 0.12, 0.12, 0.18, 0.85 }
local TEXT_COLOR = { 1, 1, 1, 1 }
local DIVIDER_COLOR = { 1, 1, 1, 0.3 }
-- score text flashes this color when the score goes up/down, then fades back to TEXT_COLOR
local SCORE_FLASH_COLOR = { 1, 0.82, 0.3, 1 }
local SCORE_DECREASE_FLASH_COLOR = { 0.85, 0.35, 0.35, 1 }
local SCORE_COUNT_TIME_S = 1.0
local SCORE_FLASH_TIME_S = 2.0

local BUTTON_COLORS = {
    normal = { bg = { 0.25, 0.25, 0.25 }, fg = { 1, 1, 1 } },
    hovered = { bg = { 0.19, 0.6, 0.73 }, fg = { 1, 1, 1 } },
    active = { bg = { 1, 0.6, 0 }, fg = { 1, 1, 1 } },
}
BUTTON_COLORS.hit = BUTTON_COLORS.active

local DISABLED_BUTTON_COLORS = {
    normal = { bg = { 0.2, 0.2, 0.2, 0.6 }, fg = { 0.5, 0.5, 0.5, 0.8 } },
}
DISABLED_BUTTON_COLORS.hovered = DISABLED_BUTTON_COLORS.normal
DISABLED_BUTTON_COLORS.active = DISABLED_BUTTON_COLORS.normal
DISABLED_BUTTON_COLORS.hit = DISABLED_BUTTON_COLORS.normal

function PlayerHudContainerEntity.new()
    local entity = Concord.entity()

    entity
        :give(Components.names.drawable, Constants.drawPriority.hudPlayerHand)
        :give(Components.names.cameraPos, 0, 0)
        :give(Components.names.mouseHandler, Constants.drawPriority.hudPlayerHand)
        :give(Components.names.boundingBox, 100, 100) -- will be resized in :resize

    EUtil.extendEntity(entity, PlayerHudContainerEntity)

    entity.ui = suit.new()
    entity.doneEnabled = false
    entity.undoEnabled = false
    entity.buttons = {
        done = { scale = 1.0, hoverTween = nil },
        pass = { scale = 1.0, hoverTween = nil },
        undo = { scale = 1.0, hoverTween = nil },
    }

    -- data cached from gameState during update for use in draw
    entity.player = nil
    entity.wildType = nil

    -- score shown in the HUD. Counts up to the player's actual score when it changes
    entity.displayedScore = 0
    entity.scoreTarget = 0
    -- 1.0 = fully SCORE_FLASH_COLOR, 0.0 = TEXT_COLOR
    entity.scoreFlash = 0
    entity.scoreFlashColor = SCORE_FLASH_COLOR
    entity.scoreTween = flux.group()

    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    entity:resize(screenWidth, screenHeight, nil)

    return entity
end

--- Enable/disable the done button. Controlled by the turn state machine
function PlayerHudContainerEntity:setDoneEnabled(enabled)
    self.doneEnabled = enabled
    if not enabled then
        self.buttons.done.scale = 1.0
        self.buttons.done.hoverTween = nil
    end
end

--- Enable/disable the undo button. Controlled by the turn state machine
function PlayerHudContainerEntity:setUndoEnabled(enabled)
    self.undoEnabled = enabled
    if not enabled then
        self.buttons.undo.scale = 1.0
        self.buttons.undo.hoverTween = nil
    end
end

function PlayerHudContainerEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    local bbox = self.boundingBox
    if not ViewUtil.ptInRect(cameraX, cameraY, self.cameraPos.x, self.cameraPos.y, bbox.w, bbox.h) then
        return false
    end

    if button == 1 then
        local done, pass, undo = self.doneRect, self.passRect, self.undoRect
        if self.doneEnabled and ViewUtil.ptInRect(cameraX, cameraY, done.x, done.y, done.w, done.h) then
            self.mouseHandler.clickEvent = { type = Components.mouseHandler.eventTypes.endTurnClicked }
        elseif ViewUtil.ptInRect(cameraX, cameraY, pass.x, pass.y, pass.w, pass.h) then
            self.mouseHandler.clickEvent = { type = Components.mouseHandler.eventTypes.passClicked }
        elseif self.undoEnabled and ViewUtil.ptInRect(cameraX, cameraY, undo.x, undo.y, undo.w, undo.h) then
            self.mouseHandler.clickEvent = { type = Components.mouseHandler.eventTypes.undoClicked }
        end
    end

    -- swallow all clicks within the HUD so they don't reach the player mats beneath
    return true
end

function PlayerHudContainerEntity:_btnHoverTween(btnCtx)
    btnCtx.hoverTween
        :to(btnCtx, 0.5, { scale = 1.05 })
        :after(btnCtx, 0.5, { scale = 0.97 })
        :oncomplete(function()
            if btnCtx.hoverTween then
                self:_btnHoverTween(btnCtx)
            end
        end)
end

--- Handle hover-pulse animation for a button
function PlayerHudContainerEntity:_animateButton(btnCtx, btnState, enabled, dt)
    if not enabled then
        return
    end
    if btnState.entered then
        btnCtx.hoverTween = flux.group()
        self:_btnHoverTween(btnCtx)
    end
    if btnState.hovered then
        if btnCtx.hoverTween then
            btnCtx.hoverTween:update(dt)
        end
    elseif btnState.left then
        btnCtx.scale = 1.0
        btnCtx.hoverTween = nil
    end
end

--- Keep displayedScore in sync with the current player's score:
---     - new player: snap to their score (no animation)
---     - same player, score changed: count up/down to the new score and flash the text
function PlayerHudContainerEntity:_updateScore(dt, previousPlayer)
    local score = self.player.score
    if self.player ~= previousPlayer then
        self.displayedScore = score
        self.scoreTarget = score
        self.scoreFlash = 0
        self.scoreTween = flux.group()
    elseif score ~= self.scoreTarget then
        self.scoreFlashColor = score > self.scoreTarget and SCORE_FLASH_COLOR or SCORE_DECREASE_FLASH_COLOR
        self.scoreTarget = score
        self.scoreFlash = 1
        self.scoreTween = flux.group()
        self.scoreTween:to(self, SCORE_COUNT_TIME_S, { displayedScore = score }):ease("quadout")
        self.scoreTween:to(self, SCORE_FLASH_TIME_S, { scoreFlash = 0 }):ease("quadin")
    end
    self.scoreTween:update(dt)
end

function PlayerHudContainerEntity:update(dt, gameState)
    local previousPlayer = self.player
    self.player = gameState.players[gameState.currentTurnPlayer]
    self.wildType = gameState:getCurrentWildType()
    self:_updateScore(dt, previousPlayer)

    -- HUD lives in screen space, so the default (screen) mouse position is correct
    self.ui:enterFrame()

    local cornerRadius = math.floor(self.doneRect.h * 0.25)
    local doneBtn = self.ui:Button("Done", {
        id = "hudDone",
        draw = ViewUtil.suitButtonDraw,
        color = self.doneEnabled and BUTTON_COLORS or DISABLED_BUTTON_COLORS,
        cornerRadius = cornerRadius,
        outline = 2,
        scale = self.buttons.done.scale,
    }, self.doneRect.x, self.doneRect.y, self.doneRect.w, self.doneRect.h)
    self:_animateButton(self.buttons.done, doneBtn, self.doneEnabled, dt)

    local passBtn = self.ui:Button("Pass", {
        id = "hudPass",
        draw = ViewUtil.suitButtonDraw,
        color = BUTTON_COLORS,
        cornerRadius = cornerRadius,
        outline = 2,
        scale = self.buttons.pass.scale,
    }, self.passRect.x, self.passRect.y, self.passRect.w, self.passRect.h)
    self:_animateButton(self.buttons.pass, passBtn, true, dt)

    local undoBtn = self.ui:Button("Undo", {
        id = "hudUndo",
        draw = ViewUtil.suitButtonDraw,
        color = self.undoEnabled and BUTTON_COLORS or DISABLED_BUTTON_COLORS,
        cornerRadius = cornerRadius,
        outline = 2,
        scale = self.buttons.undo.scale,
    }, self.undoRect.x, self.undoRect.y, self.undoRect.w, self.undoRect.h)
    self:_animateButton(self.buttons.undo, undoBtn, self.undoEnabled, dt)
end

function PlayerHudContainerEntity:_drawHandCell(cell, count, isWild)
    local alpha = count > 0 and 1.0 or EMPTY_SLOT_ALPHA

    if isWild then
        local color = TileView.TILE_COLOR[cell.type]
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setLineWidth(3)
        local r = math.floor(cell.h * 0.15)
        love.graphics.rectangle("line", cell.x, cell.y, cell.w, cell.h, r, r)
    end

    -- tile on the left of the cell. tile polygon is ~2/3 as wide as its size, so it
    -- only needs ~40% of the cell width
    local tileAreaW = math.floor(cell.w * 0.5)
    local tileSize = math.floor(cell.h * 0.8)
    local tileX = cell.x + math.floor((tileAreaW - tileSize) / 2)
    local tileY = cell.y + math.floor((cell.h - tileSize) / 2)
    TileView.drawTileAt(cell.type, tileSize, 0, tileX, tileY, alpha)

    -- count on the right
    love.graphics.setColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], alpha)
    local label = "x" .. tostring(count)
    if isWild then
        label = label .. "*"
    end
    local textW = cell.w - tileAreaW
    local font = ViewUtil.largestFontThatFits(label, textW, cell.h)
    ViewUtil.printPixelText(label, font, cell.x + tileAreaW, cell.y, textW, cell.h)
end

function PlayerHudContainerEntity:_drawDivider(y)
    love.graphics.setColor(DIVIDER_COLOR)
    love.graphics.setLineWidth(1)
    love.graphics.line(self.pad, y, self.boundingBox.w - self.pad, y)
end

function PlayerHudContainerEntity:draw(gameState)
    local origR, origG, origB, origA = love.graphics.getColor()

    -- container background
    love.graphics.setColor(BG_COLOR)
    local cornerRadius = math.floor(self.boundingBox.w * 0.05)
    ViewUtil.drawOutlinedRectangle(
        self.cameraPos.x,
        self.cameraPos.y,
        self.boundingBox.w,
        self.boundingBox.h,
        cornerRadius
    )

    if self.player then
        -- name & score
        love.graphics.setColor(TEXT_COLOR)
        local r = self.nameRect
        local name = self.player.playerName or ""
        ViewUtil.printPixelText(name, ViewUtil.largestFontThatFits(name, r.w, r.h), r.x, r.y, r.w, r.h)
        r = self.scoreRect
        local f = self.scoreFlash
        local flashColor = self.scoreFlashColor
        love.graphics.setColor(
            TEXT_COLOR[1] + (flashColor[1] - TEXT_COLOR[1]) * f,
            TEXT_COLOR[2] + (flashColor[2] - TEXT_COLOR[2]) * f,
            TEXT_COLOR[3] + (flashColor[3] - TEXT_COLOR[3]) * f,
            1
        )
        local scoreText = "Score: " .. tostring(math.floor(self.displayedScore + 0.5))
        ViewUtil.printPixelText(scoreText, ViewUtil.largestFontThatFits(scoreText, r.w, r.h), r.x, r.y, r.w, r.h)
        self:_drawDivider(self.handDividerY)

        -- hand
        for _, cell in ipairs(self.handCells) do
            self:_drawHandCell(cell, self.player.hand:num(cell.type), cell.type == self.wildType)
        end
        self:_drawDivider(self.buttonDividerY)

        -- buttons
        self.ui:draw()
    end

    love.graphics.setColor(origR, origG, origB, origA)
end

function PlayerHudContainerEntity:resize(w, h, _)
    self.boundingBox.w = math.floor(w * 0.15) -- 15% of screen width
    self.boundingBox.h = h -- Full screen height

    -- Position at the left edge of the screen
    self.cameraPos.x = 0
    self.cameraPos.y = 0

    local panelW = self.boundingBox.w
    local pad = math.max(4, math.floor(panelW * 0.06))
    self.pad = pad
    local innerW = panelW - 2 * pad

    -- all layout values are floored to land on whole pixels
    local y = pad
    self.nameRect = { x = pad, y = y, w = innerW, h = math.floor(h * NAME_ROW_H) }
    y = y + self.nameRect.h
    self.scoreRect = { x = pad, y = y, w = innerW, h = math.floor(h * SCORE_ROW_H) }
    y = y + self.scoreRect.h + math.floor(pad / 2)
    -- +0.5 so the 1px divider line is centered on a pixel row
    self.handDividerY = y + 0.5
    y = y + pad

    -- hand grid: tile types always occupy the same cell (TileType.ORDERED order)
    local halfPad = math.floor(pad / 2)
    local cellW = math.floor((panelW - (HAND_COLS + 1) * pad) / HAND_COLS)
    local cellH = math.floor(math.min(cellW * 0.75, h * MAX_HAND_CELL_H))
    self.handCells = {}
    for ii, tileType in ipairs(TileType.ORDERED) do
        local col = (ii - 1) % HAND_COLS
        local row = math.floor((ii - 1) / HAND_COLS)
        self.handCells[ii] = {
            type = tileType,
            x = pad + col * (cellW + pad),
            y = y + row * (cellH + halfPad),
            w = cellW,
            h = cellH,
        }
    end
    local numRows = math.ceil(#TileType.ORDERED / HAND_COLS)
    y = y + numRows * cellH + numRows * halfPad

    self.buttonDividerY = y + 0.5
    local handGridBtm  = y + pad
    
    -- UI buttons: aligned to bottom
    local btnH = math.floor(h * BUTTON_ROW_H)
    y = self.boundingBox.h - ((btnH + pad) * table.count(self.buttons))

    self.doneRect = { x = pad, y = y, w = innerW, h = btnH }
    y = y + btnH + pad
    self.passRect = { x = pad, y = y, w = innerW, h = btnH }
    y = y + btnH + pad

    -- half-width row: undo on the left, right half reserved for a future button
    local halfW = math.floor((innerW - pad) / 2)
    self.undoRect = { x = pad, y = y, w = halfW, h = btnH }
    self.secondaryRect = { x = pad + halfW + pad, y = y, w = halfW, h = btnH }
end

return PlayerHudContainerEntity
