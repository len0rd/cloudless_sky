--- Plays a whole game through the UI (simulated mouse clicks) and checks it as it goes.
--- Run with:  love . --bot [ID] [--seed N] [--bot-speed N]
---
--- What to do comes from a BotPlayer (ID, default "easy") for every seat: the same choices a headless
--- game makes. This file is the UI driver: it turns each chosen action into the clicks a person would
--- make (a tile, then the pick-up dialog's button; a slot, the place dialog's arrows to the chosen way
--- to pay, then Place; Pass, then confirm; bonus tiles on the pickup overlay, then Take).
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
--- Runs are repeatable: the game's rng, the view's randomness and the bots' choices all follow the
--- seed. Each choice is asked for once, when the game reaches it, so how long animations take doesn't
--- change the game. The final line prints the seed and a digest of the final game state; the same seed
--- should always give the same digest.
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local BotPlayer = require("cloudless_sky.bot.bot_player")
local HeadlessMatch = require("cloudless_sky.bot.headless_match")
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local GameEndStateMachine = require("cloudless_sky.states.game_end_sm")
local Invariants = require("cloudless_sky.model.invariants")
local SaveGame = require("cloudless_sky.model.save_game")
local TileType = require("cloudless_sky.model.tile_type")
-- registers the bots BotPlayer.create can make
require("cloudless_sky.bot.players.easy_bot")

local Bot = {}

Bot.DEFAULT_BOT = "easy"

-- real (wall clock) seconds
local STALL_TIMEOUT_S = 30
local RUN_TIMEOUT_S = 900
-- updates to wait after a click before acting again. The click is handled during the next update;
-- counting updates (not seconds) keeps the bot from acting twice on a slow frame
local CLICK_COOLDOWN_FRAMES = 3
-- how close (world units) the camera must be to its target before clicking world things
local CAMERA_SETTLED_DIST = 1

local function out(msg)
    print("BOT " .. msg)
    io.stdout:flush()
end

--------------------------------------------------------------------------------
-- digest: a canonical (key-sorted) string of the serialized game state, hashed
--------------------------------------------------------------------------------

--- @return string hex digest of everything serialized for \p gameState, plus its action history
function Bot.digest(gameState)
    return HeadlessMatch.digest(gameState)
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

--- The action the current player's bot chose for the decision the game is at now. The bot is asked
--- once per decision (a decision is identified by the turn and the history length, which only change
--- when an action is performed), then the same action is returned until it has been carried out
--- @param ask function(bot, playerIdx) -> Action
function Bot:decision(ask)
    local key = gameState.turnIdx .. "|" .. #gameState.actionHistory
    if not (self.plan and self.plan.key == key) then
        local playerIdx = gameState.currentTurnPlayer
        self.plan = { key = key, action = ask(self.players[playerIdx], playerIdx) }
    end
    return self.plan.action
end

--------------------------------------------------------------------------------
-- tile selection
--------------------------------------------------------------------------------

--- @return number|nil x, number|nil y. A world point that clicks a \p tileType tile at \p source: the
---     center of one of those tiles, or a point near it, where the topmost tile drawn is one of them
---     (tiles can overlap). nil if every one is covered
local function clickPointFor(tableEntity, source, tileType)
    local group = tableEntity.groups[source]
    local offsets = { { 0, 0 }, { 0.2, 0 }, { -0.2, 0 }, { 0, 0.2 }, { 0, -0.2 } }
    for _, tile in ipairs(group.tiles) do
        if tile.tileType == tileType then
            for _, o in ipairs(offsets) do
                local x, y = tile.x + o[1] * group.tileSize, tile.y + o[2] * group.tileSize
                local hitSource, hitTile = tableEntity:tileAt(x, y)
                if hitSource == source and hitTile and hitTile.tileType == tileType then
                    return x, y
                end
            end
        end
    end
    return nil, nil
end

function Bot:actSelection(sm)
    local states = sm.STATES
    if sm.state == states.WAIT_FOR_END then
        self:clickRect(graphicsState.hud.container.doneRect)
    elseif sm.state == states.WAIT_FOR_PICK then
        local tableEntity = graphicsState.table
        if tableEntity:isAnimating() or not cameraSettled() then
            return
        end
        local take = self:decision(function(bot, playerIdx)
            return bot:chooseTake(gameState, playerIdx)
        end).ctx
        if dialogOpen(sm.pickUpDialog) then
            local dialog = sm.pickUpDialog
            if dialog.source ~= take.source or dialog.tileType ~= take.tileType then
                self:fail(string.format(
                    "clicked %s at source %d but the dialog is for %s at source %d",
                    take.tileType, take.source, dialog.tileType, dialog.source
                ))
                return
            end
            if dialogSettled(dialog) and dialog.actionButton then
                self:clickRect(dialog.actionButton)
            end
            return
        end
        local x, y = clickPointFor(tableEntity, take.source, take.tileType)
        if not x then
            self:fail(string.format("every %s tile at source %d is covered by other tiles", take.tileType, take.source))
            return
        end
        self:clickWorld(x, y)
    end
