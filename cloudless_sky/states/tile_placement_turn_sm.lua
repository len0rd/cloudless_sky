--- State machine for a single player turn during a TilePlacement phase
local Object = require("cloudless_sky.extern.classic")
local TilePlacementTurnStateMachine = Object:extend()

local Components = require("cloudless_sky.components")
local BoxedViewSys = require("cloudless_sky.systems.boxed_view")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")
local MousePressedSys = require("cloudless_sky.systems.mouse_pressed")
local PlaceTileDialogEntity = require("cloudless_sky.entities.place_tile_dialog_entity")
local PlaceTileLackingDialogEntity = require("cloudless_sky.entities.place_tile_lacking_dialog_entity")
local PlayerMatTileAnchorSys = require("cloudless_sky.systems.player_mat_tile_anchor")
local PlaceTileAction = require("cloudless_sky.action.place_tile")
local ScoreTextEntity = require("cloudless_sky.entities.score_text_entity")

TilePlacementTurnStateMachine.STATES = {
    -- waiting for current player to place a tile or pass
    WAIT_FOR_PLACEMENT = 1,
    -- a tile has been placed and its animations are playing
    -- TODO: placement bonuses (surrounding pillars/statues/windows) need a state between
    --  SCORING and WAIT_FOR_END where the player picks their bonus tiles
    SCORING = 2,
    -- placement done. player may end their turn
    WAIT_FOR_END = 3,
}

function TilePlacementTurnStateMachine:new()
    -- nah
    self.state = self.STATES.WAIT_FOR_PLACEMENT
    self.mouseClicked = false
    -- incremented every time a turn starts. Animation callbacks compare against it so a
    -- callback from a previous turn (eg: player passed mid-animation) can't affect this one
    self.turnToken = 0
end

function TilePlacementTurnStateMachine:enter(fromState, playerIdx, gameState, graphicsState)
    self.state = self.STATES.WAIT_FOR_PLACEMENT
    self.playerIdx = playerIdx
    self.gameState = gameState
    self.graphicsState = graphicsState
    self.endTurnRequested = false
    self.turnToken = self.turnToken + 1
    self.graphicsState.hud.container:setDoneEnabled(false)
    Log.trace("entering PlacementTurnSM for " .. tostring(playerIdx))
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
    self.state = self.STATES.SCORING

    -- tile bounce-in. once done, the player may end their turn
    local token = self.turnToken
    local matEntity = self.graphicsState.matEntities[self.playerIdx]
    matEntity:animateTilePlaced(pressCtx.starIdx, pressCtx.slotIdx, function()
        if token == self.turnToken and self.state == self.STATES.SCORING then
            self.state = self.STATES.WAIT_FOR_END
            self.graphicsState.hud.container:setDoneEnabled(true)
        end
    end)

    -- "+N Points!" popup at the slot. The HUD score tweens up on its own once it sees the new score
    local scoreText = ScoreTextEntity.new(self.playerIdx, pressCtx.starIdx, pressCtx.slotIdx, action.score)
    self.graphicsState.world:addEntity(scoreText)
    local w, h = love.graphics.getPixelDimensions()
    PlayerMatTileAnchorSys.ensureEntityFullyVisible(scoreText, w, h, self.graphicsState.matEntities)
end

function TilePlacementTurnStateMachine:handleUserInput()
    if self.mouseClicked then
        local mousePressSys = self.graphicsState.world:getSystem(MousePressedSys)
        if mousePressSys and mousePressSys.lastPressedEntity then
            local pressCtx = mousePressSys.lastPressedEntity.mouseHandler.clickEvent
            if not pressCtx then
                -- entity handled a click that doesnt require state machine interaction
                return
            end

            if pressCtx.type == Components.mouseHandler.eventTypes.matSlotClicked then
                -- only one placement per turn
                if self.state == self.STATES.WAIT_FOR_PLACEMENT then
                    self:_addPlaceDialogEntity(pressCtx)
                end
            elseif pressCtx.type == Components.mouseHandler.eventTypes.placeTileClicked then
                if self.state == self.STATES.WAIT_FOR_PLACEMENT then
                    self:_placeTile(pressCtx, mousePressSys.lastPressedEntity)
                end
            elseif pressCtx.type == Components.mouseHandler.eventTypes.endTurnClicked then
                self.endTurnRequested = true
            elseif pressCtx.type == Components.mouseHandler.eventTypes.passClicked then
                Log.debug("player " .. tostring(self.playerIdx) .. " passed for the round")
                self.gameState.players[self.playerIdx].passedForPhase = true
                self.endTurnRequested = true
            end
        end
    end
end

function TilePlacementTurnStateMachine:update(dt)
    if self.endTurnRequested then
        GameStateMachineMgr.pop()
        return
    end

    self:handleUserInput()

    self:centerCamera()

    self.graphicsState.world:emit("update", dt, self.gameState)

    if self.mouseClicked then
        self.mouseClicked = false
        self.graphicsState.world:emit("leaveUpdate")
    end
end

function TilePlacementTurnStateMachine:draw()
    self.graphicsState.world:emit("draw", self.gameState)
end

function TilePlacementTurnStateMachine:mousepressed(x, y, button, istouch)
    self.graphicsState.world:emit("mousepressed", x, y, button, istouch)
    self.mouseClicked = true
end

function TilePlacementTurnStateMachine:keyreleased(key, code)
    if key == "space" then
        self.endTurnRequested = true
    end
end

function TilePlacementTurnStateMachine:resize(w, h)
    self.graphicsState.world:emit("resize", w, h, self.graphicsState)
end

function TilePlacementTurnStateMachine:centerCamera()
    local currentPlayMat = self.graphicsState.matEntities[self.playerIdx]
    local matCenterX, matCenterY, matZoom = BoxedViewSys.worldFocus(currentPlayMat)
    local hudBBox = self.graphicsState.hud.container.boundingBox
    matCenterX = matCenterX - (hudBBox.w / 2)

    camera:zoomTo(matZoom)
    camera:lockPosition(matCenterX, matCenterY)
end

return TilePlacementTurnStateMachine
