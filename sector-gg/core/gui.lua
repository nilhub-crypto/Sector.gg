-- Sector.gg GUI Engine v2.0
-- Mobile-compatible, compact, animated background

local GUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Theme
local THEME = {
    BG          = Color3.fromRGB(10, 10, 11),
    BG2         = Color3.fromRGB(17, 17, 19),
    BG3         = Color3.fromRGB(24, 24, 28),
    BG4         = Color3.fromRGB(34, 34, 38),
    BORDER      = Color3.fromRGB(42, 42, 48),
    BORDER2     = Color3.fromRGB(58, 58, 66),
    TEXT        = Color3.fromRGB(240, 240, 242),
    TEXT2       = Color3.fromRGB(136, 136, 160),
    TEXT3       = Color3.fromRGB(74, 74, 90),
    WHITE       = Color3.fromRGB(255, 255, 255),
    GREEN       = Color3.fromRGB(74, 222, 128),
    ACCENT      = Color3.fromRGB(130, 100, 255),
    ACCENT2     = Color3.fromRGB(80, 180, 255),
}

local function fetch(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res and res ~= "" then return res end
    return nil
end

local function Create(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then obj[k] = v end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = obj
        end
    end
    if props.Parent then obj.Parent = props.Parent end
    return obj
end

local function MakeStroke(parent, color, thickness)
    return Create("UIStroke", {Parent=parent, Color=color or THEME.BORDER, Thickness=thickness or 1})
end

local function MakeCorner(parent, radius)
    return Create("UICorner", {Parent=parent, CornerRadius=UDim.new(0, radius or 8)})
end

local function Tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- Animated shimmer bar
local function MakeColorBar(parent, y)
    local bar = Create("Frame", {
        Parent=parent, BackgroundColor3=THEME.WHITE,
        Position=UDim2.new(0,0,0,y), Size=UDim2.new(1,0,0,1), BorderSizePixel=0
    })
    local grad = Create("UIGradient", {Parent=bar, Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(20,20,28)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(130,100,255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80,180,255)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(130,100,255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(20,20,28)),
    })})
    task.spawn(function()
        local offset = 0
        while bar.Parent do
            offset = (offset + 0.006) % 1
            grad.Offset = Vector2.new(math.sin(offset * math.pi * 2) * 0.6, 0)
            task.wait(0.03)
        end
    end)
    return bar
end

-- Floating particle background animation
local function MakeParticles(parent, w, h)
    local particleCount = 18
    local particles = {}
    for i = 1, particleCount do
        local size = math.random(2, 5)
        local x = math.random(0, w)
        local y = math.random(0, h)
        local alpha = math.random(20, 60) / 100
        local dot = Create("Frame", {
            Parent=parent, BackgroundColor3=i % 2 == 0 and THEME.ACCENT or THEME.ACCENT2,
            Position=UDim2.new(0, x, 0, y),
            Size=UDim2.new(0, size, 0, size),
            BackgroundTransparency=1 - alpha,
            BorderSizePixel=0, ZIndex=1
        })
        MakeCorner(dot, size)
        local speed = math.random(40, 90) / 100
        local drift = (math.random(-10, 10)) / 100
        particles[i] = {dot=dot, x=x, y=y, speed=speed, drift=drift, size=size}
    end

    task.spawn(function()
        while parent.Parent do
            for _, p in ipairs(particles) do
                p.y = p.y - p.speed
                p.x = p.x + p.drift
                if p.y < -p.size then p.y = h + p.size end
                if p.x < -p.size then p.x = w + p.size end
                if p.x > w + p.size then p.x = -p.size end
                p.dot.Position = UDim2.new(0, p.x, 0, p.y)
            end
            task.wait(0.03)
        end
    end)
end

