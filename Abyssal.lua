--==================================================
-- ABYSSAL AUTOFISH | V7.0
-- UI simplificada + historico de raridade
--==================================================

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Config = {
    Enabled = false,
    ScanInterval = 0.045,
    ObjectRefresh = 0.65,
    TargetRefresh = 0.12,
    CastDelay = 0.55,
    KeyDelay = 0.018,
    ClickCooldown = 0.055,
    ArcTolerance = 43,
    RadiusTolerance = 0.32,
    HistoryLimit = 10,
}

local State = {
    LastScan = 0,
    LastCast = 0,
    LastPress = 0,
    LastObjectRefresh = 0,
    LastTargetRefresh = 0,
    LastBackpackRead = 0,
    LastBackpackCount = nil,
    LastMinigameSeen = 0,
    CastPending = false,
    Fishing = false,
    CachedFishButton = nil,
    CachedFishingGui = nil,
    GuiObjects = {},
    GreenObjects = {},
    CircleCenter = nil,
    CircleRadius = nil,
    PreviousPositions = {},
    ClickedBalls = setmetatable({}, {__mode = "k"}),
    FishCaught = 0,
    Hits = 0,
    History = {},
    SeenCatchMessages = {},
    StartedAt = os.clock(),
}

--==================================================
-- GUI
--==================================================

pcall(function()
    local hui = gethui and gethui()
    local old = (hui and hui:FindFirstChild("AbyssalAutoFish"))
        or CoreGui:FindFirstChild("AbyssalAutoFish")
    if old then old:Destroy() end
end)

local GUI = Instance.new("ScreenGui")
GUI.Name = "AbyssalAutoFish"
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.Parent = (gethui and gethui()) or CoreGui

local Panel = Instance.new("Frame")
Panel.Name = "Main"
Panel.Size = UDim2.fromOffset(330, 390)
Panel.Position = UDim2.new(0, 28, 0.22, 0)
Panel.BackgroundColor3 = Color3.fromRGB(13, 19, 29)
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.Parent = GUI

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end

corner(Panel, 14)

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(35, 210, 150)
outline.Thickness = 1.3
outline.Parent = Panel

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 58)
Header.BackgroundColor3 = Color3.fromRGB(19, 31, 42)
Header.BorderSizePixel = 0
Header.Parent = Panel
corner(Header, 14)

local function label(parent, text, size, color, pos, dims)
    local obj = Instance.new("TextLabel")
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = color
    obj.TextSize = size
    obj.Font = Enum.Font.GothamBold
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.Position = pos
    obj.Size = dims
    obj.Parent = parent
    return obj
end

local function button(parent, text, pos, dims, color)
    local obj = Instance.new("TextButton")
    obj.Text = text
    obj.Position = pos
    obj.Size = dims
    obj.BackgroundColor3 = color
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.TextSize = 11
    obj.Font = Enum.Font.GothamBold
    obj.AutoButtonColor = true
    obj.Parent = parent
    corner(obj, 8)
    return obj
end

label(Header, "ABYSSAL", 21, Color3.fromRGB(65, 235, 175),
    UDim2.fromOffset(15, 7), UDim2.fromOffset(190, 25))
label(Header, "AUTOFISH V7.0  |  RARITY TRACKER", 8,
    Color3.fromRGB(145, 165, 180),
    UDim2.fromOffset(17, 34), UDim2.fromOffset(230, 14))

local Minimize = button(Header, "—", UDim2.new(1, -69, 0, 14),
    UDim2.fromOffset(25, 26), Color3.fromRGB(35, 52, 62))
local Close = button(Header, "X", UDim2.new(1, -37, 0, 14),
    UDim2.fromOffset(25, 26), Color3.fromRGB(145, 55, 60))

local StatusCard = Instance.new("Frame")
StatusCard.Position = UDim2.fromOffset(12, 69)
StatusCard.Size = UDim2.new(1, -24, 0, 34)
StatusCard.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
StatusCard.Parent = Panel
corner(StatusCard, 8)

local Status = label(StatusCard, "● DESLIGADO", 10,
    Color3.fromRGB(220, 90, 90), UDim2.fromOffset(10, 0),
    UDim2.new(1, -20, 1, 0))

