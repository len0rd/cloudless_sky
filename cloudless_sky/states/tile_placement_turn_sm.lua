--- State machine for a single player turn during a TilePlacement phase
local TurnStateMachine = require("cloudless_sky.states.turn_sm_base")
local WorldStateMachine = require("cloudless_sky.states.world_sm")

local Anim = require("cloudless_sky.anim")
local BonusPickup = require("cloudless_sky.model.bonus_pickup")
local BonusPickupEntity = require("cloudless_sky.entities.bonus_pickup_entity")
local MatBonus = require("cloudless_sky.model.mat_bonus")
local TakeBonusTilesAction = require("cloudless_sky.action.take_bonus_tiles")
local Components = require("cloudless_sky.components")
local PlaceTileDialogEntity = require("cloudless_sky.entities.place_tile_dialog_entity")
local PlaceTileLackingDialogEntity = require("cloudless_sky.entities.place_tile_lacking_dialog_entity")
local PlayerMatTileAnchorSys = require("cloudless_sky.systems.player_mat_tile_anchor")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local ScoreTextEntity = require("cloudless_sky.entities.score_text_entity")
local PassAction = require("cloudless_sky.action.pass")
local PassConfirmDialogEntity = require("cloudless_sky.entities.pass_confirm_dialog_entity")

---@class TilePlacementTurnStateMachine : TurnStateMachine
local TilePlacementTurnStateMachine = TurnStateMachine:extend()

-- after passing, wait this long before ending the turn so the HUD score count-down can be seen
local PASS_END_DELAY_S = 0.8

TilePlacementTurnStateMachine.STATES = {
    -- waiting for current player to place a tile or pass
    WAIT_FOR_PLACEMENT = 1,
    -- a tile has been placed and its animations are playing
    SCORING = 2,
    -- placement done. player may end their turn
    WAIT_FOR_END = 3,
    -- pass confirmation dialog is open
    CONFIRM_PASS = 4,
    -- player has passed. waiting briefly before ending the turn
    PASSING = 5,
    -- the placement completed bonus spaces: the player picks up their bonus tiles (BonusPickupEntity)
    PICK_BONUS = 6,
}

function TilePlacementTurnStateMachine:onEnter()
    self.passDialog = nil
    -- the open place (or "need more tiles") dialog, if any
    self.placeDialog = nil
    self.passEndTimer = 0
    -- the bonus pickup overlay while in PICK_BONUS
    self.bonusPickup = nil
    self:setViewFocus(WorldStateMachine.VIEW.MAT)
    -- usually WAIT_FOR_PLACEMENT. Not when resuming a turn from a loaded save game
    self:_setState(self:stateFromHistory())
    Log.trace("entering PlacementTurnSM for " .. tostring(self.playerIdx))
end

function TilePlacementTurnStateMachine:hudButtons(state)
    local done = state == self.STATES.WAIT_FOR_END
    -- passing replaces placing a tile, so it's only possible before placing
    local pass = state == self.STATES.WAIT_FOR_PLACEMENT
    -- no undo mid-animation, while confirming a pass, or after passing (passing ends the turn)
    local settled = state == self.STATES.WAIT_FOR_PLACEMENT
        or state == self.STATES.WAIT_FOR_END
        or state == self.STATES.PICK_BONUS
    return done, pass, settled and self.gameState:canUndoChoice()
end

--- @return integer state The turn state implied by the actions taken so far this turn.
---     Used after an undo so the state machine doesn't need to know what was undone, and when
---     resuming a turn from a loaded save game
function TilePlacementTurnStateMachine:stateFromHistory()
    local placed = false
    for ii = self.gameState:turnStartIndex() + 1, #self.gameState.actionHistory do
        local name = self.gameState.actionHistory[ii].name
        if name == "Pass" then
            -- passing ends the turn (passEndTimer is 0 unless _pass just set it)
            return self.STATES.PASSING
        elseif name == "PlaceTile" then
            placed = true
        end
    end
    if not placed then
        return self.STATES.WAIT_FOR_PLACEMENT
    end
    return BonusPickup.owed(self.gameState) and self.STATES.PICK_BONUS or self.STATES.WAIT_FOR_END
end

--- Set the turn state, opening the bonus pickup overlay on entering PICK_BONUS and closing it on leaving
function TilePlacementTurnStateMachine:_setState(newState)
    TurnStateMachine._setState(self, newState)
    if newState == self.STATES.PICK_BONUS then
        if not self.bonusPickup then
            self:_openBonusPickup()
        end
    else
        self:_closeBonusPickup()
    end
end

