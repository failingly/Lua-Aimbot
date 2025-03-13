-- Configuration settings for the aimbot
getgenv().dhlock = {
    -- Core settings
    enabled = false,              -- Master toggle for the entire aimbot functionality
    smoothness = 1,               -- How smooth the aim is (higher = slower)
    
    -- Silent aim settings
    silent = {
        enabled = false,          -- Toggle for silent aim functionality
        hitchance = 100,          -- Chance of hit in percentage (0-100)
        methodPriority = {        -- Priority list of methods to try (1 = highest priority)
            raycast = 1,          -- Raycast method
            findpart = 2,         -- FindPartOnRay methods
            mousehit = 3          -- Mouse.Hit/Target method
        }
    },
    
    -- Targeting settings
    fov = 50,                     -- Size of the FOV circle in pixels
    teamcheck = false,            -- Whether to ignore players on your team
    wallcheck = false,            -- Whether to check if there's a wall between you and target
    alivecheck = false,           -- Whether to check if target is alive
    lockpart = "Head",            -- Body part to target when on ground
    lockpartair = "Head",         -- Body part to target when in air
    predictionX = 0,              -- Horizontal movement prediction
    predictionY = 0,              -- Vertical movement prediction
    
    -- Controls
    keybind = Enum.UserInputType.MouseButton1, -- Key to activate the aimbot (right mouse button)
    toggle = false,               -- Whether aimbot stays on after releasing key
    alwayson = false,             -- Always on aimbot regardless of keybind
    
    -- Visualization
    showfov = false,              -- Whether to show the FOV circle on screen
    fovcolorlocked = Color3.new(1, 0, 0),   -- FOV circle color when locked onto a target (red)
    fovcolorunlocked = Color3.new(1, 1, 1), -- FOV circle color when not locked (white)
    fovtransparency = 0.6,        -- Transparency of the FOV circle (0-1)
    shadowenabled = true,         -- Enable shadow behind FOV circle
    shadowcolor = Color3.new(0, 0, 0), -- Shadow color (black)
    shadowtransparency = 0.3,     -- Shadow transparency
    shadowsize = 2                -- Shadow size in pixels
}

-- Get necessary game services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Local variables
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local isAiming = false           -- Whether aimbot is currently active
local fovCircle                  -- Drawing object for FOV circle
local fovShadow                  -- Drawing object for FOV shadow
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
        -- Skip if player is self
        if player == LocalPlayer then
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
            -- Wall check
            if dhlock.wallcheck and IsWallBetween(part.Position) then
                continue
            end
            
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

    -- Check if aimbot should be active
    local shouldAim = dhlock.alwayson or holdingKeybind or (dhlock.toggle and isAiming)
    
    if shouldAim then
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

-- Creates or updates the FOV circle visualization and shadow
local function UpdateFovCircle()
    mousePosition = UserInputService:GetMouseLocation()
    
    if dhlock.showfov then
        -- Create or update shadow
        if dhlock.shadowenabled then
            if not fovShadow then
                fovShadow = Drawing.new("Circle")
                fovShadow.Filled = false
                fovShadow.Thickness = 2 + dhlock.shadowsize
                fovShadow.NumSides = 60
            end
            
            fovShadow.Visible = true
            fovShadow.Position = mousePosition
            fovShadow.Radius = dhlock.fov
            fovShadow.Color = dhlock.shadowcolor
            fovShadow.Transparency = dhlock.shadowtransparency
        elseif fovShadow then
            fovShadow.Visible = false
        end
        
        -- Create or update main FOV circle
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
    else
        -- Hide circles if showfov is disabled
        if fovCircle then
            fovCircle.Visible = false
        end
        if fovShadow then
            fovShadow.Visible = false
        end
    end
end

-- Get predicted target position
local function GetPredictedTargetPosition()
    if not lockedPlayer or not lockedPlayer.Character then return nil end
    
    local targetPart = lockedPlayer.Character:FindFirstChild(GetCurrentLockPart())
    if not targetPart then return nil end
    
    -- Calculate predicted position based on velocity
    local targetPosition = targetPart.Position
    if targetPart:IsA("BasePart") then
        targetPosition = targetPosition + targetPart.Velocity * Vector3.new(
            dhlock.predictionX * PREDICTION_MULTIPLIER,
            dhlock.predictionY * PREDICTION_MULTIPLIER,
            dhlock.predictionX * PREDICTION_MULTIPLIER
        )
    end
    
    return targetPosition
end

