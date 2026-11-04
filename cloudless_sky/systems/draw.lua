--- Drawing system
local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

local DrawSys = Concord.system({
    worldPool = { Components.names.drawable, Components.names.worldPos },
    killCheckPool = { Components.names.drawable, Components.names.worldPos, Components.names.killOffCamera },
    cameraPool = { Components.names.drawable, Components.names.cameraPos },
})

local function sortByPriority(a, b)
    return a.drawable.priority < b.drawable.priority
end

--- filter the given pool down to:
--- Entities that have an update function
---     AND if they have the playerEntity component, its index matches currentPlayerIdx
local function filterPoolForUpdate(pool, currentPlayerIdx)
    local filteredPool = {}
    for _, e in ipairs(pool) do
        if e.update then
            if e.playerEntity then
                if e.playerEntity.idx == currentPlayerIdx then
                    table.insert(filteredPool, e)
                end
            else
                table.insert(filteredPool, e)
            end
        end
    end
    table.sort(filteredPool, sortByPriority)
    return filteredPool
end

function DrawSys:update(dt, gameState)
    --- TODO: go over killCheckPool and see if any entities can be removed from the world

    -- only run update on entites that have an update function and that are tied to the current player
    local filteredWorldPool = filterPoolForUpdate(self.worldPool, gameState.currentTurnPlayer)
    for _, e in ipairs(filteredWorldPool) do
        e:update(dt, gameState)
    end

    -- TODO: add an event for element added/removed to handle resort so its not
    -- done every update
    self.cameraPool:sort(sortByPriority)
    for _, e in ipairs(self.cameraPool) do
        e:update(dt, gameState)
    end
end

function DrawSys:draw(gameState)
    -- ensure entities are priority-sorted

    camera:attach()
    for _, e in ipairs(self.worldPool) do
        if e.draw then
            e:draw(gameState)
        end
    end
    camera:detach()

    -- world entities may also draw in screen space (anchored to a world position, but not
    -- scaled by camera zoom). Used for pixel-font text, which blurs when scaled.
    -- Drawn lowest priority first so higher priority (smaller number) entities end up on top
    local screenDrawers = {}
    for _, e in ipairs(self.worldPool) do
        if e.drawScreen then
            table.insert(screenDrawers, e)
        end
    end
    table.sort(screenDrawers, function(a, b)
        return a.drawable.priority > b.drawable.priority
    end)
    for _, e in ipairs(screenDrawers) do
        e:drawScreen(gameState)
    end

    -- camera pool always has higher priority than world-entities.
    -- pool is sorted by priority (smallest first) in update. Draw in reverse so higher
    -- priority (smaller number) entities end up on top
    for ii = #self.cameraPool, 1, -1 do
        self.cameraPool[ii]:draw(gameState)
    end
end

function DrawSys:resize(w, h, graphicsState)
    --- assume elements that are tied to camera/screen position
    --- care about resizes
    self.cameraPool:sort(sortByPriority)
    for _, e in ipairs(self.cameraPool) do
        e:resize(w, h, graphicsState)
    end
end

return DrawSys
