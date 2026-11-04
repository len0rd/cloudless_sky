--- Modal dialog to confirm passing for the rest of the round.
---
--- When the player has more tiles than they may keep, it shows one "keep slot" per tile they may
--- keep (pre-filled with a suggestion). Clicking a slot opens a tile picker listing the colors
--- still available: in hand, minus what the other slots already hold. Slots can also be cleared.
---
--- The dialog never reads the game state. It reports back through mouseHandler.clickEvent:
---     { type = passConfirmed, keep = { TileType -> count } }
---     { type = passCancelled }
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local Player = require("cloudless_sky.model.player")
local TileType = require("cloudless_sky.model.tile_type")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

local suit = require("cloudless_sky.extern.suit")

---@class PassConfirmDialogEntity
local PassConfirmDialogEntity = {}
PassConfirmDialogEntity.__index = PassConfirmDialogEntity

-- layout (screen pixels)
local PAD = 16
local MIN_WIDTH = 440
local TITLE_H = 40
local SUBTITLE_H = 28
local SLOT_SIZE = 56
local SLOT_GAP = 12
local DISCARD_H = 32
local FLOOR_NOTE_H = 20
local BUTTON_H = 48
local PICKER_ENTRY_W = 56
local PICKER_ENTRY_H = 72

local BACKDROP_COLOR = { 0, 0, 0, 0.45 }
local PANEL_COLOR = { 0.12, 0.12, 0.18, 0.97 }
local PANEL_OUTLINE_COLOR = { 0.85, 0.85, 0.85 }
local SLOT_COLOR = { 0.2, 0.2, 0.27 }
local SLOT_HOVER_COLOR = { 0.3, 0.3, 0.4 }
local EMPTY_TILE_COLOR = { 0.45, 0.45, 0.45 }
local TEXT_COLOR = { 1, 1, 1 }
local SUBTLE_TEXT_COLOR = { 0.7, 0.7, 0.7 }
local PENALTY_TEXT_COLOR = { 0.9, 0.45, 0.45 }

local BUTTON_COLORS = {
    normal = { bg = { 0.25, 0.25, 0.25 }, fg = { 1, 1, 1 } },
    hovered = { bg = { 0.19, 0.6, 0.73 }, fg = { 1, 1, 1 } },
    active = { bg = { 1, 0.6, 0 }, fg = { 1, 1, 1 } },
}
BUTTON_COLORS.hit = BUTTON_COLORS.active

--- @return table available List of { tileType, count } (in TileType.ORDERED order) of tiles that could go
---     in slot \p slotIdx: those in \p hand not already used by the OTHER slots. Only entries with count > 0
--- @param hand TileBag the player's hand
--- @param slots table list of TileType|false (false = empty slot)
function PassConfirmDialogEntity.availableForSlot(hand, slots, slotIdx)
    local used = {}
    for ii, tileType in ipairs(slots) do
        if ii ~= slotIdx and tileType then
            used[tileType] = (used[tileType] or 0) + 1
        end
    end
    local available = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        local count = hand:num(tileType) - (used[tileType] or 0)
        if count > 0 then
            table.insert(available, { tileType = tileType, count = count })
        end
    end
    return available
end

--- @return table keep TileType -> count of the tiles in \p slots
function PassConfirmDialogEntity.slotsToKeep(slots)
    local keep = {}
    for _, tileType in ipairs(slots) do
        if tileType then
            keep[tileType] = (keep[tileType] or 0) + 1
        end
    end
    return keep
end

