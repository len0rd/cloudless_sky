if arg[2] == "debug" then
    require("lldebugger").start()
end

-- third-party requirements
Log = require("cloudless_sky.extern.log")
local GameStateMachineMgr = require("cloudless_sky.extern.hump.gamestate")

-- TODO: better storage/access method?
fonts = {}

-- options from the command line (see parseLaunchOptions)
launchOptions = {}

--- Command line options. With none of --seed, --bot or a save path the app opens on the main menu;
--- with any of them it goes straight into a game:
---     --seed N        seed for the game's random generator. Defaults to the current time. The seed is
---                     saved in the game state so a game can be recreated
---     --bot           play the game automatically, checking invariants every frame, then exit
---                     (exit code 0 = game finished with no problems). See cloudless_sky/bot/bot.lua
---     --bot-speed N   game speed multiplier while the bot plays (default 4)
---     --anim-speed N  animation speed multiplier (default 1, 0 = animations off). See cloudless_sky/anim.lua
---     <path>.json     load a save game (see cloudless_sky/model/save_game.lua) instead of starting a new game
local function parseLaunchOptions(args)
    local options = { bot = false, botSpeed = 4 }
    for ii, v in ipairs(args) do
        if v == "--seed" then
            options.seed = assert(tonumber(args[ii + 1]), "--seed requires a number")
        elseif v == "--bot" then
            options.bot = true
        elseif v == "--anim-speed" then
            options.animSpeed = assert(tonumber(args[ii + 1]), "--anim-speed requires a number")
        elseif v == "--bot-speed" then
            options.botSpeed = assert(tonumber(args[ii + 1]), "--bot-speed requires a number")
        elseif v:find("%.json$") and not options.savePath then
            options.savePath = v
        end
    end
    return options
end

--- The game to go straight into, skipping the main menu, when the command line asks for one (--bot,
--- --seed or a save path)
--- @return GameState|nil gameState nil: show the main menu
local function launchGameState(options)
    if not (options.bot or options.seed or options.savePath) then
        return nil
    end
    if options.savePath then
        local SaveGame = require("cloudless_sky.model.save_game")
        local loaded, reason = SaveGame.readFile(options.savePath)
        if loaded then
            Log.info("loaded " .. options.savePath)
            return loaded
        end
        Log.error("couldn't load " .. options.savePath .. ": " .. tostring(reason) .. ". starting a new game")
    end
    -- the bot's digests depend on these names (they're in the game state)
    return require("cloudless_sky.model.game_setup").newGameState({
        playerNames = { "lenord", "karoty" },
        seed = options.seed,
    })
end

-- global X,Y of where we want the camera centered
CameraXDesired, CameraYDesired = 400, 100

---------------
-- setup window
---------------
-- TODO: make more intelligent, or make fullscreen
love.window.setMode(1280, 720, { resizable = true })
love.window.setTitle("Cloudless Sky")

function love.load(args)
    -- run unit tests if --cute arg is passed in
    local cute = require("cloudless_sky.extern.cute")
    cute.go(args)
    -- end unit testing

    launchOptions = parseLaunchOptions(args)
    -- TODO: load from user settings once they exist
    require("cloudless_sky.anim").setSpeed(launchOptions.animSpeed or 1)

    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)

    -- fonts
    -- Ithaca is a pixel font drawn on a 16px grid
    -- Only load it at integer multiples of 16 with "mono" hinting so every font pixel
    -- maps to a whole number of screen pixels with no anti-aliasing/blur
    fonts.ithaca = {
        ["16"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 16, "mono"),
        ["32"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 32, "mono"),
        ["48"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 48, "mono"),
        ["64"] = love.graphics.newFont("assets/fonts/Ithaca.ttf", 64, "mono"),
    }
    fonts.ithacaBySize = { fonts.ithaca["32"], fonts.ithaca["16"] }
    for _, font in pairs(fonts.ithaca) do
        font:setFilter("nearest", "nearest")
    end

    -- GLOBAL CAMERA
    local Camera = require("cloudless_sky.extern.hump.camera")
    camera = Camera(CameraXDesired, CameraYDesired)
    -- eases toward its target. Follows the animation speed (jumps straight there when it's 0)
    camera.smoother = require("cloudless_sky.anim").cameraSmoother(5)

    -- GAMESTATE
    game = require("cloudless_sky.states.game")
    GameStateMachineMgr.registerEvents()
    local launchGame = launchGameState(launchOptions)
    if launchGame then
        GameStateMachineMgr.switch(game, launchGame)
    else
        GameStateMachineMgr.switch(require("cloudless_sky.states.main_menu_state"))
    end

    if launchOptions.bot then
        require("cloudless_sky.bot.bot").install(launchOptions)
    end
end

function love.update(dt)
    -- local mouseX, mouseY = camera:worldCoords(love.mouse.getPosition())
    -- camera motion
    -- camera:lockPosition(CameraXDesired, CameraYDesired)
    -- ui updates
end

function love.draw() end

-- events

function love.keypressed(key) end

function love.mousepressed(x, y, button, istouch) end

function love.mousereleased(x, y, button, istouch) end

function love.resize(w, h)
    -- Gamestate.current():resize(w, h)
end

-- error handling
local love_errorhandler = love.errorhandler

function love.errorhandler(msg)
    if lldebugger then
        error(msg, 2)
    else
        return love_errorhandler(msg)
    end
end
