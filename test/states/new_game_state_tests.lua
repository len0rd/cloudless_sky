local cute = require("cloudless_sky.extern.cute")
local NewGameState = require("cloudless_sky.states.new_game_state")

notion("NewGameState.playerNames trims, fills blanks with Player N, and gives exactly count names", function()
    local names = NewGameState.playerNames({ "  Ada ", "", "   ", "Bo" }, 3)
    check(#names).is(3)
    check(names[1]).is("Ada")
    check(names[2]).is("Player 2")
    check(names[3]).is("Player 3")
    -- missing boxes count as blank
    check(NewGameState.playerNames({ "x" }, 2)[2]).is("Player 2")
end)

notion("NewGameState names are capped at MAX_NAME_LENGTH characters", function()
    local long = string.rep("a", 30)
    check(#NewGameState.playerNames({ long, "b" }, 2)[1]).is(NewGameState.MAX_NAME_LENGTH)
    local full = string.rep("b", NewGameState.MAX_NAME_LENGTH)
    check(NewGameState.appendText(full, "c")).is(full)
    check(NewGameState.appendText("ab", "c")).is("abc")
    -- multi-byte characters count once and aren't cut in half
    local accents = string.rep("é", NewGameState.MAX_NAME_LENGTH)
    check(NewGameState.appendText(accents, "é")).is(accents)
end)

notion("NewGameState.backspace removes one character", function()
    check(NewGameState.backspace("abc")).is("ab")
    check(NewGameState.backspace("")).is("")
    check(NewGameState.backspace("aé")).is("a")
end)

notion("NewGameState layout fits the window for 2-4 players", function()
    for _, size in ipairs({ { 1280, 720 }, { 800, 600 }, { 1920, 1080 } }) do
        local w, h = size[1], size[2]
        for count = 2, 4 do
            local L = NewGameState.layout(w, h, count)
            local p = L.panel
            check(p.x >= 0 and p.x + p.w <= w and p.y + p.h <= h).is(true)
            check(L.title.y + L.title.h <= p.y).is(true)
            check(#L.names).is(count)
            -- every control inside the panel, rows not overlapping
            local lastBottom = p.y
            for _, row in ipairs({ L.players, L.names[1], L.names[count], L.preset }) do
                check(row.label.y >= lastBottom).is(true)
                lastBottom = row.label.y + row.label.h
                for _, r in ipairs(row) do
                    check(r.x >= p.x and r.x + r.w <= p.x + p.w).is(true)
                end
            end
            check(L.start.y >= lastBottom and L.start.y + L.start.h <= p.y + p.h).is(true)
            check(L.back.x + L.back.w < L.start.x).is(true)
        end
    end
end)
