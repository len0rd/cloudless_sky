local cute = require("cloudless_sky.extern.cute")
local json = require("cloudless_sky.extern.json")
local Canonical = require("cloudless_sky.model.canonical")
local EndRoundAction = require("cloudless_sky.action.end_round")
local FillFactoryDisplaysAction = require("cloudless_sky.action.fill_factory_displays")
local GameState = require("cloudless_sky.model.game_state")
local PassAction = require("cloudless_sky.action.pass")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local SaveGame = require("cloudless_sky.model.save_game")
local StartPlacementPhaseAction = require("cloudless_sky.action.start_placement_phase")
local TakeTilesAction = require("cloudless_sky.action.take_tiles")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

--------------------------------------------------------------------------------
-- driving a game through the model, the way GameRoundStateMachine does
--------------------------------------------------------------------------------

local function perform(gameState, action)
    local performed, reason = gameState:performAction(action)
    assert(performed, tostring(action.name) .. " failed: " .. tostring(reason))
end

--- current player takes the first legal pick (center first, then displays in order)
local function takeFirstLegal(gameState)
    for source = GameState.CENTER, gameState:numFactoryDisplays() do
        for _, tileType in ipairs(TileType.ORDERED) do
            if gameState:performAction(TakeTilesAction(gameState.currentTurnPlayer, source, tileType)) then
                return
            end
        end
    end
    error("no legal pick")
end

local function startRound(gameState)
    perform(gameState, FillFactoryDisplaysAction())
    gameState:beginTurn(gameState.startPlayer)
end

--- take tiles until the table is empty, then start the placement phase
local function finishSelection(gameState)
    while not gameState:allTileSourcesEmpty() do
        takeFirstLegal(gameState)
        gameState:incrementTurn()
    end
    perform(gameState, StartPlacementPhaseAction())
    gameState:beginTurn(gameState.startTokenHolder or gameState.startPlayer)
end

--- current player places in the first slot they can, or passes (keeping nothing)
local function placeOrPass(gameState)
    local playerIdx = gameState.currentTurnPlayer
    local player = gameState.players[playerIdx]
    for starIdx, star in ipairs(player.mat.stars) do
        for slotIdx = 1, star:numSlots() do
            if not star:isOccupied(slotIdx) then
                local options = player:generatePlacementPossibilities(starIdx, slotIdx, gameState:getCurrentWildType())
                if #options > 0 then
                    perform(gameState, PlaceTileAction(playerIdx, starIdx, slotIdx, options[1]))
                    return
                end
            end
        end
    end
    perform(gameState, PassAction(playerIdx, {}))
end

local function finishPlacement(gameState)
    while not gameState:allPlayersPassed() do
        placeOrPass(gameState)
        gameState:incrementTurn()
    end
    perform(gameState, EndRoundAction())
end

--- save through json (like a save file) and restore
local function roundTrip(gameState)
    return SaveGame.decode(SaveGame.encode(gameState))
end

local function digest(gameState)
    local parts = { Canonical.encode(gameState:serialize()) }
    for _, action in ipairs(gameState.actionHistory) do
        table.insert(parts, Canonical.encode(action:serialize()))
    end
    return table.concat(parts)
end

--------------------------------------------------------------------------------
-- tests
--------------------------------------------------------------------------------

notion("Canonical.diff finds the first difference and ignores key order", function()
    check(Canonical.diff({ a = 1, b = { 1, 2 } }, { b = { 1, 2 }, a = 1 })).is(nil)
    check(Canonical.diff({ a = 1, b = { 1, 2 } }, { a = 1, b = { 1, 3 } })).is("b.2: 2 ~= 3")
    check(Canonical.diff({ a = 1 }, { a = 1, c = true })).is("c: nil ~= true")
    -- json can turn number keys into strings: not a difference
    check(Canonical.diff({ [1] = "x" }, { ["1"] = "x" })).is(nil)
    check(Canonical.encode({ b = 1, a = 2 })).is(Canonical.encode({ a = 2, b = 1 }))
end)

