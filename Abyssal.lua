
--==================================================
-- ABYSSAL AUTOFISH | V6.2.1 REFINED
-- XENO EDITION
--==================================================

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--==================================================
-- CONFIGURATION
--==================================================

local Config = {
    Enabled = false,
    AutoCast = true,
    AutoReel = true,
    QuickCast = true,
    AutoRetry = true,

    RareProtection = true,

    Cooldown = 0.06,
    KeyDelay = 0.015,
    CastDelay = 0.22,
    CastButtonRefresh = 0.75,
    CastInputTimeout = 0.30,
    ClickReleaseDelay = 0.012,
    CircleAngleTolerance = 42,
    CircleRadiusTolerance = 0.30,

    ScanInterval = 0.06,
    ObjectCacheInterval = 2.5,
    TargetCacheInterval = 0.75,
    CounterInterval = 1.0,
    HistoryLimit = 12
}

local State = {
    LastPress = 0,
    LastCast = 0,
    LastScan = 0,
    LastCounterUpdate = 0,
    LastHistoryUpdate = 0,
    CastPending = false,
    CachedFishButton = nil,
    LastFishButtonSearch = 0,
    LastCastAttempt = 0,
    LastMinigameSeen = 0,
    LastObjectCacheUpdate = 0,
    CachedFishingGui = nil,
    CachedGuiObjects = {},
    CachedGreenObjects = {},
    CachedCircleCenter = nil,
    CachedCircleRadius = nil,
    LastTargetCacheUpdate = 0,

    Hits = 0,
    FishCaught = 0,
    Coins = nil,

    Previous = {},
    PreviousPositions = {},
    ClickedBalls = setmetatable({}, {__mode = "k"}),
    Fishing = false,
    LastBackpackCount = nil,

    StartedAt = os.clock(),
    History = {},
    LastStatus = "DESLIGADO"
}

--==================================================
-- CLEAN OLD GUI
--==================================================

pcall(function()
    local hui = gethui and gethui()
    local old = (hui and hui:FindFirstChild("AbyssalAutoFish"))
        or CoreGui:FindFirstChild("AbyssalAutoFish")

    if old then old:Destroy() end
end)

--==================================================
-- GUI HELPERS
--==================================================

local GUI = Instance.new("ScreenGui")
GUI.Name = "AbyssalAutoFish"
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.Parent = (gethui and gethui()) or CoreGui

local Panel = Instance.new("Frame")
Panel.Size = UDim2.fromOffset(350, 440)
Panel.Position = UDim2.new(0, 30, 0.2, 0)
Panel.BackgroundColor3 = Color3.fromRGB(13, 19, 29)
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.ClipsDescendants = true
Panel.Parent = GUI

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end

corner(Panel, 15)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(35, 210, 150)
stroke.Thickness = 1.4
stroke.Parent = Panel

local function label(parent, text, size, color, pos, dims)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.TextSize = size
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = pos
    l.Size = dims
    l.Parent = parent
    return l
end

local function makeButton(parent, text, pos, dims, color)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Position = pos
    b.Size = dims
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1,1,1)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.Parent = parent
    corner(b, 8)
    return b
end

--==================================================
-- HEADER
--==================================================

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,65)
Header.BackgroundColor3 = Color3.fromRGB(19,31,42)
Header.BorderSizePixel = 0
Header.Parent = Panel
corner(Header,15)

label(Header,"ABYSSAL",22,
    Color3.fromRGB(65,235,175),
    UDim2.fromOffset(16,8),
    UDim2.fromOffset(200,27))

label(Header,"REFINED QUICKCAST | ULTRA LIGHT",9,
    Color3.fromRGB(145,165,180),
    UDim2.fromOffset(18,37),
    UDim2.fromOffset(220,16))

local Close = makeButton(Header,"X",
    UDim2.new(1,-40,0,15),
    UDim2.fromOffset(27,27),
    Color3.fromRGB(145,55,60))

local Minimize = makeButton(Header,"—",
    UDim2.new(1,-73,0,15),
    UDim2.fromOffset(27,27),
    Color3.fromRGB(35,52,62))

--==================================================
-- STATUS
--==================================================