-- Modified ray creation for silent aim
local function CreateModifiedRay()
    local startPos = Camera.CFrame.Position
    local targetPos = GetPredictedTargetPosition()
    
    if not targetPos then return nil end
    
    local direction = (targetPos - startPos).Unit
    local ray = Ray.new(startPos, direction * 1000)
    
    return ray, startPos, startPos + direction * 1000
end

-- Handle the Raycast method for silent aim
local function HandleRaycast(origin, direction, raycastParams)
    local targetPos = GetPredictedTargetPosition()
    if not targetPos then return direction end
    
    -- Ensure raycastParams exists
    if not raycastParams then
        raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end
    
    -- Modify direction to point to target
    local newDirection = (targetPos - origin).Unit * 1000
    return newDirection
end

-- Handle the FindPartOnRay methods for silent aim
local function HandleFindPartOnRay(ray, ignoreList, terrainCellsAreCubes, ignoreWater)
    -- Ensure local player character is in ignore list
    if typeof(ignoreList) == "table" then
        local hasCharacter = false
        for _, v in pairs(ignoreList) do
            if v == LocalPlayer.Character then
                hasCharacter = true
                break
            end
        end
        if not hasCharacter and LocalPlayer.Character then
            table.insert(ignoreList, LocalPlayer.Character)
        end
    end
    
    local newRay, origin, endPos = CreateModifiedRay()
    if not newRay then return ray end
    
    return newRay
end

-- Handle FindPartOnRayWithWhitelist for silent aim
local function HandleFindPartOnRayWithWhitelist(ray, whitelist, ignoreWater)
    -- If target character is not in whitelist, add relevant parts
    if typeof(whitelist) == "table" and lockedPlayer and lockedPlayer.Character then
        local targetPart = lockedPlayer.Character:FindFirstChild(GetCurrentLockPart())
        if targetPart then
            table.insert(whitelist, targetPart)
        end
    end
    
    local newRay, origin, endPos = CreateModifiedRay()
    if not newRay then return ray end
    
    return newRay
end

-- Handle Mouse.Hit/Target method for silent aim
local function HandleMouseTarget()
    if not Mouse then return nil end
    
    local targetPos = GetPredictedTargetPosition()
    if not targetPos then return nil end
    
    -- This will be used by modifying Mouse.Hit and Mouse.Target properties
    local startPos = Camera.CFrame.Position
    local direction = (targetPos - startPos).Unit
    
    -- Create a CFrame for the modified hit point
    return CFrame.new(targetPos, targetPos + direction)
end

-- Original game functions that we're going to override
local originalFunctions = {}