--- @param hand TileBag the passing player's hand
--- @param limit integer how many tiles may be kept (0 in the final round)
--- @param suggestedKeep table TileType -> count to pre-fill the keep slots with
--- @param score integer the player's current score (for showing the penalty after the score floor)
function PassConfirmDialogEntity.new(hand, limit, suggestedKeep, score)
    local entity = Concord.entity()
    entity
        :give(Components.names.drawable, Constants.drawPriority.modal)
        :give(Components.names.cameraPos, 0, 0)
        :give(Components.names.mouseHandler, Constants.drawPriority.modal)
        :give(Components.names.boundingBox, MIN_WIDTH, 100) -- sized in :resize

    EUtil.extendEntity(entity, PassConfirmDialogEntity)

    entity.hand = hand
    entity.limit = limit
    entity.score = score
    entity.handTotal = hand:total()
    -- the player only chooses when they hold more tiles than they may keep
    entity.editable = limit > 0 and entity.handTotal > limit

    -- one entry per keep slot: TileType, or false when empty. No slots when nothing can be kept
    entity.slots = {}
    if limit > 0 then
        -- choosing: start from the suggestion. otherwise everything in hand is kept
        local source = entity.editable and suggestedKeep or nil
        for _, tileType in ipairs(TileType.ORDERED) do
            local count = source and (source[tileType] or 0) or hand:num(tileType)
            for _ = 1, count do
                table.insert(entity.slots, tileType)
            end
        end
        for ii = #entity.slots + 1, limit do
            entity.slots[ii] = false
        end
    end

    -- index of the slot whose tile picker is open, or nil
    entity.pickerSlot = nil

    entity.ui = suit.new()

    local screenWidth, screenHeight = love.graphics.getPixelDimensions()
    entity:resize(screenWidth, screenHeight, nil)
    return entity
end

--- @return table keep TileType -> count the player will keep
function PassConfirmDialogEntity:keep()
    return PassConfirmDialogEntity.slotsToKeep(self.slots)
end

--- @return integer numDiscarded, integer penalty
function PassConfirmDialogEntity:_discardInfo()
    local kept = 0
    for _, tileType in ipairs(self.slots) do
        if tileType then
            kept = kept + 1
        end
    end
    local numDiscarded = self.handTotal - kept
    return numDiscarded, Player.clampedPenalty(self.score, numDiscarded)
end

--- @return table|nil entries picker entries for the open picker: { tileType|false, count, rect }.
---     tileType false is the "clear" entry
function PassConfirmDialogEntity:_pickerEntries()
    if not self.pickerSlot then
        return nil
    end
    local entries = {}
    for _, avail in ipairs(PassConfirmDialogEntity.availableForSlot(self.hand, self.slots, self.pickerSlot)) do
        table.insert(entries, { tileType = avail.tileType, count = avail.count })
    end
    if self.slots[self.pickerSlot] then
        table.insert(entries, { tileType = false, count = 0 })
    end

    -- panel centered under the slot, clamped inside the dialog
    local slotRect = self.slotRects[self.pickerSlot]
    local panelW = #entries * PICKER_ENTRY_W + (#entries + 1) * 4
    local panelH = PICKER_ENTRY_H + 8
    local panelX = slotRect.x + math.floor((slotRect.w - panelW) / 2)
    panelX = math.max(self.cameraPos.x + 4, math.min(panelX, self.cameraPos.x + self.boundingBox.w - panelW - 4))
    local panelY = slotRect.y + slotRect.h + 4
    self.pickerRect = { x = panelX, y = panelY, w = panelW, h = panelH }
    for ii, entry in ipairs(entries) do
        entry.rect = { x = panelX + 4 + (ii - 1) * (PICKER_ENTRY_W + 4), y = panelY + 4, w = PICKER_ENTRY_W, h = PICKER_ENTRY_H }
    end
    return entries
end

local function inRect(x, y, r)
    return ViewUtil.ptInRect(x, y, r.x, r.y, r.w, r.h)
end

