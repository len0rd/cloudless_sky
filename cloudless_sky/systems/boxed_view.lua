local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")

---@class BoxedView Utility system for working world-entities that have a bounding box
local BoxedViewSys = Concord.system({
    pool = { Components.names.worldPos, Components.boundingBox },
})

--- Get the center X,Y world coordinates of the provided entity \p e
---@param e Entity. Must have components required by this system
function BoxedViewSys.worldCenter(e)
    local centerX = e.worldPos.x + (e.boundingBox.w / 2)
    local centerY = e.worldPos.y + (e.boundingBox.h / 2)
    return centerX, centerY
end

--- Return true if the provided worldX. worldY coordintate is within entity \p e's bounding box,
--- otherwise false
function BoxedViewSys.worldCoordInEntity(e, worldX, worldY)
    return not (
        worldX < e.worldPos.x
        or worldX > (e.worldPos.x + e.boundingBox.w)
        or worldY < e.worldPos.y
        or worldY > (e.worldPos.y + e.boundingBox.h)
    )
end

--- draw the bounding box of the provided entity
function BoxedViewSys.drawBoundingBox(e)
    local origR, origG, origB, origA = love.graphics.getColor()
    love.graphics.setColor(love.math.colorFromBytes(255, 0, 197))
    love.graphics.rectangle("line", e.worldPos.x, e.worldPos.y, e.boundingBox.w, e.boundingBox.h)
    love.graphics.setColor(origR, origG, origB, origA)
end

return BoxedViewSys
