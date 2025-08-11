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

TilePlacementTurnStateMachine.STATES = {
    IDLE = 1,
    WAIT_FOR_PLACEMENT = 2,
    SCORING = 3,
    WAIT_FOR_END = 4,
}

function TilePlacementTurnStateMachine:new()
    -- nah
    self.state = self.STATES.IDLE
    self.mouseClicked = false
    self.cameraZoom = 1.0
end

function TilePlacementTurnStateMachine:enter(fromState, playerIdx, gameState, graphicsState)
    self.state = self.STATES.IDLE
    self.playerIdx = playerIdx
    self.gameState = gameState
    self.graphicsState = graphicsState
    self.spacePressed = false
    print("entering PlacementTurnSM for " .. tostring(playerIdx))
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
                -- TODO: only allow getting creating new entity if in right turn state
                self:_addPlaceDialogEntity(pressCtx)
            elseif pressCtx.type == Components.mouseHandler.eventTypes.placeTileClicked then
                print("TIME TO PLACE A TILE BITCH")
            end
        end
    end
end

function TilePlacementTurnStateMachine:update(dt)
    if self.state == self.STATES.IDLE then
        -- transition to players mat
    end
    if self.spacePressed then
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
        self.spacePressed = true
    end
end

function TilePlacementTurnStateMachine:resize(w, h)
    self.graphicsState.world:emit("resize", w, h, self.graphicsState)
end

function TilePlacementTurnStateMachine:centerCamera()
    local matCenterX, matCenterY = BoxedViewSys.worldCenter(self.graphicsState.matEntities[self.playerIdx])

    camera:zoomTo(self.cameraZoom)
    camera:lockPosition(matCenterX, matCenterY)
end

return TilePlacementTurnStateMachine