local StatusCard = Instance.new("Frame")
StatusCard.Position = UDim2.fromOffset(12,76)
StatusCard.Size = UDim2.new(1,-24,0,35)
StatusCard.BackgroundColor3 = Color3.fromRGB(24,34,45)
StatusCard.Parent = Panel
corner(StatusCard,8)

local Status = label(StatusCard,"● DESLIGADO",11,
    Color3.fromRGB(220,90,90),
    UDim2.fromOffset(10,0),
    UDim2.new(1,-20,1,0))

--==================================================
-- TABS
--==================================================

local TabBar = Instance.new("Frame")
TabBar.Position = UDim2.fromOffset(12,120)
TabBar.Size = UDim2.new(1,-24,0,32)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Panel

local Pages = Instance.new("Frame")
Pages.Position = UDim2.fromOffset(12,160)
Pages.Size = UDim2.new(1,-24,1,-172)
Pages.BackgroundTransparency = 1
Pages.Parent = Panel

local function createPage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1,1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.Visible = false
    page.Parent = Pages

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,7)
    layout.Parent = page

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+10)
    end)

    return page
end

local FishingPage = createPage()
local InventoryPage = createPage()
local StatsPage = createPage()

FishingPage.Visible = true

local function tab(name, x, page)
    local b = makeButton(TabBar,name,
        UDim2.fromOffset(x,0),
        UDim2.fromOffset(100,30),
        Color3.fromRGB(32,48,61))

    b.Activated:Connect(function()
        FishingPage.Visible = false
        InventoryPage.Visible = false
        StatsPage.Visible = false
        page.Visible = true

        for _, tabButton in ipairs(TabBar:GetChildren()) do
            if tabButton:IsA("TextButton") then
                tabButton.BackgroundColor3 = (tabButton == b)
                    and Color3.fromRGB(25,145,100)
                    or Color3.fromRGB(32,48,61)
            end
        end
    end)

    return b
end

tab("PESCA",0,FishingPage)
tab("INVENTARIO",106,InventoryPage)
tab("ESTATISTICAS",212,StatsPage)

--==================================================
-- PAGE HELPERS
--==================================================

local function section(page,text)
    local l = label(page,text,12,
        Color3.fromRGB(65,220,165),
        UDim2.fromOffset(5,0),
        UDim2.new(1,-10,0,25))
    l.LayoutOrder = #page:GetChildren()
    return l
end

local function option(page,name,initial,callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-5,0,34)
    row.BackgroundColor3 = Color3.fromRGB(24,34,45)
    row.Parent = page
    corner(row,7)

    label(row,name,11,
        Color3.fromRGB(225,235,240),
        UDim2.fromOffset(10,0),
        UDim2.new(1,-100,1,0))

    local active = initial

    local b = makeButton(row,active and "ON" or "OFF",
        UDim2.new(1,-65,0,4),
        UDim2.fromOffset(55,26),
        active and Color3.fromRGB(25,145,100)
            or Color3.fromRGB(75,85,100))

    b.MouseButton1Click:Connect(function()
        active = not active
        b.Text = active and "ON" or "OFF"
        b.BackgroundColor3 = active
            and Color3.fromRGB(25,145,100)
            or Color3.fromRGB(75,85,100)

        callback(active)
    end)

    return b
end

local function valueRow(page,name,value)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-5,0,32)
    row.BackgroundColor3 = Color3.fromRGB(24,34,45)
    row.Parent = page
    corner(row,7)

    label(row,name,10,
        Color3.fromRGB(160,180,195),
        UDim2.fromOffset(10,0),
        UDim2.new(0.65,0,1,0))

    local val = label(row,tostring(value),12,
        Color3.fromRGB(65,235,175),
        UDim2.new(0.65,0,0,0),
        UDim2.new(0.3,0,1,0))

    return val
end

--==================================================
-- FISHING PAGE
--==================================================

section(FishingPage,"AUTOMACAO")

local MainToggle = makeButton(FishingPage,
    "ATIVAR AUTOFISH",
    UDim2.new(),UDim2.new(1,-5,0,36),
    Color3.fromRGB(25,145,100))

MainToggle.LayoutOrder = 2

option(FishingPage,"Quick Cast",true,function(v)
    Config.QuickCast = v
end)

option(FishingPage,"Auto Cast",true,function(v)
    Config.AutoCast = v
end)

option(FishingPage,"Auto Minigame",true,function(v)
    Config.AutoReel = v
end)

