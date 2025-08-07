# Actions

Actions are single steps in the game which perform some modification on the game's state (ie: updates the various 'model' classes)

Actions are serializable so they can be included in the gamesave.

- When Actions are constructed, they should be provided all the basic context they need to be performed (what tiles or slots are being acted on)
- When the Actions:perform or :undo method is called, its provided the current game state model object. it uses this + the context provided on construction to modify the game state

Actions have a corresponding `undo` function.

When an action is performed, it will often result in other actions being triggered.

Basically state in the game model classes should ONLY be modified via an Action implementation

Actions are split into 2 categories: Player and Game.

## Player Actions

These are actions performed by a specific player.

- TakeFromFactoryDisplay
- TakeFromFactoryFloor
    (trigger LoseScore if taking first player)
- PlaceTile
- CollectBonusTiles
- AddScore
- LoseScore
- SaveTiles
    (keep 1 - GameRules.playerMat.maxTileRoundCarryover for the next round at no cost)

## Game Actions

These are often triggered by a player and update the overall game state.

- FillFactoryDisplays
- AddTilesToDiscard
- AdvanceRound
    - updateWild and round number, check, for game end?
    - remove unsaved tiles from players??
    - FillFactoryDisplays
- AdvancePhase
    - TileSelection -> TilePlacement
    - set current player turn
- AdvanceTurn
    - change active player
- RefillBonusDisplay


## QUESTIONS

- Should model classes still have helper methods for modifying their state?? or move all of that into Actions?
- Then only leave access/getter util functions in model so it kinda presents itself as RO?

- how are visual state changes/wait for input handled as part of an action?
  - for instance if PlaceTile triggers the START of a CollectBonus action, that action is not fully complete/defined
    until the user selects the tiles they want



- you need to somehow seperate actions that modify game state like this (in a single step) from state machines that require player input



- NOOOOOO:::::

  - does each action need to be a state machine?
    - game only runs one action. and continues running/updating it until its complete. at which point it moves to the next?
      - or waits for user input.
        - ie: for AdvanceTurn, the action handles updating view to the current player. at which point its done ane we wait for the player to click or do something to trigger a new action?
        - some actions state machine will block waiting for user-input. ie: TakeFromFactoryDisplay. Wait for display selection then wait for TileGroup selection.

  - undo methods should NOT require a statemachine. Its just reverting game state to where it was pre-action. right?

- Actions will likely trigger one or more animations or changes to screen display. How trigger and how wait?
  - you probably want animations from an action to fully play out before you proceed to the next action
  -
