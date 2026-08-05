--[[
    ================================================================
    [ SCRIPT INFORMATION ]
    Project: Custom Script
    Author: OYB
    YouTube: https://www.youtube.com/channel/UCAlXXV1Hbvf7WbfXARuVtiQ
    
    [ TERMS AND CONDITIONS ]
    - You ARE allowed to use and modify this script for your own games.
    - You ARE NOT allowed to re-upload, redistribute, or claim 
      ownership of this script.
    - Removing or altering these credits is strictly prohibited.
    
    Copyright (c) 2026 OYB. All rights reserved.
    ================================================================
]]

-- ⚠️ IMPORTANT: Put this code at the VERY TOP of your Main Script (before obfuscating) ⚠️

local ProtectionConfig = {
    -- 🔴 CRITICAL: This MUST exactly match the 'Secret' value in your Key System's Config!
    -- If your Key System has: Secret = "Test"
    -- Then this must also be: SecretKey = "Test"
    SecretKey = "karderr",
    
    -- The name of your Hub (shown in the kick message if they try to bypass)
    HubName = "OPEX HUB"
}

-- Anti-Bypass Logic: Checks if the Key System successfully set the global variable
if not _G[ProtectionConfig.SecretKey] then
    local player = game:GetService("Players").LocalPlayer
    if player then
        player:Kick("\n🛡️ Unauthorized Execution 🛡️\n\nPlease use the official Key System to run " .. ProtectionConfig.HubName)
    end
    return -- Stops the rest of the script from loading!
end

-------------------------------------------------------------------------------
-- 👇 YOUR MAIN SCRIPT CODE STARTS HERE 👇
-------------------------------------------------------------------------------

print(ProtectionConfig.HubName .. " Loaded Successfully!")

-- OPEX HUB | +1 wings for brainrot
-- Built for Tu_papi

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Helper function for safe teleports
local function Teleport(x, y, z)
    local player = Players.LocalPlayer
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
    end
end

-- Create Window
local Window = Rayfield:CreateWindow({
   Name = "Opex Hub | +1 wings for brainrot",
   LoadingTitle = "Loading Opex Hub...",
   LoadingSubtitle = "by Tu_Papi",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "OpexHub",
      FileName = "WingsBrainrot"
   },
   Discord = {
      Enabled = false,
   },
   KeySystem = false
})

-- ==========================================
-- 1. AUTO FARM TAB
-- ==========================================
local FarmTab = Window:CreateTab("Auto Farm", 4483362458)

-- UPGRADES SECTION
local UpgradeSection = FarmTab:CreateSection("Auto Upgrades")

local autoStamina = false
FarmTab:CreateToggle({
   Name = "Auto Upgrade Stamina",
   CurrentValue = false,
   Flag = "ToggleStamina", 
   Callback = function(Value)
       autoStamina = Value
       task.spawn(function()
           while autoStamina do
               local args = {"Stamina", 1}
               ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpgradeRequested"):FireServer(unpack(args))
               task.wait(0.2)
           end
       end)
   end,
})

local autoCarry = false
FarmTab:CreateToggle({
   Name = "Auto Upgrade Carry",
   CurrentValue = false,
   Flag = "ToggleCarry", 
   Callback = function(Value)
       autoCarry = Value
       task.spawn(function()
           while autoCarry do
               local args = {"Carry", 1}
               ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpgradeRequested"):FireServer(unpack(args))
               task.wait(0.2)
           end
       end)
   end,
})

local autoSpeed = false
FarmTab:CreateToggle({
   Name = "Auto Upgrade Speed",
   CurrentValue = false,
   Flag = "ToggleSpeed", 
   Callback = function(Value)
       autoSpeed = Value
       task.spawn(function()
           while autoSpeed do
               local args = {"Speed", 1}
               ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpgradeRequested"):FireServer(unpack(args))
               task.wait(0.2)
           end
       end)
   end,
})

-- TELEPORT SECTION
local TpSection = FarmTab:CreateSection("Zone Teleports")

FarmTab:CreateButton({
   Name = "Teleport to Final Zone",
   Callback = function()
       Teleport(41.411712646484375, 1.1978585720062256, 9994.658203125)
   end,
})

FarmTab:CreateButton({
   Name = "Teleport to Cosmic Zone",
   Callback = function()
       Teleport(52.456478118896484, 4.003028869628906, 6113.20751953125)
   end,
})

FarmTab:CreateButton({
   Name = "Teleport to Safe Zone",
   Callback = function()
       Teleport(28.834819793701172, 3.0278422832489014, -55.03606033325195)
   end,
})

-- Load Settings
Rayfield:LoadConfiguration()