--- @return string eg: "Pillar + Statue bonus" for the bonus space indices \p bonuses on \p mat
function TilePlacementTurnStateMachine.bonusTitle(mat, bonuses)
    local labels = {}
    for _, bonusIdx in ipairs(bonuses or {}) do
        table.insert(labels, MatBonus.LABEL[mat:bonusAt(bonusIdx).kind])
    end
    return table.concat(labels, " + ") .. (#labels > 1 and " bonuses" or " bonus")
end

function TilePlacementTurnStateMachine:_openBonusPickup()
    local owed = BonusPickup.owed(self.gameState)
    local pool = self.gameState.bonusPool
    local mat = self.gameState.players[self.playerIdx].mat

    -- the pool as the table shows it (same slots), unless the table hasn't caught up with the model
    local tiles = {}
    local tableTiles = self.graphicsState.table.bonusPool.tiles
    local shown = self.graphicsState.table.bonusPool:counts()
    local matches = #tableTiles == pool:total()
    for tileType, count in pairs(shown) do
        matches = matches and pool:num(tileType) == count
    end
    if matches then
        for _, tile in ipairs(tableTiles) do
            table.insert(tiles, { tileType = tile.tileType, slot = tile.slot })
        end
    else
        local BonusPoolView = require("cloudless_sky.view.bonus_pool_view")
        for _, tileType in ipairs(BonusPoolView.orderedList(pool:serialize())) do
            table.insert(tiles, { tileType = tileType })
        end
    end

    self.bonusPickup = BonusPickupEntity.new({
        tiles = tiles,
        numSlots = self.gameState.rules.bonusSurrounds.numBonusTiles,
        count = owed.count,
        title = TilePlacementTurnStateMachine.bonusTitle(mat, owed.bonuses),
        short = owed.count < owed.bonusTiles,
    })
    self.graphicsState.world:addEntity(self.bonusPickup)

    -- pulse the slots around each completed bonus space
    local matEntity = self.graphicsState.matEntities[self.playerIdx]
    local perStar = {}
    for _, bonusIdx in ipairs(owed.bonuses or {}) do
        for _, slot in ipairs(mat:bonusAt(bonusIdx).slots) do
            perStar[slot[1]] = perStar[slot[1]] or {}
            table.insert(perStar[slot[1]], slot[2])
        end
    end
    for starIdx, slotIdxs in pairs(perStar) do
        matEntity.stars[starIdx]:pulseSlots(slotIdxs)
    end
end

function TilePlacementTurnStateMachine:_closeBonusPickup()
    if self.bonusPickup then
        self.graphicsState.world:removeEntity(self.bonusPickup)
        self.bonusPickup = nil
    end
end

--- Pick up \p tiles (TileType -> count) from the bonus pool
function TilePlacementTurnStateMachine:_takeBonusTiles(tiles)
    local performed, reason = self.gameState:performAction(TakeBonusTilesAction(self.playerIdx, tiles))
    if not performed then
        -- the overlay only allows the owed count of tiles in the pool, so this is a bug
        Log.error("invalid bonus pickup: " .. tostring(reason))
        return
    end
    self:_setState(self:stateFromHistory())
end

function TilePlacementTurnStateMachine:onUpdate(dt)
    if self.state == self.STATES.PASSING then
        self.passEndTimer = self.passEndTimer - dt
        if self.passEndTimer <= 0 then
            self.endTurnRequested = true
        end
    end
end

function TilePlacementTurnStateMachine:onLeave()
    -- eg: debug key ended the turn while the dialog was open
    self:_closePassDialog()
    self:_closeBonusPickup()
end

--- animate undone placements being removed from the mat
function TilePlacementTurnStateMachine:onUndone(undoneActions)
    for _, action in ipairs(undoneActions) do
        if action.name == "PlaceTile" then
            local ctx = action.ctx
            self.graphicsState.matEntities[ctx.playerIdx]:animateTileRemoved(
                ctx.starIdx,
                ctx.slotIdx,
                ctx.placement.tileType
            )
        end
    end
end

--- Open the pass confirmation dialog, pre-filled with suggested tiles to keep
function TilePlacementTurnStateMachine:_openPassDialog()
    local player = self.gameState.players[self.playerIdx]
    local limit = self.gameState:tileCarryoverLimit()
    local suggested = PassAction.suggestKeep(player.hand, limit, self.gameState:getNextRoundWildType())
    self.passDialog = PassConfirmDialogEntity.new(player.hand, limit, suggested, player.score)
    self.graphicsState.world:addEntity(self.passDialog)
    self:_setState(self.STATES.CONFIRM_PASS)
end

function TilePlacementTurnStateMachine:_closePassDialog()
    if self.passDialog then
        self.graphicsState.world:removeEntity(self.passDialog)
        self.passDialog = nil
    end
end

--- Perform the pass and end the turn shortly after (once the HUD shows the score change)
--- @param keep table TileType -> count of tiles to keep
function TilePlacementTurnStateMachine:_pass(keep)
    self:_closePassDialog()
    local performed, reason = self.gameState:performAction(PassAction(self.playerIdx, keep))
    if not performed then
        -- dialog should only allow valid choices, so this is a bug
        Log.error("invalid pass from dialog: " .. tostring(reason))
        self:_setState(self:stateFromHistory())
        return
    end
    Log.debug("player " .. tostring(self.playerIdx) .. " passed for the round")
    self.passEndTimer = Anim.time(PASS_END_DELAY_S)
    self:_setState(self.STATES.PASSING)
end

function TilePlacementTurnStateMachine:_addPlaceDialogEntity(pressCtx)
    local player = self.gameState.players[pressCtx.playerIdx]
    if player:isSlotOccupied(pressCtx.starIdx, pressCtx.slotIdx) then
        -- slot is already occupied. show scoring information
        -- TODO: look through action history to see all the cool things the player did by playing in this particular slot
        print("already played here!")
    else
        local placementOpts = player:generatePlacementPossibilities(
            pressCtx.starIdx,
            pressCtx.slotIdx,
            self.gameState:getCurrentWildType()
        )
        local prompt = nil
        if placementOpts and #placementOpts > 0 then
            -- player has enough in hand to place here
            prompt = PlaceTileDialogEntity.new(
                pressCtx.playerIdx,
                pressCtx.starIdx,
                pressCtx.slotIdx,
                self.gameState:getMatSlotCost(pressCtx.starIdx, pressCtx.slotIdx),
                placementOpts,
                self.gameState:getStarType(pressCtx.starIdx)
            )
        else
            -- player is lacking the tiles needed to place here
            prompt = PlaceTileLackingDialogEntity.new(
                pressCtx.playerIdx,
                pressCtx.starIdx,
                pressCtx.slotIdx,
                self.gameState:getMatSlotCost(pressCtx.starIdx, pressCtx.slotIdx)
            )
        end

        self.graphicsState.world:addEntity(prompt)
        self.placeDialog = prompt
        local w, h = love.graphics.getPixelDimensions()
        PlayerMatTileAnchorSys.ensureEntityFullyVisible(prompt, w, h, self.graphicsState.matEntities)
    end
end

--- Perform tile placement on game state and kick off animations.
--- Moves to SCORING, then to WAIT_FOR_END once the tile animation completes
--- @param pressCtx table placeTileClicked click event from PlaceTileDialogEntity
--- @param dialogEntity table the dialog that was clicked. Closed once the tile is placed
function TilePlacementTurnStateMachine:_placeTile(pressCtx, dialogEntity)
    local action = PlaceTileAction(self.playerIdx, pressCtx.starIdx, pressCtx.slotIdx, pressCtx.placementOpt)
    local performed, reason = self.gameState:performAction(action)
    if not performed then
        -- dialog should only ever offer valid placements, so this is a bug
        Log.error("invalid placement offered by dialog: " .. tostring(reason))
        return
    end
    dialogEntity.ephemeral.done = true
    self:_setState(self.STATES.SCORING)

    -- tile bounce-in. once done, the player may end their turn (or undo).
    -- ignore the callback if the turn has changed since (eg: player passed mid-animation)
    local turnIdx = self.gameState.turnIdx
    local matEntity = self.graphicsState.matEntities[self.playerIdx]
    matEntity:animateTilePlaced(pressCtx.starIdx, pressCtx.slotIdx, function()
        if turnIdx == self.gameState.turnIdx and self.state == self.STATES.SCORING then
            self:_setState(self:stateFromHistory())
        end
    end)

    -- "+N Points!" popup at the slot. The HUD score tweens up on its own once it sees the new score
    if Anim.isOff() then
        return
    end
    local scoreText = ScoreTextEntity.new(self.playerIdx, pressCtx.starIdx, pressCtx.slotIdx, action.score)
    self.graphicsState.world:addEntity(scoreText)
    local w, h = love.graphics.getPixelDimensions()
    PlayerMatTileAnchorSys.ensureEntityFullyVisible(scoreText, w, h, self.graphicsState.matEntities)
end

function TilePlacementTurnStateMachine:onClickEvent(pressCtx, entity)
    local eventTypes = Components.mouseHandler.eventTypes
    if pressCtx.type == eventTypes.matSlotClicked then
        -- only one placement per turn
        if self.state == self.STATES.WAIT_FOR_PLACEMENT then
            self:_addPlaceDialogEntity(pressCtx)
        end
    elseif pressCtx.type == eventTypes.placeTileClicked then
        if self.state == self.STATES.WAIT_FOR_PLACEMENT then
            self:_placeTile(pressCtx, entity)
        end
    elseif pressCtx.type == eventTypes.passClicked then
        if self.state == self.STATES.WAIT_FOR_PLACEMENT then
            self:_openPassDialog()
        end
    elseif pressCtx.type == eventTypes.passCancelled then
        self:_closePassDialog()
        self:_setState(self:stateFromHistory())
    elseif pressCtx.type == eventTypes.passConfirmed then
        if self.state == self.STATES.CONFIRM_PASS then
            self:_pass(pressCtx.keep)
        end
    elseif pressCtx.type == eventTypes.bonusTilesTaken then
        if self.state == self.STATES.PICK_BONUS then
            self:_takeBonusTiles(pressCtx.tiles)
        end
    end
end

return TilePlacementTurnStateMachine
