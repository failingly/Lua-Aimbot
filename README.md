## Load the Aimbot
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Stratxgy/DH-Lua-Lock/refs/heads/main/Main.lua"))()
```
## Customizable Settings
```lua
getgenv().dhlock = {
    enabled = false,
    showfov = false, -- Show FOV circle
    fov = 50, -- Radius of the FOV circle
    keybind = Enum.UserInputType.MouseButton2, -- Activation key
    teamcheck = false, -- Enable/disable team check
    wallcheck = false, -- Checks for walls
    alivecheck = false, -- Enable/disable alive check
    lockpart = "Head", -- Part to lock onto when on the ground
    lockpartair = "Head", -- Part to lock onto when in the air
    smoothness = 1, -- Smoothness factor (higher = slower)
    predictionX = 0, -- Prediction multiplier for X-axis (horizontal)
    predictionY = 0, -- Prediction multiplier for Y-axis (vertical)
    fovcolorlocked = Color3.new(1, 0, 0), -- Color when locked
    fovcolorunlocked = Color3.new(0, 0, 0), -- Color when unlocked
    toggle = false, -- Toggle mode (set true for toggle, false for hold)
    blacklist = {} -- Blacklisted players
}
```
> [!IMPORTANT]
> Disabled by default. Make sure to enable everything. Here's an example usage:
> ## Example Usage
> ```lua
>loadstring(game:HttpGet("https://raw.githubusercontent.com/Stratxgy/DH-Lua-Lock/refs/heads/main/Main.lua"))()
>  dhlock.fov = 80
>  dhlock.keybind = Enum.Keycode.E
>  dhlock.enabled = true
>  dhlock.showfov = true
>  dhlock.fovcolorlocked = Color3.new(1, 0, 0)
>  dhlock.fovcolorunlocked = Color3.new(1, 0, 0)
>  dhlock.lockpart = "Head"
>  dhlock.smoothness = 2
> ```
