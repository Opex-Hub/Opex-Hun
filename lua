--[[
    ╔══════════════════════════════════════════════════════╗
    ║                     OPEX HUB                         ║
    ║          Blox Fruits — Custom Lightweight UI         ║
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
local VirtualUser        = game:GetService("VirtualUser")

local LocalPlayer        = Players.LocalPlayer
local Camera             = workspace.CurrentCamera
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")
local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local CommF_             = Remotes:WaitForChild("CommF_")

--//========================= THEME =========================//
local Theme = {
    Bg          = Color3.fromRGB(18, 18, 22),
    BgHeader    = Color3.fromRGB(24, 24, 30),
    BgSidebar   = Color3.fromRGB(22, 22, 28),
    BgSection   = Color3.fromRGB(26, 26, 34),
    BgElement   = Color3.fromRGB(32, 32, 42),
    BgHover     = Color3.fromRGB(44, 44, 56),
    Accent      = Color3.fromRGB(70, 130, 220),
    AccentHv    = Color3.fromRGB(90, 150, 240),
    Success     = Color3.fromRGB(70, 190, 110),
    Danger      = Color3.fromRGB(210, 70, 70),
    Text        = Color3.fromRGB(235, 235, 245),
    TextDim     = Color3.fromRGB(150, 150, 165),
    Border      = Color3.fromRGB(45, 45, 55),
}

--//========================= UI HELPERS =========================//
local function mk(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, r)
    return mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, inst)
end

local function padding(inst, t, b, l, r)
    return mk("UIPadding", {
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or t or 0),
        PaddingLeft = UDim.new(0, l or t or 0),
        PaddingRight = UDim.new(0, r or l or t or 0),
    }, inst)
end

local function stroke(inst, col, th)
    return mk("UIStroke", {
        Color = col or Theme.Border,
        Thickness = th or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, inst)
end

local function mkLabel(parent, text, size, color, bold)
    return mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = size or UDim2.new(1, 0, 0, 20),
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        Text = text or "",
        TextColor3 = color or Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        RichText = true,
    }, parent)
end

--//========================= UI LIBRARY =========================//
local UI = {}

local Notifications = {}

function UI:Notify(opts)
    opts = opts or {}
    if not self._screen then return end

    local frame = mk("Frame", {
        Size = UDim2.new(0, 300, 0, 68),
        Position = UDim2.new(1, -320, 0, 20 + (#Notifications * 78)),
        BackgroundColor3 = Theme.BgHeader,
        BorderSizePixel = 0,
    }, self._screen)
    corner(frame, 8); stroke(frame, Theme.Accent, 1)
    padding(frame, 10)

    mkLabel(frame, opts.Title or "Notification", UDim2.new(1, 0, 0, 18), Theme.Text, true)
    local body = mkLabel(frame, opts.Content or "", UDim2.new(1, 0, 0, 30), Theme.TextDim, false)
    body.TextWrapped = true; body.TextYAlignment = Enum.TextYAlignment.Top
    body.Position = UDim2.new(0, 0, 0, 20)

    table.insert(Notifications, frame)
    task.delay(opts.Duration or 5, function()
        for i, f in ipairs(Notifications) do
            if f == frame then table.remove(Notifications, i) break end
        end
        TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        task.wait(0.2)
        frame:Destroy()
    end)
end

-- Draggable
local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Element factory: Toggle
local function makeToggle(parent, opts)
    local state = opts.Value or false
    local frame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.BgElement,
        BorderSizePixel = 0,
    }, parent)
    corner(frame, 6); stroke(frame)

    local lbl = mkLabel(frame, opts.Title or "Toggle", UDim2.new(1, -70, 1, 0), Theme.Text, false)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.TextSize = 13
    if opts.Desc and #opts.Desc > 0 then
        lbl.Text = opts.Title
        local d = mkLabel(frame, opts.Desc, UDim2.new(1, -70, 0, 12), Theme.TextDim, false)
        d.Position = UDim2.new(0, 12, 0, 20)
        d.TextSize = 10
    end

    local knobBg = mk("Frame", {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = state and Theme.Success or Theme.BgHover,
        BorderSizePixel = 0,
    }, frame)
    corner(knobBg, 10); stroke(knobBg, Theme.Border, 1)

    local knob = mk("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
    }, knobBg)
    corner(knob, 8)

    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    }, frame)

    local obj = { _state = state, _callback = opts.Callback }

    local function apply(v, fire)
        obj._state = v
        TweenService:Create(knobBg, TweenInfo.new(0.15), {
            BackgroundColor3 = v and Theme.Success or Theme.BgHover
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        if fire and obj._callback then
            local ok, err = pcall(obj._callback, v)
            if not ok then warn("[Opex] toggle callback:", err) end
        end
    end

    btn.MouseButton1Click:Connect(function() apply(not obj._state, true) end)

    function obj:Set(v) apply(v, true) end
    function obj:Get() return obj._state end
    function obj:Refresh() end
    return obj
end

-- Slider
local function makeSlider(parent, opts)
    local range = opts.Value or { Min = 0, Max = 100, Default = 0 }
    local value = range.Default or range.Min
    local min, max = range.Min or 0, range.Max or 100
    local step = opts.Step or 1

    local frame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Theme.BgElement,
        BorderSizePixel = 0,
    }, parent)
    corner(frame, 6); stroke(frame)

    mkLabel(frame, opts.Title or "Slider", UDim2.new(1, -80, 0, 18), Theme.Text, false).Position = UDim2.new(0, 12, 0, 4)
    local valLbl = mkLabel(frame, tostring(value), UDim2.new(0, 70, 0, 18), Theme.Accent, true)
    valLbl.Position = UDim2.new(1, -82, 0, 4); valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local bar = mk("Frame", {
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 0, 30),
        BackgroundColor3 = Theme.BgHover,
        BorderSizePixel = 0,
    }, frame)
    corner(bar, 3)

    local fill = mk("Frame", {
        Size = UDim2.new((value - min) / math.max(max - min, 1), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, bar)
    corner(fill, 3)

    local knob = mk("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / math.max(max - min, 1), 0, 0.5, 0),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
    }, bar)
    corner(knob, 7); stroke(knob, Theme.Accent, 2)

    local hit = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
    }, frame)

    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local raw = min + rel * (max - min)
        value = math.floor(raw / step + 0.5) * step
        if step < 1 then value = math.floor(raw / step + 0.5) * step end
        value = math.clamp(value, min, max)
        local alpha = (value - min) / math.max(max - min, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valLbl.Text = step < 1 and string.format("%.2f", value) or tostring(value)
        if opts.Callback then
            local ok, err = pcall(opts.Callback, value)
            if not ok then warn("[Opex] slider callback:", err) end
        end
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        Set = function(_, v) value = v; update({Position = Vector2.new(bar.AbsolutePosition.X + bar.AbsoluteSize.X * ((v - min) / math.max(max - min, 1)), 0)}) end,
        Get = function() return value end,
    }
