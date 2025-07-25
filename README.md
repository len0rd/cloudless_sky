# Cloudless Sky

## Dev Setup

TODO: getting graphics forwarded in a container is hard..

If using the container on Wayland, you need to enable local user access via xhost:

```
xhost +SI:localuser:$(id -un)
```

Then the user you run with needs to have a matching UID/GID

## TODO

- Win32/64 binaries via python makelove package + Wine
- Game state stack per player for undo support. need to save games randomGen state on every action? and corresponding 'undo' function

## dependencies

- Camera: [hump.camera](https://github.com/HDictus/hump)
- UI elements: [Luis](https://github.com/SiENcE/luis)
- Tick for timed callbacks [Tick](https://github.com/rxi/tick)
- Json for serial/deserialization of game state [json](https://github.com/rxi/json.lua)
- Text animation [slog](https://github.com/sysl-dev/SYSL-Text)

## shaders

- cloudy background shader? 
    - https://www.shadertoy.com/view/3dVXDc
- base warp background
    - https://www.shadertoy.com/view/tdG3Rd

## docs

### cloudless_sky/model

Model classes exist to hold game state and provide convenience functions around running the game itself

![](docs/design.drawio.svg)