notion("SaveGame restores a game mid tile selection, undo history included", function()
    local gameState = TestUtil.newGame()
    startRound(gameState)
    takeFirstLegal(gameState)
    gameState:incrementTurn()
    takeFirstLegal(gameState)

    local restored, reason = roundTrip(gameState)
    check(reason).is(nil)
    check(digest(restored)).is(digest(gameState))
    check(restored.turnIdx).is(gameState.turnIdx)
    check(restored.currentTurnPlayer).is(gameState.currentTurnPlayer)
    check(restored:turnStartIndex()).is(gameState:turnStartIndex())

    -- the pick made this turn can be undone in the restored game, exactly as in the original
    check(restored:canUndoChoice()).is(true)
    gameState:undoLastChoice()
    restored:undoLastChoice()
    check(digest(restored)).is(digest(gameState))
    -- the previous turn's pick can't
    check(restored:canUndoChoice()).is(false)

    -- and both games carry on the same way (the rng state was restored too)
    takeFirstLegal(gameState)
    takeFirstLegal(restored)
    check(digest(restored)).is(digest(gameState))
end)

notion("SaveGame restores a game across rounds", function()
    local gameState = TestUtil.newGame()
    startRound(gameState)
    finishSelection(gameState)
    placeOrPass(gameState)
    finishPlacement(gameState)
    check(gameState.round.idx).is(2)
    startRound(gameState)
    takeFirstLegal(gameState)

    local restored, reason = roundTrip(gameState)
    check(reason).is(nil)
    check(digest(restored)).is(digest(gameState))
    check(restored.round.idx).is(2)
end)

notion("SaveGame restores a game during the placement phase, including a pass", function()
    local gameState = TestUtil.newGame()
    startRound(gameState)
    finishSelection(gameState)
    perform(gameState, PassAction(gameState.currentTurnPlayer, {}))

    local restored, reason = roundTrip(gameState)
    check(reason).is(nil)
    check(digest(restored)).is(digest(gameState))
    check(restored.players[restored.currentTurnPlayer].passedForPhase).is(true)
end)

notion("SaveGame rejects saves that don't replay exactly", function()
    local gameState = TestUtil.newGame()
    startRound(gameState)
    takeFirstLegal(gameState)

    -- the snapshot doesn't match the replay
    local data = json.decode(SaveGame.encode(gameState))
    data.snapshot.players[1].score = data.snapshot.players[1].score + 5
    local restored, reason = SaveGame.restore(data)
    check(restored).is(nil)
    check(reason:find("players.1.score", 1, true) ~= nil).is(true)

    -- a different seed draws different tiles
    data = json.decode(SaveGame.encode(gameState))
    data.seed = data.seed + 1
    restored, reason = SaveGame.restore(data)
    check(restored).is(nil)
    check(type(reason)).is("string")

    -- version
    data = json.decode(SaveGame.encode(gameState))
    data.version = 999
    restored, reason = SaveGame.restore(data)
    check(restored).is(nil)
    check(reason:find("version", 1, true) ~= nil).is(true)

    -- unknown action
    data = json.decode(SaveGame.encode(gameState))
    data.history[1].name = "NotAnAction"
    restored, reason = SaveGame.restore(data)
    check(restored).is(nil)
    check(reason:find("NotAnAction", 1, true) ~= nil).is(true)

    -- not json
    restored, reason = SaveGame.decode("{ not json")
    check(restored).is(nil)
    check(type(reason)).is("string")
end)

notion("test/saves/refill_on_next_fill.json loads and its next fill refills the bag", function()
    -- see README "Save / load". Regenerate the save if this fails after a rules/action change
    local text = love.filesystem.read("test/saves/refill_on_next_fill.json")
    check(text ~= nil).is(true)
    local gameState, reason = SaveGame.decode(text)
    check(reason).is(nil)

    local fill = FillFactoryDisplaysAction()
    perform(gameState, fill)
    local refilled = false
    for _, event in ipairs(fill.ctx.events) do
        refilled = refilled or event.refill ~= nil
    end
    check(refilled).is(true)
end)