option(FishingPage,"AutoRetry",true,function(v)
    Config.AutoRetry = v
end)

--==================================================
-- INVENTORY PAGE
--==================================================

section(InventoryPage,"INVENTARIO E VENDAS")

local BackpackValue = valueRow(
    InventoryPage,"Mochila","-- / --")

local FishValue = valueRow(
    InventoryPage,"Peixes capturados",0)


local CoinValue = valueRow(
    InventoryPage,"Moedas","Não detectadas")

option(InventoryPage,"Rare Fish Protection",true,function(v)
    Config.RareProtection = v
end)



--==================================================
-- STATISTICS PAGE
--==================================================

section(StatsPage,"ESTATISTICAS DA SESSAO")

local StatFish = valueRow(StatsPage,"Capturas",0)
local StatHits = valueRow(StatsPage,"Cliques nas bolinhas",0)
local StatCoins = valueRow(StatsPage,"Moedas","--")
local StatTime = valueRow(StatsPage,"Tempo","00:00")

section(StatsPage,"HISTORICO DE CAPTURAS")

local HistoryFrame = Instance.new("Frame")
HistoryFrame.Size = UDim2.new(1,-5,0,150)
HistoryFrame.BackgroundColor3 = Color3.fromRGB(24,34,45)
HistoryFrame.Parent = StatsPage
corner(HistoryFrame,8)

local HistoryText = label(
    HistoryFrame,
    "Nenhuma captura registrada.",
    10,
    Color3.fromRGB(180,200,210),
    UDim2.fromOffset(10,8),
    UDim2.new(1,-20,1,-16))

HistoryText.TextYAlignment = Enum.TextYAlignment.Top
HistoryText.TextWrapped = true

--==================================================
-- KEY INPUT
--==================================================

local function pressKey(key)
    return pcall(function()
        VIM:SendKeyEvent(true,key,false,game)
        task.wait(Config.KeyDelay)
        VIM:SendKeyEvent(false,key,false,game)
    end)
end


--==================================================
-- BACKPACK COUNTER
--==================================================

local function getBackpack()
    for _,obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local a,b = obj.Text:match(
                "Backpack:%s*(%d+)%s*/%s*(%d+)")

            if a then
                return tonumber(a),tonumber(b)
            end
        end
    end
end

--==================================================
-- COIN COUNTER
--==================================================

local function getCoins()
    for _,obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local t = obj.Text
            local number = t:match("([%d,]+)%s*[Cc]oins")
                or t:match("[Cc]oins:%s*([%d,]+)")

            if number then
                return tonumber((number:gsub(",","")))
            end
        end
    end
end

--==================================================
-- FISHING GUI
--==================================================

local function getFishing()
    return PlayerGui:FindFirstChild("PescariaGui",true)
end

local function getRedArea(fishing)
    if not fishing then return nil end

    -- Primeiro tenta nomes comuns; se não encontrar, o detector circular
    -- usa o painel do minigame e a posição dos marcadores verdes.
    return fishing:FindFirstChild("AreaVermelha", true)
        or fishing:FindFirstChild("RedArea", true)
        or fishing:FindFirstChild("Target", true)
end

local function getColor(obj)
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        return obj.ImageColor3
    end
    return obj.BackgroundColor3
end

local function isGreen(obj)
    local c = getColor(obj)
    local s = obj.AbsoluteSize
    local roundEnough = math.abs(s.X - s.Y) <= 8

    return c.G > 0.55
        and c.G > c.R * 1.25
        and c.G > c.B * 0.80
        and s.X >= 8 and s.X <= 30
        and s.Y >= 8 and s.Y <= 30
        and roundEnough
end

local function isRed(obj)
    local c = getColor(obj)
    return c.R > 0.55 and c.R > c.G * 1.35 and c.R > c.B * 1.25
end

--==================================================
-- MINIGAME DETECTOR
--==================================================

local function centerOf(obj)
    return obj.AbsolutePosition + (obj.AbsoluteSize / 2)
end

local function isGuiVisible(obj)
    if not obj:IsA("GuiObject") or not obj.Visible then return false end
    local parent = obj.Parent
    while parent and parent ~= PlayerGui do
        if parent:IsA("GuiObject") and not parent.Visible then return false end
        parent = parent.Parent
    end
    return true
