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
        ToggleFly = Enum.KeyCode.F,
        ToggleAutoInteract = Enum.KeyCode.I,
        RefreshESP = Enum.KeyCode.R
    }
}

-- ESP System with Auto-Refresh and Smart Filtering
local ESPObjects = {}
local ESPConnections = {}

-- Smart item detection lists
local ImportantItems = {
    -- Keys
    "Key", "ElectricalRoomKey", "SkeletonKey", "RoomKey", "LibraryHallwayDoor",
    -- Tools
    "Lockpick", "Flashlight", "Candle", "Lighter", "Scanner", "Crucifix",
    -- Consumables
    "Vitamins", "Bandage", "Battery", "Batteries",
    -- Books and Papers
    "LibraryHintPaper", "Book", "Paper", "Hint",
    -- Interactive Objects
    "Lever", "Button", "Switch", "Valve", "Fuse", "Painting",
    -- Special Items
    "Herb", "Potion", "Shakelight", "Gloombat"
}

local EntityNames = {
    "Seek", "Screech", "A90", "Rush", "Ambush", "Eyes", "Halt",
    "Figure", "Dupe", "Timothy", "Jack", "Shadow", "Glitch", "Window"
}

local InteractableObjects = {
    "Door", "Drawer", "Wardrobe", "Closet", "Chest", "Cabinet",
    "Lever", "Button", "Switch", "Valve"
}

-- Filter function to avoid lag from unnecessary objects
local function ShouldESPObject(object)
    if not object or not object.Parent then return false end

    local name = object.Name:lower()

    -- Skip common props that cause lag
    local skipPatterns = {
        "mesh", "meshpart", "part", "union", "wedge", "cylinder", "sphere",
        "decal", "texture", "surfacegui", "billboardgui", "light", "sound",
        "script", "localscript", "modulescript", "folder", "model",
        "attachment", "weld", "motor6d", "humanoid", "bodyposition"
    }

    for _, pattern in pairs(skipPatterns) do
        if name:find(pattern) and not name:find("door") and not name:find("key") then
            return false
        end
    end

    -- Check if it's an important item
    for _, item in pairs(ImportantItems) do
        if name:find(item:lower()) then
            return true
        end
    end

    -- Check if it's an entity
    for _, entity in pairs(EntityNames) do
        if name:find(entity:lower()) then
            return true
        end
    end

    -- Check if it's interactable
    for _, interactable in pairs(InteractableObjects) do
        if name:find(interactable:lower()) then
            return true
        end
    end

    -- Check if it has a ProximityPrompt (likely interactable)
    if object:FindFirstChildOfClass("ProximityPrompt") then
        return true
    end

    return false
end

local function GetItemDisplayName(object)
    local name = object.Name

    -- Clean up common naming patterns
    name = name:gsub("_", " ")
    name = name:gsub("([a-z])([A-Z])", "%1 %2") -- Add space before capitals

    -- Specific item name mappings
    local nameMap = {
        ["ElectricalRoomKey"] = "Electrical Room Key",
        ["LibraryHintPaper"] = "Library Hint",
        ["SkeletonKey"] = "Skeleton Key",
        ["LibraryHallwayDoor"] = "Library Door",
        ["Shakelight"] = "Shake Light"
    }

    return nameMap[object.Name] or name
end

local function GetItemColor(object)
    local name = object.Name:lower()

    -- Color coding by item type
    if name:find("key") then
        return Color3.fromRGB(255, 215, 0) -- Gold for keys
    elseif name:find("door") then
        return Color3.fromRGB(0, 150, 255) -- Blue for doors
    elseif name:find("lever") or name:find("button") or name:find("switch") then
        return Color3.fromRGB(255, 165, 0) -- Orange for controls
    elseif name:find("book") or name:find("paper") or name:find("hint") then
        return Color3.fromRGB(160, 82, 45) -- Brown for books/papers
    elseif name:find("flashlight") or name:find("candle") or name:find("lighter") then
        return Color3.fromRGB(255, 255, 0) -- Yellow for light sources
    elseif name:find("crucifix") then
        return Color3.fromRGB(255, 255, 255) -- White for crucifix
    elseif name:find("vitamins") or name:find("bandage") then
        return Color3.fromRGB(0, 255, 0) -- Green for healing items
    else
        -- Check if it's an entity
        for _, entity in pairs(EntityNames) do
            if name:find(entity:lower()) then
                return Color3.fromRGB(255, 0, 0) -- Red for entities
            end
        end
        return Color3.fromRGB(255, 255, 255) -- White for other items
    end
end