end

-- Dropdown
local function makeDropdown(parent, opts, multi)
    local values = opts.Values or {}
    local selected = opts.Value
    if multi then selected = (type(opts.Value) == "table") and opts.Value or {} end

    local frame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.BgElement,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    }, parent)
    corner(frame, 6); stroke(frame)

    local title = opts.Title or "Dropdown"
    mkLabel(frame, title, UDim2.new(1, -30, 1, 0), Theme.Text, false).Position = UDim2.new(0, 12, 0, 0)

    local currentText = ""
    if multi then
        currentText = (#selected > 0) and table.concat(selected, ", ") or "None"
    else
        currentText = tostring(selected or (values[1] or "None"))
    end
    local curLbl = mkLabel(frame, currentText, UDim2.new(0, 150, 1, 0), Theme.Accent, true)
    curLbl.Position = UDim2.new(1, -170, 0, 0); curLbl.TextXAlignment = Enum.TextXAlignment.Right

    local arrow = mkLabel(frame, "▼", UDim2.new(0, 20, 1, 0), Theme.TextDim, false)
    arrow.Position = UDim2.new(1, -22, 0, 0); arrow.TextSize = 10

    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, Text = "",
    }, frame)

    -- Popup list
    local popup = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, math.min(#values * 26 + 8, 200)),
        Position = UDim2.new(0, 0, 1, 4),
        BackgroundColor3 = Theme.BgHeader,
        BorderSizePixel = 0,
        Visible = false,
        CanvasSize = UDim2.new(0, 0, 0, #values * 26 + 8),
        ScrollBarThickness = 3,
        ZIndex = 10,
    }, frame)
    corner(popup, 6); stroke(popup, Theme.Accent, 1)
    padding(popup, 4)

    local list = mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, popup)

    local options = {}
    local function refreshVisual()
        if multi then
            curLbl.Text = (#selected > 0) and table.concat(selected, ", ") or "None"
        else
            curLbl.Text = tostring(selected)
        end
    end

    for i, v in ipairs(values) do
        local item = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.BgElement,
            BorderSizePixel = 0,
            Text = "  " .. tostring(v),
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, popup)
        corner(item, 4)
        table.insert(options, item)

        item.MouseEnter:Connect(function() item.BackgroundColor3 = Theme.BgHover end)
        item.MouseLeave:Connect(function() item.BackgroundColor3 = Theme.BgElement end)
        item.MouseButton1Click:Connect(function()
            if multi then
                local idx = table.find(selected, v)
                if idx then table.remove(selected, idx) else table.insert(selected, v) end
                item.BackgroundColor3 = table.find(selected, v) and Theme.Accent or Theme.BgElement
            else
                selected = v
                for _, o in ipairs(options) do o.BackgroundColor3 = Theme.BgElement end
                item.BackgroundColor3 = Theme.Accent
                popup.Visible = false
            end
            refreshVisual()
            if opts.Callback then
                local ok, err = pcall(opts.Callback, selected)
                if not ok then warn("[Opex] dropdown callback:", err) end
            end
        end)
    end

    btn.MouseButton1Click:Connect(function()
        popup.Visible = not popup.Visible
    end)

    local obj = { Refresh = function(_, newList) end }
    function obj:Get() return selected end
    return obj
