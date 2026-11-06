--- Shared look for UI widgets (suit button colors) so the HUD and menus match
local UiStyle = {}

UiStyle.BUTTON_COLORS = {
    normal = { bg = { 0.25, 0.25, 0.25 }, fg = { 1, 1, 1 } },
    hovered = { bg = { 0.19, 0.6, 0.73 }, fg = { 1, 1, 1 } },
    active = { bg = { 1, 0.6, 0 }, fg = { 1, 1, 1 } },
}
UiStyle.BUTTON_COLORS.hit = UiStyle.BUTTON_COLORS.active

UiStyle.DISABLED_BUTTON_COLORS = {
    normal = { bg = { 0.2, 0.2, 0.2, 0.6 }, fg = { 0.5, 0.5, 0.5, 0.8 } },
}
UiStyle.DISABLED_BUTTON_COLORS.hovered = UiStyle.DISABLED_BUTTON_COLORS.normal
UiStyle.DISABLED_BUTTON_COLORS.active = UiStyle.DISABLED_BUTTON_COLORS.normal
UiStyle.DISABLED_BUTTON_COLORS.hit = UiStyle.DISABLED_BUTTON_COLORS.normal

-- the chosen option in a row of toggle buttons (eg: the New Game menu's player count)
UiStyle.SELECTED_BUTTON_COLORS = {
    normal = { bg = { 0.85, 0.62, 0.15 }, fg = { 1, 1, 1 } },
    hovered = { bg = { 0.95, 0.7, 0.2 }, fg = { 1, 1, 1 } },
    active = { bg = { 1, 0.6, 0 }, fg = { 1, 1, 1 } },
}
UiStyle.SELECTED_BUTTON_COLORS.hit = UiStyle.SELECTED_BUTTON_COLORS.active

UiStyle.PANEL_COLOR = { 0.12, 0.12, 0.18, 0.95 }
UiStyle.TEXT_COLOR = { 1, 1, 1, 1 }
UiStyle.ERROR_TEXT_COLOR = { 0.95, 0.4, 0.4, 1 }

return UiStyle
