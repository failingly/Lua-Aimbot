## Feel free to use this in a script.

## Load the Aimbot
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/failingly/Lua-Aimbot/refs/heads/main/Main.lua"))()
```
## Customizable Settings
```lua
getgenv().dhlock = {
    enabled = false,              -- Master toggle for the entire aimbot functionality
    showfov = false,              -- Whether to show the FOV circle on screen
    fov = 50,                     -- Size of the FOV circle in pixels
    keybind = Enum.UserInputType.MouseButton2, -- Key to activate the aimbot (right mouse button)
    teamcheck = false,            -- Whether to ignore players on your team
    wallcheck = false,            -- Whether to check if there's a wall between you and target (currently unused)
    alivecheck = false,           -- Whether to check if target is alive
    lockpart = "Head",            -- Body part to target when on ground
    lockpartair = "Head",         -- Body part to target when in air
    smoothness = 1,               -- How smooth the aim is (higher = slower)
    predictionX = 0,              -- Horizontal movement prediction
    predictionY = 0,              -- Vertical movement prediction
    fovcolorlocked = Color3.new(1, 0, 0),   -- FOV circle color when locked onto a target (red)
    fovcolorunlocked = Color3.new(0, 0, 0), -- FOV circle color when not locked (black)
    fovtransparency = 0.6,        -- Transparency of the FOV circle (0-1)
    toggle = false,               -- Whether aimbot stays on after releasing key
    blacklist = {}                -- List of player names to ignore
}

```
> [!IMPORTANT]
> Disabled by default. Make sure to enable everything. Here's an example usage:
> ## Example Usage
> ```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/failingly/Lua-Aimbot/refs/heads/main/Main.lua"))()
>  dhlock.fov = 80
>  dhlock.keybind = Enum.Keycode.E
>  dhlock.enabled = true
>  dhlock.showfov = true
>  dhlock.fovcolorlocked = Color3.new(1, 0, 0)
>  dhlock.fovcolorunlocked = Color3.new(1, 0, 0)
>  dhlock.lockpart = "Head"
>  dhlock.smoothness = 2
> ```
