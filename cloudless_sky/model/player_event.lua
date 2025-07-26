local PlayerEvent = {}

function PlayerEvent.new(type, data)
    return {
        type = type,
        data = data,
        ts = os.time(),
    }
end

return PlayerEvent