end

local function getCircularTarget(fishing, greens, guiObjects)
    -- Usa a lista em cache: evita GetDescendants() repetido a cada varredura.
    local best, bestScore = nil, -math.huge
    for _, obj in ipairs(guiObjects) do
        if obj.Parent and isGuiVisible(obj) then
            local ok, red = pcall(isRed, obj)
            if ok and red then
                local size = obj.AbsoluteSize
                local ratio = size.X / math.max(size.Y, 1)
                if size.X >= 35 and size.Y >= 20 and ratio >= 0.55 and ratio <= 2.0 then
                    local score = size.X * size.Y
                    if score > bestScore then
                        best, bestScore = obj, score
                    end
                end
            end
        end
    end

    if best then
        local p, size = best.AbsolutePosition, best.AbsoluteSize
        if math.abs(size.X - size.Y) <= math.max(size.X, size.Y) * 0.35 then
            return p + size / 2, math.min(size.X, size.Y) * 0.5, best
        end
    end

    local circleObject, circleScore = nil, -math.huge
    for _, obj in ipairs(guiObjects) do
        if obj.Parent and isGuiVisible(obj) then
            local size = obj.AbsoluteSize
            local largest = math.max(size.X, size.Y)
            local ratio = size.X / math.max(size.Y, 1)
            if largest >= 85 and largest <= 360
                and ratio >= 0.82 and ratio <= 1.22 then
                local score = size.X * size.Y
                if score > circleScore then
                    circleObject, circleScore = obj, score
                end
            end
        end
    end

    if circleObject then
        local p, size = circleObject.AbsolutePosition, circleObject.AbsoluteSize
        return p + size / 2, math.min(size.X, size.Y) * 0.5, circleObject
    end

    if #greens >= 2 then
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        for _, ball in ipairs(greens) do
            local c = centerOf(ball)
            minX, maxX = math.min(minX, c.X), math.max(maxX, c.X)
            minY, maxY = math.min(minY, c.Y), math.max(maxY, c.Y)
        end
        local center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
        local radius = math.max(maxX - minX, maxY - minY) * 0.5
        if radius > 10 then return center, radius, nil end
    end

    return nil
end

local function angleDegrees(vector)
    return math.deg(math.atan2(vector.Y, vector.X))
end

local function isInRedArc(point, center, radius)
    if not center or not radius or radius <= 0 then return false end
    local delta = point - center
    local distance = delta.Magnitude
    if distance < radius * (1 - Config.CircleRadiusTolerance)
        or distance > radius * (1 + Config.CircleRadiusTolerance) then
        return false
    end

    -- No painel mostrado, a faixa vermelha fica no topo do círculo.
    -- Roblox usa Y crescente para baixo; -90 graus é o topo.
    local angle = angleDegrees(delta)
    local difference = math.abs(((angle + 90 + 180) % 360) - 180)
    return difference <= Config.CircleAngleTolerance
end

