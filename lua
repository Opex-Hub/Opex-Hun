--//========================= SERVICES & LOCALS =========================//
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local CommF_      = Remotes:WaitForChild("CommF_")

local Actions = Opex.Actions
local Settings = Opex.Settings
local Module   = Opex.Module
local Data     = Opex.Data

--//========================= HELPER FUNCTIONS =========================//

function Module:FireInvoke(name, ...)
    local args = { ... }
    local ok, res = pcall(function()
        return CommF_:InvokeServer(name, table.unpack(args))
    end)
    return ok and res or nil
end

function Module:FireEvent(name, ...)
    local ev = Remotes:FindFirstChild(name)
    if ev and ev:IsA("RemoteEvent") then
        ev:FireServer(...)
    end
end

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getChar()
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local char = getChar()
    return char:FindFirstChildOfClass("Humanoid")
end

-- Tween the local player to a CFrame (works with BypassTP)
function Actions.TweenTo(cf, speed)
    local hrp = getHRP()
    if not hrp then return end
    speed = speed or (Settings.TweenSpeed or 200)
    local dist = (hrp.Position - cf.Position).Magnitude
    local t = dist / speed
    if t <= 0 then return end
    local info = TweenInfo.new(t, Enum.EasingStyle.Linear)
    local goal = { CFrame = cf }
    if Settings.BypassTP and dist > 300 then
        -- Bypass TP: split into small steps
        for i = 1, math.ceil(dist / 100) do
            local alpha = i / math.ceil(dist / 100)
            local step = hrp.CFrame:Lerp(cf, alpha)
            hrp.CFrame = step
            task.wait(0.05)
        end
    else
        TweenService:Create(hrp, info, goal):Play()
        task.wait(t)
    end
end

-- Bring monsters to a position (Magnet / Bring Mob)
function Actions.BringMonsters(pos, radius)
    radius = radius or (Settings.BringMonsterRadius or 350)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= getChar() then
            local root = obj:FindFirstChild("HumanoidRootPart")
            local hum  = obj:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                if (root.Position - pos).Magnitude <= radius * 2 then
                    root.CFrame = CFrame.new(pos + Vector3.new(0, Settings.PosY or 18, 0))
                end
            end
        end
    end
end

-- Get the current quest from the player data
local function getQuestName()
    local lvl = LocalPlayer:GetAttribute("Level") or 0
    for _, sea in pairs(Data.QUESTS) do
        for _, q in ipairs(sea) do
            if lvl >= q[1] and lvl <= q[2] then
                return q[4], q[5]
            end
        end
    end
    return nil, nil
end

--//========================= CORE REMOTES =========================//

function Actions.SetTeam(team)
    Module:FireInvoke("SetTeam", team)
end

function Actions.BuyBuso()
    Module:FireInvoke("Buso")
end

function Actions.RequestEntrance(pos)
    Module:FireInvoke("requestEntrance", pos)
end

function Actions.EquipWeapon(name)
    pcall(function()
        getHum():EquipTool(LocalPlayer.Backpack:FindFirstChild(name))
    end)
end

--//========================= AUTO FARM =========================//

function Actions.AcceptQuest()
    local qName, qLvl = getQuestName()
    if qName then
        Module:FireInvoke("StartQuest", qName, qLvl)
    end
end

function Actions.AbandonQuest()
    Module:FireInvoke("AbandonQuest")
end

function Actions.GetQuestProgress()
    local qName = getQuestName()
    if qName then
        return Module:FireInvoke(qName .. "Progress") or {}
    end
    return {}
end

--//========================= BOSS FARM =========================//

function Actions.GetBossList()
    local lvl = LocalPlayer:GetAttribute("Level") or 0
    local sea = 1
    if lvl >= 1500 then sea = 3 elseif lvl >= 700 then sea = 2 end
    local key = "Sea_" .. sea
    return Data.BossList[key] or {}
end

