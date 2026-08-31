local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TwSrv = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Remote & Module References
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 10)
if not GameEvents then 
    warn("Opex Hub: GameEvents folder not found!") 
    return 
end

local BuyEggRemote = GameEvents:WaitForChild("BuyPetEgg", 5)
local BuySeedRemote = GameEvents:WaitForChild("BuySeedStock", 5)
local SellRemote = GameEvents:WaitForChild("Sell_Inventory", 5)
local BuyGearRemote = GameEvents:WaitForChild("BuyGearStock", 5)

-- Precise Beanstalk Event Remote Finder
local function getBeanstalkSubmitRemote()
    if not GameEvents then return nil end
    local ev = GameEvents:FindFirstChild("Events")
    if ev and ev:FindFirstChild("BeanstalkEvent") then
        return ev.BeanstalkEvent:FindFirstChild("BeanstalkRESubmitAllPlant")
    end
    for _, desc in ipairs(GameEvents:GetDescendants()) do
        if desc:IsA("RemoteEvent") and (desc.Name:find("Submit") or desc.Name:find("Beanstalk")) then
            return desc
        end
    end
    return nil
end

-- Enhanced Craving Reader using decompiled CravingUtils logic
local function getBeanstalkCraving()
    -- Try to find the configuration object (contains Options, Interval, HashNum)
    local config = nil

    -- Helper to validate a config table
    local function isValidConfig(tbl)
        return type(tbl) == "table" and type(tbl.Options) == "table" and #tbl.Options > 0
    end

    -- 1. Search for any Instance that directly contains "Options" and "Interval"
    for _, instance in ipairs(ReplicatedStorage:GetDescendants()) do
        local optionsChild = instance:FindFirstChild("Options")
        local intervalChild = instance:FindFirstChild("Interval")
        if optionsChild and intervalChild then
            local options = {}
            if optionsChild:IsA("Folder") or optionsChild:IsA("Configuration") then
                for _, child in ipairs(optionsChild:GetChildren()) do
                    if child:IsA("StringValue") then
                        table.insert(options, child.Value)
                    elseif child:IsA("ValueBase") then
                        table.insert(options, tostring(child.Value))
                    else
                        table.insert(options, child.Name)
                    end
                end
            elseif optionsChild:IsA("StringValue") then
                table.insert(options, optionsChild.Value)
            elseif optionsChild:IsA("ValueBase") then
                table.insert(options, tostring(optionsChild.Value))
            end
            if #options > 0 then
                config = {
                    Options = options,
                    Interval = intervalChild.Value or 3600,
                    HashNum = instance:FindFirstChild("HashNum") and instance.HashNum.Value or 2654435,
                }
                break
            end
        end
    end

    -- 2. If not found, search for ModuleScripts that return a valid config
    if not config then
        for _, moduleScript in ipairs(ReplicatedStorage:GetDescendants()) do
            if moduleScript:IsA("ModuleScript") then
                local ok, data = pcall(require, moduleScript)
                if ok and isValidConfig(data) then
                    config = data
                    break
                end
            end
        end
    end

    -- 3. Fallback to a default config with common crops
    if not config then
        config = {
            Options = { "Carrot", "Tomato", "Corn", "Strawberry", "Blueberry", "Watermelon", "Buttercup", "Daffodil" },
            Interval = 3600,
            HashNum = 2654435,
        }
    end

    -- Now compute the current craving using the same algorithm as CravingUtils
    local function pickCraving(seed, cfg)
        local options = cfg.Options
        local count = #options
        if count == 0 then return "" end
        if count == 1 then return options[1] end
        local hashNum = cfg.HashNum or 2654435
        local v7 = (seed - 1) * hashNum % 2147483647 * 48271 % 2147483647 % count + 1
        local v8 = seed * hashNum % 2147483647 * 48271 % 2147483647 % count + 1
        if v8 == v7 then
            v8 = v8 % count + 1
        end
        return options[v8]
    end

    local interval = config.Interval or 3600
    local currentTime = workspace:GetServerTimeNow()
    local seed = math.floor(currentTime / interval)
    local craving = pickCraving(seed, config)
    return tostring(craving)
end

-- Helper: Get plant type from a ProximityPrompt (based on ancestor model name)
local function getPlantTypeFromPrompt(prompt)
    local model = prompt:FindFirstAncestorWhichIsA("Model")
    if model then
        return model.Name
    end
    return prompt.Parent and prompt.Parent.Name or ""