end

--------------------------------------------------------------------------------
-- tile placement
--------------------------------------------------------------------------------

--- @return boolean True if placement option \p a (PlacementPossibility) is the same payment as \p b
local function samePayment(a, b)
    return a.tileType == b.tileType
        and a.tileCount == b.tileCount
        and (a.wildCount or 0) == (b.wildCount or 0)
        and ((a.wildCount or 0) == 0 or a.wildType == b.wildType)
end

--- @return boolean True if TileType -> count tables \p a and \p b hold the same tiles
local function sameTiles(a, b)
    for _, tileType in ipairs(TileType.ORDERED) do
        if (a[tileType] or 0) ~= (b[tileType] or 0) then
            return false
        end
    end
    return true
end

function Bot:actPlacement(sm)
    local states = sm.STATES
    local hud = graphicsState.hud.container
    if sm.state == states.WAIT_FOR_END then
        self:clickRect(hud.doneRect)
    elseif sm.state == states.CONFIRM_PASS then
        local dialog = sm.passDialog
        if not (dialog and dialog.confirmRect) then
            return
        end
        local pass = self.plan and self.plan.action
        if not (pass and pass.name == "Pass") then
            self:fail("the pass dialog is open but the bot didn't choose to pass")
            return
        end
        -- the dialog starts with PassAction.suggestKeep's tiles. Changing them isn't driven yet
        if not sameTiles(dialog:keep(), pass.ctx.keep) then
            self:fail("the bot chose to keep different tiles than the pass dialog suggests (not supported yet)")
            return
        end
        self:clickRect(dialog.confirmRect)
    elseif sm.state == states.PICK_BONUS then
        local overlay = sm.bonusPickup
        if not (overlay and overlay:settled()) then
            return
        end
        local tiles = self:decision(function(bot, playerIdx)
            return bot:chooseBonusTiles(gameState, playerIdx, overlay.count)
        end).ctx.tiles
        local selected = overlay:selectedTiles()
        if sameTiles(selected, tiles) then
            self:clickRect(overlay.takeRect)
            return
        end
        -- select one more tile of a color still needed (or deselect one that isn't)
        for _, tile in ipairs(overlay.pool.tiles) do
            local wanted = (tiles[tile.tileType] or 0) - (selected[tile.tileType] or 0)
            if (wanted > 0 and not overlay.selected[tile]) or (wanted < 0 and overlay.selected[tile]) then
                self:click(tile.x, tile.y)
                return
            end
        end
        self:fail("the bonus pickup overlay doesn't have the tiles the bot chose")
    elseif sm.state == states.WAIT_FOR_PLACEMENT then
        if not cameraSettled() then
            return
        end
        local action = self:decision(function(bot, playerIdx)
            return bot:choosePlacement(gameState, playerIdx)
        end)
        if action.name == "Pass" then
            self:clickRect(hud.passRect)
            return
        end
        local place = action.ctx
        local dialog = sm.placeDialog
        if dialogOpen(dialog) then
            if not dialogSettled(dialog) then
                return
            end
            local anchor = dialog.playerMatTileAnchor
            if not dialog.actionButton or anchor.starIdx ~= place.starIdx or anchor.slotIdx ~= place.slotIdx then
                self:fail(string.format("the place dialog is for star %d slot %d, not the chosen star %d slot %d",
                    anchor.starIdx, anchor.slotIdx, place.starIdx, place.slotIdx))
                return
            end
            if samePayment(dialog.placementOptions[dialog.placementOptIdx], place.placement) then
                self:clickRect(dialog.actionButton)
            elseif dialog.rightArrowRect then
                -- the next way to pay
                self:clickRect(dialog.rightArrowRect)
            else
                self:fail("the place dialog doesn't offer the chosen way to pay")
            end
            return
        end
        local mat = graphicsState.matEntities[sm.playerIdx]
        self:clickWorld(mat:centerOfSlot(place.starIdx, place.slotIdx))
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
    -- a BotPlayer per seat. Their choices follow the seed too, without touching the game's rng
    bot.botId = options.botId or Bot.DEFAULT_BOT
    if not BotPlayer.known[bot.botId] then
        out("unknown bot '" .. tostring(bot.botId) .. "'. bots: " .. table.concat(BotPlayer.ids, ", "))
        love.event.quit(1)
        bot.done = true
        return bot
    end
    bot.players = {}
    for seat = 1, gameState:numPlayers() do
        bot.players[seat] = BotPlayer.create(bot.botId, gameState.seed, seat)
    end
    -- the current decision: { key, action } (see Bot:decision)
    bot.plan = nil
    bot.cooldown = 0
    bot.realTime = 0
    bot.lastProgressTime = 0
    bot.done = false
    bot.round = nil
    local speed = options.botSpeed or 1

    out("starting seed=" .. tostring(gameState.seed) .. " bot=" .. bot.botId .. " speed=" .. speed)

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
