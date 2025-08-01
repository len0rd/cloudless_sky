local cute = require("cloudless_sky.extern.cute")
local TileType = require("cloudless_sky.model.tile_type")
local TileBag = require("cloudless_sky.model.tile_bag")
local Player = require("cloudless_sky.model.player")
local GameRules = require("cloudless_sky.model.game_rules")
local PlacementPossibility = require("cloudless_sky.model.placement_possibility")

notion("generatePlacementPossibilities empty table in insufficient tiles", function()
    local player = Player(GameRules.currentRules().playerMat.stars, GameRules.currentRules().startScore, "testeroni")
    -- hand starts off empty
    check(player:generatePlacementPossibilities(1, 1, TileType.PURPLE)).shallowMatches({})
    local slotCost = player.mat:getStar(1):slotIndexToCost(1)
    -- assuming star 1 is a standard type. Give player hand one less tile then necessary to play in slot
    player.hand:addTiles(player.mat:starType(1), slotCost - 1)

    check(player:generatePlacementPossibilities(1, 1, TileType.PURPLE)).shallowMatches({})
end)

notion("generatePlacementPossibilities no wilds", function()
    local player = Player(GameRules.currentRules().playerMat.stars, GameRules.currentRules().startScore, "testeroni")

    local slotCost = player.mat:getStar(1):slotIndexToCost(1)
    local wildTileType = TileType.PURPLE

    -- give one more than the slot cost just to ensure
    player.hand:addTiles(player.mat:starType(1), slotCost + 1)
    check(player:generatePlacementPossibilities(1, 1, wildTileType)).shallowMatches({
        PlacementPossibility(player.mat:starType(1), slotCost, wildTileType, 0),
    })
end)

notion("generatePlacementPossibilities with wilds, all expected combos", function()
    local player = Player(GameRules.currentRules().playerMat.stars, GameRules.currentRules().startScore, "testeroni")

    local STAR = 1
    local SLOT = 1

    local slotCost = player.mat:getStar(STAR):slotIndexToCost(SLOT)
    local wildTileType = TileType.PURPLE
    local baseTileType = player.mat:starType(STAR)

    -- sanity check they arent the same cause if they are this test is useless
    check(wildTileType).isnt(baseTileType)

    player.hand:addTiles(baseTileType, slotCost + 1)
    -- add more wilds than the placement cost to ensure we dont return a possiblity of only wilds
    player.hand:addTiles(wildTileType, slotCost + 1)

    local actualPossibilities = {}

    for baseTileNum = 1, slotCost do
        table.insert(
            actualPossibilities,
            PlacementPossibility(baseTileType, baseTileNum, wildTileType, slotCost - baseTileNum)
        )
    end

    check(player:generatePlacementPossibilities(STAR, SLOT, wildTileType)).shallowMatchesUnordered(actualPossibilities)
end)
