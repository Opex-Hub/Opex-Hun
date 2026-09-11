--[[
    ╔══════════════════════════════════════════════════════╗
    ║                    OPEX HUB                          ║
    ║             Blox Fruits — WindUI (Fixed)             ║
    ╚══════════════════════════════════════════════════════╝
]]

--//========================= SERVICES =========================//
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local Lighting           = game:GetService("Lighting")
local HttpService        = game:GetService("HttpService")
local StarterGui         = game:GetService("StarterGui")
local TeleportService    = game:GetService("TeleportService")

local LocalPlayer        = Players.LocalPlayer
local Camera             = workspace.CurrentCamera
local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local CommF_             = Remotes:WaitForChild("CommF_")

--//========================= GLOBALS =========================//
getgenv().OpexHub = getgenv().OpexHub or {}
local Opex = getgenv().OpexHub

Opex.Settings = Opex.Settings or {}
Opex.Module   = Opex.Module   or {}
Opex.Funcs    = Opex.Funcs    or {}
Opex.Actions  = Opex.Actions  or {}
Opex.Data     = Opex.Data     or {}

local Settings = Opex.Settings
local Module   = Opex.Module
local Funcs    = Opex.Funcs
local Actions  = Opex.Actions
local Data     = Opex.Data

Module.Functions            = Module.Functions            or {}
Module.FunctionDisplayNames = Module.FunctionDisplayNames or {}
Module.ActiveFunction       = Module.ActiveFunction       or nil

--//========================= LOAD FILES =========================//
local function loadFile(name)
    local ok, res = pcall(function()
        local path = "OpexHub/" .. name
        if isfile and isfile(path) then
            return loadstring(readfile(path))()
        end
        return nil
    end)
    if not ok then
        warn("[Opex] Failed to load " .. name .. ": " .. tostring(res))
        return nil
    end
    return res
end

Data = loadFile("Data.lua") or Data
Opex.Data = Data

pcall(function() loadFile("Bypass.lua") end)
pcall(function() loadFile("Iris.lua") end)
pcall(function() loadFile("helper.lua") end)

--//========================= WINDUI LOAD =========================//
local WindUI
do
    local urls = {
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/source.lua",
    }
    for _, url in ipairs(urls) do
        local ok, res = pcall(function()
            return loadstring(game:HttpGet(url, true))()
        end)
        if ok and res and type(res) == "table" and res.CreateWindow then
            WindUI = res
            print("[Opex] WindUI loaded from: " .. url)
            break
        end
    end
end

if not WindUI then
    error("[Opex] Could not load WindUI. Check your internet / executor HttpGet.")
end

--//========================= WINDOW =========================//
local Window = WindUI:CreateWindow({
    Title       = "Opex Hub",
    Icon        = "anchor",
    Author      = "Opex",
    Folder      = "OpexHub",
    Size        = UDim2.fromOffset(620, 480),
    Transparent = true,
    Theme       = "Dark",
    User = {
        Enabled = true,
        Anonymous = true,
    },
})

--//========================= UI COMPATIBILITY SHIM =========================//
-- UITabs.lua expects:
--     Tab.Home:addSection()                 -> Section
--     Section:addMenu(name)                 -> Menu
--     Menu:addLabel(title, desc)            -> { :RefreshDesc(text) }
--     Menu:addButton(title, cb)
--     Menu:addButtonGrid(title, grid)
--     Menu:Toggle/Slider/Dropdown/Input/Paragraph
--
-- WindUI provides:
--     Window:Tab({...}) -> Tab
--     Tab:Section({...}) -> Section
--     Section:Toggle/Slider/Dropdown/Input/Paragraph/Button
--     (No Menu concept, so we fake it with a Paragraph header.)

local function makeLabel(parent, title, desc)
    desc = desc or ""
    local paragraph
    local ok = pcall(function()
        paragraph = parent:Paragraph({
            Title = title,
            Desc  = desc,
            Color = "FFFFFF",
        })
    end)

    local obj = { _p = paragraph, _desc = desc }

    function obj:RefreshDesc(newDesc)
        self._desc = newDesc
        if not paragraph then return end
        pcall(function()
            if type(paragraph) == "table" then
                if paragraph.SetDesc then
                    paragraph:SetDesc(newDesc)
                elseif paragraph.UpdateDesc then
                    paragraph:UpdateDesc(newDesc)
                elseif paragraph.Set then
                    paragraph:Set(newDesc)
                end
                if paragraph.Desc ~= nil then
                    paragraph.Desc = newDesc
                end
            end
        end)
    end

    obj.Refresh = function(self, text) self:RefreshDesc(text or "") end

    return obj
