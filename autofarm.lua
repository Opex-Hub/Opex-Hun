local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local AutoFarmEnabled = false

local function getPlayerFarm()
    local farms = Workspace:FindFirstChild("Farm") or Workspace:FindFirstChild("Farms")
    if not farms then return nil end

    for _, farm in ipairs(farms:GetChildren()) do
        local important = farm:FindFirstChild("Important")
        local data = important and important:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")

        if owner and owner:IsA("StringValue") and owner.Value == LocalPlayer.Name then
            return farm
        end
    end
    return nil
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OpexAutoFarmGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 180, 0, 45)
ToggleButton.Position = UDim2.new(0.5, -90, 0.05, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 16
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "Auto Farm: OFF"
ToggleButton.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

local dragging, dragStart, startPos, currentInput
ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        currentInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == currentInput and dragging then
        local delta = input.Position - dragStart
        ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

ToggleButton.Activated:Connect(function()
    AutoFarmEnabled = not AutoFarmEnabled
    if AutoFarmEnabled then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 180, 70)
        ToggleButton.Text = "Auto Farm: ON"
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        ToggleButton.Text = "Auto Farm: OFF"
    end
end)

task.spawn(function()
    while true do
        if AutoFarmEnabled then
            local farm = getPlayerFarm()
            if farm then
                local important = farm:FindFirstChild("Important")
                local plants = important and important:FindFirstChild("Plants_Physical")

                if plants then
                    for _, obj in ipairs(plants:GetDescendants()) do
                        if not AutoFarmEnabled then break end
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            -- Bypass activation distance and line-of-sight limits
                            obj.MaxActivationDistance = 999999
                            obj.RequiresLineOfSight = false
                            
                            fireproximityprompt(obj, 0)
                            task.wait(0.05)
                        end
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)