--- Modal: claims every press while open
function PassConfirmDialogEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    if button ~= 1 then
        return true
    end

    -- picker open: choose an entry, or close it
    local entries = self:_pickerEntries()
    if entries then
        for _, entry in ipairs(entries) do
            if inRect(cameraX, cameraY, entry.rect) then
                self.slots[self.pickerSlot] = entry.tileType
                break
            end
        end
        self.pickerSlot = nil
        return true
    end

    if self.editable then
        for ii, rect in ipairs(self.slotRects) do
            if inRect(cameraX, cameraY, rect) then
                self.pickerSlot = ii
                return true
            end
        end
    end

    if inRect(cameraX, cameraY, self.cancelRect) then
        self.mouseHandler.clickEvent = { type = Components.mouseHandler.eventTypes.passCancelled }
    elseif inRect(cameraX, cameraY, self.confirmRect) then
        self.mouseHandler.clickEvent = { type = Components.mouseHandler.eventTypes.passConfirmed, keep = self:keep() }
    end
    return true
end

function PassConfirmDialogEntity:update(dt, gameState)
    self.ui:enterFrame()
    local cornerRadius = math.floor(BUTTON_H * 0.25)
    for _, btn in ipairs({ { "Cancel", self.cancelRect }, { "Pass", self.confirmRect } }) do
        local r = btn[2]
        self.ui:Button(btn[1], {
            id = "passDialog" .. btn[1],
            draw = ViewUtil.suitButtonDraw,
            color = BUTTON_COLORS,
            cornerRadius = cornerRadius,
            outline = 2,
        }, r.x, r.y, r.w, r.h)
    end
end

--- draw a tile (or a gray placeholder when tileType is false) centered in rect
local function drawTileInRect(tileType, rect, size)
    local x = rect.x + math.floor((rect.w - size) / 2)
    local y = rect.y + math.floor((rect.h - size) / 2)
    if tileType then
        TileView.drawTileAt(tileType, size, 0, x, y)
    else
        local vertices = TileView.betterPolyVerticies(size, 0, x, y)
        love.graphics.setColor(EMPTY_TILE_COLOR)
        love.graphics.polygon("fill", vertices)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", vertices)
    end
end

local function printLine(text, rect, color, align)
    love.graphics.setColor(color)
    local font = ViewUtil.largestFontThatFits(text, rect.w, rect.h)
    ViewUtil.printPixelText(text, font, rect.x, rect.y, rect.w, rect.h, align)
end

function PassConfirmDialogEntity:draw(gameState)
    local origR, origG, origB, origA = love.graphics.getColor()
    local screenW, screenH = love.graphics.getPixelDimensions()
    local mouseX, mouseY = love.mouse.getPosition()

    -- dim everything behind the modal
    love.graphics.setColor(BACKDROP_COLOR)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local x, y, w, h = self.cameraPos.x, self.cameraPos.y, self.boundingBox.w, self.boundingBox.h
    love.graphics.setColor(PANEL_COLOR)
    ViewUtil.drawOutlinedRectangle(x, y, w, h, 12, 2, PANEL_OUTLINE_COLOR)

    printLine("Pass for this round?", self.titleRect, TEXT_COLOR)
    local subtitle
    if self.limit == 0 then
        subtitle = "Final round: no tiles are kept"
    elseif self.editable then
        subtitle = "Keep up to " .. self.limit .. " tiles for next round:"
    else
        subtitle = "You keep all your tiles for next round:"
    end
    printLine(subtitle, self.subtitleRect, SUBTLE_TEXT_COLOR)

    -- keep slots
    for ii, rect in ipairs(self.slotRects) do
        local hovered = self.editable and not self.pickerSlot and inRect(mouseX, mouseY, rect)
        love.graphics.setColor((hovered or self.pickerSlot == ii) and SLOT_HOVER_COLOR or SLOT_COLOR)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
        drawTileInRect(self.slots[ii], rect, math.floor(rect.h * 0.8))
    end

    -- discard / penalty summary
    local numDiscarded, penalty = self:_discardInfo()
    local summary
    if self.limit == 0 then
        summary = "All " .. numDiscarded .. " tiles discarded: -" .. penalty .. " points"
    else
        summary = "Discard " .. numDiscarded .. " tiles: -" .. penalty .. " points"
    end
    printLine(summary, self.discardRect, numDiscarded > 0 and PENALTY_TEXT_COLOR or TEXT_COLOR)
    if penalty < numDiscarded then
        printLine("(score can't go below 1)", self.floorNoteRect, SUBTLE_TEXT_COLOR)
    end

    self.ui:draw()

    -- tile picker on top of everything else in the dialog
    local entries = self:_pickerEntries()
    if entries then
        local p = self.pickerRect
        love.graphics.setColor(PANEL_COLOR)
        ViewUtil.drawOutlinedRectangle(p.x, p.y, p.w, p.h, 6, 2, PANEL_OUTLINE_COLOR)
        for _, entry in ipairs(entries) do
            local r = entry.rect
            if inRect(mouseX, mouseY, r) then
                love.graphics.setColor(SLOT_HOVER_COLOR)
                love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
            end
            local tileRect = { x = r.x, y = r.y, w = r.w, h = r.w }
            drawTileInRect(entry.tileType, tileRect, math.floor(r.w * 0.75))
            local label = entry.tileType and ("x" .. entry.count) or "Clear"
            printLine(label, { x = r.x, y = r.y + r.w, w = r.w, h = r.h - r.w }, TEXT_COLOR)
        end
    end

    love.graphics.setColor(origR, origG, origB, origA)
