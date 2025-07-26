-- represents a single star on a player board
--
--- Throughout the Star code, arrays for tile slots in the star
--- start with the top of the star (when looking at a board face up),
--- then proceed clockwise around the star.
---
--- So the indicies are like this:
---             /\
---            / \
---     ______/ 1 \______
---     \     \  /     /
---      \  6 \/   2 /
---       -----------
---      /    /\    \
---     / 5  / \  3 \
---    -----/ 4 \----
---         \  /
---          \/
local Object = require("cloudless_sky.extern.classic")
local Star = Object:extend()
local StarType = require("cloudless_sky.model.star_type")
local TileType = require("cloudless_sky.model.tile_type")

-- default Slot Color Order for the central multi_static star on the blue side
-- of the Glazed Pavilion mat
Star.GLAZED_PAVILION_BLUE_SIDE_MULTI_STATIC_COLORS = {
    TileType.PURPLE,
    TileType.GREEN,
    TileType.ORANGE,
    TileType.YELLOW,
    TileType.BLUE,
    TileType.RED,
}

-- default Slot Color Order for the central multi_static star on the purple side
-- of the Glazed Pavilion mat
Star.GLAZED_PAVILION_PURPLE_SIDE_MULTI_STATIC_COLORS = {
    TileType.ORANGE,
    TileType.RED,
    TileType.BLUE,
    TileType.YELLOW,
    TileType.GREEN,
    TileType.PURPLE,
}

--- @param starConf table Table to configure this star with the following fields:
---     {
---         type: @ref StarType. what type of star this is
---         cost: table of tile costs for each slots
---         color: [OPTIONAL], for MULTI_STATIC type this needs to define the required tile color for each slot
---     }
function Star:new(starConf)
    self.starType = starConf.type
    self.starTypeOnConstruction = starConf.type
    if StarType[starConf.type] == nil then
        StarType.emitBadStarTypeError(starConf.type)
    end

    self.slotCostOrder = starConf.cost
    if self.slotCostOrder == nil then
        error(
            "StarType '" .. tostring(starConf.type) .. "' does not have a default slotCostOrder. You must specify one"
        )
    end
    -- for StarType.MULTI_STATIC
    self.slotColorOrder = starConf.color
    if self.starType == StarType.MULTI_STATIC and starConf.color == nil then
        error("StarType '" .. tostring(self.starType) .. "' must be provided starConf.color")
    end
    -- hijack slotColorOrder to keep track of placed tile colors for StarType.MULTI
    -- (need to enforce having a color only once)
    if self.starType == StarType.MULTI or self.slotColorOrder == nil then
        self.slotColorOrder = {}
        -- just set the array to a random tile color. Elements in the array are only valid
        -- if self.occupiedSlots[ii] is true
        for ii = 1, #self.slotCostOrder do
            self.slotColorOrder[ii] = ""
        end
    end
    -- true if a slot is occupied by a tile, otherwise false. indicies in clockwise order
    self.occupiedSlots = {}
    for ii = 1, #self.slotCostOrder do
        self.occupiedSlots[ii] = false
    end
end

--- Return a table that can be used to serialize state information about this star that is NOT already
--- contained in the current GameRules
function Star:serialize()
    local serialized = {}
    if self:isNonBasicType() then
        serialized.color = self.slotColorOrder
    end
    serialized.occupied = self.occupiedSlots
    return serialized
end

--- Deserialize state information not contained in the GameRules/passed in the constructor
function Star:deserialize(data)
    if data.color ~= nil then
        self.slotColorOrder = data.color
    end
    self.occupiedSlots = data.occupied
end

function Star:numSlots()
    return #self.slotCostOrder
end

--- If the starType is not also a TileType (ie: RED), then its "non-standard" and probably
--- requires some degree of special handling
function Star:isNonBasicType()
    return TileType[self.starType] == nil
end

function Star:numOccupied()
    local numOccupied = 0
    for _, occupied in ipairs(self.occupiedSlots) do
        if occupied then
            numOccupied = numOccupied + 1
        end
    end
    return numOccupied
end

--- @return boolean occupied. True if the given slot is valid and occupied. Otherwise false
function Star:isOccupied(slotIdx)
    return self.occupiedSlots[slotIdx] ~= nil and self.occupiedSlots[slotIdx]
end

--- Get the TileType that is in the given slot index. Only valid if the slotIndex is valid and occupied (can be checked with isOccupied)
--- @return TileType occupyingTile or empty string if the slot is not occupied or slotIndex is out of bounds
function Star:tileAtSlot(slotIdx)
    if self:isOccupied(slotIdx) then
        return self.slotColorOrder[slotIdx]
    end
    return ""
end

function Star:isFull()
    return self:numOccupied() == self:numSlots()
end

function Star:isEmpty()
    return self:numOccupied() == 0
end

--- Get the cost of the slot at the index
function Star:slotIndexToCost(slotIdx)
    if slotIdx >= 1 and slotIdx <= #self.slotCostOrder then
        return self.slotCostOrder[slotIdx]
    end
    return 0
end

--- Get the first slot index with the given slotCost. Returns 0 if no slots have that cost
function Star:slotCostToIndex(slotCost)
    for ii, cost in ipairs(self.slotCostOrder) do
        if cost == slotCost then
            return ii
        end
    end
    return 0
end

--- @return boolean Present. True if the given slotCost exists somewhere on this
---     star, otherwise false. Slot occupation not considered here
function Star:hasSlotCost(slotCost)
    for _, cost in ipairs(self.slotCostOrder) do
        if cost == slotCost then
            return true
        end
    end
    return false
end

