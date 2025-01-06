getgenv().dhlock = {
    enabled = false,
    showfov = false,
    fov = 50,
    keybind = Enum.UserInputType.MouseButton2,
    teamcheck = false,
    wallcheck = false,
    alivecheck = false,
    lockpart = "Head",
    lockpartair = "HumanoidRootPart",
    smoothness = 1,
    predictionX = 0,
    predictionY = 0,
    fovcolorlocked = Color3.new(1, 0, 0),
    fovcolorunlocked = Color3.new(0, 0, 0),
    fovtransparency = 0.6,
    toggle = false,
    blacklist = {}
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local isAiming = false
local fovCircle
local lockedPlayer = nil
local holdingKeybind = false
local lastLockedPosition = nil

local function IsValidKeybind(input)
    return typeof(input) == "EnumItem" and (input.EnumType == Enum.KeyCode or input.EnumType == Enum.UserInputType)
end

local function GetCurrentLockPart()
    local character = LocalPlayer.Character
    if not character then return dhlock.lockpart end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local lockPartName = dhlock.lockpart
    if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
        lockPartName = dhlock.lockpartair
    end

    if character:FindFirstChild(lockPartName) then
        return lockPartName
    else
        return "Head"
    end
end

local function IsPlayerAlive(player)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(GetCurrentLockPart()) and not table.find(dhlock.blacklist, player.Name) then
            if (not dhlock.alivecheck or IsPlayerAlive(player)) and
               (not dhlock.teamcheck or player.Team ~= LocalPlayer.Team) then

                local part = player.Character:FindFirstChild(GetCurrentLockPart())
                local screenPoint, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(part.Position)
                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePosition).Magnitude

                if onScreen and distance <= dhlock.fov and distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end

    return closestPlayer
end

local function SmoothAimAtPlayer(player)
    if not player or not player.Character then return end

    local part = player.Character:FindFirstChild(GetCurrentLockPart())
    if not part then return end

    local camera = Workspace.CurrentCamera
    local targetCFrame = CFrame.lookAt(camera.CFrame.Position, part.Position)
    local smoothnessFactor = 1 / math.max(dhlock.smoothness, 1e-5)

    camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothnessFactor)
end

local function HandleAim()
    if not dhlock.enabled then return end

    if holdingKeybind or (dhlock.toggle and isAiming) then
        if not lockedPlayer or not lockedPlayer.Character or not lockedPlayer.Character:FindFirstChild(GetCurrentLockPart()) then
            lockedPlayer = GetClosestPlayer()
        end

        if lockedPlayer then
            SmoothAimAtPlayer(lockedPlayer)
        end
    else
        lockedPlayer = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) and IsValidKeybind(dhlock.keybind) then
        holdingKeybind = true
        if dhlock.toggle then
            isAiming = not isAiming
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) and IsValidKeybind(dhlock.keybind) then
        holdingKeybind = false
    end
end)

RunService.RenderStepped:Connect(function()
    HandleAim()
end)