end

function PassConfirmDialogEntity:resize(screenW, screenH, _)
    local numSlots = #self.slots
    local slotsW = numSlots * SLOT_SIZE + math.max(0, numSlots - 1) * SLOT_GAP
    local w = math.max(MIN_WIDTH, slotsW + 2 * PAD)
    local slotsRowH = numSlots > 0 and (SLOT_SIZE + PAD) or 0
    -- room under the slots for the picker to open without covering the buttons
    local pickerRoom = self.editable and (PICKER_ENTRY_H + 8 - DISCARD_H - FLOOR_NOTE_H) or 0
    local h = PAD + TITLE_H + SUBTITLE_H + PAD + slotsRowH + DISCARD_H + FLOOR_NOTE_H + math.max(0, pickerRoom) + PAD + BUTTON_H + PAD

    self.boundingBox.w = w
    self.boundingBox.h = h
    self.cameraPos.x = math.floor((screenW - w) / 2)
    self.cameraPos.y = math.floor((screenH - h) / 2)

    local x0, y = self.cameraPos.x, self.cameraPos.y + PAD
    local innerW = w - 2 * PAD
    self.titleRect = { x = x0 + PAD, y = y, w = innerW, h = TITLE_H }
    y = y + TITLE_H
    self.subtitleRect = { x = x0 + PAD, y = y, w = innerW, h = SUBTITLE_H }
    y = y + SUBTITLE_H + PAD

    self.slotRects = {}
    local slotX = x0 + math.floor((w - slotsW) / 2)
    for ii = 1, numSlots do
        self.slotRects[ii] = { x = slotX + (ii - 1) * (SLOT_SIZE + SLOT_GAP), y = y, w = SLOT_SIZE, h = SLOT_SIZE }
    end
    y = y + slotsRowH

    self.discardRect = { x = x0 + PAD, y = y, w = innerW, h = DISCARD_H }
    y = y + DISCARD_H
    self.floorNoteRect = { x = x0 + PAD, y = y, w = innerW, h = FLOOR_NOTE_H }

    local buttonY = self.cameraPos.y + h - PAD - BUTTON_H
    local buttonW = math.floor((innerW - PAD) / 2)
    self.cancelRect = { x = x0 + PAD, y = buttonY, w = buttonW, h = BUTTON_H }
    self.confirmRect = { x = x0 + PAD + buttonW + PAD, y = buttonY, w = buttonW, h = BUTTON_H }
end

return PassConfirmDialogEntity
