-- Sector.gg GUI Engine v1.0
-- Reads config.json from GitHub and builds the GUI dynamically

local GUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
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

-- Animated color bar (shifting white/gray)
local function MakeColorBar(parent, y)
    local bar = Create("Frame", {
        Parent=parent, BackgroundColor3=THEME.WHITE,
        Position=UDim2.new(0,0,0,y), Size=UDim2.new(1,0,0,2), BorderSizePixel=0
    })
    Create("UIGradient", {Parent=bar, Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30,30,35)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(200,200,210)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(200,200,210)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30,30,35)),
    })})
    -- Animate gradient offset
    task.spawn(function()
        local offset = 0
        while bar.Parent do
            offset = (offset + 0.008) % 1
            local grad = bar:FindFirstChildOfClass("UIGradient")
            if grad then grad.Offset = Vector2.new(math.sin(offset * math.pi * 2) * 0.5, 0) end
            task.wait(0.03)
        end
    end)
    return bar
end

function GUI:Init(config, baseUrl)
    -- Destroy existing
    if PlayerGui:FindFirstChild("SectorGG") then
        PlayerGui.SectorGG:Destroy()
    end

    local screenGui = Create("ScreenGui", {
        Name="SectorGG", Parent=PlayerGui,
        ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
        DisplayOrder=999
    })

    -- Main window
    local window = Create("Frame", {
        Parent=screenGui, Name="Window",
        BackgroundColor3=THEME.BG,
        Position=UDim2.new(0.5,-175,0.5,-220),
        Size=UDim2.new(0,350,0,440),
        BorderSizePixel=0, Active=true
    })
    MakeCorner(window, 12)
    MakeStroke(window, THEME.BORDER, 1)

    -- Scanline texture overlay
    local scan = Create("Frame", {
        Parent=window, BackgroundTransparency=1,
        Size=UDim2.new(1,0,1,0), ZIndex=10
    })

    -- Drag logic
    local dragging, dragStart, startPos = false, nil, nil
    window.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = window.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- Top bar
    local topbar = Create("Frame", {
        Parent=window, BackgroundColor3=THEME.BG2,
        Size=UDim2.new(1,0,0,42), BorderSizePixel=0
    })
    MakeCorner(topbar, 12)
    -- Square off bottom corners of topbar
    Create("Frame", {
        Parent=topbar, BackgroundColor3=THEME.BG2,
        Position=UDim2.new(0,0,0.5,0), Size=UDim2.new(1,0,0.5,0), BorderSizePixel=0
    })

    Create("TextLabel", {
        Parent=topbar, BackgroundTransparency=1,
        Position=UDim2.new(0,14,0,0), Size=UDim2.new(0.5,0,1,0),
        Text="SECTOR.gg", TextColor3=THEME.WHITE,
        Font=Enum.Font.GothamBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left
    })

    -- Status dot
    local statusDot = Create("Frame", {
        Parent=topbar, BackgroundColor3=THEME.GREEN,
        Position=UDim2.new(1,-60,0.5,-3), Size=UDim2.new(0,6,0,6)
    })
    MakeCorner(statusDot, 3)

    Create("TextLabel", {
        Parent=topbar, BackgroundTransparency=1,
        Position=UDim2.new(1,-50,0,0), Size=UDim2.new(0,40,1,0),
        Text="Online", TextColor3=THEME.TEXT2, Font=Enum.Font.Gotham, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left
    })

    -- Pulse animation on dot
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
        Position=UDim2.new(1,-36,0,0), Size=UDim2.new(0,36,1,0),
        Text="✕", TextColor3=THEME.TEXT3, Font=Enum.Font.GothamBold, TextSize=13
    })
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = THEME.TEXT end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = THEME.TEXT3 end)
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

    -- Color bar
    MakeColorBar(window, 42)

    -- Game badge
    local badge = Create("Frame", {
        Parent=window, BackgroundColor3=THEME.BG3,
        Position=UDim2.new(0,12,0,52), Size=UDim2.new(1,-24,0,38), BorderSizePixel=0
    })
    MakeCorner(badge, 8)
    MakeStroke(badge, THEME.BORDER, 1)

    Create("TextLabel", {
        Parent=badge, BackgroundTransparency=1,
        Position=UDim2.new(0,10,0,0), Size=UDim2.new(0.7,0,0.55,0),
        Text=config.gameName or "Unknown Game",
        TextColor3=THEME.TEXT, Font=Enum.Font.GothamMedium, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left
    })
    Create("TextLabel", {
        Parent=badge, BackgroundTransparency=1,
        Position=UDim2.new(0,10,0.55,0), Size=UDim2.new(0.7,0,0.45,0),
        Text="ID: " .. tostring(game.PlaceId),
        TextColor3=THEME.TEXT3, Font=Enum.Font.Gotham, TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left
    })

    -- Loaded pill
    local loadedPill = Create("Frame", {
        Parent=badge, BackgroundColor3=Color3.fromRGB(74,222,128,0.08),
        Position=UDim2.new(1,-70,0.5,-11), Size=UDim2.new(0,60,0,22), BorderSizePixel=0
    })
    loadedPill.BackgroundColor3 = Color3.fromRGB(10,40,20)
    MakeCorner(loadedPill, 4)
    MakeStroke(loadedPill, Color3.fromRGB(40,90,55), 1)
    Create("TextLabel", {
        Parent=loadedPill, BackgroundTransparency=1,
        Size=UDim2.new(1,0,1,0),
        Text="● Loaded", TextColor3=THEME.GREEN,
        Font=Enum.Font.Gotham, TextSize=10
    })

    -- Second color bar
    MakeColorBar(window, 98)

    -- Tabs
    local tabsFrame = Create("Frame", {
        Parent=window, BackgroundTransparency=1,
        Position=UDim2.new(0,0,0,106), Size=UDim2.new(1,0,0,36)
    })
    Create("UIListLayout", {
        Parent=tabsFrame, FillDirection=Enum.FillDirection.Horizontal,
        Padding=UDim.new(0,4), VerticalAlignment=Enum.VerticalAlignment.Center
    })
    Create("UIPadding", {Parent=tabsFrame, PaddingLeft=UDim.new(0,12)})

    -- Content scroll
    local contentFrame = Create("ScrollingFrame", {
        Parent=window, BackgroundTransparency=1,
        Position=UDim2.new(0,12,0,148), Size=UDim2.new(1,-24,0,250),
        ScrollBarThickness=2, ScrollBarImageColor3=THEME.BORDER2,
        CanvasSize=UDim2.new(0,0,0,0), BorderSizePixel=0
    })
    Create("UIListLayout", {
        Parent=contentFrame, Padding=UDim.new(0,6),
        SortOrder=Enum.SortOrder.LayoutOrder
    })

    -- Build tabs and content
    local tabs = config.tabs or {}
    local activeTab = nil
    local tabButtons = {}
    local buttonSections = {}

    local function setActive(tabName)
        if activeTab == tabName then return end
        activeTab = tabName

        for name, btn in pairs(tabButtons) do
            if name == tabName then
                Tween(btn, {BackgroundColor3=THEME.BG3}, 0.1)
                btn.TextColor3 = THEME.TEXT
            else
                Tween(btn, {BackgroundColor3=Color3.fromRGB(0,0,0,0)}, 0.1)
                btn.TextColor3 = THEME.TEXT2
            end
        end

        for name, section in pairs(buttonSections) do
            section.Visible = (name == tabName)
        end

        -- Update canvas size
        local layout = contentFrame:FindFirstChildOfClass("UIListLayout")
        if layout then
            contentFrame.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 8)
        end
    end

    for i, tab in ipairs(tabs) do
        -- Tab button
        local tabBtn = Create("TextButton", {
            Parent=tabsFrame, BackgroundColor3=THEME.BG3,
            Size=UDim2.new(0,0,0,26), AutomaticSize=Enum.AutomaticSize.X,
            Text=" " .. tab.name .. " ",
            TextColor3=THEME.TEXT2, Font=Enum.Font.GothamMedium, TextSize=11,
            BorderSizePixel=0
        })
        MakeCorner(tabBtn, 6)
        MakeStroke(tabBtn, THEME.BORDER, 1)
        tabBtn.BackgroundTransparency = 1
        tabButtons[tab.name] = tabBtn

        -- Section frame
        local section = Create("Frame", {
            Parent=contentFrame, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
            Visible=false, LayoutOrder=i
        })
        local grid = Create("Frame", {
            Parent=section, BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y
        })
        Create("UIGridLayout", {
            Parent=grid, CellSize=UDim2.new(0.5,-4,0,52),
            CellPaddingSize=UDim2.new(0,6,0,6), SortOrder=Enum.SortOrder.LayoutOrder
        })
        buttonSections[tab.name] = section

        -- Buttons (loaded from GitHub or config)
        local buttons = tab.buttons or {}
        for j, btnCfg in ipairs(buttons) do
            local btnFrame = Create("Frame", {
                Parent=grid, BackgroundColor3=THEME.BG3,
                BorderSizePixel=0, LayoutOrder=j
            })
            MakeCorner(btnFrame, 8)
            MakeStroke(btnFrame, THEME.BORDER, 1)

            Create("TextLabel", {
                Parent=btnFrame, BackgroundTransparency=1,
                Position=UDim2.new(0,10,0,10), Size=UDim2.new(1,-20,0,16),
                Text=btnCfg.name, TextColor3=THEME.TEXT,
                Font=Enum.Font.GothamMedium, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left
            })
            Create("TextLabel", {
                Parent=btnFrame, BackgroundTransparency=1,
                Position=UDim2.new(0,10,0,27), Size=UDim2.new(1,-20,0,12),
                Text=btnCfg.desc or "", TextColor3=THEME.TEXT3,
                Font=Enum.Font.Gotham, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left
            })

            -- Toggle or execute button
            if btnCfg.type == "toggle" then
                local togOn = false
                local togBg = Create("Frame", {
                    Parent=btnFrame, BackgroundColor3=THEME.BORDER2,
                    Position=UDim2.new(1,-30,0,8), Size=UDim2.new(0,24,0,13), BorderSizePixel=0
                })
                MakeCorner(togBg, 7)
                local togDot = Create("Frame", {
                    Parent=togBg, BackgroundColor3=THEME.WHITE,
                    Position=UDim2.new(0,2,0,2), Size=UDim2.new(0,9,0,9), BorderSizePixel=0
                })
                MakeCorner(togDot, 5)

                local clickArea = Create("TextButton", {
                    Parent=btnFrame, BackgroundTransparency=1,
                    Size=UDim2.new(1,0,1,0), Text=""
                })
                clickArea.MouseButton1Click:Connect(function()
                    togOn = not togOn
                    if togOn then
                        Tween(togBg, {BackgroundColor3=Color3.fromRGB(200,200,220)}, 0.15)
                        Tween(togDot, {Position=UDim2.new(0,13,0,2), BackgroundColor3=THEME.BG}, 0.15)
                        Tween(btnFrame, {BackgroundColor3=THEME.BG4}, 0.1)
                        -- Execute the script for this button
                        task.spawn(function()
                            local scriptUrl = baseUrl .. "/" .. tab.name .. "/" .. btnCfg.name:gsub(" ","_") .. ".lua"
                            local src = fetch(scriptUrl)
                            if src then
                                local fn, err = loadstring(src)
                                if fn then fn() else warn("[Sector.gg] Script error: " .. tostring(err)) end
                            end
                        end)
                    else
                        Tween(togBg, {BackgroundColor3=THEME.BORDER2}, 0.15)
                        Tween(togDot, {Position=UDim2.new(0,2,0,2), BackgroundColor3=THEME.WHITE}, 0.15)
                        Tween(btnFrame, {BackgroundColor3=THEME.BG3}, 0.1)
                    end
                end)

            else
                -- Execute button
                local execBtn = Create("TextButton", {
                    Parent=btnFrame, BackgroundColor3=THEME.BG4,
                    Position=UDim2.new(1,-32,0,6), Size=UDim2.new(0,22,0,22),
                    Text="▶", TextColor3=THEME.TEXT2, Font=Enum.Font.GothamBold, TextSize=10,
                    BorderSizePixel=0
                })
                MakeCorner(execBtn, 6)
                execBtn.MouseButton1Click:Connect(function()
                    task.spawn(function()
                        local scriptUrl = baseUrl .. "/" .. tab.name .. "/" .. btnCfg.name:gsub(" ","_") .. ".lua"
                        local src = fetch(scriptUrl)
                        if src then
                            local fn, err = loadstring(src)
                            if fn then fn() else warn("[Sector.gg] Script error: " .. tostring(err)) end
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

    -- Footer
    local footer = Create("Frame", {
        Parent=window, BackgroundColor3=THEME.BG2,
        Position=UDim2.new(0,0,1,-34), Size=UDim2.new(1,0,0,34), BorderSizePixel=0
    })
    MakeCorner(footer, 12)
    Create("Frame", {
        Parent=footer, BackgroundColor3=THEME.BG2,
        Size=UDim2.new(1,0,0.5,0), BorderSizePixel=0
    })
    Create("TextLabel", {
        Parent=footer, BackgroundTransparency=1,
        Position=UDim2.new(0,14,0,0), Size=UDim2.new(0.6,0,1,0),
        Text="discord.gg/sector", TextColor3=THEME.TEXT3,
        Font=Enum.Font.Gotham, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left
    })
    Create("TextLabel", {
        Parent=footer, BackgroundTransparency=1,
        Position=UDim2.new(1,-60,0,0), Size=UDim2.new(0,54,1,0),
        Text="v" .. (config.version or "1.0.0"), TextColor3=THEME.TEXT3,
        Font=Enum.Font.Gotham, TextSize=10, TextXAlignment=Enum.TextXAlignment.Right
    })

    return screenGui
end

return GUI
