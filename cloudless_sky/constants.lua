---@class Constants Table of constant values used across various domains
local Constants = {

    ---@field drawPriority table Priorities for various entities
    drawPriority = {
        playerMat = 50,
        tileScoreAnimations = 47,
        tilePlacePrompt = 44,
        min = 100,
    },

    -- In game, leave 10% of size on each border clear for HUD elements
    hudPadPercent = 0.1,
}

return Constants
