local ScoreEvent = {}

function ScoreEvent.new(tileType, starIndex, slotIndex, score)
    return {
        tileType = tileType,
        starIdx = starIndex,
        slotIdx = slotIndex,
        score = score,
    }
end

return ScoreEvent
