local cute = require("cloudless_sky.extern.cute")
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local GameRules = require("cloudless_sky.model.game_rules")
local StarType = require("cloudless_sky.model.star_type")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

local MULTI_COLORS = { TileType.RED, TileType.ORANGE, TileType.YELLOW, TileType.GREEN, TileType.BLUE, TileType.PURPLE }

--- @return Player player, table rules. Player 1 of a new game with \p rules (default: base game), and
---     the game's rules
local function newPlayer(rules)
    local gameState = TestUtil.newGame(rules)
    return gameState.players[1], gameState.rules
end

--- Place a tile in every slot of star \p starIdx: \p color, or a different color per slot for MULTI
local function fillStar(player, starIdx, color)
    local star = player.mat:getStar(starIdx)
    for slotIdx = 1, star:numSlots() do
        local tileType = color or MULTI_COLORS[slotIdx]
        assert(player.mat:placeTile(tileType, starIdx, slotIdx) ~= nil)
        assert(star:isOccupied(slotIdx), "couldn't place " .. tileType .. " at " .. starIdx .. "," .. slotIdx)
    end
end

--- Place a tile on every slot of value \p value, except the one at (skipStar, skipSlot)
local function coverValue(player, value, skipStar, skipSlot)
    for starIdx, star in ipairs(player.mat.stars) do
        for slotIdx = 1, star:numSlots() do
            if star:slotIndexToCost(slotIdx) == value and not star:isOccupied(slotIdx) and not (starIdx == skipStar and slotIdx == skipSlot) then
                local tileType = star.starType == StarType.MULTI and MULTI_COLORS[slotIdx] or star.starType
                player.mat:placeTile(tileType, starIdx, slotIdx)
                assert(star:isOccupied(slotIdx))
            end
        end
    end
end

--- @return string bonuses as text, eg: "star:2:RED:14 number:1:4"
local function bonusesText(bonuses)
    local parts = {}
    for _, bonus in ipairs(bonuses) do
        if bonus.kind == EndGameBonus.KIND.STAR then
            table.insert(parts, "star:" .. tostring(bonus.starIdx or "-") .. ":" .. bonus.starType .. ":" .. bonus.points)
        else
            table.insert(parts, "number:" .. bonus.value .. ":" .. bonus.points)
        end
    end
    return table.concat(parts, " ")
end

notion("EndGameBonus: an empty board has no bonuses", function()
    local player, rules = newPlayer()
    local bonuses = EndGameBonus.forPlayer(rules, player)
    check(#bonuses).is(0)
    check(EndGameBonus.total(bonuses)).is(0)
end)

notion("EndGameBonus: a completed colored star scores its color's bonus", function()
    local player, rules = newPlayer()
    -- star 2 is red on the base game mat
    fillStar(player, 2, TileType.RED)
    local bonuses = EndGameBonus.forPlayer(rules, player)
    check(bonusesText(bonuses)).is("star:2:RED:14")
    check(EndGameBonus.total(bonuses)).is(14)
end)

notion("EndGameBonus: a completed multicolor star scores the multi bonus", function()
    local player, rules = newPlayer()
    fillStar(player, 7)
    check(bonusesText(EndGameBonus.forPlayer(rules, player))).is("star:7:MULTI:12")
end)

notion("EndGameBonus: a partly filled star scores nothing", function()
    local player, rules = newPlayer()
    player.mat:placeTile(TileType.RED, 2, 1)
    check(#EndGameBonus.forPlayer(rules, player)).is(0)
end)

notion("EndGameBonus: covering every 1 scores the number bonus, listing every 1 slot", function()
    local player, rules = newPlayer()
    coverValue(player, 1)
    local bonuses = EndGameBonus.forPlayer(rules, player)
    check(bonusesText(bonuses)).is("number:1:4")
    -- one 1 on each of the 7 stars
    check(#bonuses[1].slots).is(7)
    for _, slot in ipairs(bonuses[1].slots) do
        check(player.mat:getStar(slot[1]):slotIndexToCost(slot[2])).is(1)
    end
end)

notion("EndGameBonus: one uncovered 1 means no number bonus", function()
    local player, rules = newPlayer()
    local star = player.mat:getStar(3)
    coverValue(player, 1, 3, star:slotCostToIndex(1))
    check(#EndGameBonus.forPlayer(rules, player)).is(0)
end)

notion("EndGameBonus: a full board scores every star and number bonus", function()
    local player, rules = newPlayer()
    for starIdx, star in ipairs(player.mat.stars) do
        fillStar(player, starIdx, star.starType ~= StarType.MULTI and star.starType or nil)
    end
    local bonuses = EndGameBonus.forPlayer(rules, player)
    check(bonusesText(bonuses)).is(
        "star:1:ORANGE:17 star:2:RED:14 star:3:BLUE:15 star:4:YELLOW:16 star:5:GREEN:18 star:6:PURPLE:20 star:7:MULTI:12"
            .. " number:1:4 number:2:8 number:3:12 number:4:16"
    )
    -- 112 for the stars, 40 for the numbers
    check(EndGameBonus.total(bonuses)).is(152)
end)

notion("EndGameBonus: a completed monochrome (variant) star scores as the color it became", function()
    local player, rules = newPlayer(GameRules.DEFAULTS.BASE_GAME_MONO_RULES)
    check(player.mat:getStar(1).starType).is(StarType.MONO)
    fillStar(player, 1, TileType.PURPLE)
    check(bonusesText(EndGameBonus.forPlayer(rules, player))).is("star:1:PURPLE:20")
end)

notion("EndGameBonus: rules decoded from json (string keys) still score number bonuses", function()
    local player = newPlayer()
    local rules = TestUtil.copyRules()
    rules.endGameBonus.slotCompletion = { ["1"] = 4, ["2"] = 8 }
    coverValue(player, 1)
    check(bonusesText(EndGameBonus.forPlayer(rules, player))).is("number:1:4")
end)

notion("EndGameBonus.reference lists stars by points, then numbers", function()
    local bonuses = EndGameBonus.reference(GameRules.DEFAULTS.BASE_GAME_RULES)
    check(bonusesText(bonuses)).is(
        "star:-:MULTI:12 star:-:RED:14 star:-:BLUE:15 star:-:YELLOW:16 star:-:ORANGE:17 star:-:GREEN:18 star:-:PURPLE:20"
            .. " number:1:4 number:2:8 number:3:12 number:4:16"
    )
end)

notion("EndGameBonus.describe explains a bonus", function()
    check(EndGameBonus.describe({ kind = "star", starType = StarType.RED, points = 14 })).is("Full red star = 14 pts")
    check(EndGameBonus.describe({ kind = "star", starType = StarType.MULTI, points = 12 })).is("Full multicolor star = 12 pts")
    check(EndGameBonus.describe({ kind = "number", value = 1, points = 4 })).is("Every 1 on your board covered = 4 pts")
end)