end

local function makeButtonGrid(parent, title, gridData)
    if type(gridData) ~= "table" then return end
    for _, entry in ipairs(gridData) do
        local btnTitle = entry[1] or "Button"
        local btnCb    = entry[2]
        pcall(function()
            parent:Button({
                Title    = btnTitle,
                Callback = function()
                    if type(btnCb) == "function" then
                        local ok, err = pcall(btnCb)
                        if not ok then warn("[Opex] Button error:", err) end
                    end
                end,
            })
        end)
    end
end

-- Attach addMenu/addLabel/addButton/addSection to any WindUI object
local function shim(obj)
    if type(obj) ~= "table" and type(obj) ~= "userdata" then return obj end
    if obj.__shimmed then return obj end
    obj.__shimmed = true

    -- addMenu (fake: just a heading paragraph)
    obj.addMenu = function(self, name)
        pcall(function()
            self:Paragraph({
                Title = "▸ " .. tostring(name),
                Desc  = "",
                Color = "88CCFF",
            })
        end)
        return self
    end

    -- addLabel
    obj.addLabel = function(self, title, desc)
        return makeLabel(self, title, desc)
    end

    -- addButton
    obj.addButton = function(self, title, cb)
        return self:Button({
            Title    = title,
            Callback = function()
                if type(cb) == "function" then
                    local ok, err = pcall(cb)
                    if not ok then warn("[Opex] Button error:", err) end
                end
            end,
        })
    end

    -- addButtonGrid
    obj.addButtonGrid = function(self, title, gridData)
        makeButtonGrid(self, title, gridData)
    end

    -- addSection: use native Tab:Section if available, else return self
    if not obj.addSection then
        obj.addSection = function(self)
            if self.Section then
                local s = self:Section({ Title = "Section" })
                return shim(s)
            end
            return shim(self)
        end
    end

    return obj
end

--//========================= FUNCS (element wrappers) =========================//
local function registerFunction(key, value)
    Settings[key] = value
    Module.Functions[key] = Module.Functions[key] or {}
    Module.Functions[key].Value = value
    Module.Functions[key].Enabled = (value == true)
end

function Funcs:CreateToggle(parent, title, key, default, opts)
    opts = opts or {}
    local toggle = parent:Toggle({
        Title    = title,
        Desc     = opts.description or "",
        Value    = default or false,
        Flag     = key,
        Callback = function(state)
            registerFunction(key, state)
            if opts.callback then
                local ok, err = pcall(opts.callback, state)
                if not ok then warn("[Opex] Toggle callback error:", err) end
            end
        end,
    })
    registerFunction(key, default or false)
    return toggle
end

function Funcs:CreateSlider(parent, title, key, min, max, default, opts)
    opts = opts or {}
    local slider = parent:Slider({
        Title    = title,
        Desc     = opts.description or "",
        Value    = { Min = min, Max = max, Default = default },
        Step     = opts.step or 1,
        Flag     = key,
        Callback = function(v)
            Settings[key] = v
            Module.Functions[key] = Module.Functions[key] or {}
            Module.Functions[key].Value = v
            if opts.callback then pcall(opts.callback, v) end
        end,
    })
    Settings[key] = default
    return slider
end

function Funcs:CreateDropdown(parent, title, key, default, options, opts, multi)
    opts = opts or {}
    local dropFn = (multi and parent.MultiDropdown) and parent.MultiDropdown or parent.Dropdown
    local args = {
        Title    = title,
        Desc     = opts.description or "",
        Values   = options or {},
        Value    = default,
        Multi    = multi or false,
        Flag     = key,
        Callback = function(v)
            Settings[key] = v
            Module.Functions[key] = Module.Functions[key] or {}
            Module.Functions[key].Value = v
            if opts.callback then pcall(opts.callback, v) end
        end,
    }
    local dd = dropFn(parent, args)
    Settings[key] = default
    return dd
end

function Funcs:CreateTextbox(parent, title, key, opts)
    opts = opts or {}
    return parent:Input({
        Title    = title,
        Value    = "",
        Flag     = key,
        Callback = function(v)
            Settings[key] = v
            if opts.callback then pcall(opts.callback, v) end
        end,
    })
