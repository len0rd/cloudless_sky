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
local NUM_ROWS = 4
local ICON_W = 40
local ICON_OUTLINE = { 0.35, 0.35, 0.4, 1 }
local ACHIEVED_COLOR = { 0.7, 0.5, 0, 1 }
local TEXT_COLOR = { 0, 0, 0, 1 }

--- @param info table { kind = MatBonus.KIND, tiles = integer, filled = integer, total = integer }
--- @return table lines { title, reward, instruction, progress } and achieved (boolean)
function BonusInfoDialogEntity.lines(info)
    local achieved = info.filled >= info.total
    return {
        title = MatBonus.LABEL[info.kind],
        reward = "Pick up " .. info.tiles .. " bonus " .. (info.tiles == 1 and "tile" or "tiles"),
        instruction = "Fill the " .. info.total .. " outlined slots",
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

local function drawIconCell(_, opt, x, y, w, h)
    local size = math.min(w, h) * 0.85
    MatBonusView.drawIcon(opt.kind, x + w / 2, y + h / 2, size, opt.achieved, ICON_OUTLINE)
end

function BonusInfoDialogEntity:layoutContent(dt, w, h)
    local pad = PopInDialog.LAYOUT_PAD
    local rowH = math.floor(h / NUM_ROWS)
    local iconW = math.floor(ICON_W * self.scale)
    -- the three lines under the title share one font, the largest that fits all of them
    local longest = ""
    for _, line in ipairs({ self.text.reward, self.text.instruction, self.text.progress }) do
        if #line > #longest then
            longest = line
        end
    end
    local bodyFont = ViewUtil.largestFontThatFits(longest, w - 2 * pad - 4, rowH)
    local function opts(color, font)
        return { draw = ViewUtil.suitLabelDraw, color = { normal = { fg = color } }, fixedFont = font }
    end
    -- the icon and the name
    self.ui:Label(nil, { draw = drawIconCell, kind = self.info.kind, achieved = self.achieved }, self.ui.layout:col(iconW, rowH))
    self.ui:Label(self.text.title, opts(TEXT_COLOR), self.ui.layout:col(w - iconW - 3 * pad, rowH))
    for _, line in ipairs({
        { self.text.reward, TEXT_COLOR },
        { self.text.instruction, TEXT_COLOR },
        { self.text.progress, self.achieved and ACHIEVED_COLOR or TEXT_COLOR },
    }) do
        self.ui.layout:newRow()
        self.ui:Label(line[1], opts(line[2], bodyFont), self.ui.layout:col(w - 2 * pad, rowH))
    end
end

return BonusInfoDialogEntity