end

-- Textbox
local function makeInput(parent, opts)
    local frame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.BgElement,
        BorderSizePixel = 0,
    }, parent)
    corner(frame, 6); stroke(frame)

    mkLabel(frame, opts.Title or "Input", UDim2.new(0, 120, 1, 0), Theme.Text, false).Position = UDim2.new(0, 12, 0, 0)

    local box = mk("TextBox", {
        Size = UDim2.new(1, -140, 0, 24),
        Position = UDim2.new(0, 130, 0.5, -12),
        BackgroundColor3 = Theme.BgHeader,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        PlaceholderText = "Type here...",
        PlaceholderColor3 = Theme.TextDim,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 13,
        ClearTextOnFocus = false,
    }, frame)
    corner(box, 4); stroke(box)

    box.FocusLost:Connect(function()
        if opts.Callback then
            local ok, err = pcall(opts.Callback, box.Text)
            if not ok then warn("[Opex] input callback:", err) end
        end
    end)

    return box
end

-- Paragraph (with RefreshDesc)
local function makeParagraph(parent, title, desc)
    local frame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.BgSection,
        BorderSizePixel = 0,
    }, parent)
    corner(frame, 6); stroke(frame)
    padding(frame, 10)

    mkLabel(frame, title or "", UDim2.new(1, 0, 0, 16), Theme.Accent, true).TextSize = 13
    local body = mkLabel(frame, desc or "", UDim2.new(1, 0, 0, 0), Theme.TextDim, false)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Position = UDim2.new(0, 0, 0, 18)
    body.TextSize = 12
    body.TextWrapped = true
    body.RichText = true

    local obj = {}
    function obj:RefreshDesc(t)
        body.Text = t or ""
        frame.Size = UDim2.new(1, 0, 0, 28 + (#body.Text > 60 and 30 or 0) + select(2, string.gsub(t or "", "\n", "")) * 16)
    end
    obj.SetDesc = obj.RefreshDesc
    return obj
end

-- Button
local function makeButton(parent, title, cb)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.BgElement,
        BorderSizePixel = 0,
        Text = title or "Button",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.Text,
        AutoButtonColor = false,
    }, parent)
    corner(btn, 6); stroke(btn)

    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.BgHover }):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.BgElement }):Play() end)
    btn.MouseButton1Click:Connect(function()
        if type(cb) == "function" then
            local ok, err = pcall(cb)
            if not ok then warn("[Opex] button error:", err) end
        end
    end)
    return btn
end

--//========================= WINDOW / TAB / SECTION / MENU =========================//

