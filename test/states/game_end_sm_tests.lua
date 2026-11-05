local cute = require("cloudless_sky.extern.cute")
local GameEndStateMachine = require("cloudless_sky.states.game_end_sm")
local SaveGame = require("cloudless_sky.model.save_game")
local ScoreEndGameAction = require("cloudless_sky.action.score_end_game")
local TestUtil = require("test.test_util")

local STATES = GameEndStateMachine.STATES

notion("GameEndStateMachine.resumePoint: title first, then the next unscored player, then final scores", function()
    local gameState = TestUtil.playToGameEnd(TestUtil.newGame())
    local state, playerIdx = GameEndStateMachine.resumePoint(gameState)
    check(state).is(STATES.TITLE)
    check(playerIdx).is(1)

    gameState:performAction(ScoreEndGameAction(1))
    state, playerIdx = GameEndStateMachine.resumePoint(gameState)
    check(state).is(STATES.PLAYER_INTRO)
    check(playerIdx).is(2)

    gameState:performAction(ScoreEndGameAction(2))
    state, playerIdx = GameEndStateMachine.resumePoint(gameState)
    check(state).is(STATES.FINAL_SCORES)
    check(playerIdx).is(nil)
end)

notion("GameEndStateMachine.standings splits scores and finds the winner", function()
    local gameState = TestUtil.newGame()
    gameState.players[1].score = 30
    gameState.players[1].endGameBonus = 12
    gameState.players[2].score = 25
    gameState.players[2].endGameBonus = 0
    local standings = GameEndStateMachine.standings(gameState)
    check(standings.headline).is("p1 wins!")
    local r1, r2 = standings.rows[1], standings.rows[2]
    check(r1.before .. "+" .. r1.bonus .. "=" .. r1.final).is("18+12=30")
    check(r2.before .. "+" .. r2.bonus .. "=" .. r2.final).is("25+0=25")
    check(r1.winner).is(true)
    check(r2.winner).is(false)
end)

notion("GameEndStateMachine.standings: tied players share the win", function()
    local gameState = TestUtil.newGame()
    gameState.players[1].score = 20
    gameState.players[2].score = 20
    local standings = GameEndStateMachine.standings(gameState)
    check(standings.headline).is("Tie! p1 & p2")
    check(standings.rows[1].winner).is(true)
    check(standings.rows[2].winner).is(true)
end)

notion("test/saves/final_round_last_pass.json loads with one player left to pass in the final round", function()
    -- see README "Save / load". Regenerate the save if this fails after a rules/action change
    local gameState, reason = SaveGame.decode((love.filesystem.read("test/saves/final_round_last_pass.json")))
    check(reason).is(nil)
    check(#gameState.players).is(2)
    check(gameState:isFinalRound()).is(true)
    check(gameState.round.phase).is(gameState.RoundPhase.TILE_PLACEMENT)
    local unpassed = 0
    for _, player in ipairs(gameState.players) do
        if not player.passedForPhase then
            unpassed = unpassed + 1
        end
    end
    check(unpassed).is(1)
    check(gameState.players[gameState.currentTurnPlayer].passedForPhase).is(false)
end)