local Tabs = Instance.new("Frame")
Tabs.Position = UDim2.fromOffset(12, 112)
Tabs.Size = UDim2.new(1, -24, 0, 30)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Panel

local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(12, 150)
Content.Size = UDim2.new(1, -24, 1, -162)
Content.BackgroundTransparency = 1
Content.Parent = Panel

local function makePage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = Content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end)
    return page
end

local FishPage = makePage()
local CatchPage = makePage()
FishPage.Visible = true

local function section(page, text)
    local obj = label(page, text, 11, Color3.fromRGB(65, 220, 165),
        UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 23))
    obj.LayoutOrder = #page:GetChildren()
end

local function valueRow(page, name, initial)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
    row.Parent = page
    corner(row, 7)

    label(row, name, 10, Color3.fromRGB(160, 180, 195),
        UDim2.fromOffset(10, 0), UDim2.new(0.62, 0, 1, 0))
    local value = label(row, tostring(initial), 11,
        Color3.fromRGB(65, 235, 175), UDim2.new(0.62, 0, 0, 0),
        UDim2.new(0.35, -8, 1, 0))
    value.TextXAlignment = Enum.TextXAlignment.Right
    return value
end

local function tab(name, x, page)
    local b = button(Tabs, name, UDim2.fromOffset(x, 0),
        UDim2.fromOffset(145, 29), Color3.fromRGB(32, 48, 61))
    b.Activated:Connect(function()
        FishPage.Visible = page == FishPage
        CatchPage.Visible = page == CatchPage
        for _, item in ipairs(Tabs:GetChildren()) do
            if item:IsA("TextButton") then
                item.BackgroundColor3 = item == b
                    and Color3.fromRGB(25, 145, 100)
                    or Color3.fromRGB(32, 48, 61)
            end
        end
    end)
end

tab("PESCA", 0, FishPage)
tab("CAPTURAS", 151, CatchPage)

section(FishPage, "CONTROLE")
local MainToggle = button(FishPage, "ATIVAR AUTOFISH",
    UDim2.new(), UDim2.new(1, -5, 0, 39),
    Color3.fromRGB(25, 145, 100))
MainToggle.LayoutOrder = 2

section(FishPage, "SESSAO")
local BackpackValue = valueRow(FishPage, "Mochila", "-- / --")
local FishValue = valueRow(FishPage, "Peixes capturados", "0")
local HitValue = valueRow(FishPage, "Acertos no minigame", "0")
local TimeValue = valueRow(FishPage, "Tempo ativo", "00:00")

section(CatchPage, "ULTIMAS CAPTURAS")
local HistoryFrame = Instance.new("Frame")
HistoryFrame.Size = UDim2.new(1, -5, 0, 245)
HistoryFrame.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
HistoryFrame.Parent = CatchPage
corner(HistoryFrame, 8)

local HistoryText = label(HistoryFrame, "Nenhuma captura detectada.",
    10, Color3.fromRGB(210, 220, 225),
    UDim2.fromOffset(10, 8), UDim2.new(1, -20, 1, -16))
HistoryText.TextYAlignment = Enum.TextYAlignment.Top
HistoryText.TextWrapped = true

--==================================================
-- INPUT / UTILITIES
--==================================================

local function pressKey(key)
    return pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(Config.KeyDelay)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

local function isVisible(obj)
    if not obj:IsA("GuiObject") or not obj.Visible then return false end
    local parent = obj.Parent
    while parent and parent ~= PlayerGui do
        if parent:IsA("GuiObject") and not parent.Visible then
            return false
        end
        parent = parent.Parent
    end
    return true
end

local function getColor(obj)
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        return obj.ImageColor3
    end
    return obj.BackgroundColor3
end

local function isGreen(obj)
    local ok, color, size = pcall(function()
        return getColor(obj), obj.AbsoluteSize
    end)
    if not ok then return false end
    return color.G > 0.55
        and color.G > color.R * 1.25
        and color.G > color.B * 0.80
        and size.X >= 8 and size.X <= 32
        and size.Y >= 8 and size.Y <= 32
        and math.abs(size.X - size.Y) <= 9
end

local function isRed(obj)
    local ok, color = pcall(getColor, obj)
    return ok and color.R > 0.55
        and color.R > color.G * 1.35
        and color.R > color.B * 1.25
end

