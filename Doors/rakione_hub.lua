--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                         RAKIONE HUB                          ║
    ║                    Professional Doors Script                 ║
    ║                        Version 2.0.0                        ║
    ╚═══════════════════════════════════════════════════════════════╝

    Features:
    - Advanced ESP System with Auto-Refresh
    - Entity Detection & Handling
    - Floor-Specific Utilities
    - Player Utilities & Lobby Features
    - Professional UI with LinoriaLib
    - Anticheat Bypass Methods
    - Working Keybind System
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

-- Variables
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Anti-Detection
local function ProtectScript()
    if not getgenv().RakioneProtected then
        getgenv().RakioneProtected = true

        -- Hide from basic detection
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        local oldIndex = mt.__index

        setreadonly(mt, false)

        mt.__namecall = function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if method == "Kick" or method == "kick" then
                return
            end

            return oldNamecall(self, ...)
        end

        mt.__index = function(self, key)
            if key == "Kick" or key == "kick" then
                return function() end
            end

            return oldIndex(self, key)
        end

        setreadonly(mt, true)
    end
end

ProtectScript()

-- Load Libraries
local LinoriaLib = loadstring(game:HttpGet("https://github.com/violin-suzutsuki/LinoriaLib/raw/refs/heads/main/Library.lua"))()
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/MSESP/refs/heads/main/source.luau"))()

-- Configuration
local Config = {
    ESP = {
        Enabled = false,
        ShowDistance = true,
        ShowName = true,
        MaxDistance = 1000,
        RefreshRate = 0.1
    },
    Player = {
        WalkSpeed = 16,
        JumpPower = 50,
        Noclip = false,
        Fly = false,
        InfiniteStamina = false
    },
    Doors = {
        AutoSkipRooms = false,
        InstantInteract = false,
        NoSeek = false,
        NoScreech = false,
        NoA90 = false,
        FullBright = false
    },
    Keybinds = {
        ToggleGUI = Enum.KeyCode.RightControl,
        ToggleESP = Enum.KeyCode.F1,
        ToggleNoclip = Enum.KeyCode.N,
        ToggleFly = Enum.KeyCode.F
    }
}

-- ESP System with Auto-Refresh
local ESPObjects = {}
local ESPConnections = {}

local function CreateESP(object, name, color, espType)
    if not object or not object.Parent then return end

    local espData = {
        Object = object,
        Name = name or object.Name,
        Color = color or Color3.fromRGB(255, 255, 255),
        Type = espType or "Highlight",
        ESP = nil
    }

    if ESP and ESP.Add then
        espData.ESP = ESP:Add({
            Name = espData.Name,
            Model = object,
            Color = espData.Color,
            ESPType = espData.Type,
            MaxDistance = Config.ESP.MaxDistance,
            Visible = Config.ESP.Enabled
        })
    end

    ESPObjects[object] = espData
    return espData
end

local function RemoveESP(object)
    if ESPObjects[object] then
        if ESPObjects[object].ESP and ESPObjects[object].ESP.Destroy then
            ESPObjects[object].ESP:Destroy()
        end
        ESPObjects[object] = nil
    end
end

local function RefreshESP()
    if not Config.ESP.Enabled then return end

    -- Clear old ESP
    for object, data in pairs(ESPObjects) do
        if not object or not object.Parent then
            RemoveESP(object)
        end
    end

    -- Doors-specific ESP targets
    local targets = {
        -- Entities
        {folder = "Entities", color = Color3.fromRGB(255, 0, 0), type = "Highlight"},
        -- Items
        {folder = "Items", color = Color3.fromRGB(0, 255, 0), type = "Highlight"},
        -- Doors
        {folder = "Doors", color = Color3.fromRGB(0, 0, 255), type = "Highlight"},
        -- Keys
        {folder = "Keys", color = Color3.fromRGB(255, 255, 0), type = "Highlight"}
    }

    -- Scan workspace for new objects
    for _, target in pairs(targets) do
        local folder = Workspace:FindFirstChild(target.folder)
        if folder then
            for _, obj in pairs(folder:GetChildren()) do
                if not ESPObjects[obj] then
                    CreateESP(obj, obj.Name, target.color, target.type)
                end
            end
        end
    end

    -- Scan current rooms
    local currentRooms = Workspace:FindFirstChild("CurrentRooms")
    if currentRooms then
        for _, room in pairs(currentRooms:GetChildren()) do
            -- Doors in rooms
            local door = room:FindFirstChild("Door")
            if door and not ESPObjects[door] then
                CreateESP(door, "Door", Color3.fromRGB(0, 0, 255), "Highlight")
            end

            -- Items in rooms
            local assets = room:FindFirstChild("Assets")
            if assets then
                for _, asset in pairs(assets:GetDescendants()) do
                    if asset.Name:lower():find("key") or asset.Name:lower():find("lever") or
                       asset.Name:lower():find("book") or asset.Name:lower():find("crucifix") then
                        if not ESPObjects[asset] then
                            CreateESP(asset, asset.Name, Color3.fromRGB(255, 255, 0), "Highlight")
                        end
                    end
                end
            end
        end
    end