local function createWindow(cfg)
    cfg = cfg or {}
    local self = { _tabs = {}, _tabButtons = {}, _activeTab = nil }

    local screen = mk("ScreenGui", {
        Name = "OpexHubUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)
    self._screen = screen

    local main = mk("Frame", {
        Name = "Main",
        Size = UDim2.new(0, cfg.Size and cfg.Size.X.Offset or 640, 0, cfg.Size and cfg.Size.Y.Offset or 480),
        Position = UDim2.new(0.5, -320, 0.5, -240),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        Active = true,
    }, screen)
    corner(main, 10); stroke(main, Theme.Border, 1)
    self._main = main

    -- Title bar
    local titleBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.BgHeader,
        BorderSizePixel = 0,
    }, main)
    corner(titleBar, 10)
    mk("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.BgHeader,
        BorderSizePixel = 0,
    }, titleBar)

    mkLabel(titleBar, cfg.Title or "Opex Hub", UDim2.new(1, -100, 1, 0), Theme.Text, true).Position = UDim2.new(0, 16, 0, 0)
    mkLabel(titleBar, "by " .. (cfg.Author or "Opex"), UDim2.new(0, 80, 1, 0), Theme.TextDim, false).Position = UDim2.new(1, -95, 0, 0)

    local closeBtn = mk("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -36, 0.5, -14),
        BackgroundColor3 = Theme.Danger,
        BorderSizePixel = 0,
        Text = "×",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Theme.Text,
    }, titleBar)
    corner(closeBtn, 14)
    closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

    makeDraggable(main, titleBar)

    -- Sidebar
    local sidebar = mk("Frame", {
        Size = UDim2.new(0, 150, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = Theme.BgSidebar,
        BorderSizePixel = 0,
    }, main)
    mk("Frame", {
        Size = UDim2.new(0, 10, 1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        BackgroundColor3 = Theme.BgSidebar,
        BorderSizePixel = 0,
    }, sidebar)

    local tabList = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    }, sidebar)
    padding(tabList, 8)
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)
    self._tabList = tabList

    -- Content
    local content = mk("Frame", {
        Size = UDim2.new(1, -150, 1, -40),
        Position = UDim2.new(0, 150, 0, 40),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
    }, main)
    padding(content, 0, 0, 8, 8)
    self._contentArea = content

    -- Tab creation
    function self:Tab(cfg)
        cfg = cfg or {}
        local tabName = cfg.Title or "Tab"

        -- Tab button
        local tabBtn = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Theme.BgElement,
            BorderSizePixel = 0,
            Text = "  " .. tabName,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        }, tabList)
        corner(tabBtn, 6)

        -- Scroll frame
        local scroll = mk("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        }, content)
        mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
        padding(scroll, 6)

        tabBtn.MouseEnter:Connect(function()
            if self._activeTab ~= tabBtn then tabBtn.BackgroundColor3 = Theme.BgHover end
        end)
        tabBtn.MouseLeave:Connect(function()
            if self._activeTab ~= tabBtn then tabBtn.BackgroundColor3 = Theme.BgElement end
        end)
        tabBtn.MouseButton1Click:Connect(function()
            for _, btn in ipairs(self._tabButtons) do
                btn.BackgroundColor3 = Theme.BgElement
            end
            for _, scr in ipairs(self._tabScrolls) do scr.Visible = false end
            tabBtn.BackgroundColor3 = Theme.Accent
            scroll.Visible = true
            self._activeTab = tabBtn
        end)

        self._tabButtons = self._tabButtons or {}
        self._tabScrolls = self._tabScrolls or {}
        table.insert(self._tabButtons, tabBtn)
        table.insert(self._tabScrolls, scroll)

        if #self._tabButtons == 1 then
            tabBtn.BackgroundColor3 = Theme.Accent
            scroll.Visible = true
            self._activeTab = tabBtn
        end

        -- Tab object (shimmed with addSection)
        local tab = { _name = tabName, _scroll = scroll }

        function tab:addSection()
            local section = { _tab = tab }
            function section:addMenu(name)
                -- Section header
                local header = mk("Frame", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundTransparency = 1,
                }, scroll)
                mk("UIListLayout", { Padding = UDim.new(0, 0) }, header)
                local label = mkLabel(header, "▸ " .. tostring(name), UDim2.new(1, 0, 1, 0), Theme.Accent, true)
                label.TextSize = 14
                return tab  -- menu methods live directly on tab
            end
            return section
        end

        -- Menu methods on tab itself
        function tab:addLabel(title, desc)
            return makeParagraph(scroll, title, desc)
        end

        function tab:addButton(title, cb)
            return makeButton(scroll, title, cb)
        end

        function tab:addButtonGrid(title, gridData)
            if type(gridData) ~= "table" then return end
            for _, entry in ipairs(gridData) do
                if type(entry) == "table" then
                    makeButton(scroll, entry[1] or "Button", entry[2])
                end
            end
        end

        function tab:Toggle(opts)     return makeToggle(scroll, opts) end
        function tab:Slider(opts)     return makeSlider(scroll, opts) end
        function tab:Dropdown(opts)   return makeDropdown(scroll, opts, false) end
        function tab:MultiDropdown(opts) return makeDropdown(scroll, opts, true) end
        function tab:Input(opts)      return makeInput(scroll, opts) end
        function tab:Paragraph(opts)  return makeParagraph(scroll, opts.Title or "", opts.Desc or opts.Content or "") end
        function tab:Button(opts)     return makeButton(scroll, opts.Title, opts.Callback) end
        function tab:Section(opts)    return tab end

        return tab
    end

    function self:Notify(opts) UI:Notify(opts) end

    -- Keybind toggle (RightShift)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            main.Visible = not main.Visible
        end
    end)

    -- Show notify that UI loaded
    task.defer(function()
        task.wait(0.2)
        self:Notify({ Title = "Opex Hub", Content = "Loaded. RightShift to toggle.", Duration = 5 })
    end)

    return self