function Actions.KillBoss(bossName)
    local bosses = Actions.GetBossList()
    for _, boss in ipairs(bosses) do
        if boss[2] == bossName then
            -- Request entrance if far
            local hrp = getHRP()
            if hrp then
                local pos = Vector3.new(-7894, 5547, -380) -- placeholder, override per boss
                if (hrp.Position - pos).Magnitude > 7500 then
                    Actions.RequestEntrance(pos)
                end
            end
            -- Tween to boss
            local bossModel = workspace:FindFirstChild(bossName)
            if bossModel then
                local root = bossModel:FindFirstChild("HumanoidRootPart")
                if root then
                    Actions.TweenTo(root.CFrame * CFrame.new(0, 30, 0))
                end
            end
            break
        end
    end
end

--//========================= MATERIAL FARM =========================//

function Actions.GetMaterialEnemies(material)
    local lvl = LocalPlayer:GetAttribute("Level") or 0
    local sea = 1
    if lvl >= 1500 then sea = 3 elseif lvl >= 700 then sea = 2 end
    local key = "Sea_" .. sea
    return (Data.MaterialEnemies[key] or {})[material] or {}
end

function Actions.FarmMaterial(material)
    local enemies = Actions.GetMaterialEnemies(material)
    if #enemies == 0 then return end
    -- Find nearest enemy and attack
    local hrp = getHRP()
    if not hrp then return end
    local closest, closestDist = nil, math.huge
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            for _, e in ipairs(enemies) do
                if obj.Name == e then
                    local root = obj:FindFirstChild("HumanoidRootPart")
                    local hum  = obj:FindFirstChildOfClass("Humanoid")
                    if root and hum and hum.Health > 0 then
                        local d = (root.Position - hrp.Position).Magnitude
                        if d < closestDist then
                            closest, closestDist = obj, d
                        end
                    end
                end
            end
        end
    end
    if closest then
        local root = closest:FindFirstChild("HumanoidRootPart")
        if root then
            Actions.TweenTo(root.CFrame * CFrame.new(0, Settings.PosY or 18, 0))
        end
    end
end

--//========================= CHEST FARM =========================//

function Actions.FindChest()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:find("Chest") then
            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
            if root then
                return obj, root.CFrame
            end
        end
    end
    return nil, nil
end

--//========================= SEA EVENTS =========================//

function Actions.FindMirageIsland()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:lower():find("mirage") then
            return obj
        end
    end
    return nil
end

function Actions.FindKitsuneIsland()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:lower():find("kitsune") then
            return obj
        end
    end
    return nil
end

function Actions.FindPrehistoricIsland()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:lower():find("prehistoric") then
            return obj
        end
    end
    return nil
end

--//========================= TRAVEL =========================//

function Actions.TravelToIsland(islandName)
    local lvl = LocalPlayer:GetAttribute("Level") or 0
    local sea = 1
    if lvl >= 1500 then sea = 3 elseif lvl >= 700 then sea = 2 end
    local key = "Sea " .. sea
    local islands = Data.Islands[key] or {}
    local cf = islands[islandName]
    if cf then
        Actions.TweenTo(cf)
    end
end

function Actions.TravelToNPC(npcName)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == npcName and obj:FindFirstChild("HumanoidRootPart") then
            Actions.TweenTo(obj.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0))
            return
        end
    end
end

function Actions.RejoinServer()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

function Actions.ServerHop()
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if not ok then return end
    local body = HttpService:JSONDecode(res)
    for _, s in ipairs(body.data or {}) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            return
        end
    end
end

function Actions.TeleportJobID(jobId)
    if jobId and #jobId > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end
end

function Actions.TeleportQuantumPremium(code)
    print("[Opex] Quantum Premium:", code)
    -- Implement your API join here
end

function Actions.JoinAPI(kind)
    print("[Opex] JoinAPI:", kind)
    -- Example: use a quantum/API server hop service
end

function Actions.JoinRaidBossServer()
    Actions.ServerHop()
end

--//========================= SHOP =========================//

function Actions.BuyItem(itemName, category)
    if not itemName or not category then return end
    local entry = Data.ItemsToBuy and Data.ItemsToBuy[category] and Data.ItemsToBuy[category][itemName]
    if not entry then
        -- fallback: try the item name directly
        Module:FireInvoke(itemName)
        return
    end
    if type(entry[1]) == "table" then
        for _, remote in ipairs(entry) do
            Module:FireInvoke(remote[1], table.unpack(remote, 2))
        end
    else
        Module:FireInvoke(entry[1], table.unpack(entry, 2))
    end