local function centerOf(obj)
    return obj.AbsolutePosition + obj.AbsoluteSize / 2
end

local function getFishing()
    return PlayerGui:FindFirstChild("PescariaGui", true)
end

--==================================================
-- BACKPACK + CATCH RARITY
-- A notificação visível do jogo mostra nome e raridade.
-- Exemplo visto no vídeo: "Discus" / "Epic · 0.35 kg · 1884 coins".
--==================================================

local Rarities = {
    "Secret", "Mythical", "Legendary", "Epic",
    "Rare", "Uncommon", "Common",
}

local function getRarity(text)
    local lower = string.lower(text or "")
    for _, rarity in ipairs(Rarities) do
        if lower:find(string.lower(rarity), 1, true) then
            return rarity
        end
    end
    return nil
end

local function cleanText(text)
    return (text or ""):gsub("<[^>]->", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function addCatch(message)
    message = cleanText(message)
    if message == "" or State.SeenCatchMessages[message] then return end
    State.SeenCatchMessages[message] = os.clock()

    local rarity = getRarity(message) or "Raridade não identificada"
    table.insert(State.History, 1, os.date("%H:%M:%S") .. "  •  " .. message .. "  [" .. rarity .. "]")

    while #State.History > Config.HistoryLimit do
        table.remove(State.History)
    end

    HistoryText.Text = table.concat(State.History, "\n\n")
end

local function inspectCatchText(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
    local text = cleanText(obj.Text)
    if text == "" then return end

    local rarity = getRarity(text)
    local hasCatchDetails = text:lower():find("kg", 1, true)
        or text:lower():find("coins", 1, true)

    if rarity and hasCatchDetails then
        -- Tenta incluir o nome do peixe exibido imediatamente acima/abaixo.
        local fishName = nil
        local parent = obj.Parent
        if parent then
            for _, sibling in ipairs(parent:GetChildren()) do
                if sibling ~= obj and (sibling:IsA("TextLabel") or sibling:IsA("TextButton")) then
                    local candidate = cleanText(sibling.Text)
                    if candidate ~= "" and not getRarity(candidate)
                        and not candidate:lower():find("kg", 1, true)
                        and not candidate:lower():find("coins", 1, true) then
                        fishName = candidate
                        break
                    end
                end
            end
        end

        local details = text:gsub("%s*[·•|]?%s*[%d,]+%s*[Cc]oins?.*$", "")
        addCatch((fishName and (fishName .. " — ") or "") .. details)
    end
end

local function scanCatchNotifications()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        inspectCatchText(obj)
    end
end

-- Captura textos novos e textos de notificações reutilizadas pelo jogo.
local function hookTextObject(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        inspectCatchText(obj)
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            inspectCatchText(obj)
        end)
    end
end

for _, obj in ipairs(PlayerGui:GetDescendants()) do
    hookTextObject(obj)
end
PlayerGui.DescendantAdded:Connect(hookTextObject)

local function getBackpack()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local a, b = (obj.Text or ""):match("Backpack:%s*(%d+)%s*/%s*(%d+)")
            if a then return tonumber(a), tonumber(b) end
        end
    end
end

local function updateCounters()
    local now = os.clock()
    if now - State.LastBackpackRead < 0.45 then return end
    State.LastBackpackRead = now

    local current, maximum = getBackpack()
    if current then
        BackpackValue.Text = current .. " / " .. maximum
        if State.LastBackpackCount == nil then
            State.LastBackpackCount = current
        elseif current > State.LastBackpackCount then
            State.FishCaught += current - State.LastBackpackCount
        end
        State.LastBackpackCount = current
    end

    FishValue.Text = tostring(State.FishCaught)
    HitValue.Text = tostring(State.Hits)

    local elapsed = math.floor(now - State.StartedAt)
    TimeValue.Text = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
end

--==================================================
-- MINIGAME DETECTION
--==================================================

local function refreshObjectCache(fishing, now)
    if State.CachedFishingGui ~= fishing
        or now - State.LastObjectRefresh >= Config.ObjectRefresh then

        local objects, greens = {}, {}
        for _, obj in ipairs(fishing:GetDescendants()) do
            if obj:IsA("GuiObject") then
                objects[#objects + 1] = obj
                if isGreen(obj) then
                    greens[#greens + 1] = obj
                end
            end
        end

        State.GuiObjects = objects
        State.GreenObjects = greens
        State.CachedFishingGui = fishing
        State.LastObjectRefresh = now
        State.LastTargetRefresh = 0
        State.CircleCenter = nil
        State.CircleRadius = nil
    end
end

local function findCircle(fishing, greens, objects)
    local bestRed, redScore = nil, -math.huge

    for _, obj in ipairs(objects) do
        if obj.Parent and isVisible(obj) and isRed(obj) then
            local size = obj.AbsoluteSize
            local ratio = size.X / math.max(size.Y, 1)
            if size.X >= 35 and size.Y >= 20 and ratio >= 0.55 and ratio <= 2 then
                local score = size.X * size.Y
                if score > redScore then
                    bestRed, redScore = obj, score
                end
            end
        end
    end

    if bestRed then
        local size = bestRed.AbsoluteSize
        if math.abs(size.X - size.Y) <= math.max(size.X, size.Y) * 0.38 then
            return bestRed.AbsolutePosition + size / 2, math.min(size.X, size.Y) * 0.5
        end
    end

    local best, bestScore = nil, -math.huge
    for _, obj in ipairs(objects) do
        if obj.Parent and isVisible(obj) then
            local size = obj.AbsoluteSize
            local largest = math.max(size.X, size.Y)
            local ratio = size.X / math.max(size.Y, 1)
            if largest >= 85 and largest <= 360 and ratio >= 0.82 and ratio <= 1.22 then
                local score = size.X * size.Y
                if score > bestScore then
                    best, bestScore = obj, score
                end
            end
        end
    end

    if best then
        local size = best.AbsoluteSize
        return best.AbsolutePosition + size / 2, math.min(size.X, size.Y) * 0.5
    end

    if #greens >= 2 then
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        for _, ball in ipairs(greens) do
            local p = centerOf(ball)
            minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
            minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
        end
        local center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
        local radius = math.max(maxX - minX, maxY - minY) * 0.5
        if radius > 10 then return center, radius end
    end
end

local function inRedArc(point, center, radius)
    if not center or not radius or radius <= 0 then return false end
    local delta = point - center
    local distance = delta.Magnitude
    if distance < radius * (1 - Config.RadiusTolerance)
        or distance > radius * (1 + Config.RadiusTolerance) then
        return false
    end

    local angle = math.deg(math.atan2(delta.Y, delta.X))
    local difference = math.abs(((angle + 90 + 180) % 360) - 180)
    return difference <= Config.ArcTolerance
end

local function scanMinigame()
    local fishing = getFishing()
    if not fishing then return false end

    local now = os.clock()
    refreshObjectCache(fishing, now)

    local greens = {}
    for _, obj in ipairs(State.GreenObjects) do
        if obj.Parent and isVisible(obj) and isGreen(obj) then
            greens[#greens + 1] = obj
        end
    end

    if #greens == 0 then
        table.clear(State.PreviousPositions)
        table.clear(State.ClickedBalls)
        State.CircleCenter, State.CircleRadius = nil, nil
        return false
    end

    if not State.CircleCenter or now - State.LastTargetRefresh >= Config.TargetRefresh then
        State.CircleCenter, State.CircleRadius = findCircle(fishing, greens, State.GuiObjects)
        State.LastTargetRefresh = now
    end

    local center, radius = State.CircleCenter, State.CircleRadius
    if not center then return true end

    local nextPositions = {}
    for _, ball in ipairs(greens) do
        local pos = centerOf(ball)
        local previous = State.PreviousPositions[ball]
        local hit = inRedArc(pos, center, radius)

        -- Interpola o movimento entre ciclos para não perder bolinhas rápidas.
        if previous and not hit then
            local distance = (pos - previous).Magnitude
            local steps = math.clamp(math.ceil(distance / 3), 1, 16)
            for step = 1, steps do
                if inRedArc(previous:Lerp(pos, step / steps), center, radius) then
                    hit = true
                    break
                end
            end
        end

        if hit and not State.ClickedBalls[ball]
            and now - State.LastPress >= Config.ClickCooldown then
            State.ClickedBalls[ball] = true
            State.LastPress = now
            State.Hits += 1
            task.spawn(pressKey, Enum.KeyCode.Space)
        elseif not hit then
            State.ClickedBalls[ball] = nil
        end

        nextPositions[ball] = pos
    end

    State.PreviousPositions = nextPositions
    return true
end

--==================================================
-- AUTO CAST
--==================================================

local function findFishButton()
    local cached = State.CachedFishButton
    if cached and cached.Parent and cached.Visible then
        return cached
    end

    State.CachedFishButton = nil
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible then
            local text = string.lower((obj.Text or ""):gsub("%s+", " "))
            if text:find("fish", 1, true) and text:find("%(e%)") then
                State.CachedFishButton = obj
                return obj
            end
        end
    end
end

local function autoCast()
    if State.Fishing or State.CastPending then return end
    local now = os.clock()
    if now - State.LastCast < Config.CastDelay then return end

    local fishButton = findFishButton()
    if not fishButton then
        State.CachedFishButton = nil
        return
    end

    State.CastPending = true
    State.LastCast = now
    task.spawn(function()
        local ok = pressKey(Enum.KeyCode.E)
        task.wait(0.25)
        State.CastPending = false
        if not ok or not fishButton.Parent or not fishButton.Visible then
            State.CachedFishButton = nil
            State.LastCast = os.clock() - 0.25
        end
    end)
end

--==================================================
-- CONTROLS / MAIN LOOP
--==================================================

local function setEnabled(value)
    State.Enabled = value
    Config.Enabled = value

    MainToggle.Text = value and "DESATIVAR AUTOFISH" or "ATIVAR AUTOFISH"
    MainToggle.BackgroundColor3 = value
        and Color3.fromRGB(175, 65, 70)
        or Color3.fromRGB(25, 145, 100)

    Status.Text = value and "● AUTOFISH ATIVO" or "● DESLIGADO"
    Status.TextColor3 = value
        and Color3.fromRGB(65, 235, 175)
        or Color3.fromRGB(220, 90, 90)

    State.LastCast = 0
    State.LastMinigameSeen = 0
    State.Fishing = false
    State.CachedFishingGui = nil
    State.CachedFishButton = nil
    State.CircleCenter, State.CircleRadius = nil, nil
    table.clear(State.PreviousPositions)
    table.clear(State.ClickedBalls)
end

MainToggle.Activated:Connect(function()
    setEnabled(not Config.Enabled)
end)

local minimized = false
local expandedSize = UDim2.fromOffset(330, 390)
local minimizedSize = UDim2.fromOffset(330, 58)

Minimize.Activated:Connect(function()
    minimized = not minimized
    StatusCard.Visible = not minimized
    Tabs.Visible = not minimized
    Content.Visible = not minimized
    Panel.Size = minimized and minimizedSize or expandedSize
    Minimize.Text = minimized and "+" or "—"
end)

local connection
Close.Activated:Connect(function()
    setEnabled(false)
    if connection then connection:Disconnect() end
    GUI:Destroy()
end)

connection = RunService.Heartbeat:Connect(function()
    if not GUI.Parent then
        connection:Disconnect()
        return
    end

    updateCounters()
    if not Config.Enabled then return end

    local now = os.clock()
    if now - State.LastScan < Config.ScanInterval then return end
    State.LastScan = now

    local fishing = getFishing()
    if not fishing then
        State.Fishing = false
        State.CachedFishingGui = nil
        State.GuiObjects = {}
        State.GreenObjects = {}
        State.CircleCenter, State.CircleRadius = nil, nil
        Status.Text = "● PROCURANDO PESCA"
        autoCast()
        return
    end

    local active = scanMinigame()
    if active then
        State.Fishing = true
        State.LastMinigameSeen = now
        Status.Text = "● MINIGAME ATIVO"
    else
        State.Fishing = (now - State.LastMinigameSeen) < 0.75
        if not State.Fishing then
            table.clear(State.PreviousPositions)
            autoCast()
            Status.Text = "● AGUARDANDO PRÓXIMA PESCA"
        end
    end
end)

-- Primeira leitura para registrar o valor atual da mochila sem contar peixes antigos.
task.defer(function()
    task.wait(1)
    local current = getBackpack()
    if current then State.LastBackpackCount = current end
    scanCatchNotifications()
end)

print("[ABYSSAL] V7.0 CARREGADO")