end

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

--//========================= LOAD LOCAL FILES =========================//
local function loadFile(name)
    local ok, res = pcall(function()
        local path = "OpexHub/" .. name
        if isfile and isfile(path) then return loadstring(readfile(path))() end
    end)
    if not ok then warn("[Opex] load " .. name .. ": " .. tostring(res)) return nil end
    return res
end

Data = loadFile("Data.lua") or Data
Opex.Data = Data
pcall(function() loadFile("Bypass.lua") end)
pcall(function() loadFile("Iris.lua") end)
pcall(function() loadFile("helper.lua") end)

--//========================= CREATE WINDOW =========================//
local Window = createWindow({
    Title = "Opex Hub",
    Author = "Opex",
    Size = UDim2.fromOffset(660, 500),
})

--//========================= FUNCS (element wrappers) =========================//
local function registerFunction(key, value)
    Settings[key] = value
    Module.Functions[key] = Module.Functions[key] or {}
    Module.Functions[key].Value = value
    Module.Functions[key].Enabled = (value == true)
end

function Funcs:CreateToggle(parent, title, key, default, opts)
    opts = opts or {}
    local t = parent:Toggle({
        Title = title, Desc = opts.description or "", Value = default or false,
        Callback = function(state)
            registerFunction(key, state)
            if opts.callback then pcall(opts.callback, state) end
        end,
    })
    registerFunction(key, default or false)
    return t
end

function Funcs:CreateSlider(parent, title, key, min, max, default, opts)
    opts = opts or {}
    local s = parent:Slider({
        Title = title, Desc = opts.description or "",
        Value = { Min = min, Max = max, Default = default },
        Step = opts.step or 1,
        Callback = function(v)
            Settings[key] = v
            Module.Functions[key] = Module.Functions[key] or {}
            Module.Functions[key].Value = v
            if opts.callback then pcall(opts.callback, v) end
        end,
    })
    Settings[key] = default
    return s
end

function Funcs:CreateDropdown(parent, title, key, default, options, opts, multi)
    opts = opts or {}
    local method = multi and parent.MultiDropdown or parent.Dropdown
    local d = method(parent, {
        Title = title, Desc = opts.description or "",
        Values = options or {}, Value = default, Multi = multi or false,
        Callback = function(v)
            Settings[key] = v
            Module.Functions[key] = Module.Functions[key] or {}
            Module.Functions[key].Value = v
            if opts.callback then pcall(opts.callback, v) end
        end,
    })
    Settings[key] = default
    return d
end

function Funcs:CreateTextbox(parent, title, key, opts)
    opts = opts or {}
    return parent:Input({
        Title = title,
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
    local ok, res = pcall(function() return CommF_:InvokeServer(name, ...) end)
    return ok and res or nil
end
function Module:FireEvent(name, ...)
    local ev = Remotes:FindFirstChild(name)
    if ev and ev:IsA("RemoteEvent") then ev:FireServer(...) end
end

--//========================= ACTION HELPERS =========================//
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Actions.TweenTo(cf, speed)
    local hrp = getHRP(); if not hrp then return end
    speed = speed or (Settings.TweenSpeed or 200)
    local dist = (hrp.Position - cf.Position).Magnitude
    local t = dist / speed
    if t <= 0.05 then hrp.CFrame = cf; return end
    if Settings.BypassTP and dist > 300 then
        local steps = math.ceil(dist / 120)
        for i = 1, steps do
            hrp.CFrame = hrp.CFrame:Lerp(cf, i / steps)
            task.wait(0.03)
        end
    else
        local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = cf })
        tw:Play(); tw.Completed:Wait()
    end
end

function Actions.BringMonsters(pos, radius)
    radius = radius or (Settings.BringMonsterRadius or 350)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local root = obj:FindFirstChild("HumanoidRootPart")
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 and (root.Position - pos).Magnitude <= radius then
                root.CFrame = CFrame.new(pos + Vector3.new(0, Settings.PosY or 18, 0))
            end
        end
    end
end

--//========================= ACTIONS (full set) =========================//
function Actions.RemoveEffects()
    pcall(function()
        local Container = ReplicatedStorage:WaitForChild("Effect"):WaitForChild("Container")
        local CameraShaker = require(ReplicatedStorage:WaitForChild("Util"):WaitForChild("CameraShaker"))
        local Death = require(Container:FindFirstChild("Death"))
        local Respawn = require(Container:FindFirstChild("Respawn"))
        local LevelUp = require(Container:FindFirstChild("LevelUp"))
        local DisplayNPC = require(ReplicatedStorage:WaitForChild("GuideModule")).ChangeDisplayedNPC
        hookfunction(Death, function() end); hookfunction(LevelUp, function() end)
        hookfunction(Respawn, function() end); hookfunction(DisplayNPC, function() end)
        CameraShaker:Stop()
        Window:Notify({ Title = "Effects Removed", Content = "Camera shake/VFX disabled.", Duration = 3 })
    end)
