--- Things that must always be true about a GameState, no matter what actions have been performed.
--- Used by the bot (cloudless_sky/bot/bot.lua) every frame and by unit tests
local TileType = require("cloudless_sky.model.tile_type")
local Player = require("cloudless_sky.model.player")

local Invariants = {}

--- @return integer number of tiles a game with \p rules has in total (GameState puts the same number
---     of each color in the bag)
function Invariants.expectedTileTotal(rules)
    return math.floor(rules.totalTiles / #TileType.ORDERED) * #TileType.ORDERED
end

--- @return table TileType -> number of tiles of each color placed on \p player's mat
local function matTileCounts(player)
    local counts = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        counts[tileType] = 0
    end
    for _, star in ipairs(player.mat.stars) do
        for slotIdx = 1, star:numSlots() do
            if star:isOccupied(slotIdx) then
                local tileType = star:tileAtSlot(slotIdx)
                counts[tileType] = counts[tileType] + 1
            end
        end
    end
    return counts
end

--- Check every invariant
--- @param gameState GameState
--- @return string[] failures description of each broken invariant. Empty if all hold
function Invariants.check(gameState)
    local failures = {}
    local fail = function(msg)
        table.insert(failures, msg)
    end

    -- every tile is somewhere, and nowhere has a negative count
    local bags = {
        { "bag", gameState.tileBag },
        { "tower", gameState.discard },
        { "center", gameState.center },
    }
    for ii, display in ipairs(gameState.factoryDisplays) do
        table.insert(bags, { "display " .. ii, display })
    end
    for ii, player in ipairs(gameState.players) do
        table.insert(bags, { "player " .. ii .. " hand", player.hand })
    end
    local perType = {}
    for _, tileType in ipairs(TileType.ORDERED) do
        perType[tileType] = 0
    end
    for _, entry in ipairs(bags) do
        for _, tileType in ipairs(TileType.ORDERED) do
            local count = entry[2]:num(tileType)
            if count < 0 or count ~= math.floor(count) then
                fail(entry[1] .. " has " .. tostring(count) .. " " .. tileType)
            end
            perType[tileType] = perType[tileType] + count
        end
    end
    for _, player in ipairs(gameState.players) do
        for tileType, count in pairs(matTileCounts(player)) do
            perType[tileType] = perType[tileType] + count
        end
    end
    local perTypeExpected = Invariants.expectedTileTotal(gameState.rules) / #TileType.ORDERED
    for _, tileType in ipairs(TileType.ORDERED) do
        if perType[tileType] ~= perTypeExpected then
            fail(tileType .. " tiles total " .. perType[tileType] .. ", expected " .. perTypeExpected)
        end
    end

    -- scores: penalties can't go below the floor, and nothing else takes points away
    for ii, player in ipairs(gameState.players) do
        if player.score < Player.MIN_SCORE_AFTER_PENALTY then
            fail("player " .. ii .. " score " .. player.score .. " is below " .. Player.MIN_SCORE_AFTER_PENALTY)
        end
    end

    -- turn/round bookkeeping
    if not gameState.players[gameState.currentTurnPlayer] then
        fail("currentTurnPlayer " .. tostring(gameState.currentTurnPlayer) .. " is not a player")
    end
    if not gameState.players[gameState.startPlayer] then
        fail("startPlayer " .. tostring(gameState.startPlayer) .. " is not a player")
    end
    if gameState.startTokenHolder ~= nil and not gameState.players[gameState.startTokenHolder] then
        fail("startTokenHolder " .. tostring(gameState.startTokenHolder) .. " is not a player")
    end
    local numRounds = #gameState.rules.wildPerRound
    if gameState.round.idx < 1 or gameState.round.idx > numRounds then
        fail("round " .. tostring(gameState.round.idx) .. " is outside 1.." .. numRounds)
    end
    if gameState.turnHistoryStart < 0 or gameState.turnHistoryStart > #gameState.actionHistory then
        fail("turnHistoryStart " .. gameState.turnHistoryStart .. " is outside the action history")
    end

    -- phase rules
    if gameState.round.phase == gameState.RoundPhase.TILE_PLACEMENT then
        if not gameState:allTileSourcesEmpty() then
            fail("tiles are left on the table during the placement phase")
        end
    else
        for ii, player in ipairs(gameState.players) do
            if player.passedForPhase then
                fail("player " .. ii .. " has passed during the selection phase")
            end
        end
    end

    return failures
end

return Invariants
