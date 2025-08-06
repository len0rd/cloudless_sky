# Entity Component System


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
