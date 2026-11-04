local Concord = require("cloudless_sky.extern.concord")
local Components = require("cloudless_sky.components")
local Constants = require("cloudless_sky.constants")

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

--- @return number CenterX, number CenterY, number Scale. The center X,Y of the provided
---     entity in world coordintates. Scale is the max camera scale so the entity \p e
---     occupies the entire screen. Takes hud margin into account
function BoxedViewSys.worldFocus(e)
    local screenW, screenH = love.graphics.getPixelDimensions()

    local maxWidth = screenW * Constants.hudPadPercent
    local maxHeight = screenH * Constants.hudPadPercent
    local widthZoomFactor = maxWidth / e.boundingBox.w
    local heightZoomFactor = maxHeight / e.boundingBox.h

    local eCenterX, eCenterY = BoxedViewSys.worldCenter(e)
    return eCenterX, eCenterY, math.min(widthZoomFactor, heightZoomFactor)
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

--- Put entity \p e (sized in screen pixels) at the world point (worldX, worldY).
--- worldX/Y is top-left corner of it. Becomes bottom-right corner if box would go off screen
--- @param w number screen width
--- @param h number screen height
function BoxedViewSys.placeOnScreenNear(e, worldX, worldY, w, h)
    e.worldPos.x = worldX
    e.worldPos.y = worldY

    -- is this point even in view right now
    if camera:isWorldCoordsInFrame(worldX, worldY) then
        local cameraX, cameraY = camera:cameraCoords(worldX, worldY)
        -- entities placed this way are sized in screen pixels (they draw in screen space), so convert
        -- their size to world units before shifting their world position
        if cameraX + e.boundingBox.w > w then
            e.worldPos.x = e.worldPos.x - e.boundingBox.w / camera.scale
        end
        if cameraY + e.boundingBox.h > h then
            e.worldPos.y = e.worldPos.y - e.boundingBox.h / camera.scale
        end
    end
end

--- draw the bounding box of the provided entity
function BoxedViewSys.drawBoundingBox(e)
    local origR, origG, origB, origA = love.graphics.getColor()
    love.graphics.setColor(love.math.colorFromBytes(255, 0, 197))
    love.graphics.rectangle("line", e.worldPos.x, e.worldPos.y, e.boundingBox.w, e.boundingBox.h)
    love.graphics.setColor(origR, origG, origB, origA)
end

return BoxedViewSys
