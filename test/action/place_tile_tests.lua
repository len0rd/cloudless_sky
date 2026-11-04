local cute = require("cloudless_sky.extern.cute")
local Action = require("cloudless_sky.action.action")
local AddScoreAction = require("cloudless_sky.action.add_score")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local GameRules = require("cloudless_sky.model.game_rules")
local GameState = require("cloudless_sky.model.game_state")
local PlacementPossibility = require("cloudless_sky.model.placement_possibility")
local TileType = require("cloudless_sky.model.tile_type")

-- star indices/costs on the default (base game) mat. See GameRules.DEFAULTS.BASE_GAME_RULES
local RED_STAR = 2 -- costs { 5, 6, 1, 2, 3, 4 }
local PURPLE_STAR = 6 -- costs { 1, 2, 3, 4, 5, 6 }
local MULTI_STAR = 7 -- costs { 1, 2, 3, 4, 5, 6 }

local P1 = 1

local newGame = function()
    return GameState(GameRules.currentRules(), { "p1", "p2" })
end

--- @return string snapshot of all state a PlaceTileAction may touch for player 1
local snapshot = function(gameState)
    local player = gameState.players[P1]
    local parts = { "score=" .. player.score }
    for _, tileType in ipairs(TileType.ORDERED) do
        table.insert(parts, "hand." .. tileType .. "=" .. player.hand:num(tileType))
        table.insert(parts, "discard." .. tileType .. "=" .. gameState.discard:num(tileType))
    end
    for starIdx, star in ipairs(player.mat.stars) do
        for slotIdx = 1, star:numSlots() do
            table.insert(parts, starIdx .. "." .. slotIdx .. "=" .. tostring(star:tileAtSlot(slotIdx)))
        end
    end
    table.insert(parts, "history=" .. #gameState.actionHistory)
    return table.concat(parts, ",")
end

--- place a tile on the purple star paying entirely in purple
local placePurple = function(gameState, slotIdx)
    local cost = gameState.players[P1].mat:getStar(PURPLE_STAR):slotIndexToCost(slotIdx)
    gameState.players[P1].hand:addTiles(TileType.PURPLE, cost)
    local action = PlaceTileAction(P1, PURPLE_STAR, slotIdx, PlacementPossibility(TileType.PURPLE, cost))
    gameState:performAction(action)
    return action
end

notion("PlaceTile no wilds: pays from hand, rest of payment to tower, fills slot", function()
    local gameState = newGame()
    local player = gameState.players[P1]
    player.hand:addTiles(TileType.RED, 7)

    -- RED star slot 1 costs 5
    local action = PlaceTileAction(P1, RED_STAR, 1, PlacementPossibility(TileType.RED, 5, TileType.PURPLE, 0))
    action:perform(gameState)

    check(player.hand:num(TileType.RED)).is(2)
    check(gameState.discard:num(TileType.RED)).is(4)
    check(gameState.discard:total()).is(4)
    check(player.mat:getStar(RED_STAR):tileAtSlot(1)).is(TileType.RED)
    check(action.score).is(1)
end)

notion("PlaceTile with wilds: wilds and extra color tiles go to tower", function()
    local gameState = newGame()
    local player = gameState.players[P1]
    player.hand:addTiles(TileType.RED, 2)
    player.hand:addTiles(TileType.PURPLE, 4)

    -- RED star slot 1 costs 5: 2 red + 3 purple wilds
    local action = PlaceTileAction(P1, RED_STAR, 1, PlacementPossibility(TileType.RED, 2, TileType.PURPLE, 3))
    action:perform(gameState)

    check(player.hand:num(TileType.RED)).is(0)
    check(player.hand:num(TileType.PURPLE)).is(1)
    check(gameState.discard:num(TileType.RED)).is(1)
    check(gameState.discard:num(TileType.PURPLE)).is(3)
    -- the placed tile is the star's color, never the wild
    check(player.mat:getStar(RED_STAR):tileAtSlot(1)).is(TileType.RED)
end)

notion("PlaceTile scores adjacency within the star", function()
    local gameState = newGame()
    -- lone tile: 1 point (rulebook example B)
    check(placePurple(gameState, 1).score).is(1)
    -- next to 1 tile: 2 points
    check(placePurple(gameState, 2).score).is(2)
    -- next to a run of 2: 3 points (rulebook example C)
    check(placePurple(gameState, 3).score).is(3)
    -- slot 6 neighbours slot 1 (star wraps around): run 6,1,2,3 = 4 points
    check(placePurple(gameState, 6).score).is(4)
    -- slot 5 joins 6,1,2,3: 5 points
    check(placePurple(gameState, 5).score).is(5)
    -- last slot completes the star: 6 points
    check(placePurple(gameState, 4).score).is(6)
end)

notion("PlaceTile does not connect tiles across different stars", function()
    local gameState = newGame()
    placePurple(gameState, 1)
    local player = gameState.players[P1]
    player.hand:addTiles(TileType.RED, 1)
    -- RED star slot 3 costs 1
    local action = PlaceTileAction(P1, RED_STAR, 3, PlacementPossibility(TileType.RED, 1))
    gameState:performAction(action)
    check(action.score).is(1)
end)

notion("performAction records PlaceTile then AddScore and updates score", function()
    local gameState = newGame()
    local startScore = gameState.players[P1].score
    placePurple(gameState, 1)
    gameState.players[P1].hand:addTiles(TileType.PURPLE, 2)
    local performed =
        gameState:performAction(PlaceTileAction(P1, PURPLE_STAR, 2, PlacementPossibility(TileType.PURPLE, 2)))

    check(#performed).is(2)
    check(performed[1].name).is("PlaceTile")
    check(performed[2].name).is("AddScore")
    check(performed[2].ctx.score).is(2)

    -- history contains both placements and both scores, in order
    check(#gameState.actionHistory).is(4)
    check(gameState.actionHistory[1].name).is("PlaceTile")
    check(gameState.actionHistory[2].name).is("AddScore")
    -- same action instances are recorded (check identity; cute's .is doesnt compare tables)
    check(gameState.actionHistory[3] == performed[1]).is(true)
    check(gameState.actionHistory[4] == performed[2]).is(true)

    check(gameState.players[P1].score).is(startScore + 1 + 2)
end)

notion("PlaceTile invalid placements fail validation and leave state unchanged", function()
    local gameState = newGame()
    local player = gameState.players[P1]
    placePurple(gameState, 1)
    player.hand:addTiles(TileType.RED, 3)
    player.hand:addTiles(TileType.ORANGE, 6)
    player.hand:addTiles(TileType.PURPLE, 6)

    local invalid = {
        -- not enough red in hand (RED slot 2 costs 6)
        PlaceTileAction(P1, RED_STAR, 2, PlacementPossibility(TileType.RED, 6)),
        -- slot already occupied
        PlaceTileAction(P1, PURPLE_STAR, 1, PlacementPossibility(TileType.PURPLE, 1)),
        -- wrong color for star (RED slot 3 costs 1)
        PlaceTileAction(P1, RED_STAR, 3, PlacementPossibility(TileType.ORANGE, 1)),
        -- payment doesnt match cost (RED slot 3 costs 1)
        PlaceTileAction(P1, RED_STAR, 3, PlacementPossibility(TileType.RED, 2)),
        -- no tile of the placed color, only wilds (RED slot 4 costs 2)
        PlaceTileAction(P1, RED_STAR, 4, PlacementPossibility(TileType.RED, 0, TileType.PURPLE, 2)),
        -- wild substituting for its own color (PURPLE slot 3 costs 3)
        PlaceTileAction(P1, PURPLE_STAR, 3, PlacementPossibility(TileType.PURPLE, 1, TileType.PURPLE, 2)),
        -- not enough wilds in hand (RED slot 1 costs 5. round 1 wild is PURPLE)
        PlaceTileAction(P1, RED_STAR, 1, PlacementPossibility(TileType.RED, 1, TileType.PURPLE, 7)),
        -- wilds that aren't this round's wild color (RED slot 1 costs 5. ORANGE isn't wild in round 1)
        PlaceTileAction(P1, RED_STAR, 1, PlacementPossibility(TileType.RED, 1, TileType.ORANGE, 4)),
        -- bad indices
        PlaceTileAction(P1, 99, 1, PlacementPossibility(TileType.RED, 1)),
        PlaceTileAction(P1, RED_STAR, 99, PlacementPossibility(TileType.RED, 1)),
    }

    local before = snapshot(gameState)
    for ii, action in ipairs(invalid) do
        local valid = action:validate(gameState)
        check(valid).is(false)
        -- performAction rejects without raising (raising would trip debugger break-on-error,
        -- even inside pcall)
        local performed, reason = gameState:performAction(action)
        if performed ~= nil then
            error("invalid placement #" .. ii .. " was performed")
        end
        check(type(reason)).is("string")
        check(snapshot(gameState)).is(before)
    end
end)

notion("PlaceTile undo restores hand, tower, mat and score", function()
    local gameState = newGame()
    local player = gameState.players[P1]
    placePurple(gameState, 1)
    player.hand:addTiles(TileType.RED, 3)
    player.hand:addTiles(TileType.PURPLE, 3)

    local before = snapshot(gameState)
    -- RED slot 1 costs 5: 2 red + 3 purple wilds
    gameState:performAction(PlaceTileAction(P1, RED_STAR, 1, PlacementPossibility(TileType.RED, 2, TileType.PURPLE, 3)))
    check(snapshot(gameState)).isnt(before)

    check(gameState:undoLastAction().name).is("AddScore")
    check(gameState:undoLastAction().name).is("PlaceTile")
    check(snapshot(gameState)).is(before)
    check(player:isSlotOccupied(RED_STAR, 1)).is(false)
end)

notion("PlaceTile on MULTI star allows each color only once", function()
    local gameState = newGame()
    local player = gameState.players[P1]
    player.hand:addTiles(TileType.RED, 3)

    -- MULTI slot 1 costs 1, slot 2 costs 2
    gameState:performAction(PlaceTileAction(P1, MULTI_STAR, 1, PlacementPossibility(TileType.RED, 1)))
    check(player.mat:getStar(MULTI_STAR):tileAtSlot(1)).is(TileType.RED)

    local second = PlaceTileAction(P1, MULTI_STAR, 2, PlacementPossibility(TileType.RED, 2))
    check(second:validate(gameState)).is(false)

    -- undoing the first red frees the color again
    gameState:undoLastAction()
    gameState:undoLastAction()
    check(second:validate(gameState)).is(true)
end)

notion("PlaceTileAction serialize/deserialize roundtrip", function()
    local action = PlaceTileAction(P1, RED_STAR, 1, PlacementPossibility(TileType.RED, 2, TileType.PURPLE, 3))
    local restored = Action.deserialize(action:serialize())
    check(restored.name).is("PlaceTile")
    check(restored.ctx.playerIdx).is(P1)
    check(restored.ctx.starIdx).is(RED_STAR)
    check(restored.ctx.slotIdx).is(1)
    check(restored.ctx.placement).shallowMatches(action.ctx.placement)
end)