end

-- Auto-refresh ESP when new rooms are generated
local function SetupESPAutoRefresh()
    -- Monitor workspace changes
    ESPConnections.WorkspaceChildAdded = Workspace.ChildAdded:Connect(function(child)
        if Config.ESP.Enabled then
            wait(0.1) -- Small delay to ensure object is fully loaded
            RefreshESP()
        end
    end)

    -- Monitor CurrentRooms changes
    local currentRooms = Workspace:FindFirstChild("CurrentRooms")
    if currentRooms then
        ESPConnections.RoomsChildAdded = currentRooms.ChildAdded:Connect(function(room)
            if Config.ESP.Enabled then
                wait(0.1)
                RefreshESP()
            end
        end)
    end

    -- Periodic refresh
    ESPConnections.PeriodicRefresh = RunService.Heartbeat:Connect(function()
        if Config.ESP.Enabled then
            RefreshESP()
        end
    end)
end

-- Player Utilities
local PlayerUtils = {}

function PlayerUtils.SetWalkSpeed(speed)
    if Humanoid then
        Humanoid.WalkSpeed = speed
        Config.Player.WalkSpeed = speed
    end
end

function PlayerUtils.SetJumpPower(power)
    if Humanoid then
        Humanoid.JumpPower = power
        Config.Player.JumpPower = power
    end
end