end

function Actions.BuyFruitDealer(fruitName)
    Module:FireInvoke("PurchaseRawFruit", fruitName)
end

function Actions.BuyRandomFruit()
    Module:FireInvoke("Cousin", "Buy")
end

function Actions.StoreFruit(fruitName)
    Module:FireInvoke("StoreFruit", fruitName)
end

function Actions.BuyCyborgRace()
    Module:FireInvoke("BuyCyborg")
end

function Actions.BuyGhoulRace()
    Module:FireInvoke("BuyGhoul")
end

function Actions.CraftScroll()
    Module:FireInvoke("CraftScroll")
end

--//========================= RAID =========================//

function Actions.BuyRaidChip()
    Module:FireInvoke("Raids", "Buy")
end

function Actions.StartRaid()
    Module:FireInvoke("Raids", "Start")
end

function Actions.AutoAwaken()
    Module:FireInvoke("Awaken")
end

--//========================= PLAYER =========================//

function Actions.GetPlayerList()
    local out = { "Nearest" }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(out, plr.Name)
        end
    end
    return out
end

function Actions.GetStatsInfo()
    local lvl  = LocalPlayer:GetAttribute("Level") or "?"
    local beli = LocalPlayer:GetAttribute("Beli")  or "?"
    local frag = LocalPlayer:GetAttribute("Fragments") or "?"
    local hum  = getHum()
    return ("Level: %s | Beli: %s | Frags: %s\nHP: %d/%d"):format(
        tostring(lvl), tostring(beli), tostring(frag),
        math.floor(hum and hum.Health or 0),
        math.floor(hum and hum.MaxHealth or 0)
    )
end

function Actions.StatusServer()
    return ("JobId: %s\nPlayers: %d/%d\nPing: %dms"):format(
        tostring(game.JobId),
        #Players:GetPlayers(), Players.MaxPlayers,
        math.floor(LocalPlayer:GetNetworkPing() * 1000)
    )
end

function Actions.PlayerStatus()
    return ("Name: %s\nUser: %s\nAccountAge: %d days"):format(
        LocalPlayer.DisplayName, LocalPlayer.Name, LocalPlayer.AccountAge
    )
end

function Actions.GetFruitStock()
    local ok, stock = pcall(function()
        return Module:FireInvoke("GetFruits")
    end)
    if ok and stock then
        local out = {}
        for _, f in ipairs(stock) do
            table.insert(out, f.Name or tostring(f))
        end
        return table.concat(out, ", ")
    end
    return "—"
end

function Actions.AutoStats()
    local points = Settings.PointsSlider or 10
    local stat = nil
    if Settings.Melee then stat = "Melee"
    elseif Settings.Defense then stat = "Defense"
    elseif Settings.Sword then stat = "Sword"
    elseif Settings.Gun then stat = "Gun"
    elseif Settings.DemonFruit then stat = "Demon Fruit" end
    if stat then
        Module:FireInvoke("AddPoint", stat, points)
    end
end

function Actions.GetPlayerHunterQuest()
    Module:FireInvoke("StartQuest", "PlayerHunter")
end

--//========================= ESP =========================//

local ESPObjects = {}

function Actions.CreateESP(target, kind)
    if not target then return end
    if ESPObjects[target] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Filled = false
    box.Visible = false
    ESPObjects[target] = box

    task.spawn(function()
        while ESPObjects[target] do
            local obj = target
            if not obj or not obj.Parent then
                box:Remove()
                ESPObjects[target] = nil
                break
            end
            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
            if root then
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    box.Visible = true
                    box.Size = Vector2.new(50, 50)
                    box.Position = Vector2.new(pos.X - 25, pos.Y - 25)
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
            task.wait(0.05)
        end
    end)
end

function Actions.ClearESP(kind)
    for target, box in pairs(ESPObjects) do
        if box then box:Remove() end
    end
    ESPObjects = {}
