-- Configuration settings for the aimbot
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

-- Get necessary game services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Local variables
local LocalPlayer = Players.LocalPlayer
local isAiming = false           -- Whether aimbot is currently active
local fovCircle                  -- Drawing object for FOV circle
local lockedPlayer = nil         -- Currently targeted player
local holdingKeybind = false     -- Whether the keybind is currently held

-- Constants
local PREDICTION_MULTIPLIER = 0.0400  -- Base multiplier for movement prediction

-- Cache frequently accessed values
local mousePosition = Vector2.new()
local lastUpdateTime = tick()
local updateFrequency = 0.01     -- Update frequency limiter

-- Checks if an input is a valid keybind type
local function IsValidKeybind(input)
    return typeof(input) == "EnumItem" and (input.EnumType == Enum.KeyCode or input.EnumType == Enum.UserInputType)
end

-- Determines which body part to target based on whether the local player is in air
local function GetCurrentLockPart()
    local character = LocalPlayer.Character
    if not character then return dhlock.lockpart end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local lockPartName = dhlock.lockpart
    
    -- Use air lock part if player is in the air
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
        lockPartName = dhlock.lockpartair
    end

    -- Verify the part exists on character, otherwise default to Head
    if character:FindFirstChild(lockPartName) then
        return lockPartName
    else
        return "Head"
    end
end

-- Checks if a player is alive (has a humanoid with health > 0)
local function IsPlayerAlive(player)
    if not player or not player.Character then return false end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- Checks if there's a wall between the camera and target (for wallcheck feature)
local function IsWallBetween(targetPosition)
    if not dhlock.wallcheck then return false end
    
    local ray = Ray.new(Camera.CFrame.Position, targetPosition - Camera.CFrame.Position)
    local hit, position = Workspace:FindPartOnRayWithIgnoreList(
        ray, 
        {LocalPlayer.Character, targetPosition.Parent}, 
        false, 
        true
    )
    
    return hit ~= nil
end

-- Gets the closest player to the mouse cursor within FOV
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = dhlock.fov  -- Only consider players within FOV
    mousePosition = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        -- Skip if player is self or in blacklist
        if player == LocalPlayer or table.find(dhlock.blacklist, player.Name) then
            continue
        end
        
        -- Skip if player has no character or target part
        local character = player.Character
        if not character then continue end
        
        local part = character:FindFirstChild(GetCurrentLockPart())
        if not part then continue end
        
        -- Team check
        if dhlock.teamcheck and player.Team == LocalPlayer.Team then
            continue
        end
        
        -- Alive check
        if dhlock.alivecheck and not IsPlayerAlive(player) then
            continue
        end
        
        -- Calculate screen position and distance
        local screenPoint, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        
        local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePosition).Magnitude
        
        -- Check if closer than current closest and within FOV
        if distance < shortestDistance then
            -- Wall check (commented out to optimize - enable if needed)
            -- if dhlock.wallcheck and IsWallBetween(part.Position) then
            --     continue
            -- end
            
            closestPlayer = player
            shortestDistance = distance
        end
    end

    return closestPlayer
end

-- Smoothly aims at a target player with prediction
local function SmoothAimAtPlayer(player)
    if not player or not player.Character then return end

    local part = player.Character:FindFirstChild(GetCurrentLockPart())
    if not part then return end

    -- Calculate target position with velocity prediction
    local targetPosition = part.Position
    if part:IsA("BasePart") then
        targetPosition = targetPosition + part.Velocity * Vector3.new(
            dhlock.predictionX * PREDICTION_MULTIPLIER,
            dhlock.predictionY * PREDICTION_MULTIPLIER,
            dhlock.predictionX * PREDICTION_MULTIPLIER
        )
    end
    
    -- Create target CFrame and apply smoothing
    local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    local smoothnessFactor = 1 / math.clamp(dhlock.smoothness, 0.1, 10)  -- Prevent division by zero

    -- Apply the camera movement
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothnessFactor)
end

-- Main aimbot function - handles target acquisition and aiming
local function HandleAim()
    if not dhlock.enabled then return end

    if holdingKeybind or (dhlock.toggle and isAiming) then
        -- Only search for a new target if we don't have one or if current is invalid
        if not lockedPlayer or 
           not lockedPlayer.Character or 
           not lockedPlayer.Character:FindFirstChild(GetCurrentLockPart()) or
           (dhlock.alivecheck and not IsPlayerAlive(lockedPlayer)) or
           (dhlock.teamcheck and lockedPlayer.Team == LocalPlayer.Team) then
            
            lockedPlayer = GetClosestPlayer()
            
            -- Update FOV circle color based on lock status
            if fovCircle then
                fovCircle.Color = lockedPlayer and dhlock.fovcolorlocked or dhlock.fovcolorunlocked
            end
        end

        if lockedPlayer then
            SmoothAimAtPlayer(lockedPlayer)
        end
    else
        -- Reset lock and FOV color when not aiming
        if lockedPlayer and fovCircle then
            fovCircle.Color = dhlock.fovcolorunlocked
        end
        lockedPlayer = nil
    end
end

-- Creates or updates the FOV circle visualization
local function UpdateFovCircle()
    mousePosition = UserInputService:GetMouseLocation()
    
    if dhlock.showfov then
        if not fovCircle then
            -- Create new FOV circle if it doesn't exist
            fovCircle = Drawing.new("Circle")
            fovCircle.Filled = false
            fovCircle.Thickness = 2
            fovCircle.NumSides = 60  -- More sides = smoother circle
        end
        
        -- Update properties
        fovCircle.Visible = true
        fovCircle.Position = mousePosition
        fovCircle.Radius = dhlock.fov
        fovCircle.Color = lockedPlayer and dhlock.fovcolorlocked or dhlock.fovcolorunlocked
        fovCircle.Transparency = dhlock.fovtransparency
    elseif fovCircle then
        -- Hide circle if showfov is disabled
        fovCircle.Visible = false
    end
end

-- Handle keybind press
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Skip if input was processed by the game
    if gameProcessed then return end
    
    -- Check if the input matches our keybind
    if IsValidKeybind(dhlock.keybind) and 
       (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) then
        
        holdingKeybind = true
        
        -- Toggle aim if toggle mode is enabled
        if dhlock.toggle then
            isAiming = not isAiming
            
            -- Update FOV circle color
            if fovCircle then
                fovCircle.Color = isAiming and (lockedPlayer and dhlock.fovcolorlocked or dhlock.fovcolorunlocked)
            end
        end
    end
end)

-- Handle keybind release
UserInputService.InputEnded:Connect(function(input)
    -- Check if the released input matches our keybind
    if IsValidKeybind(dhlock.keybind) and 
       (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) then
        
        holdingKeybind = false
        
        -- If not in toggle mode, reset lock when key is released
        if not dhlock.toggle then
            lockedPlayer = nil
            
            -- Update FOV circle color
            if fovCircle then
                fovCircle.Color = dhlock.fovcolorunlocked
            end
        end
    end
end)

-- Main loop - throttled for better performance
RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    
    -- Throttle updates for performance
    if currentTime - lastUpdateTime >= updateFrequency then
        HandleAim()
        UpdateFovCircle()
        lastUpdateTime = currentTime
    end
end)

-- Clean up resources when script is unloaded
local scriptDestructor = Instance.new("BindableEvent")
scriptDestructor.Event:Connect(function()
    if fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
end)

-- Return destructor to allow proper cleanup
return scriptDestructor
