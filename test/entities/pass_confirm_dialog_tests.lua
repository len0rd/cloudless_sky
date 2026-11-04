local cute = require("cloudless_sky.extern.cute")
local PassConfirmDialogEntity = require("cloudless_sky.entities.pass_confirm_dialog_entity")
local TileBag = require("cloudless_sky.model.tile_bag")
local TileType = require("cloudless_sky.model.tile_type")

local bagOf = function(counts)
    local bag = TileBag()
    for tileType, count in pairs(counts) do
        bag:addTiles(tileType, count)
    end
    return bag
end

--- @return table TileType -> count from availableForSlot's list
local availableMap = function(hand, slots, slotIdx)
    local result = {}
    for _, entry in ipairs(PassConfirmDialogEntity.availableForSlot(hand, slots, slotIdx)) do
        result[entry.tileType] = entry.count
    end
    return result
end

notion("availableForSlot excludes tiles used by the other slots", function()
    local hand = bagOf({ RED = 6, PURPLE = 2 })
    local slots = { TileType.RED, TileType.RED, TileType.RED, TileType.RED }

    -- slot 4's own red doesn't count against it
    check(availableMap(hand, slots, 4)).shallowMatches({ RED = 3, PURPLE = 2 })

    slots[4] = TileType.PURPLE
    check(availableMap(hand, slots, 1)).shallowMatches({ RED = 4, PURPLE = 1 })

    -- all purples used by other slots: purple isn't offered
    slots[3] = TileType.PURPLE
    check(availableMap(hand, slots, 1)).shallowMatches({ RED = 5 })
end)

notion("availableForSlot treats empty slots as unused and lists in TileType order", function()
    local hand = bagOf({ PURPLE = 1, RED = 1, GREEN = 2 })
    local available = PassConfirmDialogEntity.availableForSlot(hand, { false, false, TileType.GREEN, false }, 1)
    local order = {}
    for ii, entry in ipairs(available) do
        order[ii] = entry.tileType
    end
    check(order).shallowMatches({ TileType.RED, TileType.GREEN, TileType.PURPLE })
end)

notion("slotsToKeep counts filled slots", function()
    check(PassConfirmDialogEntity.slotsToKeep({ TileType.RED, false, TileType.RED, TileType.BLUE })).shallowMatches({
        RED = 2,
        BLUE = 1,
    })
    check(PassConfirmDialogEntity.slotsToKeep({ false, false })).shallowMatches({})
    check(PassConfirmDialogEntity.slotsToKeep({})).shallowMatches({})
end)
