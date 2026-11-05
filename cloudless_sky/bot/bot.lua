--- Plays a whole game through the UI (simulated mouse clicks) and checks it as it goes.
--- Run with:  love . --bot [--seed N] [--bot-speed N]
---
--- Every frame it checks:
---     - the model invariants (cloudless_sky/model/invariants.lua)
---     - when the table isn't animating: the table's visual state matches the model
---     - progress: something must happen every STALL_TIMEOUT_S (catches stuck state machines)
--- At the start of every round and at the end of the game it checks the game saves and loads back
--- exactly (SaveGame through json: replaying the history from the seed gives the same game)
--- At the end of the game it waits for the game end sequence to reach the final scores, then checks
--- every player's end-game bonuses were scored exactly once
--- Exit codes: 0 = game finished, every check held. 1 = a check failed. 2 = timed out. 3 = Lua error.
---
--- Runs are repeatable: the game's rng, the view's randomness and the bot's choices all follow the
--- seed. The final line prints the seed and a digest of the final game state; the same seed should
--- always give the same digest.
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local Canonical = require("cloudless_sky.model.canonical")
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local GameEndStateMachine = require("cloudless_sky.states.game_end_sm")
local Invariants = require("cloudless_sky.model.invariants")
local SaveGame = require("cloudless_sky.model.save_game")
local TableAreaEntity = require("cloudless_sky.entities.table_area_entity")
local TileType = require("cloudless_sky.model.tile_type")

local Bot = {}

-- real (wall clock) seconds
local STALL_TIMEOUT_S = 30
local RUN_TIMEOUT_S = 900
-- updates to wait after a click before acting again. The click is handled during the next update;
-- counting updates (not seconds) keeps the bot from acting twice on a slow frame, which would use an
-- extra random draw and make runs with the same seed differ
local CLICK_COOLDOWN_FRAMES = 3
-- chance of passing during placement even when a tile could be placed (exercises the keep dialog)
local VOLUNTARY_PASS_CHANCE = 0.1
-- how close (world units) the camera must be to its target before clicking world things
local CAMERA_SETTLED_DIST = 1

local CENTER = 0

local function out(msg)
    print("BOT " .. msg)
    io.stdout:flush()
end

--------------------------------------------------------------------------------
-- digest: a canonical (key-sorted) string of the serialized game state, hashed
--------------------------------------------------------------------------------

--- @return string hex digest of everything serialized for \p gameState, plus its action history
function Bot.digest(gameState)
    local parts = { Canonical.encode(gameState:serialize()) }
    for _, action in ipairs(gameState.actionHistory) do
        table.insert(parts, Canonical.encode(action:serialize()))
    end
    return Canonical.hash(table.concat(parts))
end

--------------------------------------------------------------------------------
-- checks
--------------------------------------------------------------------------------

--- @return string[] differences between the table's visual state and the model
local function tableViewFailures(tableEntity)
    local failures = {}
    for source, group in pairs(tableEntity.groups) do
        local bag = gameState:tileSource(source)
        local counts = group:counts()
        for _, tileType in ipairs(TileType.ORDERED) do
            if counts[tileType] ~= bag:num(tileType) then
                table.insert(
                    failures,
                    string.format("table source %d shows %d %s, model has %d", source, counts[tileType], tileType, bag:num(tileType))
                )
            end
        end
    end
    local poolCounts = tableEntity.bonusPool:counts()
    for _, tileType in ipairs(TileType.ORDERED) do
        if poolCounts[tileType] ~= gameState.bonusPool:num(tileType) then
            table.insert(
                failures,
                string.format("bonus pool shows %d %s, model has %d", poolCounts[tileType], tileType, gameState.bonusPool:num(tileType))
            )
        end
    end
    if math.floor(tableEntity.bagCount + 0.5) ~= gameState.tileBag:total() then
        table.insert(failures, "bag shows " .. tableEntity.bagCount .. ", model has " .. gameState.tileBag:total())
    end
    if math.floor(tableEntity.towerCount + 0.5) ~= gameState.discard:total() then
        table.insert(failures, "tower shows " .. tableEntity.towerCount .. ", model has " .. gameState.discard:total())
    end
    if tableEntity.tokenInCenter ~= (gameState.startTokenHolder == nil) then
        table.insert(failures, "start token shown in the wrong place")
    end
    return failures
