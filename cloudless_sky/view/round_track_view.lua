--- The round track: a row of tiles, one per round in that round's wild color with the round number on
--- it, and a gold marker on the current round that slides along when the round changes. Past rounds
--- are dimmed. Drawn on the table (TableAreaEntity) in world space; its labels in screen space
local Object = require("cloudless_sky.extern.classic")
local Anim = require("cloudless_sky.anim")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

---@class RoundTrackView : Object
---@field slots table[] {x, y, size} world rect of each round's tile, left to right
---@field markerRound number round the marker is on. Slides to the model's round
local RoundTrackView = Object:extend()

-- in world units from the table's top-left
local LEFT = 30
local CENTER_Y = 54
local TILE_SIZE = 56
local STEP = 52
-- the current round's tile is drawn this much bigger
local CURRENT_SCALE = 1.2
-- the marker behind the current round's tile, relative to that tile
local MARKER_SCALE = 1.15
local PAST_ALPHA = 0.35
-- "Round N of M" label under the track, from the middle of the track
local LABEL_TOP = 38
local LABEL_H = 24
local SLIDE_S = 0.6

local MARKER_COLOR = { 1, 0.84, 0.3, 1 }
local OUTLINE_COLOR = { 0, 0, 0, 1 }
local LABEL_COLOR = { 1, 1, 1, 1 }

--- For layout checks: how far below the middle of the track its label reaches, and how much bigger
--- than a slot the current round's marker is drawn
RoundTrackView.LABEL_BOTTOM = LABEL_TOP + LABEL_H
RoundTrackView.MAX_SCALE = CURRENT_SCALE * MARKER_SCALE

--- @return table[] {x, y, size} world rect (top-left, size square) of each round's tile, left to
---     right, for a table with its top-left at (\p tableX, \p tableY)
function RoundTrackView.layout(tableX, tableY, numRounds)
    local slots = {}
    for ii = 1, numRounds do
        slots[ii] = {
            x = tableX + LEFT + (ii - 1) * STEP,
            y = tableY + CENTER_Y - TILE_SIZE / 2,
            size = TILE_SIZE,
        }
    end
    return slots
end

--- @param round integer the current round (the marker starts on it)
function RoundTrackView:new(tableX, tableY, numRounds, round)
    self.slots = RoundTrackView.layout(tableX, tableY, numRounds)
    self.markerRound = round
    self.targetRound = round
end

--- Slide the marker to \p round when it changes
--- @param tweens table flux group the slide runs in
function RoundTrackView:update(round, tweens)
    if self.targetRound ~= round then
        self.targetRound = round
        tweens:to(self, Anim.time(SLIDE_S), { markerRound = round }):ease("quadinout")
    end
end

--- @return number scale how much bigger round \p idx's tile is drawn: CURRENT_SCALE under the
---     marker, easing back to 1 as the marker moves away
function RoundTrackView:_scale(idx)
    local closeness = math.max(0, 1 - math.abs(idx - self.markerRound))
    return 1 + (CURRENT_SCALE - 1) * closeness
end

--- @return number x, number y, number size. Rect of round \p idx's tile as drawn (scaled about its center)
function RoundTrackView:_tileRect(idx)
    local slot = self.slots[idx]
    local size = slot.size * self:_scale(idx)
    return slot.x + (slot.size - size) / 2, slot.y + (slot.size - size) / 2, size
end

--- @return number alpha past rounds are dimmed
function RoundTrackView:_alpha(idx)
    return idx < self.markerRound - 0.5 and PAST_ALPHA or 1
end

--- @param wilds TileType[] the wild for each round (GameRules.wildPerRound)
function RoundTrackView:draw(wilds)
    -- marker behind the current round's tile: a bigger gold diamond, sliding between rounds
    local lower = math.max(1, math.min(#wilds, math.floor(self.markerRound)))
    local upper = math.min(#wilds, lower + 1)
    local frac = self.markerRound - lower
    local a, b = self.slots[lower], self.slots[upper]
    local markerSize = TILE_SIZE * CURRENT_SCALE * MARKER_SCALE
    local markerX = a.x + (b.x - a.x) * frac + (TILE_SIZE - markerSize) / 2
    local markerY = a.y + (TILE_SIZE - markerSize) / 2
    TileView.drawDiamond(markerX, markerY, markerSize, 0, MARKER_COLOR)

    for idx, wild in ipairs(wilds) do
        local x, y, size = self:_tileRect(idx)
        TileView.drawDiamond(x, y, size, 0, TileView.TILE_COLOR[wild], OUTLINE_COLOR, 2, self:_alpha(idx))
    end
end

--- Round numbers in the tiles, and "Round N of M" under them. Screen space (see DrawSys)
--- @param round integer the current round
function RoundTrackView:drawScreen(wilds, round)
    for idx = 1, #wilds do
        local x, y, size = self:_tileRect(idx)
        local textX, textY, textW, textH = TileView.labelRect(x, y, size)
        ViewUtil.drawWorldLabel(tostring(idx), textX, textY, textW, textH, { 0, 0, 0, self:_alpha(idx) })
    end
    local first, last = self.slots[1], self.slots[#wilds]
    ViewUtil.drawWorldLabel(
        "Round " .. round .. " of " .. #wilds,
        first.x,
        first.y + TILE_SIZE / 2 + LABEL_TOP,
        last.x + last.size - first.x,
        LABEL_H,
        LABEL_COLOR
    )
end

return RoundTrackView
