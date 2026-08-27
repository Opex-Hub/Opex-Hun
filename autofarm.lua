local players = game:GetService("Players")
local TwSrv = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = players.LocalPlayer
local enabled = false
local currFarm

-- Keys that count as "the player wants to walk"
local WALK_KEYS = {
    [Enum.KeyCode.W] = true,
    [Enum.KeyCode.A] = true,
    [Enum.KeyCode.S] = true,
    [Enum.KeyCode.D] = true,
    [Enum.KeyCode.Up] = true,
    [Enum.KeyCode.Down] = true,
    [Enum.KeyCode.Left] = true,
    [Enum.KeyCode.Right] = true,
    [Enum.KeyCode.Space] = true,
}

local function findFarm()
    for _, farm in ipairs(workspace.Farm:GetChildren()) do
        if farm.Name == "Farm" then
            local important = farm:FindFirstChild("Important")
            local data = important and important:FindFirstChild("Data")
            local owner = data and data:FindFirstChild("Owner")

            if owner and owner:IsA("StringValue") and owner.Value == player.Name then
                return farm
            end
        end
    end
end

local function getPrompts(farm)
    local prompts = {}
    local important = farm and farm:FindFirstChild("Important")
    local plants = important and important:FindFirstChild("Plants_Physical")

    if not plants then
        return prompts
    end

    for _, obj in ipairs(plants:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            table.insert(prompts, obj)
        end
    end

    return prompts
end

local function isPlayerMoving()
    for key in pairs(WALK_KEYS) do
        if UIS:IsKeyDown(key) then
            return true
        end
    end

    -- covers mobile joystick / any humanoid-driven movement
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.MoveDirection.Magnitude > 0.01 then
        return true
    end

    return false
end

local function TweenFunc(prompt)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid or humanoid.Health <= 0 then
        return
    end

    if not prompt:IsDescendantOf(workspace) then
        return
    end

    local part = prompt.Parent
    if not part:IsA("BasePart") then
        part = prompt:FindFirstAncestorWhichIsA("BasePart")
    end
    if not part then
        return
    end

    -- Stand BESIDE the plant, never on top of it
    local flatDelta = (root.Position - part.Position) * Vector3.new(1, 0, 1)

    if flatDelta.Magnitude < 0.1 then
        flatDelta = Vector3.new(1, 0, 1) -- fallback if we're basically on top already
    else
        flatDelta = flatDelta.Unit
    end

    local plantRadius = math.max(part.Size.X, part.Size.Z) * 0.5
    local standDist = math.clamp(
        plantRadius + 2,
        3,
        math.max(prompt.MaxActivationDistance * 0.7, 4)
    )

    local standPos = part.Position + flatDelta * standDist

    -- Snap Y to real ground level (excludes plants so we can't raycast onto a crop)
    local farmModel = prompt:FindFirstAncestor("Farm")
    local important = farmModel and farmModel:FindFirstChild("Important")
    local plants = important and important:FindFirstChild("Plants_Physical")

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = plants and {character, plants} or {character}

    local groundHit = workspace:Raycast(
        Vector3.new(standPos.X, standPos.Y + 25, standPos.Z),
        Vector3.new(0, -150, 0),
        rayParams
    )

    if groundHit then
        standPos = Vector3.new(standPos.X, groundHit.Position.Y + 3, standPos.Z)
    else
        standPos = Vector3.new(standPos.X, part.Position.Y + 2, standPos.Z)
    end

    -- Face the plant while standing next to it
    local lookDir = Vector3.new(part.Position.X - standPos.X, 0, part.Position.Z - standPos.Z)
    local targetCFrame
    if lookDir.Magnitude > 0.01 then
        targetCFrame = CFrame.lookAt(standPos, standPos + lookDir.Unit)
    else
        targetCFrame = CFrame.new(standPos)
    end

    local distance = (root.Position - standPos).Magnitude
    local duration = math.clamp(distance / 250, 0.03, 0.25)

    local tween = TwSrv:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = targetCFrame
    })

    tween:Play()

    -- Hand control back to the player THE MOMENT they try to move
    while tween.PlaybackState == Enum.PlaybackState.Playing do
        task.wait(0.02)

        if isPlayerMoving() then
            tween:Cancel()
            return
        end
    end

    if not enabled or not prompt:IsDescendantOf(workspace) or not prompt.Enabled then
        return
    end

    if isPlayerMoving() then
        return
    end

    task.wait(0.1)

    if isPlayerMoving() then
        return
    end

    local currDist = (root.Position - part.Position).Magnitude
    if currDist <= prompt.MaxActivationDistance + 2 then
        fireproximityprompt(prompt)
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "WhateverGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 190, 0, 45)
button.Position = UDim2.new(0.5, -95, 0.1, 0)
button.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = 18
button.Text = "AutoFarm [OFF]"
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local dragging = false
local dragStart
local startPos
local currTarget

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = button.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        currTarget = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == currTarget and dragging then
        local delta = input.Position - dragStart
        button.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

button.Activated:Connect(function()
    enabled = not enabled

    if enabled then
        button.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
        button.Text = "AutoFarm [ON]"
        currFarm = findFarm()
    else
        button.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        button.Text = "AutoFarm [OFF]"
        currFarm = nil
    end
end)

task.spawn(function()
    while true do
        if enabled then
            currFarm = findFarm()
        else
            currFarm = nil
        end

        task.wait(10)
    end
end)

task.spawn(function()
    while true do
        if enabled and currFarm then
            local prompts = getPrompts(currFarm)

            for _, prompt in ipairs(prompts) do
                if not enabled then
                    break
                end

                -- While YOU'RE walking around, collecting pauses quietly
                while enabled and isPlayerMoving() do
                    task.wait(0.15)
                end

                if not enabled then
                    break
                end

                if prompt:IsDescendantOf(currFarm) and prompt.Enabled then
                    TweenFunc(prompt)
                    task.wait(0.05)
                end
            end
        end

        task.wait(0.5)
    end
end)