end

-- Load WindUI Library
local Success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not Success or not WindUI then
    warn("Opex Hub: Failed to load WindUI library.")
    return
end

-- Custom Solid Blue Theme
WindUI:AddTheme({
    Name = "OpexBlue",
    Accent = Color3.fromRGB(0, 160, 255),
    Outline = Color3.fromRGB(0, 110, 230),
    Text = Color3.fromRGB(255, 255, 255),
    PlaceholderText = Color3.fromRGB(180, 210, 255),
    Background = Color3.fromRGB(12, 32, 68),
    Window = Color3.fromRGB(18, 45, 95),
    Tab = Color3.fromRGB(25, 60, 125),
    Element = Color3.fromRGB(32, 70, 145)
})

-- Create Window (Bigger UI)
local Window = WindUI:CreateWindow({
    Title = "Opex Hub | Grow a Garden",
    Author = "Tu_papi",
    Folder = "OpexHubConfig",
    Size = UDim2.fromOffset(650, 580),  -- Increased size
    Transparent = false,
    Theme = "OpexBlue"
})

-- UI Tabs
local MainTab = Window:Tab({ Title = "Main", Icon = "home" })
local FarmTab = Window:Tab({ Title = "Auto Farm", Icon = "sprout" })
local EventTab = Window:Tab({ Title = "Event", Icon = "calendar" })
local ShopTab = Window:Tab({ Title = "Shop", Icon = "shopping-bag" })
local SellTab = Window:Tab({ Title = "Sell", Icon = "dollar-sign" })

-- ===== STATE VARIABLES =====
local AutoFarm = false
local FastTween = true
local AutoSell = false

local AutoBeanstalk = false
local UserMaxCapacity = 20

local AntiAFK = true
local InfiniteJump = false
local Noclip = false
local WalkSpeedVal = 16
local JumpPowerVal = 50

local SelectedSeed = "Carrot Seed"
local AutoBuySeed = false

local SelectedGear = "Watering Can"
local AutoBuyGear = false

local SelectedEgg = "Common Egg"
local AutoBuyEgg = false

-- Item Lists
local SeedsList = { "Carrot Seed", "Strawberry Seed", "Blueberry Seed", "Buttercup Seed", "Tomato Seed", "Corn Seed", "Daffodil Seed", "Watermelon Seed" }
local GearsList = { "Watering Can", "Basic Sprinkler", "Advanced Sprinkler", "Godly Sprinkler" }
local EggsList = { "Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg" }

-- ===== HELPER FUNCTIONS =====
local function isInventoryFull()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        return #backpack:GetChildren() >= UserMaxCapacity
    end
    return false
end

local lastNotifyTime = 0
local function NotifyPurchase(itemName, forceInstant)
    local currentTime = tick()
    if forceInstant or (currentTime - lastNotifyTime >= 4) then
        Window:Notification({ Title = "🛍️ Purchase Successful!", Text = "Bought: " .. itemName, Duration = 2.5 })
        lastNotifyTime = currentTime
    end
end

local function findFarm()
    local farmFolder = workspace:FindFirstChild("Farm")
    if not farmFolder then return nil end

    for _, farm in ipairs(farmFolder:GetChildren()) do
        if farm.Name == "Farm" then
            local important = farm:FindFirstChild("Important")
            local data = important and important:FindFirstChild("Data")
            local owner = data and data:FindFirstChild("Owner")
            if owner and owner:IsA("StringValue") and owner.Value == LocalPlayer.Name then
                return farm
            end
        end
    end
    return nil
end

local function getPrompts(farm)
    local prompts = {}
    local important = farm and farm:FindFirstChild("Important")
    local plants = important and important:FindFirstChild("Plants_Physical")
    if not plants then return prompts end

    for _, obj in ipairs(plants:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            table.insert(prompts, obj)
        end
    end
    return prompts
end

local function FastMove(prompt)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not prompt:IsDescendantOf(workspace) then return end

    local part = prompt.Parent
    if not part:IsA("BasePart") then part = prompt:FindFirstAncestorWhichIsA("BasePart") end
    if not part then return end

    if FastTween then
        local distance = (root.Position - part.Position).Magnitude
        local duration = math.clamp(distance / 350, 0.01, 0.15)
        local tween = TwSrv:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            CFrame = part.CFrame + Vector3.new(0, 3, 0)
        })
        tween:Play()
        tween.Completed:Wait()
    else
        root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
    end

    if prompt:IsDescendantOf(workspace) and prompt.Enabled then
        fireproximityprompt(prompt)
    end