local function refreshGuiObjectCache(fishing, now)
    if State.CachedFishingGui ~= fishing
        or now - State.LastObjectCacheUpdate >= Config.ObjectCacheInterval then

        local objects, greenCandidates = {}, {}
        for _, obj in ipairs(fishing:GetDescendants()) do
            if obj:IsA("GuiObject") then
                objects[#objects + 1] = obj

                -- Classifica tamanho/cor apenas ao atualizar o cache,
                -- em vez de repetir esses testes em todos os ciclos.
                local size = obj.AbsoluteSize
                if size.X >= 8 and size.X <= 30
                    and size.Y >= 8 and size.Y <= 30
                    and math.abs(size.X - size.Y) <= 8 then
                    local ok, green = pcall(isGreen, obj)
                    if ok and green then
                        greenCandidates[#greenCandidates + 1] = obj
                    end
                end
            end
        end

        State.CachedGuiObjects = objects
        State.CachedGreenObjects = greenCandidates
        State.CachedFishingGui = fishing
        State.LastObjectCacheUpdate = now
        State.LastTargetCacheUpdate = 0
    end

    return State.CachedGuiObjects, State.CachedGreenObjects
end

local function refreshCircleTarget(fishing, greens, guiObjects, now)
    if State.CachedCircleCenter
        and now - State.LastTargetCacheUpdate < Config.TargetCacheInterval then
        return State.CachedCircleCenter, State.CachedCircleRadius
    end

    local center, radius = getCircularTarget(fishing, greens, guiObjects)
    if center and radius then
        State.CachedCircleCenter = center
        State.CachedCircleRadius = radius
        State.LastTargetCacheUpdate = now
    end
    return center, radius
end

local function scanMinigame()
    local fishing = getFishing()
    if not fishing then return false end

    local now = os.clock()
    local guiObjects, cachedGreens = refreshGuiObjectCache(fishing, now)
    local greens = {}

    -- Só percorre os poucos candidatos verdes já classificados.
    for _, obj in ipairs(cachedGreens) do
        if obj.Parent and isGuiVisible(obj) then
            greens[#greens + 1] = obj
        end
    end

    if #greens == 0 then
        State.PreviousPositions = {}
        table.clear(State.ClickedBalls)
        State.CachedCircleCenter = nil
        State.CachedCircleRadius = nil
        return false
    end

    local circleCenter, circleRadius =
        refreshCircleTarget(fishing, greens, guiObjects, now)

    if not circleCenter then
        State.DetectorMessage = "Não foi possível localizar o centro do círculo"
        return true
    end

    local nextPositions = {}
    local pressed = 0

    for _, ball in ipairs(greens) do
        local pos = centerOf(ball)
        local previous = State.PreviousPositions[ball]
        local inArc = isInRedArc(pos, circleCenter, circleRadius)
        local crossed = false

        if previous then
            local distance = (pos - previous).Magnitude
            local steps = math.clamp(math.ceil(distance / 5), 1, 10)
            for step = 1, steps do
                if isInRedArc(previous:Lerp(pos, step / steps), circleCenter, circleRadius) then
                    crossed = true
                    break
                end
            end
        end

        if (inArc or crossed) and not State.ClickedBalls[ball]
            and now - State.LastPress >= Config.Cooldown then
            State.ClickedBalls[ball] = true
            State.LastPress = now
            pressed += 1
            task.spawn(function()
                pressKey(Enum.KeyCode.Space)
            end)
        elseif not inArc and not crossed then
            State.ClickedBalls[ball] = nil
        end

        nextPositions[ball] = pos
    end

    State.PreviousPositions = nextPositions
    if pressed > 0 then State.Hits += pressed end
    State.DetectorMessage = "Alvos verdes: " .. tostring(#greens)
    return true
end

--==================================================
-- FISH BUTTON
--==================================================

local function findFishButton(forceRefresh)
    local now = os.clock()
    local cached = State.CachedFishButton

    if not forceRefresh and cached and cached.Parent and cached.Visible
        and now - State.LastFishButtonSearch < Config.CastButtonRefresh then
        return cached
    end

    if not forceRefresh and now - State.LastFishButtonSearch < Config.CastButtonRefresh then
        return nil
    end

    State.LastFishButtonSearch = now
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

    return nil
end

--==================================================
-- QUICK CAST / AUTORETRY
--==================================================

local function autoCast()
    if not Config.AutoCast or not Config.AutoRetry then return end
    if State.Fishing or State.CastPending then return end

    local now = os.clock()
    local delay = Config.QuickCast and Config.CastDelay or 1.2

    if now - State.LastCast < delay then return end
    if now - State.LastCastAttempt < 0.20 then return end

    local button = findFishButton(false)
    if not button then return end

    State.LastCastAttempt = now
    State.LastCast = now
    State.CastPending = true

    task.spawn(function()
        local ok = pressKey(Enum.KeyCode.E)
        task.wait(Config.CastInputTimeout)
        State.CastPending = false

        if not button.Parent or not button.Visible then
            State.CachedFishButton = nil
        elseif not ok then
            State.LastCast = 0
        end
    end)
end

--==================================================
-- HISTORY
--==================================================

local function addHistory(amount)
    for i=1,amount do
        table.insert(State.History,1,
            os.date("%H:%M:%S").."  •  Peixe capturado")
    end

    while #State.History > Config.HistoryLimit do
        table.remove(State.History)
    end

    HistoryText.Text = table.concat(State.History,"\n")
end

--==================================================
-- COUNTER UPDATE
--==================================================

local function updateCounters()
    local now = os.clock()
    if now-State.LastCounterUpdate < Config.CounterInterval then return end
    State.LastCounterUpdate = now

    local current,maximum = getBackpack()

    if current then
        BackpackValue.Text = current.." / "..maximum

        if State.LastBackpackCount == nil then
            State.LastBackpackCount = current
        elseif current > State.LastBackpackCount then
            local gained = current-State.LastBackpackCount
            State.FishCaught += gained
            addHistory(gained)
        elseif current < State.LastBackpackCount then
        end

        State.LastBackpackCount = current
    end

    local coins = getCoins()
    if coins then
        State.Coins = coins
        CoinValue.Text = tostring(coins)
    end

    FishValue.Text = tostring(State.FishCaught)

    StatFish.Text = tostring(State.FishCaught)
    StatHits.Text = tostring(State.Hits)
    StatCoins.Text = State.Coins and tostring(State.Coins) or "--"

    local elapsed = math.floor(now-State.StartedAt)
    StatTime.Text = string.format("%02d:%02d",
        math.floor(elapsed/60),elapsed%60)
end

--==================================================
-- MAIN TOGGLE
--==================================================

MainToggle.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled

    MainToggle.Text = Config.Enabled
        and "DESATIVAR AUTOFISH"
        or "ATIVAR AUTOFISH"

    MainToggle.BackgroundColor3 = Config.Enabled
        and Color3.fromRGB(175,65,70)
        or Color3.fromRGB(25,145,100)

    Status.Text = Config.Enabled
        and "● AUTOFISH ATIVO"
        or "● DESLIGADO"

    Status.TextColor3 = Config.Enabled
        and Color3.fromRGB(65,235,175)
        or Color3.fromRGB(220,90,90)

    table.clear(State.Previous)
    table.clear(State.PreviousPositions)
    table.clear(State.ClickedBalls)
    State.CachedFishingGui = nil
    State.CachedGuiObjects = {}
    State.CachedGreenObjects = {}
    State.CachedCircleCenter = nil
    State.CachedCircleRadius = nil
end)

--==================================================
-- MINIMIZE / RESTORE
--==================================================

local minimized = false
local expandedSize = UDim2.fromOffset(350,440)
local minimizedSize = UDim2.fromOffset(350,65)
local panelBody = {StatusCard, TabBar, Pages}

local function setMinimized(value)
    minimized = value

    for _, obj in ipairs(panelBody) do
        if obj and obj.Parent then
            obj.Visible = not minimized
        end
    end

    Panel.Size = minimized and minimizedSize or expandedSize
    Minimize.Text = minimized and "+" or "—"
    Minimize.BackgroundColor3 = minimized
        and Color3.fromRGB(25,145,100)
        or Color3.fromRGB(35,52,62)

    Header.Visible = true
    Close.Visible = true
    Minimize.Visible = true
end

Minimize.Activated:Connect(function()
    setMinimized(not minimized)
end)

--==================================================
-- CLEANUP
--==================================================

local connection

Close.Activated:Connect(function()
    Config.Enabled = false
    if connection then connection:Disconnect() end
    GUI:Destroy()
end)

--==================================================
-- MAIN LOOP
--==================================================

connection = RunService.Heartbeat:Connect(function()
    if not GUI.Parent then
        connection:Disconnect()
        return
    end

    updateCounters()

    if not Config.Enabled then return end

    if os.clock()-State.LastScan < Config.ScanInterval then return end
    State.LastScan = os.clock()

    local fishing = getFishing()

    if not fishing then
        State.Fishing = false
        State.CachedFishingGui = nil
        State.CachedGuiObjects = {}
        State.CachedGreenObjects = {}
        State.CachedCircleCenter = nil
        State.CachedCircleRadius = nil
        Status.Text = "● AGUARDANDO PESCA"
        return
    end

    local active = scanMinigame()

    if active then
        State.Fishing = true
        State.LastMinigameSeen = os.clock()
        Status.Text = "● MINIGAME ATIVO"
    else
        local transitionGrace = (os.clock() - State.LastMinigameSeen) < 0.85
        State.Fishing = transitionGrace
        table.clear(State.Previous)

        if not State.Fishing then
            autoCast()
            Status.Text = "● AGUARDANDO PRÓXIMA PESCA"
        end
    end
end)

print("[ABYSSAL] V6.2.1 REFINED CARREGADO")
