--- What to display when the user clicks on a tile but they dont have enough in their hand to play it
--- TODO: show something..

local Object = require("cloudless_sky.extern.classic")
local PlacePromptInsufficientView = Object:extend()

function PlacePromptInsufficientView:new(tileWorldX, tileWorldY) end

function PlacePromptInsufficientView:close() end

function PlacePromptInsufficientView:mousePressed(worldX, worldY, button, istouch)
    return false
end

function PlacePromptInsufficientView:closing()
    return true
end

function PlacePromptInsufficientView:isClosed()
    return true
end

function PlacePromptInsufficientView:update(dt) end

function PlacePromptInsufficientView:draw() end

function PlacePromptInsufficientView:resize(w, h, tileWorldX, tileWorldY) end

return PlacePromptInsufficientView
