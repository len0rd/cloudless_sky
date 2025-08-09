# Entity Component System

- all high-level visual board entities:
    - player mats
    - factory display
    - board display

    - should have their respective draw function called on EVERY iteration.
    - from there relevant entities should check if they are in the camera frame (overlapping worldCoord BB's) and if so, THEN call the rest of draw, otherwise skip!
    - these entities should exist in the world for the lifetime of the game (not removed/re-instantiated during each turn)
    - is this bad for performance??
    - motivation is for transitions between objects. ie: i want to smoothly move from current board to next player board when the turn changes

**gameState** = Container of all non-graphical game state. Top-level model object that can be serialized for save games.
**world** = The ECS container for all the game's graphic entities. Entities represent portions of gameState. The only state they own is visualization-related. As such they are typically provided `gameState` on construction and update to enable accurate representation of the current model.


- probably a bastardization of true ECS since my entities are full classes that also contain a number of convenience functions... ¯\_(ツ)_/¯


QUESTIONS

- how to interact with events??
    - ie: use clicks place button, how to emit event that:
        - removes place prompt
        - updates model info
        - animates placement
    world:emit("tilePlaced", placementCost, starIdx, slotIdx)

## components

### TileFocus

    - starIdx
    - slotIdx

    For entities that are focused on a specific tile on the board

### WorldPosition

    - worldX
    - worldY

    for entities that have a position in the world coordinate system

### CameraPosition

    for entities that have a position in the camera coordinate system

### Drawable

    - priority. Lower number = drawn later (be drawn over everthing else)

    entities that have a draw function that can be called

### MouseHandler

    - priority. Lower number = check for handling earlier

    entities that can handle user-input. Return TRUE if input has been handled (skip calling lower priority entities)

    HOW TO LAYER THIS if stuff is on top of each other???




## systems

### TileFocusDrawable

    On a resize event, this should update the coordinates of an entity with `WorldPosition` + `TileFocus`


### TilePlacedReactor??

    system to update all the model classes on tile placement? or an aggregator of other events?

    world:emit("scoreUpdate", newScore)