end

function Actions.ToggleDamageCounter(v) Settings.DisableDamageCounter = v end
function Actions.ToggleNotifications(v) Settings.DisableNotifications = v end
function Actions.ToggleWalkInWater(v) Settings.Water = v end
function Actions.ToggleAntiAFK(v) Settings.AntiAFK = v end
function Actions.ToggleHopAdmin(v) Settings.HopWhenAdmin = v end
function Actions.OnAutoHop30Mins(v) Settings.AutoHopwhen30mins = v end
function Actions.OnAutoLoadScript(v) Settings.AutoLoadScriptonLoad = v end
function Actions.ToggleXray(v) Settings.XrayVision = v end
function Actions.ToggleInfiniteZoom(v) Settings.InfiniteZoom = v end
function Actions.ToggleWhiteScreen(v) Settings.White_Screen = v end
function Actions.ToggleBlackScreen(v) Settings.BlackScreen = v end
function Actions.ToggleUpgradeDragonTalon(v) Settings.AutoUpgradeDragonTalon = v end
function Actions.OnFastModeToggle(v) Settings.AutoFastMode = v end
function Actions.OnCamLockToggle(v) Settings.CamLock = v end
function Actions.OnSpectateToggle(v) Settings.SpectatePlayer = v end
function Actions.OnTPPlayerToggle(v) Settings.TeleporttoPlayer = v end

function Actions.GetPlayerList()
    local out = { "Nearest" }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then table.insert(out, plr.Name) end
    end
    return out
end

function Actions.GetStatsInfo()
    local lvl = LocalPlayer:GetAttribute("Level") or "?"
    local beli = LocalPlayer:GetAttribute("Beli") or "?"
    local frag = LocalPlayer:GetAttribute("Fragments") or "?"
    local hum = getHum()
    return ("Level: %s | Beli: %s\nFrags: %s | HP: %d/%d"):format(
        tostring(lvl), tostring(beli), tostring(frag),
        math.floor(hum and hum.Health or 0), math.floor(hum and hum.MaxHealth or 0))
end

function Actions.StatusServer()
    return ("JobId: %s\nPlayers: %d/%d\nPing: %dms"):format(
        tostring(game.JobId), #Players:GetPlayers(), Players.MaxPlayers,
        math.floor(LocalPlayer:GetNetworkPing() * 1000))
end

function Actions.PlayerStatus()
    return ("Name: %s\nUser: %s\nAge: %d days"):format(
        LocalPlayer.DisplayName, LocalPlayer.Name, LocalPlayer.AccountAge)
end

function Actions.GetFruitStock()
    local ok, stock = pcall(function() return Module:FireInvoke("GetFruits") end)
    if ok and type(stock) == "table" then
        local out = {}
        for _, f in ipairs(stock) do table.insert(out, tostring(f.Name or f)) end
        return #out > 0 and table.concat(out, ", ") or "Empty"
    end
    return "—"
end

function Actions.AutoStats()
    local points = Settings.PointsSlider or 10
    local stat
    if Settings.Melee then stat = "Melee"
    elseif Settings.Defense then stat = "Defense"
    elseif Settings.Sword then stat = "Sword"
    elseif Settings.Gun then stat = "Gun"
    elseif Settings.DemonFruit then stat = "Demon Fruit" end
    if stat then Module:FireInvoke("AddPoint", stat, points) end
end

function Actions.SetWalkSpeed(v) local h = getHum(); if h then h.WalkSpeed = v end end
function Actions.SetJumpPower(v) local h = getHum(); if h then h.JumpPower = v end end
function Actions.CleanMemory() if collectgarbage then collectgarbage("collect") end end

function Actions.RejoinServer() TeleportService:Teleport(game.PlaceId, LocalPlayer) end

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

function Actions.TeleportJobID(v)
    if v and #v > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, v, LocalPlayer) end
end
function Actions.TeleportQuantumPremium(v) print("[Opex] QuantumPremium:", v) end
function Actions.JoinAPI(kind) print("[Opex] JoinAPI:", kind) end
function Actions.JoinRaidBossServer() Actions.ServerHop() end

function Actions.BuyItem(item, category)
    if not item or not category then return end
    local entry = Data.ItemsToBuy and Data.ItemsToBuy[category] and Data.ItemsToBuy[category][item]
    if not entry then Module:FireInvoke(item); return end
    if type(entry[1]) == "table" then
        for _, r in ipairs(entry) do Module:FireInvoke(r[1], table.unpack(r, 2)) end
    else
        Module:FireInvoke(entry[1], table.unpack(entry, 2))
    end