--- Check if the slot of cost slotCost has a tile on it
--- @param slotCost integer 6 to check if the slot of cost 6 is covered
--- @return boolean True if ALL slots of the given cost are covered, otherwise false
---     (note some stars can have multiple slots at the same cost).
---     If the star has NO slots of cost \p slotCost, then return false
function Star:isSlotOfCostCovered(slotCost)
    local slotsOfCostCovered = true
    local slotCostExists = false
    for ii, cost in ipairs(self.slotCostOrder) do
        if cost == slotCost then
            slotsOfCostCovered = self.occupiedSlots[ii] and slotsOfCostCovered
            slotCostExists = true
        end
    end
    return slotsOfCostCovered and slotCostExists
end

--- Check if the given tileType would be allowed in this star at slotIndex
--- @return boolean True if the tileType is allowed in the given slot index
---         Will return FALSE if the tileType is allowed, but the slot is occupied
function Star:isTileTypeAllowedInSlot(tileType, slotIdx)
    if slotIdx < 1 or slotIdx > #self.slotCostOrder then
        return false
    end
    if self.starType == StarType.MONO then
        -- MONO star type is updated to the correct color as soon as the
        -- first tile is placed. So if type is still MONO, any tile may be placed
        return true
    elseif self.starType == StarType.MULTI_STATIC then
        -- MULTI_STATIC must have slotColorOrder defined
        -- tile can be placed if the slot is not occupied and its color matches the tile
        return not self.occupiedSlots[slotIdx] and self.slotColorOrder[slotIdx] == tileType
    elseif self.starType == StarType.MULTI then
        -- in multi stars you can only have a color occur once
        if not self.occupiedSlots[slotIdx] then
            for ii, occupiedType in ipairs(self.slotColorOrder) do
                if self.occupiedSlots[ii] and occupiedType == tileType then
                    -- cant have 2 of the same tileColor
                    return false
                end
            end
            return true
        else
            -- slot is already occupied
            return false
        end
    else
        -- assuming this is a normal colored star
        return self.starType == tileType and not self.occupiedSlots[slotIdx]
    end
end

--- Return a list of possible spots the number of tileTypes could be placed on the board
--- For example:
---     - If this star is StarType.RED with no slots occupied
---     - If tileType == TileType.RED and count == 3
---     The you could afford the slots that cost 1, 2 or 3 tiles.
---     In the default RED star these indicies would be {3,4,5} <- return value
--- @param tileType TileType the type of tiles to check placement options for
--- @param count integer how many \p tileType tiles you have
--- @return table An ordered list from {min,max} of the slot indicies the given type+count could occupy
function Star:possiblePlacements(tileType, count)
    local placements = {}
    for ii, cost in ipairs(self.slotCostOrder) do
        if cost <= count and self:isTileTypeAllowedInSlot(tileType, ii) then
            table.insert(placements, ii)
        end
    end
    table.sort(placements)
    return placements
end

--- @return integer How many points you would get for placing a tile at \p slotIndex
---     This essetially just calculates the adjacency bonus
---     Returns 0 if the index is out of bounds. DOES NOT CHECK IF SLOT IS ALREADY OCCUPIED
function Star:possibleScoreForPlacement(slotIndex)
    if slotIndex < 1 or slotIndex > #self.slotCostOrder then
        return 0
    end
    -- 1pt for placing the tile
    local score = 1
    -- do a full check as below scoring assumes theres a break in adjacency somewhere
    if self:isFull() then
        return #self.occupiedSlots
    end

    -- check adjacency bonus by iterating in both directions from the start slot
    local n = #self.occupiedSlots
    local upIndex = slotIndex % n + 1
    local downIndex = ((slotIndex - 2 + n) % n) + 1

    -- Check upwards (clockwise)
    local idx = upIndex
    while idx ~= slotIndex do
        if self.occupiedSlots[idx] then
            score = score + 1
            idx = idx % n + 1
        else
            break
        end
    end

    -- Check downwards (counter-clockwise)
    idx = downIndex
    while idx ~= slotIndex do
        if self.occupiedSlots[idx] then
            score = score + 1
            idx = ((idx - 2 + n) % n) + 1
        else
            break
        end
    end

    return score
end

--- Remove a tile from the given slot if its occupied
--- This effectively rolls back any state changes on the Star.
--- Notably if the Star was previously MONO, and all tiles are
--- removed, StarType will revert to MONO
--- Since tallying scores is not tracked here, higher levels are responsible for
--- subtracting whatever was added when the tile was placed
function Star:removeTile(slotIndex)
    if slotIndex < 1 or slotIndex > #self.slotCostOrder then
        print("removeTile: bad slotIndex" .. slotIndex)
    end
    self.occupiedSlots[slotIndex] = false
    if self:isEmpty() and self.starTypeOnConstruction == StarType.MONO then
        self.starType = StarType.MONO
    end
    -- revert star color assignment just to be overly cautious
    self.starColorOrder[slotIndex] = ""
end

--- Place a tile on this star in the specified slot
--- @return integer Score. Number of points placing a tile at slotIndex scored.
---     0 if placement was not allowed  (already occupied or invalid tileType)
function Star:placeTile(tileType, slotIndex)
    if not self:isTileTypeAllowedInSlot(tileType, slotIndex) then
        return 0
    end
    self.occupiedSlots[slotIndex] = true
    -- lets take the slot
    local score = self:possibleScoreForPlacement(slotIndex)
    assert(score ~= 0)
    -- tracking which tile colors have been placed is necessary for StarType.MULTI
    self.slotColorOrder[slotIndex] = tileType
    if self.starType == StarType.MONO then
        -- first placement in this star. its color is now this tile
        self.starType = tileType
    end
    return score
end

return Star