end

--//========================= MODULE HELPERS =========================//
function Module.GetEnabledFunctionNames()
    local list = {}
    for k, v in pairs(Module.Functions) do
        if v and v.Enabled then table.insert(list, k) end
    end
    return list
end

function Module.IsMultiFunction(_) return false end

function Module:FireInvoke(name, ...)
    local ok, res = pcall(function()
        return CommF_:InvokeServer(name, ...)
    end)
    return ok and res or nil
end

function Module:FireEvent(name, ...)
    local ev = Remotes:FindFirstChild(name)
    if ev and ev:IsA("RemoteEvent") then ev:FireServer(...) end
end

--//========================= ACTIONS — full table from prior message =========================//
-- (Paste your complete Actions implementation here — everything from
--  Actions.RemoveEffects through Actions.SendDataLogNow.
--  It's identical to the previous message's block.)
dofile and pcall(function() end) -- no-op placeholder; leave your Actions block in place

--//========================= TABS =========================//
local Tabs = {
    Home    = shim(Window:Tab({ Title = "Home",    Icon = "home" })),
    Sub     = shim(Window:Tab({ Title = "Sub",     Icon = "layers" })),
    Sevent  = shim(Window:Tab({ Title = "Sea",     Icon = "waves" })),
    Player  = shim(Window:Tab({ Title = "Player",  Icon = "user" })),
    Dragon  = shim(Window:Tab({ Title = "Dragon",  Icon = "flame" })),
    Raid    = shim(Window:Tab({ Title = "Raid",    Icon = "skull" })),
    Trial   = shim(Window:Tab({ Title = "Trial",   Icon = "trophy" })),
    Travel  = shim(Window:Tab({ Title = "Travel",  Icon = "plane" })),
    Shop    = shim(Window:Tab({ Title = "Shop",    Icon = "shopping-cart" })),
    Misc    = shim(Window:Tab({ Title = "Misc",    Icon = "settings" })),
    Web     = shim(Window:Tab({ Title = "Webhook", Icon = "globe" })),
}

--//========================= BUILD UI =========================//
local UITabs = loadFile("UITabs.lua")
if UITabs then
    local ctx = {
        Funcs    = Funcs,
        Settings = Settings,
        Module   = Module,
        Data     = Data,
        Actions  = Actions,
        PlayerESP    = function() Actions.EnablePlayerESP    and Actions.EnablePlayerESP()    end,
        IslandESP    = function() Actions.EnableIslandESP    and Actions.EnableIslandESP()    end,
        FruitESP     = function() Actions.EnableFruitESP     and Actions.EnableFruitESP()     end,
        ChestESP     = function() Actions.EnableChestESP     and Actions.EnableChestESP()     end,
        BerryESP     = function() end,
        RealFruitESP = function() end,
        ClearESP     = function(kind) Actions.ClearESP and Actions.ClearESP(kind) end,
    }

    local ok, err = pcall(function()
        UITabs(Tabs, ctx)
    end)

    if not ok then
        warn("[Opex] UITabs error: " .. tostring(err))
        -- Fallback: build a minimal Home tab so UI still shows
        local fallbackTab = Tabs.Home:addSection()
        fallbackTab:addLabel("Opex Hub", "UITabs.lua failed to build. Check console for error.")
        fallbackTab:addButton("Reload Script", function()
            game:GetService("StarterGui"):SetCore("ResetButtonCallback", false)
        end)
    end
else
    warn("[Opex] UITabs.lua not found.")
    local fallbackTab = Tabs.Home:addSection()
    fallbackTab:addLabel("Opex Hub", "UITabs.lua missing from OpexHub/ folder.")
end

--//========================= BACKGROUND THREADS =========================//
task.spawn(function()
    while task.wait(60) do
        if Settings.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(60) do
        if Settings.AutoCleanMemory then
            pcall(function() collectgarbage("collect") end)
        end
    end
end)

if Players.PlayerAdded then
    Players.PlayerAdded:Connect(function(plr)
        if Settings.HopWhenAdmin then
            warn("[Opex] Player joined:", plr.Name)
        end
    end)
end

--//========================= READY =========================//
pcall(function()
    WindUI:Notify({
        Title    = "Opex Hub",
        Content  = "Loaded successfully.",
        Duration = 5,
    })
end)

print("[Opex Hub] Loaded. Tabs built:", #Window.Tabs or "?")