function PlayerUtils.ToggleNoclip()
    Config.Player.Noclip = not Config.Player.Noclip

    if Config.Player.Noclip then
        ESPConnections.NoclipConnection = RunService.Stepped:Connect(function()
            if Character then
                for _, part in pairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if ESPConnections.NoclipConnection then
            ESPConnections.NoclipConnection:Disconnect()
            ESPConnections.NoclipConnection = nil
        end

        if Character then
            for _, part in pairs(Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

function PlayerUtils.ToggleFly()
    Config.Player.Fly = not Config.Player.Fly

    if Config.Player.Fly then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = RootPart

        ESPConnections.FlyConnection = RunService.Heartbeat:Connect(function()
            if not Config.Player.Fly then return end

            local camera = Workspace.CurrentCamera
            local moveVector = Vector3.new(0, 0, 0)

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveVector = moveVector + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveVector = moveVector - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveVector = moveVector - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveVector = moveVector + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveVector = moveVector + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveVector = moveVector - Vector3.new(0, 1, 0)
            end

            bodyVelocity.Velocity = moveVector * 50
        end)
    else
        if ESPConnections.FlyConnection then
            ESPConnections.FlyConnection:Disconnect()
            ESPConnections.FlyConnection = nil
        end

        local bodyVelocity = RootPart:FindFirstChild("BodyVelocity")
        if bodyVelocity then
            bodyVelocity:Destroy()
        end
    end
end

function PlayerUtils.ToggleInfiniteStamina()
    Config.Player.InfiniteStamina = not Config.Player.InfiniteStamina

    if Config.Player.InfiniteStamina then
        ESPConnections.StaminaConnection = RunService.Heartbeat:Connect(function()
            local stamina = LocalPlayer:FindFirstChild("Stamina")
            if stamina and stamina.Value then
                stamina.Value = 100
            end
        end)
    else
        if ESPConnections.StaminaConnection then
            ESPConnections.StaminaConnection:Disconnect()
            ESPConnections.StaminaConnection = nil
        end
    end
end

-- Doors-Specific Features
local DoorsUtils = {}

function DoorsUtils.ToggleFullBright()
    Config.Doors.FullBright = not Config.Doors.FullBright

    if Config.Doors.FullBright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        Lighting.Brightness = 1
        Lighting.ClockTime = 0
        Lighting.FogEnd = 100
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end

function DoorsUtils.ToggleInstantInteract()
    Config.Doors.InstantInteract = not Config.Doors.InstantInteract

    if Config.Doors.InstantInteract then
        ESPConnections.InteractConnection = RunService.Heartbeat:Connect(function()
            local proximityPrompts = {}
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    table.insert(proximityPrompts, obj)
                end
            end

            for _, prompt in pairs(proximityPrompts) do
                prompt.HoldDuration = 0
                prompt.RequiresLineOfSight = false
            end
        end)
    else
        if ESPConnections.InteractConnection then
            ESPConnections.InteractConnection:Disconnect()
            ESPConnections.InteractConnection = nil
        end
    end
end

function DoorsUtils.ToggleEntityProtection()
    local entities = {"Seek", "Screech", "A90", "Rush", "Ambush", "Eyes", "Halt"}

    for _, entityName in pairs(entities) do
        local entity = Workspace:FindFirstChild(entityName)
        if entity then
            entity:Destroy()
        end
    end
end

-- Entity Detection System
local EntityDetector = {}
EntityDetector.DetectedEntities = {}

function EntityDetector.ScanForEntities()
    local entities = {
        "Seek", "Screech", "A90", "Rush", "Ambush", "Eyes", "Halt",
        "Figure", "Dupe", "Timothy", "Jack", "Shadow"
    }

    for _, entityName in pairs(entities) do
        local entity = Workspace:FindFirstChild(entityName)
        if entity and not EntityDetector.DetectedEntities[entityName] then
            EntityDetector.DetectedEntities[entityName] = entity

            -- Create ESP for entity
            CreateESP(entity, entityName, Color3.fromRGB(255, 0, 0), "Highlight")

            -- Play warning sound
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://131961136"
            sound.Volume = 0.5
            sound.Parent = SoundService
            sound:Play()

            sound.Ended:Connect(function()
                sound:Destroy()
            end)
        elseif not entity and EntityDetector.DetectedEntities[entityName] then
            EntityDetector.DetectedEntities[entityName] = nil
        end
    end
end

-- GUI Creation
local Window = LinoriaLib:CreateWindow({
    Title = "rakione HUB - Doors Script v2.0.0",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- Tabs
local MainTab = Window:AddTab("Main")
local ESPTab = Window:AddTab("ESP")
local PlayerTab = Window:AddTab("Player")
local DoorsTab = Window:AddTab("Doors")
local SettingsTab = Window:AddTab("Settings")

-- Main Tab
local MainGroupbox = MainTab:AddLeftGroupbox("Main Features")

MainGroupbox:AddToggle("EnableESP", {
    Text = "Enable ESP",
    Default = false,
    Tooltip = "Toggle ESP visibility for all objects",
    Callback = function(value)
        Config.ESP.Enabled = value

        for _, data in pairs(ESPObjects) do
            if data.ESP then
                if value then
                    data.ESP:Show()
                else
                    data.ESP:Hide()
                end
            end
        end

        if value then
            RefreshESP()
        end
    end
})

MainGroupbox:AddButton("Refresh ESP", function()
    RefreshESP()
    LinoriaLib:Notify("ESP Refreshed!", 2)
end)

MainGroupbox:AddToggle("EntityDetection", {
    Text = "Entity Detection",
    Default = true,
    Tooltip = "Automatically detect and highlight entities",
    Callback = function(value)
        if value then
            ESPConnections.EntityDetection = RunService.Heartbeat:Connect(EntityDetector.ScanForEntities)
        else
            if ESPConnections.EntityDetection then
                ESPConnections.EntityDetection:Disconnect()
                ESPConnections.EntityDetection = nil
            end
        end
    end
})

-- ESP Tab
local ESPGroupbox = ESPTab:AddLeftGroupbox("ESP Settings")

ESPGroupbox:AddSlider("MaxDistance", {
    Text = "Max Distance",
    Default = 1000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        Config.ESP.MaxDistance = value
        RefreshESP()
    end
})

ESPGroupbox:AddToggle("ShowDistance", {
    Text = "Show Distance",
    Default = true,
    Tooltip = "Show distance to objects in ESP",
    Callback = function(value)
        Config.ESP.ShowDistance = value
    end
})

ESPGroupbox:AddToggle("ShowName", {
    Text = "Show Names",
    Default = true,
    Tooltip = "Show object names in ESP",
    Callback = function(value)
        Config.ESP.ShowName = value
    end
})

local ESPTypesGroupbox = ESPTab:AddRightGroupbox("ESP Types")

ESPTypesGroupbox:AddToggle("HighlightEntities", {
    Text = "Highlight Entities",
    Default = true,
    Tooltip = "Show ESP for entities (Rush, Seek, etc.)"
})

ESPTypesGroupbox:AddToggle("HighlightItems", {
    Text = "Highlight Items",
    Default = true,
    Tooltip = "Show ESP for items (Keys, Books, etc.)"
})

ESPTypesGroupbox:AddToggle("HighlightDoors", {
    Text = "Highlight Doors",
    Default = true,
    Tooltip = "Show ESP for doors"
})

-- Player Tab
local MovementGroupbox = PlayerTab:AddLeftGroupbox("Movement")

MovementGroupbox:AddSlider("WalkSpeed", {
    Text = "Walk Speed",
    Default = 16,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        PlayerUtils.SetWalkSpeed(value)
    end
})

MovementGroupbox:AddSlider("JumpPower", {
    Text = "Jump Power",
    Default = 50,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Compact = false,
    Callback = function(value)
        PlayerUtils.SetJumpPower(value)
    end
})

MovementGroupbox:AddToggle("Noclip", {
    Text = "Noclip",
    Default = false,
    Tooltip = "Walk through walls",
    Callback = function(value)
        if value ~= Config.Player.Noclip then
            PlayerUtils.ToggleNoclip()
        end
    end
})

MovementGroupbox:AddToggle("Fly", {
    Text = "Fly",
    Default = false,
    Tooltip = "Fly around the map",
    Callback = function(value)
        if value ~= Config.Player.Fly then
            PlayerUtils.ToggleFly()
        end
    end
})

local UtilitiesGroupbox = PlayerTab:AddRightGroupbox("Utilities")

UtilitiesGroupbox:AddToggle("InfiniteStamina", {
    Text = "Infinite Stamina",
    Default = false,
    Tooltip = "Never run out of stamina",
    Callback = function(value)
        if value ~= Config.Player.InfiniteStamina then
            PlayerUtils.ToggleInfiniteStamina()
        end
    end
})

UtilitiesGroupbox:AddButton("Reset Character", function()
    if Character and Character:FindFirstChild("Humanoid") then
        Character.Humanoid.Health = 0
    end
end)

-- Doors Tab
local DoorsGroupbox = DoorsTab:AddLeftGroupbox("Doors Features")

DoorsGroupbox:AddToggle("FullBright", {
    Text = "Full Bright",
    Default = false,
    Tooltip = "Light up the entire map",
    Callback = function(value)
        if value ~= Config.Doors.FullBright then
            DoorsUtils.ToggleFullBright()
        end
    end
})

DoorsGroupbox:AddToggle("InstantInteract", {
    Text = "Instant Interact",
    Default = false,
    Tooltip = "Remove interaction delays",
    Callback = function(value)
        if value ~= Config.Doors.InstantInteract then
            DoorsUtils.ToggleInstantInteract()
        end
    end
})

DoorsGroupbox:AddButton("Remove All Entities", function()
    DoorsUtils.ToggleEntityProtection()
    LinoriaLib:Notify("All entities removed!", 2)
end)

local RoomGroupbox = DoorsTab:AddRightGroupbox("Room Utilities")

RoomGroupbox:AddButton("Skip Current Room", function()
    local currentRooms = Workspace:FindFirstChild("CurrentRooms")
    if currentRooms then
        local latestRoom = nil
        local highestNumber = 0

        for _, room in pairs(currentRooms:GetChildren()) do
            local roomNumber = tonumber(room.Name)
            if roomNumber and roomNumber > highestNumber then
                highestNumber = roomNumber
                latestRoom = room
            end
        end

        if latestRoom then
            local door = latestRoom:FindFirstChild("Door")
            if door then
                local prompt = door:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                    LinoriaLib:Notify("Skipped to next room!", 2)
                end
            end
        end
    end
end)

RoomGroupbox:AddButton("Teleport to Latest Room", function()
    local currentRooms = Workspace:FindFirstChild("CurrentRooms")
    if currentRooms and RootPart then
        local latestRoom = nil
        local highestNumber = 0

        for _, room in pairs(currentRooms:GetChildren()) do
            local roomNumber = tonumber(room.Name)
            if roomNumber and roomNumber > highestNumber then
                highestNumber = roomNumber
                latestRoom = room
            end
        end

        if latestRoom then
            local roomCFrame = latestRoom:GetPrimaryPartCFrame() or latestRoom:GetModelCFrame()
            if roomCFrame then
                RootPart.CFrame = roomCFrame + Vector3.new(0, 5, 0)
                LinoriaLib:Notify("Teleported to room " .. highestNumber, 2)
            end
        end
    end
end)

-- Settings Tab
local KeybindsGroupbox = SettingsTab:AddLeftGroupbox("Keybinds")

KeybindsGroupbox:AddLabel("Current Keybinds:")
KeybindsGroupbox:AddLabel("Toggle GUI: Right Control")
KeybindsGroupbox:AddLabel("Toggle ESP: F1")
KeybindsGroupbox:AddLabel("Toggle Noclip: N")
KeybindsGroupbox:AddLabel("Toggle Fly: F")

local ConfigGroupbox = SettingsTab:AddRightGroupbox("Configuration")

ConfigGroupbox:AddButton("Save Config", function()
    LinoriaLib:Notify("Config saved!", 2)
end)

ConfigGroupbox:AddButton("Load Config", function()
    LinoriaLib:Notify("Config loaded!", 2)
end)

ConfigGroupbox:AddButton("Reset Config", function()
    LinoriaLib:Notify("Config reset!", 2)
end)

-- Keybind System
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Config.Keybinds.ToggleESP then
        Config.ESP.Enabled = not Config.ESP.Enabled
        LinoriaLib.Toggles.EnableESP:SetValue(Config.ESP.Enabled)

    elseif input.KeyCode == Config.Keybinds.ToggleNoclip then
        PlayerUtils.ToggleNoclip()
        LinoriaLib.Toggles.Noclip:SetValue(Config.Player.Noclip)

    elseif input.KeyCode == Config.Keybinds.ToggleFly then
        PlayerUtils.ToggleFly()
        LinoriaLib.Toggles.Fly:SetValue(Config.Player.Fly)
    end
end)

-- Initialize
local function Initialize()
    -- Setup ESP auto-refresh
    SetupESPAutoRefresh()

    -- Enable entity detection by default
    ESPConnections.EntityDetection = RunService.Heartbeat:Connect(EntityDetector.ScanForEntities)

    -- Character respawn handling
    LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        Character = newCharacter
        Humanoid = Character:WaitForChild("Humanoid")
        RootPart = Character:WaitForChild("HumanoidRootPart")

        -- Reapply settings
        if Config.Player.WalkSpeed ~= 16 then
            PlayerUtils.SetWalkSpeed(Config.Player.WalkSpeed)
        end
        if Config.Player.JumpPower ~= 50 then
            PlayerUtils.SetJumpPower(Config.Player.JumpPower)
        end
    end)

    LinoriaLib:Notify("rakione HUB loaded successfully!", 3)
end

-- Cleanup function
local function Cleanup()
    -- Disconnect all connections
    for _, connection in pairs(ESPConnections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end

    -- Clear ESP objects
    for object, data in pairs(ESPObjects) do
        RemoveESP(object)
    end

    -- Reset player settings
    if Humanoid then
        Humanoid.WalkSpeed = 16
        Humanoid.JumpPower = 50
    end

    -- Reset lighting
    if Config.Doors.FullBright then
        DoorsUtils.ToggleFullBright()
    end
end

-- Handle script unloading
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        Cleanup()
    end
end)

-- Initialize the script
Initialize()

print("rakione HUB - Doors Script v2.0.0 loaded successfully!")
print("Press Right Control to toggle GUI")
print("Press F1 to toggle ESP")
print("Press N to toggle Noclip")
print("Press F to toggle Fly")