function GUI:Init(config, baseUrl)
    if PlayerGui:FindFirstChild("SectorGG") then
        PlayerGui.SectorGG:Destroy()
    end

    local screenGui = Create("ScreenGui", {
        Name="SectorGG", Parent=PlayerGui,
        ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
        DisplayOrder=999
    })

    -- Detect mobile
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    -- Main window — shorter height (360 vs 440)
    local WIN_W = 340
    local WIN_H = 370
    local window = Create("Frame", {
        Parent=screenGui, Name="Window",
        BackgroundColor3=THEME.BG,
        Position=UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
        Size=UDim2.new(0, WIN_W, 0, WIN_H),
        BorderSizePixel=0, Active=true, ClipsDescendants=true
    })
    MakeCorner(window, 12)
    MakeStroke(window, THEME.BORDER, 1)

    -- Background particles (behind everything, ZIndex=1)
    MakeParticles(window, WIN_W, WIN_H)

    -- Content overlay so particles don't cover UI
    local overlay = Create("Frame", {
        Parent=window, BackgroundTransparency=1,
        Size=UDim2.new(1,0,1,0), ZIndex=2
    })

    -- ── DRAG (Mouse + Touch) ──────────────────────────────────────
    local dragging, dragStart, startPos = false, nil, nil

    local function beginDrag(inputPos)
        dragging = true
        dragStart = inputPos
        startPos = window.Position
    end
    local function moveDrag(inputPos)
        if not dragging then return end
        local delta = inputPos - dragStart
        window.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    local function endDrag() dragging = false end

    window.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            beginDrag(input.Position)
        elseif input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input.Position)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            moveDrag(input.Position)
        elseif input.UserInputType == Enum.UserInputType.Touch then
            moveDrag(input.Position)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)

    -- ── TOP BAR ───────────────────────────────────────────────────
    local topbar = Create("Frame", {
        Parent=overlay, BackgroundColor3=THEME.BG2,
        Size=UDim2.new(1,0,0,40), BorderSizePixel=0, ZIndex=3
    })
    MakeCorner(topbar, 12)
    Create("Frame", {
        Parent=topbar, BackgroundColor3=THEME.BG2,
        Position=UDim2.new(0,0,0.5,0), Size=UDim2.new(1,0,0.5,0), BorderSizePixel=0, ZIndex=3
    })

    -- Animated title gradient
    local titleLabel = Create("TextLabel", {
        Parent=topbar, BackgroundTransparency=1,
        Position=UDim2.new(0,14,0,0), Size=UDim2.new(0.55,0,1,0),
        Text="SECTOR.gg", TextColor3=THEME.WHITE,
        Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=4
    })

    -- Status dot
    local statusDot = Create("Frame", {
        Parent=topbar, BackgroundColor3=THEME.GREEN,
        Position=UDim2.new(1,-72,0.5,-3), Size=UDim2.new(0,6,0,6), ZIndex=4
    })
    MakeCorner(statusDot, 3)
    Create("TextLabel", {
        Parent=topbar, BackgroundTransparency=1,
        Position=UDim2.new(1,-62,0,0), Size=UDim2.new(0,44,1,0),
        Text="Online", TextColor3=THEME.TEXT2, Font=Enum.Font.Gotham, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4
    })
    task.spawn(function()
        local on = true
        while statusDot.Parent do
            Tween(statusDot, {BackgroundTransparency = on and 0.5 or 0}, 1)
            on = not on
            task.wait(1)
        end
    end)

    -- Close button
    local closeBtn = Create("TextButton", {
        Parent=topbar, BackgroundTransparency=1,
        Position=UDim2.new(1,-34,0,0), Size=UDim2.new(0,34,1,0),
        Text="✕", TextColor3=THEME.TEXT3, Font=Enum.Font.GothamBold, TextSize=13, ZIndex=5
    })
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = THEME.TEXT end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = THEME.TEXT3 end)
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

    -- Shimmer bar under top bar
    MakeColorBar(overlay, 40)

    -- ── TABS ──────────────────────────────────────────────────────
    local tabsFrame = Create("Frame", {
        Parent=overlay, BackgroundTransparency=1,
        Position=UDim2.new(0,0,0,47), Size=UDim2.new(1,0,0,32), ZIndex=3
    })
    Create("UIListLayout", {
        Parent=tabsFrame, FillDirection=Enum.FillDirection.Horizontal,
        Padding=UDim.new(0,4), VerticalAlignment=Enum.VerticalAlignment.Center
    })
    Create("UIPadding", {Parent=tabsFrame, PaddingLeft=UDim.new(0,10)})

    -- ── CONTENT SCROLL ────────────────────────────────────────────
    local contentFrame = Create("ScrollingFrame", {
        Parent=overlay, BackgroundTransparency=1,
        Position=UDim2.new(0,10,0,84), Size=UDim2.new(1,-20,0,WIN_H-84-34),
        ScrollBarThickness=2, ScrollBarImageColor3=THEME.BORDER2,
        CanvasSize=UDim2.new(0,0,0,0), BorderSizePixel=0, ZIndex=3
    })
    Create("UIListLayout", {
        Parent=contentFrame, Padding=UDim.new(0,6),
        SortOrder=Enum.SortOrder.LayoutOrder
    })

    -- ── BUILD TABS ────────────────────────────────────────────────
    local tabs = config.tabs or {}
    local activeTab = nil
    local tabButtons = {}
    local buttonSections = {}

    local function setActive(tabName)
        if activeTab == tabName then return end
        activeTab = tabName
        for name, btn in pairs(tabButtons) do
            if name == tabName then
                Tween(btn, {BackgroundColor3=THEME.BG3, BackgroundTransparency=0}, 0.12)
                btn.TextColor3 = THEME.TEXT
            else
                Tween(btn, {BackgroundTransparency=1}, 0.12)
                btn.TextColor3 = THEME.TEXT2
            end
        end
        for name, section in pairs(buttonSections) do
            section.Visible = (name == tabName)
        end
        local layout = contentFrame:FindFirstChildOfClass("UIListLayout")
        if layout then
            contentFrame.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 8)
        end
    end

    for i, tab in ipairs(tabs) do
        -- Tab button
        local tabBtn = Create("TextButton", {
            Parent=tabsFrame, BackgroundColor3=THEME.BG3,
            Size=UDim2.new(0,0,0,24), AutomaticSize=Enum.AutomaticSize.X,
            Text=" " .. tab.name .. " ",
            TextColor3=THEME.TEXT2, Font=Enum.Font.GothamMedium, TextSize=11,
            BorderSizePixel=0, BackgroundTransparency=1, ZIndex=4
        })
        MakeCorner(tabBtn, 6)
        MakeStroke(tabBtn, THEME.BORDER, 1)
        tabButtons[tab.name] = tabBtn

        -- Section
        local section = Create("Frame", {
            Parent=contentFrame, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
            Visible=false, LayoutOrder=i, ZIndex=3
        })
        local grid = Create("Frame", {
            Parent=section, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=3
        })
        Create("UIGridLayout", {
            Parent=grid, CellSize=UDim2.new(0.5,-4,0,50),
            CellPaddingSize=UDim2.new(0,6,0,6), SortOrder=Enum.SortOrder.LayoutOrder
        })
        buttonSections[tab.name] = section

        -- Buttons
        local buttons = tab.buttons or {}
        for j, btnCfg in ipairs(buttons) do
            local btnFrame = Create("Frame", {
                Parent=grid, BackgroundColor3=THEME.BG3,
                BorderSizePixel=0, LayoutOrder=j, ZIndex=4
            })
            MakeCorner(btnFrame, 8)
            MakeStroke(btnFrame, THEME.BORDER, 1)

            Create("TextLabel", {
                Parent=btnFrame, BackgroundTransparency=1,
                Position=UDim2.new(0,8,0,8), Size=UDim2.new(1,-18,0,15),
                Text=btnCfg.name, TextColor3=THEME.TEXT,
                Font=Enum.Font.GothamMedium, TextSize=11,
                TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5
            })
            Create("TextLabel", {
                Parent=btnFrame, BackgroundTransparency=1,
                Position=UDim2.new(0,8,0,24), Size=UDim2.new(1,-18,0,11),
                Text=btnCfg.desc or "", TextColor3=THEME.TEXT3,
                Font=Enum.Font.Gotham, TextSize=9,
                TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5
            })

            if btnCfg.type == "toggle" then
                local togOn = false
                local togBg = Create("Frame", {
                    Parent=btnFrame, BackgroundColor3=THEME.BORDER2,
                    Position=UDim2.new(1,-28,0,7), Size=UDim2.new(0,22,0,12), BorderSizePixel=0, ZIndex=5
                })
                MakeCorner(togBg, 6)
                local togDot = Create("Frame", {
                    Parent=togBg, BackgroundColor3=THEME.WHITE,
                    Position=UDim2.new(0,2,0,2), Size=UDim2.new(0,8,0,8), BorderSizePixel=0, ZIndex=6
                })
                MakeCorner(togDot, 4)

                local clickArea = Create("TextButton", {
                    Parent=btnFrame, BackgroundTransparency=1,
                    Size=UDim2.new(1,0,1,0), Text="", ZIndex=7
                })
                clickArea.MouseButton1Click:Connect(function()
                    togOn = not togOn
                    if togOn then
                        Tween(togBg, {BackgroundColor3=THEME.ACCENT}, 0.15)
                        Tween(togDot, {Position=UDim2.new(0,12,0,2), BackgroundColor3=THEME.WHITE}, 0.15)
                        Tween(btnFrame, {BackgroundColor3=THEME.BG4}, 0.1)
                        task.spawn(function()
                            local scriptUrl = baseUrl .. "/" .. tab.name .. "/" .. btnCfg.name:gsub(" ","_") .. ".lua"
                            local src = fetch(scriptUrl)
                            if src then
                                local fn, err = loadstring(src)
                                if fn then fn() else warn("[Sector.gg] Script error: " .. tostring(err)) end
                            else
                                warn("[Sector.gg] Could not load: " .. scriptUrl)
                            end
                        end)
                    else
                        Tween(togBg, {BackgroundColor3=THEME.BORDER2}, 0.15)
                        Tween(togDot, {Position=UDim2.new(0,2,0,2), BackgroundColor3=THEME.WHITE}, 0.15)
                        Tween(btnFrame, {BackgroundColor3=THEME.BG3}, 0.1)
                    end
                end)
            else
                local execBtn = Create("TextButton", {
                    Parent=btnFrame, BackgroundColor3=THEME.BG4,
                    Position=UDim2.new(1,-30,0,6), Size=UDim2.new(0,22,0,22),
                    Text="▶", TextColor3=THEME.TEXT2, Font=Enum.Font.GothamBold, TextSize=10,
                    BorderSizePixel=0, ZIndex=7
                })
                MakeCorner(execBtn, 6)
                execBtn.MouseButton1Click:Connect(function()
                    task.spawn(function()
                        local scriptUrl = baseUrl .. "/" .. tab.name .. "/" .. btnCfg.name:gsub(" ","_") .. ".lua"
                        local src = fetch(scriptUrl)
                        if src then
                            local fn, err = loadstring(src)
                            if fn then fn() else warn("[Sector.gg] Script error: " .. tostring(err)) end
                        else
                            warn("[Sector.gg] Could not load: " .. scriptUrl)
                        end
                    end)
                end)
            end
        end

        tabBtn.MouseButton1Click:Connect(function() setActive(tab.name) end)
        tabBtn.MouseEnter:Connect(function()
            if activeTab ~= tab.name then
                Tween(tabBtn, {BackgroundColor3=THEME.BG4, BackgroundTransparency=0}, 0.1)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if activeTab ~= tab.name then
                Tween(tabBtn, {BackgroundTransparency=1}, 0.1)
            end
        end)

        if i == 1 then setActive(tab.name) end
    end

    -- ── FOOTER ────────────────────────────────────────────────────
    local footer = Create("Frame", {
        Parent=overlay, BackgroundColor3=THEME.BG2,
        Position=UDim2.new(0,0,1,-32), Size=UDim2.new(1,0,0,32),
        BorderSizePixel=0, ZIndex=3
    })
    MakeCorner(footer, 12)
    Create("Frame", {
        Parent=footer, BackgroundColor3=THEME.BG2,
        Size=UDim2.new(1,0,0.5,0), BorderSizePixel=0, ZIndex=3
    })
    Create("TextLabel", {
        Parent=footer, BackgroundTransparency=1,
        Position=UDim2.new(0,12,0,0), Size=UDim2.new(0.6,0,1,0),
        Text="discord.gg/sector", TextColor3=THEME.TEXT3,
        Font=Enum.Font.Gotham, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4
    })
    Create("TextLabel", {
        Parent=footer, BackgroundTransparency=1,
        Position=UDim2.new(1,-58,0,0), Size=UDim2.new(0,52,1,0),
        Text="v" .. (config.version or "1.0.0"), TextColor3=THEME.TEXT3,
        Font=Enum.Font.Gotham, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Right, ZIndex=4
    })

    -- Subtle window fade-in on open
    window.BackgroundTransparency = 1
    Tween(window, {BackgroundTransparency=0}, 0.2)

    return screenGui
end

return GUI