end

local function submitBeanstalkPlants()
    local remote = getBeanstalkSubmitRemote()
    if remote then
        pcall(function() remote:FireServer() end)
    end
end

-- ===== MAIN TAB =====
MainTab:Section({ Title = "Opex Hub - Grow a Garden" })
MainTab:Paragraph({
    Title = "Version v3.5",
    Desc = "• Updated CravingUtils logic to search for actual crop name instead of 'Active' state."
})

MainTab:Section({ Title = "Player Information" })
local executorName = "Unknown"
if identifyexecutor then executorName = identifyexecutor()
elseif getexecutorname then executorName = getexecutorname() end

MainTab:Paragraph({ Title = "Username", Desc = LocalPlayer.Name })
MainTab:Paragraph({ Title = "Executor", Desc = executorName })
MainTab:Paragraph({ Title = "Server ID", Desc = game.JobId })

MainTab:Section({ Title = "Player Character Tweaks" })
MainTab:Slider({
    Title = "WalkSpeed",
    Step = 1,
    Min = 16,
    Max = 200,
    Default = 16,
    Callback = function(v) WalkSpeedVal = v end
})
MainTab:Slider({
    Title = "JumpPower",
    Step = 1,
    Min = 50,
    Max = 300,
    Default = 50,
    Callback = function(v) JumpPowerVal = v end
})
MainTab:Toggle({
    Title = "Infinite Jump",
    Value = false,
    Callback = function(v) InfiniteJump = v end
})
MainTab:Toggle({
    Title = "Noclip",
    Value = false,
    Callback = function(v) Noclip = v end
})
MainTab:Toggle({
    Title = "Anti-AFK",
    Value = true,
    Callback = function(v) AntiAFK = v end
})

MainTab:Section({ Title = "Server Actions" })
MainTab:Button({
    Title = "Rejoin Server",
    Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
})
MainTab:Button({
    Title = "Server Hop",
    Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
})

-- ===== FARM TAB =====
FarmTab:Section({ Title = "Auto Farm Controls" })
FarmTab:Toggle({
    Title = "Auto Farm All Crops",
    Desc = "Tweens to crops in YOUR garden and triggers ProximityPrompts",
    Value = false,
    Callback = function(Value) AutoFarm = Value end
})
FarmTab:Toggle({
    Title = "Ultra Fast Movement",
    Desc = "Speeds up tweening to harvest plants instantly",
    Value = true,
    Callback = function(Value) FastTween = Value end
})

-- ===== EVENT TAB =====
EventTab:Section({ Title = "Beanstalk Event Info" })

local CravingParagraph = EventTab:Paragraph({
    Title = "Current Beanstalk Craving",
    Desc = "Loading Craving..."
})

-- Update craving display immediately and then every 3 seconds
local function updateCravingDisplay()
    local craving = getBeanstalkCraving()
    if craving and craving ~= "" then
        CravingParagraph:SetDesc("NPC Wants: " .. craving)
    else
        CravingParagraph:SetDesc("NPC Wants: Unknown")
    end
end
task.spawn(updateCravingDisplay)
task.spawn(function()
    while task.wait(3) do
        updateCravingDisplay()
    end
end)

EventTab:Slider({
    Title = "Your Max Inventory Capacity",
    Desc = "Slide this to match your exact bag size so it submits accurately!",
    Step = 1,
    Min = 5,
    Max = 150,
    Default = 20,
    Callback = function(Value) UserMaxCapacity = Value end
})

EventTab:Toggle({
    Title = "Auto Grow Beanstalk",
    Desc = "Collects crops and submits automatically when your backpack hits the set limit",
    Value = false,
    Callback = function(Value) AutoBeanstalk = Value end
})

EventTab:Button({
    Title = "Force Submit Inventory Now",
    Callback = function()
        submitBeanstalkPlants()
        Window:Notification({ Title = "Beanstalk Event", Text = "Fired Submit Remote!", Duration = 2.5 })
    end
})

-- ===== SHOP TAB =====
ShopTab:Section({ Title = "Seed Shop" })
ShopTab:Dropdown({ Title = "Select Seed", Values = SeedsList, Value = "Carrot Seed", Callback = function(Opt) SelectedSeed = Opt end })
ShopTab:Toggle({ Title = "Auto Buy Selected Seed", Value = false, Callback = function(Val) AutoBuySeed = Val end })

