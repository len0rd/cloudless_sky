local cute = require("cloudless_sky.extern.cute")
local EndGameBonus = require("cloudless_sky.model.end_game_bonus")
local Invariants = require("cloudless_sky.model.invariants")
local SaveGame = require("cloudless_sky.model.save_game")
local ScoreEndGameAction = require("cloudless_sky.action.score_end_game")
local TileType = require("cloudless_sky.model.tile_type")
local TestUtil = require("test.test_util")

local P1 = 1
local P2 = 2

--- @return GameState a game played to the end (not yet scored)
local function finishedGame()
    return TestUtil.playToGameEnd(TestUtil.newGame())
end

notion("ScoreEndGame can't score before the game is over", function()
    local gameState = TestUtil.newGame()
    local performed, reason = gameState:performAction(ScoreEndGameAction(P1))
    check(performed).is(nil)
    check(reason).is("the game isn't over yet")
    check(gameState.players[P1].endGameBonus).is(nil)
end)

notion("ScoreEndGame scores a player's bonuses once", function()
    local gameState = finishedGame()
    check(gameState:isGameScored()).is(false)

    local player = gameState.players[P1]
    local expected = EndGameBonus.forPlayer(gameState.rules, player)
    local score = player.score

    local performed = gameState:performAction(ScoreEndGameAction(P1))
    check(performed ~= nil).is(true)
    local action = performed[1]
    check(action.ctx.total).is(EndGameBonus.total(expected))
    check(#action.ctx.bonuses).is(#expected)
    check(player.endGameBonus).is(action.ctx.total)
    check(player.score).is(score + action.ctx.total)
    if action.ctx.total > 0 then
        check(performed[2].name).is("AddScore")
        check(performed[2].isFollowUp).is(true)
    end

    -- only once
    local again, reason = gameState:performAction(ScoreEndGameAction(P1))
    check(again).is(nil)
    check(reason).is("player 1 has already been scored")
    check(gameState:performAction(ScoreEndGameAction(99))).is(nil)

    check(gameState:isGameScored()).is(false)
    gameState:performAction(ScoreEndGameAction(P2))
    check(gameState:isGameScored()).is(true)
    check(#Invariants.check(gameState)).is(0)
end)

notion("ScoreEndGame adds its bonus total as a follow-up, and undo restores the player", function()
    local gameState = finishedGame()
    local player = gameState.players[P1]
    -- a known bonus regardless of how the game went: fill the multicolor star (7) where it's empty
    local star = player.mat:getStar(7)
    local colors = { TileType.RED, TileType.ORANGE, TileType.YELLOW, TileType.GREEN, TileType.BLUE, TileType.PURPLE }
    for slotIdx = 1, star:numSlots() do
        if not star:isOccupied(slotIdx) then
            for _, color in ipairs(colors) do
                player.mat:placeTile(color, 7, slotIdx)
                if star:isOccupied(slotIdx) then
                    break
                end
            end
        end
    end
    check(star:isFull()).is(true)
    local score = player.score

    local performed = gameState:performAction(ScoreEndGameAction(P1))
    local total = performed[1].ctx.total
    check(total >= 12).is(true)
    check(player.score).is(score + total)

    -- the bonus and its AddScore follow-up undo together
    gameState:undoLastAction()
    gameState:undoLastAction()
    check(player.score).is(score)
    check(player.endGameBonus).is(nil)
end)

notion("ScoreEndGame is a barrier: players can't undo final scoring", function()
    local gameState = finishedGame()
    gameState:performAction(ScoreEndGameAction(P1))
    check(gameState:canUndoChoice()).is(false)
    check(gameState:undoLastChoice()).is(nil)
end)

notion("ScoreEndGame with no bonuses scores 0 without an AddScore", function()
    local gameState = TestUtil.newGame()
    -- end of the game without playing: final round, everyone passed, empty boards
    gameState.round.idx = #gameState.rules.wildPerRound
    for _, player in ipairs(gameState.players) do
        player.passedForPhase = true
    end
    local score = gameState.players[P2].score
    local performed = gameState:performAction(ScoreEndGameAction(P2))
    check(#performed).is(1)
    check(performed[1].ctx.total).is(0)
    check(gameState.players[P2].endGameBonus).is(0)
    check(gameState.players[P2].score).is(score)
end)

notion("ScoreEndGame survives a save and load", function()
    local gameState = finishedGame()
    gameState:performAction(ScoreEndGameAction(P1))

    local restored, reason = SaveGame.decode(SaveGame.encode(gameState))
    check(reason).is(nil)
    check(restored.players[P1].endGameBonus).is(gameState.players[P1].endGameBonus)
    check(restored.players[P1].score).is(gameState.players[P1].score)
    check(restored.players[P2].endGameBonus).is(nil)

    -- and the restored game carries on to the same result
    restored:performAction(ScoreEndGameAction(P2))
    gameState:performAction(ScoreEndGameAction(P2))
    check(restored.players[P2].score).is(gameState.players[P2].score)
    check(restored:isGameScored()).is(true)
end)

notion("Invariants: end-game bonuses can't be scored before the game is over", function()
    local gameState = TestUtil.newGame()
    gameState.players[P1].endGameBonus = 0
    local failures = Invariants.check(gameState)
    check(#failures).is(1)
    check(failures[1]).is("player 1 has end-game bonuses scored before the game is over")
end)
