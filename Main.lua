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

local function UpdateKeybind(newKeybind)
    if IsValidKeybind(newKeybind) then
        dhlock.keybind = newKeybind
        RebindKeybind()
    end
end

local function CreateFOVCircle()
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 2
        fovCircle.NumSides = 64
        fovCircle.Filled = false
    end
end

local function UpdateFOVCircle()
    CreateFOVCircle()
    fovCircle.Visible = dhlock.showfov
    fovCircle.Position = UserInputService:GetMouseLocation()
    fovCircle.Radius = dhlock.fov
    fovCircle.Transparency = dhlock.fovtransparency
    if lockedPlayer then
        fovCircle.Color = dhlock.fovcolorlocked
    else
        fovCircle.Color = dhlock.fovcolorunlocked
    end
end

local function ResetState()
    lockedPlayer = nil
    lastLockedPosition = nil
    isAiming = false
end

local function RebindKeybind()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) and IsValidKeybind(dhlock.keybind) then
            if dhlock.toggle then
                isAiming = not isAiming
                if not isAiming then
                    ResetState()
                end
            else
                holdingKeybind = true
                isAiming = true
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == dhlock.keybind or input.KeyCode == dhlock.keybind) and IsValidKeybind(dhlock.keybind) then
            holdingKeybind = false
            if not dhlock.toggle then
                isAiming = false
                ResetState()
            end
        end
    end)
end

RunService.RenderStepped:Connect(function()
    UpdateFOVCircle()

    if dhlock.enabled then
        if dhlock.toggle then
            isAiming = isAiming or holdingKeybind
        else
            isAiming = holdingKeybind
        end

        if isAiming and lockedPlayer and lockedPlayer.Character and lockedPlayer.Character:FindFirstChild("Head") then

        elseif isAiming then
            lockedPlayer = GetClosestPlayer()
        else
            ResetState()
        end
    end
end)
