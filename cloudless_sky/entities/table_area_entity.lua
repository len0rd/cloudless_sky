--- The table: factory displays in a ring around the center of the table, plus the bag and tower, the
--- round track (each round's wild tile, with a marker on the current round) in the top-left corner and
--- the bonus pool (BonusPoolView) in the top-right corner.
--- Lives in the world north of the player mats, centered between them.
--- The bag and tower are hidden except while a refill (tower -> bag) animation plays.
---
--- Visual state (tile positions, bag/tower counts) is kept here, separate from the model. While idle
--- it is kept in step with the model every update (syncFromModel), which also covers undo and round
--- changes. During animations (fill, take) it deliberately lags the model and catches up as the
--- animation plays.
--- The visual state (groups, bagCount, towerCount, tokenInCenter) is plain data so other views (eg:
--- a future compact read-only factory bar) can draw the same thing.
local Concord = require("cloudless_sky.extern.concord")
local Anim = require("cloudless_sky.anim")
local BonusPoolView = require("cloudless_sky.view.bonus_pool_view")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")
local EUtil = require("cloudless_sky.entities.e_util")
local RoundTrackView = require("cloudless_sky.view.round_track_view")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")
local TileGroupView = require("cloudless_sky.view.tile_group_view")
local TileType = require("cloudless_sky.model.tile_type")
local TileView = require("cloudless_sky.view.tile_view")
local ViewUtil = require("cloudless_sky.view.view_util")

local flux = require("cloudless_sky.extern.flux")

---@class TableAreaEntity
---@field groups table<integer, TileGroupView> tile source (GameState.CENTER or display index) -> group
---@field bagCount number tiles shown in the bag
---@field towerCount number tiles shown in the tower
---@field tokenInCenter boolean start player token is shown in the center
---@field bagTowerAlpha number visibility of the bag and tower (0 = hidden). Only shown during a refill
---@field roundTrack RoundTrackView
---@field bonusPool BonusPoolView tiles in the bonus pool
---@field poolSmall table {x, y, scale} where the bonus pool sits in the corner, and its size there
local TableAreaEntity = {}
TableAreaEntity.__index = TableAreaEntity

-- GameState.CENTER
local CENTER = 0

-- world size of the table
local TABLE_W = 1200
local TABLE_H = 800
-- world gap between the bottom of the table and the top of the player mats
local MAT_GAP = 150

-- layout, as fractions of TABLE_H
local RING_RADIUS = 0.36
local MAX_DISPLAY_RADIUS = 0.12
local CENTER_MARGIN = 0.03
local TILE_SIZE_OF_DISPLAY = 0.62

-- animation timing (seconds at normal speed. See Anim)
local FILL_FLY_S = 0.3
local FILL_STAGGER_S = 0.07
local REFILL_ARC_S = 0.6
local REFILL_STAGGER_S = 0.05
local REFILL_MAX_GHOSTS = 12
-- bag/tower fade in before a refill, and out after it
local REVEAL_S = 0.25
local TAKE_S = 0.45
local POP_IN_S = 0.25

-- bonus pool, in world units: gap from the table's top-right corner, and its disc's radius there (its
-- tiles are drawn small enough to fit, at most POOL_MAX_SMALL_SCALE of their normal size)
local POOL_MARGIN = 30
local POOL_SMALL_R = 64
local POOL_MAX_SMALL_SCALE = 0.6
-- "Bonus tiles" label under it
local POOL_LABEL_GAP = 4
local POOL_LABEL_H = 22

local COLORS = {
    table = { 0.15, 0.21, 0.19, 1 },
    tableOutline = { 0.08, 0.1, 0.1, 1 },
    display = { 0.86, 0.83, 0.75, 1 },
    displayOutline = { 0.35, 0.3, 0.25, 1 },
    center = { 0.2, 0.27, 0.25, 1 },
    centerOutline = { 0.3, 0.38, 0.35, 1 },
    bag = { 0.55, 0.38, 0.22, 1 },
    bagTie = { 0.35, 0.22, 0.12, 1 },
    tower = { 0.55, 0.55, 0.6, 1 },
    towerDark = { 0.38, 0.38, 0.42, 1 },
    token = { 0.97, 0.97, 0.92, 1 },
    tokenOutline = { 0, 0, 0, 1 },
    label = { 1, 1, 1, 1 },
}

--- @return TileType[] \p counts (TileType -> count) expanded into a shuffled list of tiles
local function expandShuffled(counts, rng)
    local list = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        for _ = 1, counts[tileType] or 0 do
            table.insert(list, tileType)
        end
    end
    for ii = #list, 2, -1 do
        local jj = rng:random(1, ii)
        list[ii], list[jj] = list[jj], list[ii]
    end
    return list
end

--- @param gameState GameState used for the number of displays and the starting bag/tower counts
--- @param matEntities table PlayerMatEntity list. The table is placed north of them, centered
function TableAreaEntity.new(gameState, matEntities)
    local entity = Concord.entity()

    local firstMat = matEntities[1]
    local lastMat = matEntities[#matEntities]
    local centerX = (firstMat.worldPos.x + lastMat.worldPos.x + lastMat.boundingBox.w) / 2
    local x = centerX - TABLE_W / 2
    local y = firstMat.worldPos.y - MAT_GAP - TABLE_H

    entity
        :give(Components.names.worldPos, x, y)
        :give(Components.names.boundingBox, TABLE_W, TABLE_H)
        :give(Components.names.drawable, Constants.drawPriority.tableArea)
        :give(Components.names.mouseHandler, Constants.drawPriority.tableArea)

    EUtil.extendEntity(entity, TableAreaEntity)

    -- view-only randomness (tile positions, rotations). Seeded from the game so a run looks the same
    -- every time, but separate from the game's rng so visuals never affect game results
    entity.viewRng = love.math.newRandomGenerator(gameState.seed)
    entity:_layout(gameState:numFactoryDisplays(), gameState.rules.bonusSurrounds.numBonusTiles)
    entity.roundTrack = RoundTrackView(x, y, #gameState.rules.wildPerRound, gameState.round.idx)

    entity.tweens = flux.group()
    -- queued animation steps. Each is a function(done)
    entity.steps = {}
    entity.busy = false
    -- tiles moving between places (not in any group). Drawn on top
    entity.flying = {}

    entity.hovered = nil
    entity.highlight = nil
    entity.selectable = false

    entity.bagCount = gameState.tileBag:total()
    entity.towerCount = gameState.discard:total()
    entity.tokenInCenter = gameState.startTokenHolder == nil
    entity.bagTowerAlpha = 0
    entity:syncFromModel(gameState, true)

    return entity
end

--- Position the displays, center, bag, tower and bonus pool
--- @param numPoolSlots integer how many tiles the bonus pool holds
function TableAreaEntity:_layout(numDisplays, numPoolSlots)
    local cx = self.worldPos.x + TABLE_W / 2
    local cy = self.worldPos.y + TABLE_H / 2
    local ringR = TABLE_H * RING_RADIUS
    local displayR = math.min(TABLE_H * MAX_DISPLAY_RADIUS, math.sin(math.pi / numDisplays) * ringR * 0.85)
    local tileSize = displayR * TILE_SIZE_OF_DISPLAY

    self.groups = {}
    -- first display at the top, then clockwise
    for ii, point in ipairs(ViewUtil.pointsOnCircle(cx, cy, ringR, numDisplays, -math.pi / 2)) do
        self.groups[ii] = TileGroupView(point.x, point.y, displayR, tileSize, self.viewRng)
    end
    local centerR = ringR - displayR - TABLE_H * CENTER_MARGIN
    self.groups[CENTER] = TileGroupView(cx, cy, centerR, tileSize, self.viewRng)
    self.tileSize = tileSize

    self.bag = { x = self.worldPos.x + TABLE_W * 0.1, y = self.worldPos.y + TABLE_H * 0.8, w = 110, h = 120 }
    self.tower = { x = self.worldPos.x + TABLE_W * 0.9, y = self.worldPos.y + TABLE_H * 0.78, w = 90, h = 160 }

    self.bonusPool = BonusPoolView(numPoolSlots, tileSize)
    local poolScale = math.min(POOL_MAX_SMALL_SCALE, POOL_SMALL_R / self.bonusPool:radiusAt(1))
    local poolR = self.bonusPool:radiusAt(poolScale)
    self.poolSmall = {
        x = self.worldPos.x + TABLE_W - POOL_MARGIN - poolR,
        y = self.worldPos.y + POOL_MARGIN + poolR,
        scale = poolScale,
    }
    self.bonusPool:setPlacement(self.poolSmall.x, self.poolSmall.y, self.poolSmall.scale)
end

--- @return number x, number y, number w, number h. World rect of the "Bonus tiles" label under the
---     bonus pool (in the corner)
function TableAreaEntity:poolLabelRect()
    local small = self.poolSmall
    local r = self.bonusPool:radiusAt(small.scale)
    return small.x - r, small.y + r + POOL_LABEL_GAP, r * 2, POOL_LABEL_H
end

--- @return number x, number y world point tiles fly to/from for the bag
function TableAreaEntity:bagMouth()
    return self.bag.x, self.bag.y - self.bag.h * 0.35
end

--- @return number x, number y world point tiles fly to/from for the tower
function TableAreaEntity:towerTop()
    return self.tower.x, self.tower.y - self.tower.h * 0.5
end

--- @return boolean True while an animation is playing (visual state lags the model)
function TableAreaEntity:isAnimating()
    return self.busy
end

--------------------------------------------------------------------------------
-- animation queue
--------------------------------------------------------------------------------

function TableAreaEntity:_queue(step)
    table.insert(self.steps, step)
    if not self.busy then
        self:_runNext()
    end
end

function TableAreaEntity:_runNext()
    local step = table.remove(self.steps, 1)
    if not step then
        self.busy = false
        return
    end
    self.busy = true
    step(function()
        self:_runNext()
    end)
end

--- Animate FillFactoryDisplaysAction. Must be called the same update the action was performed, so
--- the visual state still shows the tiles in the bag
--- @param events table FillFactoryDisplaysAction (or FillBonusPoolAction) ctx.events
--- @param onComplete function|nil called once every display is filled
function TableAreaEntity:playFill(events, onComplete)
    for _, event in ipairs(events) do
        if event.refill then
            self:_queue(function(done)
                self:_animateRefill(event.refill, done)
            end)
        elseif event.display then
            self:_queue(function(done)
                self:_animateFlyIn(self.groups[event.display], expandShuffled(event.tiles, self.viewRng), done)
            end)
        elseif event.pool then
            self:_queue(function(done)
                -- in color order, so colors sit together around the pool
                self:_animateFlyIn(self.bonusPool, BonusPoolView.orderedList(event.pool), done)
            end)
        end
    end
    self:_queue(function(done)
        if onComplete then
            onComplete()
        end
        done()
    end)
end

--- Tiles fly from the bag to their spots in \p container (a display, or the bonus pool), one after another
--- @param container TileGroupView|BonusPoolView
--- @param list TileType[] the tiles, in the order they fly
function TableAreaEntity:_animateFlyIn(container, list, done)
    local finish = Anim.join(#list, done)
    local bagX, bagY = self:bagMouth()
    for ii, tileType in ipairs(list) do
        local tile = container:receiveTile({
            tileType = tileType,
            x = bagX,
            y = bagY,
            rot = self.viewRng:random() * 2 * math.pi,
            scale = 0.5,
            alpha = 0,
        })
        self.tweens
            :to(tile, Anim.time(FILL_FLY_S), { x = tile.targetX, y = tile.targetY, scale = 1, alpha = 1 })
            :ease("quadout")
            :delay(Anim.time((ii - 1) * FILL_STAGGER_S))
            :onstart(function()
                self.bagCount = self.bagCount - 1
            end)
            :oncomplete(function()
                tile.targetX, tile.targetY = nil, nil
                finish()
            end)
    end
end

--- The bag ran out: the tower's tiles arc over into the bag
function TableAreaEntity:_animateRefill(counts, done)
    self.tweens:to(self, Anim.time(REVEAL_S), { bagTowerAlpha = 1 }):ease("quadout"):oncomplete(function()
        self:_animateRefillArc(counts, function()
            self.tweens:to(self, Anim.time(REVEAL_S), { bagTowerAlpha = 0 }):ease("quadin")
            done()
        end)
    end)
end

function TableAreaEntity:_animateRefillArc(counts, done)
    local list = expandShuffled(counts, self.viewRng)
    local numTiles = #list
    local numGhosts = math.min(numTiles, REFILL_MAX_GHOSTS)
    local fromX, fromY = self:towerTop()
    local toX, toY = self:bagMouth()
    -- control point for the arc: above the midpoint
    local ctrlX, ctrlY = (fromX + toX) / 2, math.min(fromY, toY) - TABLE_H * 0.35

    local totalTime = Anim.time(REFILL_ARC_S + (numGhosts - 1) * REFILL_STAGGER_S)
    local finish = Anim.join(numGhosts + 1, done)
    for ii = 1, numGhosts do
        -- spread the ghosts over the colors moved
        local ghost = {
            tileType = list[math.floor((ii - 1) * numTiles / numGhosts) + 1],
            x = fromX,
            y = fromY,
            rot = self.viewRng:random() * 2 * math.pi,
            scale = 0.8,
            alpha = 0,
            t = 0,
        }
        table.insert(self.flying, ghost)
        self.tweens
            :to(ghost, Anim.time(REFILL_ARC_S), { t = 1, alpha = 1 })
            :ease("linear")
            :delay(Anim.time((ii - 1) * REFILL_STAGGER_S))
            :onupdate(function()
                -- quadratic bezier from the tower to the bag
                local t = ghost.t
                local u = 1 - t
                ghost.x = u * u * fromX + 2 * u * t * ctrlX + t * t * toX
                ghost.y = u * u * fromY + 2 * u * t * ctrlY + t * t * toY
                ghost.rot = ghost.rot + 0.15
            end)
            :oncomplete(function()
                self:_removeFlying(ghost)
                finish()
            end)
    end
    -- counts tick over while the tiles fly
    self.tweens
        :to(self, totalTime, { towerCount = self.towerCount - numTiles, bagCount = self.bagCount + numTiles })
        :ease("linear")
        :oncomplete(finish)
end

function TableAreaEntity:_removeFlying(tile)
    for ii, t in ipairs(self.flying) do
        if t == tile then
            table.remove(self.flying, ii)
            return
        end
    end
end

--- Animate TakeTilesAction: taken tiles slide off toward the HUD and fade, the rest of the display
--- slides into the center
--- @param ctx table TakeTilesAction ctx (after perform)
--- @param onComplete function|nil
function TableAreaEntity:animateTake(ctx, onComplete)
    self:_queue(function(done)
        local group = self.groups[ctx.source]
        local center = self.groups[CENTER]
        local moving = {}

        -- toward the HUD (left edge of the screen, vertically centered)
        local _, screenH = love.graphics.getDimensions()
        local hudX, hudY = camera:worldCoords(0, screenH / 2)
        for _, tileType in ipairs(TileType.ORDERED) do
            local count = ctx.taken[tileType] or 0
            for _, tile in ipairs(group:removeTiles(tileType, count, self.lastClickedTile)) do
                table.insert(self.flying, tile)
                table.insert(moving, { tile = tile, vars = { x = hudX, y = hudY, alpha = 0, scale = 0.6 }, fly = true })
            end
        end
        for _, tileType in ipairs(TileType.ORDERED) do
            local count = (ctx.toCenter or {})[tileType] or 0
            for _, tile in ipairs(group:removeTiles(tileType, count)) do
                center:receiveTile(tile)
                table.insert(moving, { tile = tile, vars = { x = tile.targetX, y = tile.targetY } })
            end
        end
        if ctx.tookToken then
            self.tokenInCenter = false
        end

        local finish = Anim.join(#moving, function()
            if onComplete then
                onComplete()
            end
            done()
        end)
        for _, move in ipairs(moving) do
            self.tweens:to(move.tile, Anim.time(TAKE_S), move.vars):ease("quadinout"):oncomplete(function()
                move.tile.targetX, move.tile.targetY = nil, nil
                if move.fly then
                    self:_removeFlying(move.tile)
                end
                finish()
            end)
        end
    end)
end

--------------------------------------------------------------------------------
-- model sync
--------------------------------------------------------------------------------

--- Bring the visual state in line with the model: add (popping in) or remove tiles so each group
--- matches its tile source, and update the bag/tower counts and the token
--- @param instant boolean|nil if true, added tiles appear without popping in
function TableAreaEntity:syncFromModel(gameState, instant)
    for source, group in pairs(self.groups) do
        local bag = gameState:tileSource(source)
        if bag then
            self:_syncContainer(group, bag, instant)
        end
    end
    self:_syncContainer(self.bonusPool, gameState.bonusPool, instant)
    self.bagCount = gameState.tileBag:total()
    self.towerCount = gameState.discard:total()
    self.tokenInCenter = gameState.startTokenHolder == nil
    -- how much of the action history the visual state reflects (lets checks skip frames where the
    -- view hasn't caught up yet)
    self.syncedHistoryLen = #gameState.actionHistory
end

--- Add (popping in) or remove tiles so \p container (TileGroupView or BonusPoolView) matches \p bag
function TableAreaEntity:_syncContainer(container, bag, instant)
    local counts = container:counts()
    for _, tileType in ipairs(TileType.ORDERED) do
        local diff = bag:num(tileType) - counts[tileType]
        if diff < 0 then
            container:removeTiles(tileType, -diff)
        else
            for _ = 1, diff do
                local tile = container:addTile(tileType)
                if not instant then
                    tile.scale = 0
                    self.tweens:to(tile, Anim.time(POP_IN_S), { scale = 1 }):ease("backout")
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- hover / click
--------------------------------------------------------------------------------

--- @return integer|nil source, VisualTile|nil tile. The topmost tile under the world point
function TableAreaEntity:tileAt(worldX, worldY)
    -- center first: tiles in it may be drawn over nearby displays
    local tile = self.groups[CENTER]:tileAt(worldX, worldY)
    if tile then
        return CENTER, tile
    end
    for source, group in ipairs(self.groups) do
        tile = group:tileAt(worldX, worldY)
        if tile then
            return source, tile
        end
    end
    return nil, nil
end

--- @return table VisualTile -> true for the tiles that \p take (TileType -> count) would pick up,
---     preferring \p hovered
function TableAreaEntity:_highlightFor(source, hovered, take)
    local group = self.groups[source]
    local set = {}
    for tileType, count in pairs(take) do
        local picked = 0
        if hovered.tileType == tileType then
            set[hovered] = true
            picked = 1
        end
        for _, tile in ipairs(group.tiles) do
            if picked >= count then
                break
            end
            if tile.tileType == tileType and not set[tile] then
                set[tile] = true
                picked = picked + 1
            end
        end
    end
    return set
end

--- @return table|nil take TileType -> count picked up for \p tile at \p source, or nil if not allowed
function TableAreaEntity.takeFor(gameState, source, tileType)
    local bag = gameState:tileSource(source)
    if not bag then
        return nil
    end
    return TakeTilesAction.tilesToTake(
        bag,
        tileType,
        gameState:getCurrentWildType(),
        gameState.rules.factoryDisplay.maxWildPerTurn
    )
end

function TableAreaEntity:mousePressed(cameraX, cameraY, worldX, worldY, button, istouch)
    if button ~= 1 or not self.selectable then
        return false
    end
    local source, tile = self:tileAt(worldX, worldY)
    if not tile then
        return false
    end
    self.lastClickedTile = tile
    self.mouseHandler.clickEvent = {
        type = Components.mouseHandler.eventTypes.tableTileClicked,
        source = source,
        tileType = tile.tileType,
        worldX = tile.x,
        worldY = tile.y,
    }
    return true
end

function TableAreaEntity:update(dt, gameState)
    self.tweens:update(dt)
    -- not held back by other table animations: the marker slides as soon as the round changes,
    -- while the new round's fill plays
    self.roundTrack:update(gameState.round.idx, self.tweens)
    -- tiles that have landed in the pool follow their slot
    self.bonusPool:setPlacement(self.poolSmall.x, self.poolSmall.y, self.poolSmall.scale)
    if not self.busy then
        self:syncFromModel(gameState)
    else
        -- the token isn't animated (except by animateTake, which sets it to match the model), so it
        -- always follows the model. eg: it returns to the center while the next round's fill plays
        self.tokenInCenter = gameState.startTokenHolder == nil
    end

    self.selectable = not self.busy and gameState.round.phase == gameState.RoundPhase.TILE_SELECTION
    self.hovered = nil
    self.highlight = nil
    if self.selectable then
        local source, tile = self:tileAt(camera:mousePosition())
        if tile then
            local take = TableAreaEntity.takeFor(gameState, source, tile.tileType)
            if take then
                self.hovered = { source = source, tile = tile }
                self.highlight = self:_highlightFor(source, tile, take)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- drawing
--------------------------------------------------------------------------------

function TableAreaEntity:_drawBag()
    local b = self.bag
    local a = self.bagTowerAlpha
    ViewUtil.setColorAlpha(COLORS.bag, a)
    love.graphics.ellipse("fill", b.x, b.y + b.h * 0.1, b.w / 2, b.h * 0.4)
    -- gathered neck
    love.graphics.polygon(
        "fill",
        b.x - b.w * 0.18,
        b.y - b.h * 0.25,
        b.x + b.w * 0.18,
        b.y - b.h * 0.25,
        b.x + b.w * 0.3,
        b.y - b.h * 0.45,
        b.x - b.w * 0.3,
        b.y - b.h * 0.45
    )
    ViewUtil.setColorAlpha(COLORS.bagTie, a)
    love.graphics.setLineWidth(6)
    love.graphics.line(b.x - b.w * 0.2, b.y - b.h * 0.27, b.x + b.w * 0.2, b.y - b.h * 0.27)
end

function TableAreaEntity:_drawTower()
    local t = self.tower
    local a = self.bagTowerAlpha
    local left, top = t.x - t.w / 2, t.y - t.h / 2
    ViewUtil.setColorAlpha(COLORS.tower, a)
    love.graphics.rectangle("fill", left, top + t.h * 0.12, t.w, t.h * 0.88)
    -- battlements
    local merlonW = t.w / 5
    for ii = 0, 4, 2 do
        love.graphics.rectangle("fill", left + ii * merlonW, top, merlonW, t.h * 0.14)
    end
    -- doorway
    ViewUtil.setColorAlpha(COLORS.towerDark, a)
    love.graphics.rectangle("fill", t.x - t.w * 0.18, top + t.h * 0.65, t.w * 0.36, t.h * 0.35, t.w * 0.18, t.w * 0.18)
end

--- @return number x, number y, number size. Top-left and size of the start player token, which is
---     tile-shaped (an upright diamond) and the same size as a tile
function TableAreaEntity:_tokenRect()
    local center = self.groups[CENTER]
    local size = self.tileSize
    return center.x - size / 2, center.y - center.radius * 0.75 - size / 2, size
end

function TableAreaEntity:_drawToken()
    local x, y, size = self:_tokenRect()
    TileView.drawDiamond(x, y, size, 0, COLORS.token, COLORS.tokenOutline, 2)
end

function TableAreaEntity:draw(gameState)
    love.graphics.push()
    love.graphics.setColor(COLORS.table)
    ViewUtil.drawOutlinedRectangle(
        self.worldPos.x,
        self.worldPos.y,
        TABLE_W,
        TABLE_H,
        TABLE_H * 0.05,
        4,
        COLORS.tableOutline
    )

    local center = self.groups[CENTER]
    love.graphics.setColor(COLORS.center)
    love.graphics.circle("fill", center.x, center.y, center.radius)
    love.graphics.setColor(COLORS.centerOutline)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", center.x, center.y, center.radius)

    for _, group in ipairs(self.groups) do
        love.graphics.setColor(COLORS.display)
        love.graphics.circle("fill", group.x, group.y, group.radius)
        love.graphics.setColor(COLORS.displayOutline)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", group.x, group.y, group.radius)
    end

    self.roundTrack:draw(gameState.rules.wildPerRound)

    if self.bagTowerAlpha > 0 then
        self:_drawBag()
        self:_drawTower()
    end

    if self.tokenInCenter then
        self:_drawToken()
    end

    for _, group in ipairs(self.groups) do
        group:drawTiles(self.highlight)
    end
    center:drawTiles(self.highlight)

    self.bonusPool:drawBase()
    self.bonusPool:drawTiles()

    for _, tile in ipairs(self.flying) do
        TileGroupView.drawTile(tile, self.tileSize)
    end
    love.graphics.pop()
end

--- labels drawn in screen space so the pixel font stays crisp (see DrawSys)
function TableAreaEntity:drawScreen(gameState)
    local origR, origG, origB, origA = love.graphics.getColor()

    local drawLabel = ViewUtil.drawWorldLabel

    if self.bagTowerAlpha > 0 then
        local labelColor = { COLORS.label[1], COLORS.label[2], COLORS.label[3], COLORS.label[4] * self.bagTowerAlpha }
        local b = self.bag
        drawLabel("Bag: " .. math.floor(self.bagCount + 0.5), b.x - b.w, b.y + b.h * 0.55, b.w * 2, 40, labelColor)
        local t = self.tower
        drawLabel("Tower: " .. math.floor(self.towerCount + 0.5), t.x - t.w, t.y + t.h * 0.55, t.w * 2, 40, labelColor)
    end
    self.roundTrack:drawScreen(gameState.rules.wildPerRound, gameState.round.idx)
    drawLabel("Bonus tiles", self:poolLabelRect())

    if self.tokenInCenter then
        local x, y, size = self:_tokenRect()
        local textX, textY, textW, textH = TileView.labelRect(x, y, size)
        drawLabel("1", textX, textY, textW, textH, { 0, 0, 0, 1 })
    end

    love.graphics.setColor(origR, origG, origB, origA)
end

return TableAreaEntity