end

-- Player ESP
function Actions.EnablePlayerESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            Actions.CreateESP(plr.Character, "Player")
        end
    end
end

-- Island ESP (searches for island models)
function Actions.EnableIslandESP()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:lower():find("island") or obj.Name:lower():find("town") then
            Actions.CreateESP(obj, "Island")
        end
    end
end

-- Fruit ESP
function Actions.EnableFruitESP()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:find("Fruit") then
            Actions.CreateESP(obj, "Fruit")
        end
    end
end

-- Chest ESP
function Actions.EnableChestESP()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:find("Chest") then
            Actions.CreateESP(obj, "Chest")
        end
    end
end

--//========================= MISC =========================//

function Actions.RemoveEffects()
    pcall(function()
        local Container   = ReplicatedStorage:WaitForChild("Effect"):WaitForChild("Container")
        local CameraShaker = require(ReplicatedStorage:WaitForChild("Util"):WaitForChild("CameraShaker"))
        local Death    = require(Container:FindFirstChild("Death"))
        local Respawn  = require(Container:FindFirstChild("Respawn"))
        local LevelUp  = require(Container:FindFirstChild("LevelUp"))
        local DisplayNPC = require(ReplicatedStorage:WaitForChild("GuideModule")).ChangeDisplayedNPC

        hookfunction(Death,    function() end)
        hookfunction(LevelUp,  function() end)
        hookfunction(Respawn,  function() end)
        hookfunction(DisplayNPC, function() end)
        CameraShaker:Stop()
        WindUI:Notify({ Title = "Effects Removed", Content = "Camera shakes & death VFX suppressed.", Duration = 3 })
    end)
end

function Actions.ToggleDamageCounter(v)  Settings.DisableDamageCounter = v end
function Actions.ToggleNotifications(v)  Settings.DisableNotifications  = v end
function Actions.ToggleWalkInWater(v)    Settings.Water                = v end
function Actions.ToggleAntiAFK(v)        Settings.AntiAFK              = v end
function Actions.ToggleHopAdmin(v)       Settings.HopWhenAdmin         = v end
function Actions.OnAutoHop30Mins(v)      Settings.AutoHopwhen30mins    = v end
function Actions.OnAutoLoadScript(v)     Settings.AutoLoadScriptonLoad = v end
function Actions.ToggleXray(v)           Settings.XrayVision           = v end
function Actions.ToggleInfiniteZoom(v)   Settings.InfiniteZoom         = v end
function Actions.ToggleWhiteScreen(v)    Settings.White_Screen          = v end
function Actions.ToggleBlackScreen(v)    Settings.BlackScreen          = v end
function Actions.ToggleUpgradeDragonTalon(v) Settings.AutoUpgradeDragonTalon = v end
function Actions.OnFastModeToggle(v)     Settings.AutoFastMode         = v end
function Actions.OnCamLockToggle(v)      Settings.CamLock              = v end
function Actions.OnSpectateToggle(v)     Settings.SpectatePlayer       = v end
function Actions.OnTPPlayerToggle(v)     Settings.TeleporttoPlayer     = v end

function Actions.SetWalkSpeed(v)
    local hum = getHum()
    if hum then hum.WalkSpeed = v end
end

function Actions.SetJumpPower(v)
    local hum = getHum()
    if hum then hum.JumpPower = v end
end

function Actions.CleanMemory()
    if collectgarbage then collectgarbage("collect") end
end

function Actions.ForceFPSBoost()
    pcall(function()
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                v.Enabled = false
            end
        end
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = 1
    end)
end

function Actions.RedeemAllCodes()
    local codes = {
        "SUB2GAMERROBOT_EXP1", "SUB2OFFICIALNOOBIE", "StarcodeHEO",
        "KITT_RESET", "Sub2Fer999", "Enyu_is_Pro", "Magicbus",
        "JCWK", "Starcodeheo", "Bluxxy", "fudd10_v2", "FUDD10",
        "BIGNEWS", "THEGREATACE", "SUB2GAMERROBOT_RESET1", "Sub2OfficialNoobie",
        "SUB2NOOBMASTER123", "Sub2Daigrock", "AxiX_Reset", "AxiX_Free",
        "AxiX_Sorry", "AxiX_Pro", "AxiX_Reset2", "AxiX_Reset3"
    }
    for _, code in ipairs(codes) do
        Module:FireInvoke("Redeem", code)
        task.wait(0.5)
    end
