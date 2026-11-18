---@class Constants Table of constant values used across various domains
local Constants = {

    ---@field drawPriority table Priorities for various entities
    drawPriority = {
        -- minimum/lowest priority = largest number that can be used to represent priority
        min = 100,

        playerMat = 50,
        tableArea = 50,
        tileScoreAnimations = 47,
        tilePlacePrompt = 44,
        -- the zoomed out view of the whole game: over the world, under the hud
        overview = 30,

        -- hud elements should end up on top
        hudPlayerHand = 20,
        -- modal dialogs are above everything, including the hud
        modal = 10,
    },

    -- In game, leave 10% of size on each border clear for HUD elements
    hudPadPercent = 0.95,
}

return Constants