end
function Actions.BuySelectedFruit() Module:FireInvoke("PurchaseRawFruit", Settings.SelectFruitDealerFruit) end
function Actions.CraftScroll() Module:FireInvoke("CraftScroll") end
function Actions.BuyCyborgRace() Module:FireInvoke("BuyCyborg") end
function Actions.BuyGhoulRace() Module:FireInvoke("BuyGhoul") end

function Actions.GetAllBoats() return { "My Boat" } end
function Actions.BuyNewBoat() Module:FireInvoke("BuyBoat") end
function Actions.BribeLeviathan() Module:FireInvoke("BribeLeviathan") end
function Actions.TPDojoTrainer() Actions.TravelToNPC("Dojo Trainer") end
function Actions.TPDragonHunter() Actions.TravelToNPC("Dragon Hunter") end
function Actions.TPDragonWizard() Actions.TravelToNPC("Dragon Wizard") end
function Actions.TPTrialArea(area)
    local map = {
        GreatTree = CFrame.new(2205, 22, -6766),
        TempleOfTime = CFrame.new(-12463, 374, -7523),
        AncientOne = CFrame.new(-9517, 142, 5528),
        LeverPull = CFrame.new(-9517, 142, 5528),
        SafeZone = CFrame.new(2205, 22, -6766),
        PvpZone = CFrame.new(2205, 22, -6766),
        Clock = CFrame.new(2205, 22, -6766),
    }
    if map[area] then Actions.TweenTo(map[area]) end
end
function Actions.TPRaceDoor() Actions.TravelToNPC("Race Door") end
function Actions.ResetCharHead() local c = LocalPlayer.Character; if c then c:BreakJoints() end end
function Actions.ChangeDracoRace() Module:FireInvoke("ChangeRace", "Draco") end
function Actions.CraftPrehistoricItem(i) Module:FireInvoke("Craft", i) end
function Actions.TPDungeonHub() Module:FireInvoke("Dungeon", "Hub") end
function Actions.TPDungeonBack() Module:FireInvoke("Dungeon", "Back") end
function Actions.UnlockDungeonDifficulty() Module:FireInvoke("Dungeon", "Unlock") end

function Actions.BuyTrinket() Module:FireInvoke("BuyTrinket") end
function Actions.FuseTrinkets() Module:FireInvoke("FuseTrinket") end
function Actions.RefineTrinket() Module:FireInvoke("RefineTrinket") end
function Actions.OpenTrinketMergeGUI() Module:FireInvoke("OpenTrinketMerge") end
function Actions.OpenTrinketRefineGUI() Module:FireInvoke("OpenTrinketRefine") end
function Actions.OpenTrinketScrapGUI() Module:FireInvoke("OpenTrinketScrap") end

function Actions.OpenTitleNames() Module:FireInvoke("OpenTitles") end
function Actions.OpenAwakenings() Module:FireInvoke("OpenAwakenings") end
function Actions.OpenHakiColors() Module:FireInvoke("OpenHakiColors") end
function Actions.OpenFishIndex() Module:FireInvoke("FishIndex") end
function Actions.OpenNormalFruitShop() Module:FireInvoke("OpenShop") end
function Actions.OpenAdvFruitShop() Module:FireInvoke("OpenAdvancedShop") end
function Actions.TPAdvFruitDealer() Actions.TravelToNPC("Advanced Fruit Dealer") end
function Actions.RedeemAllCodes()
    local codes = { "SUB2GAMERROBOT_EXP1", "SUB2OFFICIALNOOBIE", "StarcodeHEO",
        "KITT_RESET", "Sub2Fer999", "Enyu_is_Pro", "Magicbus", "JCWK",
        "Starcodeheo", "Bluxxy", "fudd10_v2", "FUDD10", "BIGNEWS",
        "THEGREATACE", "SUB2GAMERROBOT_RESET1", "Sub2OfficialNoobie" }
    for _, c in ipairs(codes) do Module:FireInvoke("Redeem", c); task.wait(0.3) end
end
function Actions.ForceFPSBoost()
    pcall(function()
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false end
        end
        Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = 1
    end)
end
function Actions.OpenDevConsole() StarterGui:SetCore("DevConsoleVisible", true) end
function Actions.GetPlayerHunterQuest() Module:FireInvoke("StartQuest", "PlayerHunter") end

function Actions.TravelToNPC(npcName)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == npcName and obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") then
            Actions.TweenTo(obj.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0))
            return
        end
    end
end