end

function Actions.OpenDevConsole()
    game:GetService("StarterGui"):SetCore("DevConsoleVisible", true)
end

function Actions.OpenFishIndex()       Module:FireInvoke("FishIndex") end
function Actions.OpenNormalFruitShop() Module:FireInvoke("OpenShop") end
function Actions.OpenAdvFruitShop()    Module:FireInvoke("OpenAdvancedShop") end
function Actions.TPAdvFruitDealer()    print("[Opex] TP adv dealer — use island travel.") end
function Actions.OpenTitleNames()      Module:FireInvoke("OpenTitles") end
function Actions.OpenAwakenings()      Module:FireInvoke("OpenAwakenings") end
function Actions.OpenHakiColors()      Module:FireInvoke("OpenHakiColors") end

--//========================= DRAGON / PREHISTORIC =========================//

function Actions.TPDragonHunter()
    Actions.TravelToNPC("Dragon Hunter")
end

function Actions.TPDragonWizard()
    Actions.TravelToNPC("Dragon Wizard")
end

function Actions.TPDungeonHub()
    Actions.TravelToNPC("Dungeon Hub")
end

function Actions.TPDungeonBack()
    Module:FireInvoke("Dungeon", "Back")
end

function Actions.CraftPrehistoricItem(item)
    Module:FireInvoke("Craft", item)
end

function Actions.ChangeDracoRace()
    Module:FireInvoke("ChangeRace", "Draco")
end

function Actions.TPTrialArea(area)
    local map = {
        GreatTree     = CFrame.new(2205, 22, -6766),
        TempleOfTime  = CFrame.new(-12463, 374, -7523),
        AncientOne    = CFrame.new(-9517, 142, 5528),
        LeverPull     = CFrame.new(-9517, 142, 5528),
        SafeZone      = CFrame.new(2205, 22, -6766),
        PvpZone       = CFrame.new(2205, 22, -6766),
        Clock         = CFrame.new(2205, 22, -6766),
    }
    if map[area] then Actions.TweenTo(map[area]) end
end

function Actions.TPRaceDoor()
    Actions.TravelToNPC("Race Door")
end

function Actions.ResetCharHead()
    local char = getChar()
    if char then char:BreakJoints() end
end

function Actions.BribeLeviathan()
    Module:FireInvoke("BribeLeviathan")
end

--//========================= TRINKETS =========================//

function Actions.BuyTrinket()           Module:FireInvoke("BuyTrinket") end
function Actions.FuseTrinkets()         Module:FireInvoke("FuseTrinket") end
function Actions.RefineTrinket()        Module:FireInvoke("RefineTrinket") end
function Actions.OpenTrinketMergeGUI()  Module:FireInvoke("OpenTrinketMerge") end
function Actions.OpenTrinketRefineGUI() Module:FireInvoke("OpenTrinketRefine") end
function Actions.OpenTrinketScrapGUI()  Module:FireInvoke("OpenTrinketScrap") end

--//========================= WEBHOOK =========================//

function Actions.SendTestWebhook()
    local url = Settings.Webhook
    if not url or #url < 10 then return end
    local body = HttpService:JSONEncode({
        content = "**Opex Hub** — Test webhook successful.",
        username = "Opex Hub"
    })
    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
    end)
end

function Actions.SendDataLogNow()
    local url = Settings.DataLogWebhookUrl
    if not url or #url < 10 then return end
    local body = HttpService:JSONEncode({
        content = ("**Data Log**\nLevel: %s\nBeli: %s\nFrags: %s"):format(
            LocalPlayer:GetAttribute("Level") or "?",
            LocalPlayer:GetAttribute("Beli") or "?",
            LocalPlayer:GetAttribute("Fragments") or "?"
        ),
        username = "Opex Hub"
    })
    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
    end)
end