local function CreateESP(object, customName, customColor, espType)
    if not object or not object.Parent or not ShouldESPObject(object) then return end

    local displayName = customName or GetItemDisplayName(object)
    local color = customColor or GetItemColor(object)

    local espData = {
        Object = object,
        Name = displayName,
        Color = color,
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
            Visible = Config.ESP.Enabled,
            FillTransparency = 0.7,
            OutlineTransparency = 0
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

    -- Clear old ESP for objects that no longer exist
    for object, data in pairs(ESPObjects) do
        if not object or not object.Parent then
            RemoveESP(object)
        end
    end

    -- Scan current rooms for items
    local currentRooms = Workspace:FindFirstChild("CurrentRooms")
    if currentRooms then
        for _, room in pairs(currentRooms:GetChildren()) do
            -- Scan all descendants but filter smartly
            for _, obj in pairs(room:GetDescendants()) do
                if not ESPObjects[obj] and ShouldESPObject(obj) then
                    CreateESP(obj)
                end
            end
        end
    end

    -- Scan workspace for entities and important objects
    for _, obj in pairs(Workspace:GetChildren()) do
        if not ESPObjects[obj] and ShouldESPObject(obj) then
            CreateESP(obj)
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

-- Auto-Interact System
local AutoInteract = {
    Enabled = false,
    Range = 20,
    Blacklist = {
        "Door", "NextArea", "MainDoor" -- Don't auto-interact with doors to avoid skipping rooms
    }
}

function AutoInteract.Toggle()
    AutoInteract.Enabled = not AutoInteract.Enabled

    if AutoInteract.Enabled then
        ESPConnections.AutoInteractConnection = RunService.Heartbeat:Connect(function()
            if not RootPart then return end

            local currentRooms = Workspace:FindFirstChild("CurrentRooms")
            if not currentRooms then return end

            for _, room in pairs(currentRooms:GetChildren()) do
                for _, obj in pairs(room:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        local parent = obj.Parent
                        if not parent then continue end

                        -- Check if object is in blacklist
                        local isBlacklisted = false
                        for _, blacklisted in pairs(AutoInteract.Blacklist) do
                            if parent.Name:lower():find(blacklisted:lower()) then
                                isBlacklisted = true
                                break
                            end
                        end

                        if isBlacklisted then continue end

                        -- Check distance
                        local objPosition = parent:GetPivot().Position
                        local distance = (RootPart.Position - objPosition).Magnitude

                        if distance <= AutoInteract.Range then
                            -- Check if it's a useful item to interact with
                            local objName = parent.Name:lower()
                            local shouldInteract = false

                            -- Items worth auto-collecting
                            local autoCollectItems = {
                                "key", "flashlight", "lockpick", "crucifix", "vitamins",
                                "bandage", "battery", "candle", "lighter", "book", "lever",
                                "button", "switch", "valve", "drawer", "wardrobe", "closet"
                            }

                            for _, item in pairs(autoCollectItems) do
                                if objName:find(item) then
                                    shouldInteract = true
                                    break
                                end
                            end

                            if shouldInteract and obj.Enabled then
                                -- Small delay to avoid spam
                                wait(0.1)
                                fireproximityprompt(obj)
                            end
                        end
                    end
                end
            end
        end)
    else
        if ESPConnections.AutoInteractConnection then
            ESPConnections.AutoInteractConnection:Disconnect()
            ESPConnections.AutoInteractConnection = nil
        end
    end
end

function AutoInteract.SetRange(range)
    AutoInteract.Range = range
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

ESPTypesGroupbox:AddToggle("HighlightInteractables", {
    Text = "Highlight Interactables",
    Default = true,
    Tooltip = "Show ESP for levers, buttons, drawers, etc."
})

local ESPFiltersGroupbox = ESPTab:AddLeftGroupbox("ESP Filters")

ESPFiltersGroupbox:AddButton("Clear All ESP", function()
    for object, data in pairs(ESPObjects) do
        RemoveESP(object)
    end
    LinoriaLib:Notify("All ESP cleared!", 2)
end)

ESPFiltersGroupbox:AddButton("Refresh ESP Now", function()
    RefreshESP()
    LinoriaLib:Notify("ESP refreshed manually!", 2)
end)

ESPFiltersGroupbox:AddLabel("ESP will auto-refresh when new rooms are generated")

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

DoorsGroupbox:AddToggle("AutoInteract", {
    Text = "Auto Interact",
    Default = false,
    Tooltip = "Automatically interact with nearby items",
    Callback = function(value)
        if value ~= AutoInteract.Enabled then
            AutoInteract.Toggle()
        end
    end
})

DoorsGroupbox:AddSlider("AutoInteractRange", {
    Text = "Auto Interact Range",
    Default = 20,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Tooltip = "Range for auto-interact (studs)",
    Callback = function(value)
        AutoInteract.SetRange(value)
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
KeybindsGroupbox:AddLabel("Toggle Auto-Interact: I")
KeybindsGroupbox:AddLabel("Refresh ESP: R")

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
        LinoriaLib:Notify("ESP " .. (Config.ESP.Enabled and "Enabled" or "Disabled"), 1)

    elseif input.KeyCode == Config.Keybinds.ToggleNoclip then
        PlayerUtils.ToggleNoclip()
        LinoriaLib.Toggles.Noclip:SetValue(Config.Player.Noclip)
        LinoriaLib:Notify("Noclip " .. (Config.Player.Noclip and "Enabled" or "Disabled"), 1)

    elseif input.KeyCode == Config.Keybinds.ToggleFly then
        PlayerUtils.ToggleFly()
        LinoriaLib.Toggles.Fly:SetValue(Config.Player.Fly)
        LinoriaLib:Notify("Fly " .. (Config.Player.Fly and "Enabled" or "Disabled"), 1)

    elseif input.KeyCode == Config.Keybinds.ToggleAutoInteract then
        AutoInteract.Toggle()
        LinoriaLib.Toggles.AutoInteract:SetValue(AutoInteract.Enabled)
        LinoriaLib:Notify("Auto-Interact " .. (AutoInteract.Enabled and "Enabled" or "Disabled"), 1)

    elseif input.KeyCode == Config.Keybinds.RefreshESP then
        RefreshESP()
        LinoriaLib:Notify("ESP Refreshed!", 1)
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
print("=== KEYBINDS ===")
print("Right Control - Toggle GUI")
print("F1 - Toggle ESP")
print("N - Toggle Noclip")
print("F - Toggle Fly")
print("I - Toggle Auto-Interact")
print("R - Refresh ESP")
print("================")
print("ESP now filters out lag-causing objects and auto-refreshes!")
print("Auto-Interact will collect nearby items automatically!")
