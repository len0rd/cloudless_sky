--- Pop-up dialog shown when a bonus space icon on a mat is clicked: what the bonus is, the tiles it
--- earns, and how many of its slots are filled (the mat outlines those slots while this is open, see
--- PlayerMatEntity:selectBonus). Closes on a click outside it (PopInDialog).
---
--- It never reads the game state: everything it shows is passed in
local MatBonus = require("cloudless_sky.model.mat_bonus")
local MatBonusView = require("cloudless_sky.view.mat_bonus_view")
local PopInDialog = require("cloudless_sky.entities.pop_in_dialog")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class BonusInfoDialogEntity : PopInDialog
local BonusInfoDialogEntity = setmetatable({}, { __index = PopInDialog })
BonusInfoDialogEntity.__index = BonusInfoDialogEntity

-- dialog dimensions in screen pixels
local WIDTH = 300
local ROW_H = 30
local NUM_ROWS = 3
local ICON_W = 40
-- gap between the icon and the bonus's name
local ICON_GAP = 6
local ICON_OUTLINE = { 0.35, 0.35, 0.4, 1 }
local ACHIEVED_COLOR = { 0.7, 0.5, 0, 1 }
local TEXT_COLOR = { 0, 0, 0, 1 }

--- @param info table { kind = MatBonus.KIND, tiles = integer, filled = integer, total = integer }
--- @return table lines { title, reward, progress } and achieved (boolean)
function BonusInfoDialogEntity.lines(info)
    local achieved = info.filled >= info.total
    return {
        title = MatBonus.LABEL[info.kind],
        reward = "Pick up " .. info.tiles .. " bonus " .. (info.tiles == 1 and "tile" or "tiles"),
        progress = achieved and "Achieved!" or (info.filled .. " / " .. info.total .. " filled"),
    },
        achieved
end

--- @param info table see BonusInfoDialogEntity.lines
function BonusInfoDialogEntity.new(info)
    local entity = PopInDialog.create(BonusInfoDialogEntity, WIDTH, ROW_H * NUM_ROWS + 8)
    entity.info = info
    entity.text, entity.achieved = BonusInfoDialogEntity.lines(info)
    return entity
end

--- The title row: the icon and the bonus's name side by side, centered together in the row (away from
--- the dialog's rounded corners)
local function drawTitleRow(text, opt, x, y, w, h)
    local font = ViewUtil.largestFontThatFits(text, w - opt.iconW - ICON_GAP, h)
    local groupW = opt.iconW + ICON_GAP + font:getWidth(text)
    local left = x + (w - groupW) / 2
    local size = math.min(opt.iconW, h) * 0.85
    MatBonusView.drawIcon(opt.kind, left + opt.iconW / 2, y + h / 2, size, opt.achieved, ICON_OUTLINE)
    love.graphics.setColor(TEXT_COLOR)
    ViewUtil.printPixelText(text, font, left + opt.iconW + ICON_GAP, y, w, h, "left")
end

function BonusInfoDialogEntity:layoutContent(dt, w, h)
    local pad = PopInDialog.LAYOUT_PAD
    local rowH = math.floor(h / NUM_ROWS)
    -- the lines under the title share one font, the largest that fits both
    local longest = #self.text.reward >= #self.text.progress and self.text.reward or self.text.progress
    local bodyFont = ViewUtil.largestFontThatFits(longest, w - 2 * pad - 4, rowH)
    local function opts(color, font)
        return { draw = ViewUtil.suitLabelDraw, color = { normal = { fg = color } }, fixedFont = font }
    end
    self.ui:Label(self.text.title, {
        draw = drawTitleRow,
        kind = self.info.kind,
        achieved = self.achieved,
        iconW = math.floor(ICON_W * self.scale),
    }, self.ui.layout:col(w - 2 * pad, rowH))
    for _, line in ipairs({
        { self.text.reward, TEXT_COLOR },
        { self.text.progress, self.achieved and ACHIEVED_COLOR or TEXT_COLOR },
    }) do
        self.ui.layout:newRow()
        self.ui:Label(line[1], opts(line[2], bodyFont), self.ui.layout:col(w - 2 * pad, rowH))
    end
end

return BonusInfoDialogEntity