ShopTab:Section({ Title = "Gear Shop" })
ShopTab:Dropdown({ Title = "Select Gear", Values = GearsList, Value = "Watering Can", Callback = function(Opt) SelectedGear = Opt end })
ShopTab:Toggle({ Title = "Auto Buy Selected Gear", Value = false, Callback = function(Val) AutoBuyGear = Val end })

ShopTab:Section({ Title = "Pet Egg Shop" })
ShopTab:Dropdown({ Title = "Select Egg", Values = EggsList, Value = "Common Egg", Callback = function(Opt) SelectedEgg = Opt end })
ShopTab:Toggle({ Title = "Auto Buy Selected Egg", Value = false, Callback = function(Val) AutoBuyEgg = Val end })

-- ===== SELL TAB =====
SellTab:Section({ Title = "Sell Inventory" })
SellTab:Button({
    Title = "Sell Inventory Now",
    Callback = function() if SellRemote then SellRemote:FireServer() end end
})
SellTab:Toggle({
    Title = "Auto Sell Inventory",
    Value = false,
    Callback = function(Value) AutoSell = Value end
})

-- ===== BACKGROUND LOOPS & CONNECTIONS =====

-- Character Tweaks Loop
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if hum.WalkSpeed ~= WalkSpeedVal then hum.WalkSpeed = WalkSpeedVal end
                if hum.JumpPower ~= JumpPowerVal then hum.JumpPower = JumpPowerVal end
            end
            if Noclip then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end
end)

-- Infinite Jump Hook
UserInputService.JumpRequest:Connect(function()
    if InfiniteJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Anti-AFK Hook
LocalPlayer.Idled:Connect(function()
    if AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Standard Auto Farm Loop
task.spawn(function()
    while task.wait(0.2) do
        if AutoFarm then
            local currFarm = findFarm()
            if currFarm then
                local prompts = getPrompts(currFarm)
                for _, prompt in ipairs(prompts) do
                    if not AutoFarm then break end
                    if prompt:IsDescendantOf(currFarm) and prompt.Enabled then
                        FastMove(prompt)
                        task.wait(0.05)
                    end
                end
            end
        end
    end
end)

-- Single Auto Beanstalk Loop (Craving‑Aware)
task.spawn(function()
    while task.wait(0.5) do
        if AutoBeanstalk then
            local craving = getBeanstalkCraving()
            local cravingLower = craving:lower()

            -- Submit if inventory full
            if isInventoryFull() then
                submitBeanstalkPlants()
                task.wait(0.5)
            end

            local currFarm = findFarm()
            if currFarm then
                local allPrompts = getPrompts(currFarm)
                local cravingPrompts = {}

                -- Filter prompts by craving
                for _, prompt in ipairs(allPrompts) do
                    if not AutoBeanstalk then break end
                    local plantName = getPlantTypeFromPrompt(prompt):lower()
                    if plantName:find(cravingLower, 1, true) then
                        table.insert(cravingPrompts, prompt)
                    end
                end

                -- Farm only the matching prompts
                for _, prompt in ipairs(cravingPrompts) do
                    if not AutoBeanstalk then break end
                    if prompt:IsDescendantOf(currFarm) and prompt.Enabled then
                        FastMove(prompt)
                        if isInventoryFull() then
                            submitBeanstalkPlants()
                            task.wait(0.2)
                        end
                        task.wait(0.05)
                    end
                end

                -- After farming all craving plants, submit once more
                submitBeanstalkPlants()
            end
        end
    end
end)

-- Shop & Sell Loops
task.spawn(function()
    while task.wait(0.5) do
        if AutoBuySeed and SelectedSeed ~= "" and BuySeedRemote then 
            local cleanSeedName = SelectedSeed:gsub(" Seed", "")
            BuySeedRemote:FireServer("Shop", cleanSeedName)
            NotifyPurchase(cleanSeedName, false)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if AutoBuyGear and SelectedGear ~= "" and BuyGearRemote then 
            BuyGearRemote:FireServer(SelectedGear)
            NotifyPurchase(SelectedGear, false)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if AutoBuyEgg and SelectedEgg ~= "" and BuyEggRemote then 
            BuyEggRemote:FireServer(SelectedEgg)
            NotifyPurchase(SelectedEgg, false)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if AutoSell and SellRemote then 
            SellRemote:FireServer() 
        end
    end
end)