function Actions.TravelToIsland(name)
    local lvl = LocalPlayer:GetAttribute("Level") or 0
    local sea = 1; if lvl >= 1500 then sea = 3 elseif lvl >= 700 then sea = 2 end
    local islands = Data.Islands["Sea " .. sea] or {}
    if islands[name] then Actions.TweenTo(islands[name]) end
end

function Actions.SendTestWebhook()
    local url = Settings.Webhook
    if not url or #url < 10 then return end
    pcall(function()
        request({ Url = url, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ content = "**Opex Hub** — test OK", username = "Opex Hub" }) })
    end)
end

function Actions.SendDataLogNow()
    local url = Settings.DataLogWebhookUrl
    if not url or #url < 10 then return end
    local hum = getHum()
    pcall(function()
        request({ Url = url, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                content = ("**Data Log**\nLevel: %s | Beli: %s | Frags: %s\nHP: %d/%d"):format(
                    LocalPlayer:GetAttribute("Level") or "?",
                    LocalPlayer:GetAttribute("Beli") or "?",
                    LocalPlayer:GetAttribute("Fragments") or "?",
                    math.floor(hum and hum.Health or 0), math.floor(hum and hum.MaxHealth or 0)),
                username = "Opex Hub" }) })
    end)
end

-- ESP stubs
local ESPObjects = {}
function Actions.CreateESP(target)
    if not target or ESPObjects[target] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1; box.Color = Color3.fromRGB(70, 130, 220); box.Filled = false; box.Visible = false
    ESPObjects[target] = box
    task.spawn(function()
        while ESPObjects[target] do
            if not target or not target.Parent then box:Remove(); ESPObjects[target] = nil; break end
            local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
            if root then
                local pos, on = Camera:WorldToViewportPoint(root.Position)
                box.Visible = on
                if on then box.Size = Vector2.new(50, 50); box.Position = Vector2.new(pos.X - 25, pos.Y - 25) end
            else box.Visible = false end
            task.wait(0.05)
        end
    end)
end
function Actions.ClearESP()
    for t, b in pairs(ESPObjects) do if b then b:Remove() end end
    ESPObjects = {}
end
function Actions.EnablePlayerESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then Actions.CreateESP(p.Character) end
    end
end
function Actions.EnableIslandESP()
    for _, o in ipairs(workspace:GetChildren()) do
        if o.Name:lower():find("island") then Actions.CreateESP(o) end
    end
end
function Actions.EnableFruitESP()
    for _, o in ipairs(workspace:GetChildren()) do
        if o.Name:find("Fruit") then Actions.CreateESP(o) end
    end
end
function Actions.EnableChestESP()
    for _, o in ipairs(workspace:GetChildren()) do
        if o.Name:find("Chest") then Actions.CreateESP(o) end
    end
end

--//========================= BUILD UI FROM UITabs =========================//
local Tabs = {
    Home    = Window:Tab({ Title = "Home" }),
    Sub     = Window:Tab({ Title = "Sub" }),
    Sevent  = Window:Tab({ Title = "Sea Events" }),
    Player  = Window:Tab({ Title = "Player" }),
    Dragon  = Window:Tab({ Title = "Dragon" }),
    Raid    = Window:Tab({ Title = "Raid" }),
    Trial   = Window:Tab({ Title = "Trial" }),
    Travel  = Window:Tab({ Title = "Travel" }),
    Shop    = Window:Tab({ Title = "Shop" }),
    Misc    = Window:Tab({ Title = "Misc" }),
    Web     = Window:Tab({ Title = "Webhook" }),
}

local UITabs = loadFile("UITabs.lua")
if UITabs then
    local ctx = {
        Funcs = Funcs, Settings = Settings, Module = Module, Data = Data, Actions = Actions,
        PlayerESP = Actions.EnablePlayerESP, IslandESP = Actions.EnableIslandESP,
        FruitESP = Actions.EnableFruitESP, ChestESP = Actions.EnableChestESP,
        BerryESP = function() end, RealFruitESP = function() end,
        ClearESP = function() Actions.ClearESP() end,
    }
    local ok, err = pcall(function() UITabs(Tabs, ctx) end)
    if not ok then warn("[Opex] UITabs error: " .. tostring(err)) end
else
    warn("[Opex] UITabs.lua not found.")
end

--//========================= BACKGROUND TASKS =========================//
task.spawn(function()
    while task.wait(60) do
        if Settings.AntiAFK then
            pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
        end
    end
end)

task.spawn(function()
    while task.wait(60) do
        if Settings.AutoCleanMemory then pcall(function() collectgarbage("collect") end) end
    end
end)

print("[Opex Hub] Loaded. Press RightShift to toggle UI.")