-- Function to set up our modified versions of game functions
local function SetupFunctionOverrides()
    -- Store original Workspace functions
    originalFunctions.Raycast = Workspace.Raycast
    originalFunctions.FindPartOnRay = Workspace.FindPartOnRay
    originalFunctions.FindPartOnRayWithIgnoreList = Workspace.FindPartOnRayWithIgnoreList
    originalFunctions.FindPartOnRayWithWhitelist = Workspace.FindPartOnRayWithWhitelist
    
    -- Override the Raycast method
    Workspace.Raycast = function(self, origin, direction, raycastParams)
        if self ~= Workspace then
            return originalFunctions.Raycast(self, origin, direction, raycastParams)
        end
        
        if dhlock.enabled and dhlock.silent.enabled and 
           lockedPlayer and lockedPlayer.Character and 
           math.random(1, 100) <= dhlock.silent.hitchance and
           dhlock.silent.methodPriority.raycast then
            
            local newDirection = HandleRaycast(origin, direction, raycastParams)
            return originalFunctions.Raycast(self, origin, newDirection, raycastParams)
        end
        
        return originalFunctions.Raycast(self, origin, direction, raycastParams)
    end
    
    -- Override the FindPartOnRay method
    Workspace.FindPartOnRay = function(self, ray, ignoreDescendantsInstance, terrainCellsAreCubes, ignoreWater)
        if self ~= Workspace then
            return originalFunctions.FindPartOnRay(self, ray, ignoreDescendantsInstance, terrainCellsAreCubes, ignoreWater)
        end
        
        if dhlock.enabled and dhlock.silent.enabled and 
           lockedPlayer and lockedPlayer.Character and 
           math.random(1, 100) <= dhlock.silent.hitchance and
           dhlock.silent.methodPriority.findpart then
            
            local ignoreList = ignoreDescendantsInstance and {ignoreDescendantsInstance} or {}
            local newRay = HandleFindPartOnRay(ray, ignoreList, terrainCellsAreCubes, ignoreWater)
            return originalFunctions.FindPartOnRay(self, newRay, ignoreDescendantsInstance, terrainCellsAreCubes, ignoreWater)
        end
        
        return originalFunctions.FindPartOnRay(self, ray, ignoreDescendantsInstance, terrainCellsAreCubes, ignoreWater)
    end
    
    -- Override the FindPartOnRayWithIgnoreList method
    Workspace.FindPartOnRayWithIgnoreList = function(self, ray, ignoreList, terrainCellsAreCubes, ignoreWater)
        if self ~= Workspace then
            return originalFunctions.FindPartOnRayWithIgnoreList(self, ray, ignoreList, terrainCellsAreCubes, ignoreWater)
        end
        
        if dhlock.enabled and dhlock.silent.enabled and 
           lockedPlayer and lockedPlayer.Character and 
           math.random(1, 100) <= dhlock.silent.hitchance and
           dhlock.silent.methodPriority.findpart then
            
            local newRay = HandleFindPartOnRay(ray, ignoreList, terrainCellsAreCubes, ignoreWater)
            return originalFunctions.FindPartOnRayWithIgnoreList(self, newRay, ignoreList, terrainCellsAreCubes, ignoreWater)
        end
        
        return originalFunctions.FindPartOnRayWithIgnoreList(self, ray, ignoreList, terrainCellsAreCubes, ignoreWater)
    end
    
    -- Override the FindPartOnRayWithWhitelist method
    Workspace.FindPartOnRayWithWhitelist = function(self, ray, whitelist, ignoreWater)
        if self ~= Workspace then
            return originalFunctions.FindPartOnRayWithWhitelist(self, ray, whitelist, ignoreWater)
        end
        
        if dhlock.enabled and dhlock.silent.enabled and 
           lockedPlayer and lockedPlayer.Character and 
           math.random(1, 100) <= dhlock.silent.hitchance and
           dhlock.silent.methodPriority.findpart then
            
            local newRay = HandleFindPartOnRayWithWhitelist(ray, whitelist, ignoreWater)
            return originalFunctions.FindPartOnRayWithWhitelist(self, newRay, whitelist, ignoreWater)
        end
        
        return originalFunctions.FindPartOnRayWithWhitelist(self, ray, whitelist, ignoreWater)
    end
    
    -- Modify Mouse properties
    local mouseMetatable = getmetatable(Mouse)
    if mouseMetatable then
        -- Store original __index function
        originalFunctions.mouseIndex = mouseMetatable.__index
        
        -- Override __index to modify Mouse.Hit and Mouse.Target
        mouseMetatable.__index = function(self, key)
            if dhlock.enabled and dhlock.silent.enabled and 
               lockedPlayer and lockedPlayer.Character and
               math.random(1, 100) <= dhlock.silent.hitchance and
               dhlock.silent.methodPriority.mousehit and
               (key == "Hit" or key == "Target") then
                
                local hitCFrame = HandleMouseTarget()
                if hitCFrame then
                    if key == "Hit" then
                        return hitCFrame
                    else
                        -- For Target, we need to find the actual part at the hit position
                        local targetPos = hitCFrame.Position
                        local ray = Ray.new(Camera.CFrame.Position, (targetPos - Camera.CFrame.Position).Unit * 1000)
                        local part = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character}, false, true)
                        
                        if part then
                            return part
                        end
                    end
                end
            end
            
            return originalFunctions.mouseIndex(self, key)
        end
    end
end

-- Function to restore original functions when script is unloaded
local function RestoreOriginalFunctions()
    -- Restore Workspace functions
    if originalFunctions.Raycast then
        Workspace.Raycast = originalFunctions.Raycast
    end
    
    if originalFunctions.FindPartOnRay then
        Workspace.FindPartOnRay = originalFunctions.FindPartOnRay
    end
    
    if originalFunctions.FindPartOnRayWithIgnoreList then
        Workspace.FindPartOnRayWithIgnoreList = originalFunctions.FindPartOnRayWithIgnoreList
    end
    
    if originalFunctions.FindPartOnRayWithWhitelist then
        Workspace.FindPartOnRayWithWhitelist = originalFunctions.FindPartOnRayWithWhitelist
    end
    
    -- Restore Mouse metatable
    local mouseMetatable = getmetatable(Mouse)
    if mouseMetatable and originalFunctions.mouseIndex then
        mouseMetatable.__index = originalFunctions.mouseIndex
    end
end

-- Set up our function overrides
SetupFunctionOverrides()

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
        if not dhlock.toggle and not dhlock.alwayson then
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
    -- Clean up drawing objects
    if fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
    if fovShadow then
        fovShadow:Remove()
        fovShadow = nil
    end
    
    -- Restore original functions
    RestoreOriginalFunctions()
end)

-- Return destructor to allow proper cleanup
return scriptDestructor