end

--------------------------------------------------------------------------------
-- clicking
--------------------------------------------------------------------------------

function Bot:click(screenX, screenY)
    love.mouse.setPosition(screenX, screenY)
    love.mousepressed(screenX, screenY, 1, false)
    self.cooldown = CLICK_COOLDOWN_FRAMES
end

function Bot:clickRect(r)
    self:click(r.x + r.w / 2, r.y + r.h / 2)
end

function Bot:clickWorld(worldX, worldY)
    self:click(camera:cameraCoords(worldX, worldY))
end

local function cameraSettled()
    local target = graphicsState.cameraTarget
    if not target then
        return false
    end
    return math.abs(camera.x - target.x) < CAMERA_SETTLED_DIST and math.abs(camera.y - target.y) < CAMERA_SETTLED_DIST
end

--- @return boolean True once a pop-in dialog has finished popping in
local function dialogSettled(dialog)
    return dialog.scale >= 0.999 and #dialog.transitionTween == 0
end

local function dialogOpen(dialog)
    return dialog ~= nil and not dialog.ephemeral.done
end

function Bot:pick(list)
    return list[self.rng:random(1, #list)]
end

--------------------------------------------------------------------------------
-- tile selection
--------------------------------------------------------------------------------

--- @return VisualTile|nil a tile of \p tileType at \p source that is on top where it's drawn (so
---     clicking its center clicks it)
local function clickableTile(tableEntity, source, tileType)
    for _, tile in ipairs(tableEntity.groups[source].tiles) do
        if tile.tileType == tileType then
            local hitSource, hitTile = tableEntity:tileAt(tile.x, tile.y)
            if hitSource == source and hitTile == tile then
                return tile
            end
        end
    end
    return nil
end

function Bot:actSelection(sm)
    local states = sm.STATES
    if sm.state == states.WAIT_FOR_END then
        self:clickRect(graphicsState.hud.container.doneRect)
    elseif sm.state == states.WAIT_FOR_PICK then
        if dialogOpen(sm.pickUpDialog) then
            local dialog, intended = sm.pickUpDialog, self.intendedPick
            if intended and (dialog.source ~= intended.source or dialog.tileType ~= intended.tileType) then
                self:fail(string.format(
                    "clicked %s at source %d but the dialog is for %s at source %d",
                    intended.tileType, intended.source, dialog.tileType, dialog.source
                ))
                return
            end
            if dialogSettled(sm.pickUpDialog) and sm.pickUpDialog.actionButton then
                self:clickRect(sm.pickUpDialog.actionButton)
            end
            return
        end
        local tableEntity = graphicsState.table
        if tableEntity:isAnimating() or not cameraSettled() then
            return
        end
        -- choose from the model's legal picks (not the visuals) so choices follow the seed
        local choices = {}
        for source = CENTER, gameState:numFactoryDisplays() do
            for _, tileType in ipairs(TileType.ORDERED) do
                if TableAreaEntity.takeFor(gameState, source, tileType) then
                    table.insert(choices, { source = source, tileType = tileType })
                end
            end
        end
        if #choices == 0 then
            self:fail("no legal pick while selection continues")
            return
        end
        -- tiles can overlap: if every tile of the chosen pick is covered at its center, choose again
        while #choices > 0 do
            local idx = self.rng:random(1, #choices)
            local choice = choices[idx]
            local tile = clickableTile(tableEntity, choice.source, choice.tileType)
            if tile then
                self.intendedPick = choice
                self:clickWorld(tile.x, tile.y)
                return
            end
            table.remove(choices, idx)
        end
        self:fail("every legal pick is covered by other tiles")
    end
end

--------------------------------------------------------------------------------
-- tile placement
--------------------------------------------------------------------------------

function Bot:actPlacement(sm)
    local states = sm.STATES
    local hud = graphicsState.hud.container
    if sm.state == states.WAIT_FOR_END then
        self:clickRect(hud.doneRect)
    elseif sm.state == states.CONFIRM_PASS then
        if sm.passDialog and sm.passDialog.confirmRect then
            self:clickRect(sm.passDialog.confirmRect)
        end
    elseif sm.state == states.WAIT_FOR_PLACEMENT then
        if dialogOpen(sm.placeDialog) then
            if dialogSettled(sm.placeDialog) then
                if sm.placeDialog.actionButton then
                    self:clickRect(sm.placeDialog.actionButton)
                else
                    -- "need more tiles": the bot only clicks placeable slots, so this is a bug
                    self:fail("bot opened a slot it can't place in")
                end
            end
            return
        end
        if not cameraSettled() then
            return
        end
        local player = gameState.players[sm.playerIdx]
        local wild = gameState:getCurrentWildType()
        local slots = {}
        for starIdx, star in ipairs(player.mat.stars) do
            for slotIdx = 1, star:numSlots() do
                if not star:isOccupied(slotIdx) then
                    local options = player:generatePlacementPossibilities(starIdx, slotIdx, wild)
                    if #options > 0 then
                        table.insert(slots, { starIdx = starIdx, slotIdx = slotIdx })
                    end
                end
            end
        end
        if #slots == 0 or self.rng:random() < VOLUNTARY_PASS_CHANCE then
            self:clickRect(hud.passRect)
            return
        end
        local slot = self:pick(slots)
        local mat = graphicsState.matEntities[sm.playerIdx]
        self:clickWorld(mat:centerOfSlot(slot.starIdx, slot.slotIdx))
    end
end

--------------------------------------------------------------------------------
-- driver
--------------------------------------------------------------------------------

--- Fail the run unless the game survives a save + load unchanged
function Bot:checkSaveRoundTrip()
    local restored, reason = SaveGame.decode(SaveGame.encode(gameState))
    if not restored then
        self:fail("save/load: " .. tostring(reason))
        return
    end
    local expected, actual = Bot.digest(gameState), Bot.digest(restored)
    if actual ~= expected then
        self:fail("save/load: restored game digest " .. actual .. " ~= " .. expected)
    end
end

--- Fail the run unless every player's end-game bonuses were scored exactly once, for what their mat holds
function Bot:checkEndGameScoring()
    local scored = {}
    for _, action in ipairs(gameState.actionHistory) do
        if action.name == "ScoreEndGame" then
            local idx = action.ctx.playerIdx
            if scored[idx] then
                self:fail("player " .. idx .. " was scored twice")
                return
            end
            scored[idx] = action.ctx.total
        end
    end
    for ii, player in ipairs(gameState.players) do
        local expected = EndGameBonus.total(EndGameBonus.forPlayer(gameState.rules, player))
        if scored[ii] ~= expected or player.endGameBonus ~= expected then
            self:fail(string.format("player %d end-game bonus: scored %s, recorded %s, expected %d", ii, tostring(scored[ii]), tostring(player.endGameBonus), expected))
            return
        end
    end
end

function Bot:fail(msg)
    if self.done then
        return
    end
    self.done = true
    out(string.format("FAIL seed=%s t=%.1fs round=%d: %s", tostring(gameState.seed), self.realTime, gameState.round.idx, msg))
    out("replay with: love . --bot --seed " .. tostring(gameState.seed))
    love.event.quit(1)
end

function Bot:finish()
    self.done = true
    local scores = {}
    for ii, player in ipairs(gameState.players) do
        scores[ii] = player.playerName .. "=" .. player.score
    end
    out(string.format(
        "PASS seed=%s rounds=%d actions=%d scores=[%s] time=%.1fs digest=%s",
        tostring(gameState.seed),
        gameState.round.idx,
        #gameState.actionHistory,
        table.concat(scores, " "),
        self.realTime,
        Bot.digest(gameState)
    ))
    love.event.quit(0)
end

--- @return string something that changes whenever the game makes progress
local function progressKey()
    local top = GameStateMachineMgr.current()
    return table.concat({
        #gameState.actionHistory,
        gameState.turnIdx,
        gameState.round.idx,
        tostring(top),
        tostring(top.state),
        tostring(graphicsState.table:isAnimating()),
    }, "|")
end

function Bot:check()
    for _, msg in ipairs(Invariants.check(gameState)) do
        self:fail("invariant: " .. msg)
        return
    end
    -- only compare once the table has caught up with the latest actions (it syncs during its update)
    local tableEntity = graphicsState.table
    if not tableEntity:isAnimating() and tableEntity.syncedHistoryLen == #gameState.actionHistory then
        for _, msg in ipairs(tableViewFailures(graphicsState.table)) do
            self:fail("table view: " .. msg)
            return
        end
    end

    local key = progressKey()
    if key ~= self.lastProgressKey then
        self.lastProgressKey = key
        self.lastProgressTime = self.realTime
    elseif self.realTime - self.lastProgressTime > STALL_TIMEOUT_S then
        self:fail("stalled for " .. STALL_TIMEOUT_S .. "s at " .. key)
    end
end

function Bot:act()
    self.cooldown = self.cooldown - 1
    if self.cooldown > 0 then
        return
    end
    local top = GameStateMachineMgr.current()
    -- hump.gamestate drops input events for a newly entered state until it has been updated once.
    -- Wait a few updates after any state/turn change so clicks aren't lost (a lost click makes the
    -- bot decide again, using an extra random draw)
    local topKey = tostring(top) .. "|" .. gameState.turnIdx
    if topKey ~= self.lastTopKey then
        self.lastTopKey = topKey
        self.cooldown = CLICK_COOLDOWN_FRAMES
        return
    end
    if top == game.roundSm.selectionTurn then
        self:actSelection(top)
    elseif top == game.roundSm.placementTurn then
        self:actPlacement(top)
    end
end

function Bot:update(realDt)
    if self.done then
        return
    end
    self.realTime = self.realTime + realDt
    if gameState.round.idx ~= self.round then
        self.round = gameState.round.idx
        out("round " .. self.round .. " (wild " .. tostring(gameState:getCurrentWildType()) .. ")")
        self:checkSaveRoundTrip()
        if self.done then
            return
        end
    end

    self:check()
    if self.done then
        return
    end
    if game.gameOver then
        -- the game end sequence plays by itself: wait for the final scores
        if game.gameEndSm.state ~= GameEndStateMachine.STATES.FINAL_SCORES then
            return
        end
        self:checkEndGameScoring()
        if self.done then
            return
        end
        self:checkSaveRoundTrip()
        if self.done then
            return
        end
        self:finish()
        return
    end
    if self.realTime > RUN_TIMEOUT_S then
        self.done = true
        out("TIMEOUT seed=" .. tostring(gameState.seed) .. " after " .. RUN_TIMEOUT_S .. "s")
        love.event.quit(2)
        return
    end
    self:act()
end

--- Start the bot. Call after the game state has been entered (gameState/graphicsState exist)
--- @param options table launchOptions (botSpeed)
function Bot.install(options)
    local bot = setmetatable({}, { __index = Bot })
    -- the bot's own choices follow the seed too, without touching the game's rng
    bot.rng = love.math.newRandomGenerator(gameState.seed + 1)
    bot.cooldown = 0
    bot.realTime = 0
    bot.lastProgressTime = 0
    bot.done = false
    bot.round = nil
    local speed = options.botSpeed or 1

    out("starting seed=" .. tostring(gameState.seed) .. " speed=" .. speed)

    local origUpdate = love.update
    love.update = function(dt)
        origUpdate(dt * speed)
        bot:update(dt)
    end

    -- any Lua error fails the run instead of showing the error screen
    love.errorhandler = function(msg)
        out("ERROR seed=" .. tostring(gameState and gameState.seed) .. ": " .. tostring(msg))
        print(debug.traceback())
        io.stdout:flush()
        os.exit(3)
    end
    return bot
end

return Bot
