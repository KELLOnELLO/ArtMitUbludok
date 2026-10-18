local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

local REJOIN_FLAG_FILE = "void_yba_rejoined.flag"
local IS_REJOINED = false

if isfile and isfile(REJOIN_FLAG_FILE) then
    IS_REJOINED = true
    pcall(function() delfile(REJOIN_FLAG_FILE) end)
end

if IS_REJOINED then
    task.spawn(function()
        task.wait(3)
        pcall(function()
            local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
            if not pg then return end
            local ls = pg:WaitForChild("LoadingScreen", 15)
            if not ls then return end
            local frames = ls:WaitForChild("Frames", 10)
            if not frames then return end
            local main = frames:WaitForChild("Main", 10)
            if not main then return end
            local playBtn = main:WaitForChild("Play", 10)
            if not playBtn then return end

            if firesignal then
                pcall(function() firesignal(playBtn.MouseButton1Click) end)
            elseif getconnections then
                for _, c in ipairs(getconnections(playBtn.MouseButton1Click)) do
                    pcall(function() c.Function() end)
                end
            end
            pcall(function()
                local p = playBtn.AbsolutePosition
                local s = playBtn.AbsoluteSize
                VirtualInputManager:SendMouseButtonEvent(p.X + s.X / 2, p.Y + s.Y / 2 + 36, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(p.X + s.X / 2, p.Y + s.Y / 2 + 36, 0, false, game, 1)
            end)
        end)
    end)
end

if _G.VoidYBAFarm then
    pcall(function()
        if _G.VoidYBAFarm.cleanup then _G.VoidYBAFarm.cleanup() end
    end)
    _G.VoidYBAFarm = nil
end

if _G.VoidYBAFarmCameraNoclip then
    pcall(function()
        local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        if PlayerScripts then
            local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
            if PlayerModule then
                local PopperClient = PlayerModule.CameraModule.ZoomController.Popper
                for i, v in next, getgc() do
                    if getfenv(v).script == PopperClient and typeof(v) == "function" then
                        for i2, v2 in next, debug.getconstants(v) do
                            if tonumber(v2) == 0 then
                                debug.setconstant(v, i2, 0.25)
                            elseif tonumber(v2) == 0.25 then
                                debug.setconstant(v, i2, 0)
                            end
                        end
                    end
                end
            end
        end
    end)
    _G.VoidYBAFarmCameraNoclip = false
end

_G.VoidYBAFarm = {
    connections = {},
    threads = {},
    gui = nil,
    cleanup = nil
}

local Config = {
    FPSCap = 60,
    RenderDistance = 5,
    RemoveTrees = false,
    ServerHop = false,
    TPOffset = 10,
    TPSpeed = 1.0,
    AutoSell = false,
    SellMouseX = 1236,
    SellMouseY = 681,
    WebhookURL = "",
    CameraInItem = false,
    InfoEnabled = false,
}

local SELL_ITEMS_DEFAULT = {
    "Gold Coin", "Rokakaka", "Pure Rokakaka", "Mysterious Arrow",
    "Diamond", "Ancient Scroll", "Caesar's Headband", "Stone Mask",
    "Rib Cage of The Saint's Corpse", "Quinton's Glove",
    "Zeppeli's Hat", "Lucky Arrow", "Lucky Stone Mask", "Clackers",
    "Steel Ball", "Dio's Diary"
}

local BaseMaxAmounts = {
    ["Gold Coin"]                      = 45,
    ["Rokakaka"]                       = 25,
    ["Pure Rokakaka"]                  = 10,
    ["Mysterious Arrow"]               = 25,
    ["Diamond"]                        = 30,
    ["Ancient Scroll"]                 = 10,
    ["Caesar's Headband"]              = 10,
    ["Stone Mask"]                     = 10,
    ["Rib Cage of The Saint's Corpse"] = 20,
    ["Quinton's Glove"]                = 10,
    ["Zeppeli's Hat"]                  = 10,
    ["Lucky Arrow"]                    = 10,
    ["Lucky Stone Mask"]               = 10,
    ["Clackers"]                       = 10,
    ["Steel Ball"]                     = 10,
    ["Dio's Diary"]                    = 10,
}

local MaxItemAmounts = {}
for k, v in pairs(BaseMaxAmounts) do
    MaxItemAmounts[k] = v
end

local has2xInventory = false
local GAMEPASS_2X_INVENTORY = 14597778

local SellItems = {}
for _, name in ipairs(SELL_ITEMS_DEFAULT) do
    SellItems[name] = true
end

local CONFIG_FILE = "void_yba_config.json"

local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if k ~= "SellItems" then
                    Config[k] = v
                end
            end
            if type(data.SellItems) == "table" then
                SellItems = data.SellItems
            end
        end
    end
end

local function saveConfig()
    if writefile then
        local out = {}
        for k, v in pairs(Config) do out[k] = v end
        out.SellItems = SellItems
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(out))
        end)
    end
end

loadConfig()

task.spawn(function()
    pcall(function()
        has2xInventory = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, GAMEPASS_2X_INVENTORY)
    end)
    if has2xInventory then
        for k, v in pairs(BaseMaxAmounts) do
            MaxItemAmounts[k] = v * 2
        end
        print("[VoidYBA] 2x Inventory detected — все лимиты удвоены.")
    else
        print("[VoidYBA] No 2x Inventory — базовые лимиты.")
    end
end)

local function doWebhookRequest(url, body)
    local success = false
    local reqFunc = nil
    if syn and syn.request then reqFunc = syn.request
    elseif http_request then reqFunc = http_request
    elseif request then reqFunc = request
    elseif http and http.request then reqFunc = http.request
    end

    if reqFunc then
        local ok = pcall(function()
            reqFunc({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                },
                Body = body
            })
        end)
        if ok then success = true end
    end

    if not success then
        pcall(function()
            HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
        end)
    end
end

local function sendCustomWebhook(content)
    if not Config.WebhookURL or Config.WebhookURL == "" then return end
    local body = HttpService:JSONEncode({
        content = content,
        username = "Void | YBA Farm",
        avatar_url = "https://cdn.discordapp.com/embed/avatars/0.png"
    })
    task.spawn(function()
        doWebhookRequest(Config.WebhookURL, body)
    end)
end

local function applyFPSCap(cap)
    if setfpscap then pcall(setfpscap, cap) end
end

local function applyRenderDistance(dist)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() workspace.StreamingTargetRadius = dist * 100 end)
end

local function removeTreesAndBushes()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Tree" or obj.Name == "Bush" then
            obj:Destroy()
        end
    end
end

local OriginalNamecallTP
OriginalNamecallTP = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local Arguments = {...}
    local Method = getnamecallmethod()
    if Method == "InvokeServer" and Arguments[1] == "idklolbrah2de" then
        return "  ___XP DE KEY"
    end
    return OriginalNamecallTP(self, ...)
end))

local autofarmEnabled = false
local noclipEnabled = false
local cameraNoclipEnabled = false
local randomTPEnabled = true
local lockConnection = nil
local lockedPosition = nil
local farmCoroutine = nil
local noclipConnection = nil
local hopConnection = nil
local currentTarget = nil
local animTrack = nil
local animConnection = nil
local ANIM_ID = "rbxassetid://72675993856360"
local ANIM_START_TIME = 0.5

local cameraInItemEnabled = false
local cameraTargetItem = nil
local cameraLockConnection = nil
local lastMouseYaw = 0
local lastMousePitch = 0
local mouseInputConn = nil
local savedCameraType = nil

local CUSTOM_TP_POINTS = {
    Vector3.new(95, 62, 72),
    Vector3.new(-216, 10, -66),
    Vector3.new(-36, -42, 523),
    Vector3.new(39, -33, 23),
    Vector3.new(-200, -33, -269),
    Vector3.new(-65, -33, -606),
    Vector3.new(73, 24, -932),
    Vector3.new(97, 14, -531),
    Vector3.new(253, 57, -210),
    Vector3.new(509, 14, 106),
    Vector3.new(976, -43, -111),
    Vector3.new(-655, -21, -750),
    Vector3.new(-190, 15, -585),
    Vector3.new(-182, 0, -231)
}
local MERCHANT_POS = Vector3.new(-702, -25, -335)
local WEATHER_VALUE = "Sunny"

local threeDDisabled = false
local totalTPs = 0
local totalPicked = 0
local pickedItems = {}
local lastPickedItem = "—"
local threeDOverlay = nil
local overlayLabels = nil

local sellingNow = false
local autoSellLoopThread = nil
local currentClickCount = 0

local infoEnabled = false
local infoConnection = nil
local infoLabel = nil

local autoStealThread = nil

local function countItem(name)
    local count = 0
    if LocalPlayer.Backpack then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool.Name == name then count = count + 1 end
        end
    end
    if LocalPlayer.Character then
        for _, obj in ipairs(LocalPlayer.Character:GetChildren()) do
            if obj:IsA("Tool") and obj.Name == name then count = count + 1 end
        end
    end
    return count
end

local function isItemFull(name)
    local cap = MaxItemAmounts[name]
    if not cap then return false end
    return countItem(name) >= cap
end

local function getMaxAmount(name)
    return MaxItemAmounts[name] or 0
end

local function getItemPosition(item)
    if item:IsA("Model") then
        local mesh = item:FindFirstChildWhichIsA("MeshPart", true)
        if mesh then
            return mesh.Position
        end
        local primary = item.PrimaryPart
        if primary then return primary.Position end
        for _, d in ipairs(item:GetChildren()) do
            if d:IsA("BasePart") then return d.Position end
        end
    elseif item:IsA("BasePart") then
        return item.Position
    end
    return nil
end

local function getItemProximityPrompt(item)
    if not item then return nil end
    if item:IsA("Model") then
        local mesh = item:FindFirstChildWhichIsA("MeshPart", true)
        if mesh then
            local prox = mesh:FindFirstChildWhichIsA("ProximityPrompt")
            if prox then return prox end
        end
        return item:FindFirstChildWhichIsA("ProximityPrompt", true)
    elseif item:IsA("BasePart") then
        return item:FindFirstChildWhichIsA("ProximityPrompt")
    end
    return nil
end

local function getItemName(item)
    if not item then return "" end
    local prox = getItemProximityPrompt(item)
    if prox and prox.ObjectText and prox.ObjectText ~= "" then
        return prox.ObjectText
    end
    return item.Name
end

local function isItemAvailable(item)
    if not item or not item.Parent then return false end
    if item:IsA("Model") then
        for _, d in ipairs(item:GetChildren()) do
            if d:IsA("BasePart") and d.Transparency < 0.95 then
                return true
            end
        end
        return false
    elseif item:IsA("BasePart") then
        return item.Transparency < 0.95
    end
    return false
end

local function getItemFolder()
    local spawns = workspace:FindFirstChild("Item_Spawns")
    if not spawns then return nil end
    return spawns:FindFirstChild("Items")
end

local function getAllItems()
    local folder = getItemFolder()
    if not folder then return {} end
    local items = {}
    for _, item in ipairs(folder:GetChildren()) do
        if isItemAvailable(item) then
            local name = getItemName(item)
            if not isItemFull(name) then
                local pos = getItemPosition(item)
                if pos then table.insert(items, {item = item, pos = pos, name = name}) end
            end
        end
    end
    return items
end

local function lockToPosition(position)
    totalTPs = totalTPs + 1
    lockedPosition = Vector3.new(position.X, position.Y - Config.TPOffset, position.Z)
    if lockConnection then lockConnection:Disconnect() end
    lockConnection = RunService.Heartbeat:Connect(function()
        if not autofarmEnabled or not lockedPosition then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local cam = workspace.CurrentCamera
        local flatDir = Vector3.new(0, 0, -1)
        if cam then
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then flatDir = flat.Unit end
        end
        hrp.CFrame = CFrame.new(lockedPosition, lockedPosition + flatDir)
        hrp.Velocity = Vector3.zero
    end)
end

local function unlockPosition()
    lockedPosition = nil
    if lockConnection then
        lockConnection:Disconnect()
        lockConnection = nil
    end
end

local function randomTeleport()
    if #CUSTOM_TP_POINTS > 0 then
        local chosen = CUSTOM_TP_POINTS[math.random(1, #CUSTOM_TP_POINTS)]
        lockToPosition(chosen)
    end
end

local function enableNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection = RunService.Stepped:Connect(function()
        if noclipEnabled and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
end

local function disableNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

local function enableCameraNoclip()
    pcall(function()
        local PopperClient = LocalPlayer:WaitForChild("PlayerScripts").PlayerModule.CameraModule.ZoomController.Popper
        for i, v in next, getgc() do
            if getfenv(v).script == PopperClient and typeof(v) == "function" then
                for i2, v2 in next, debug.getconstants(v) do
                    if tonumber(v2) == 0.25 then
                        debug.setconstant(v, i2, 0)
                    elseif tonumber(v2) == 0 then
                        debug.setconstant(v, i2, 0.25)
                    end
                end
            end
        end
    end)
    _G.VoidYBAFarmCameraNoclip = true
end

local function disableCameraNoclip()
    pcall(function()
        local PopperClient = LocalPlayer:WaitForChild("PlayerScripts").PlayerModule.CameraModule.ZoomController.Popper
        for i, v in next, getgc() do
            if getfenv(v).script == PopperClient and typeof(v) == "function" then
                for i2, v2 in next, debug.getconstants(v) do
                    if tonumber(v2) == 0 then
                        debug.setconstant(v, i2, 0.25)
                    elseif tonumber(v2) == 0.25 then
                        debug.setconstant(v, i2, 0)
                    end
                end
            end
        end
    end)
    _G.VoidYBAFarmCameraNoclip = false
end

local function setCameraNoclip(state)
    cameraNoclipEnabled = state
    if state then enableCameraNoclip() else disableCameraNoclip() end
end

local function lockCameraToItem(item)
    if not cameraInItemEnabled then return end
    cameraTargetItem = item
    local cam = workspace.CurrentCamera
    if not cam then return end

    savedCameraType = cam.CameraType
    cam.CameraType = Enum.CameraType.Scriptable

    lastMouseYaw = 0
    lastMousePitch = 0

    if mouseInputConn then mouseInputConn:Disconnect() end
    mouseInputConn = UserInputService.InputChanged:Connect(function(input)
        if not cameraTargetItem then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            lastMouseYaw = lastMouseYaw - input.Delta.X * 0.005
            lastMousePitch = math.clamp(lastMousePitch - input.Delta.Y * 0.005, -math.rad(80), math.rad(80))
        end
    end)

    if cameraLockConnection then cameraLockConnection:Disconnect() end
    cameraLockConnection = RunService.RenderStepped:Connect(function()
        if not cameraTargetItem or not autofarmEnabled then return end
        local cam2 = workspace.CurrentCamera
        if not cam2 then return end

        local targetPos = nil
        if cameraTargetItem and cameraTargetItem.Parent then
            targetPos = getItemPosition(cameraTargetItem)
        end
        if not targetPos then return end

        local c = math.cos(lastMousePitch)
        local s = math.sin(lastMousePitch)
        local lookDir = Vector3.new(
            math.sin(lastMouseYaw) * c,
            s,
            math.cos(lastMouseYaw) * c
        )
        cam2.CFrame = CFrame.new(targetPos, targetPos + lookDir)
    end)
end

local function unlockCamera()
    cameraTargetItem = nil
    if cameraLockConnection then
        cameraLockConnection:Disconnect()
        cameraLockConnection = nil
    end
    if mouseInputConn then
        mouseInputConn:Disconnect()
        mouseInputConn = nil
    end
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = savedCameraType or Enum.CameraType.Custom
        end
    end)
end

local function setCameraInItem(state)
    cameraInItemEnabled = state
    if not state then
        unlockCamera()
    end
end

local function buildItemsList()
    if #pickedItems == 0 then return "—" end
    local counts = {}
    for _, name in ipairs(pickedItems) do
        counts[name] = (counts[name] or 0) + 1
    end
    local list = {}
    for name, count in pairs(counts) do
        local max = getMaxAmount(name)
        table.insert(list, name .. ": " .. count .. "/" .. max)
    end
    table.sort(list)
    return table.concat(list, "\n")
end

local function enable3DOff()
    threeDDisabled = true
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then obj.LocalTransparencyModifier = 1 end
        end
    end)
    if threeDOverlay then threeDOverlay:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Void3DOffOverlay"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = -1
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local bg = Instance.new("Frame")
    bg.Name = "BG"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Active = false
    bg.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0.05, 0)
    title.BackgroundTransparency = 1
    title.Text = "ПОСЛЕДНИЙ СОБРАННЫЙ ПРЕДМЕТ:"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 28
    title.ZIndex = 2
    title.Parent = bg

    local lastItem = Instance.new("TextLabel")
    lastItem.Size = UDim2.new(1, 0, 0, 50)
    lastItem.Position = UDim2.new(0, 0, 0.05, 45)
    lastItem.BackgroundTransparency = 1
    lastItem.Text = lastPickedItem
    lastItem.TextColor3 = Color3.fromRGB(180, 40, 40)
    lastItem.Font = Enum.Font.GothamBold
    lastItem.TextSize = 40
    lastItem.ZIndex = 2
    lastItem.Parent = bg

    local list = Instance.new("TextLabel")
    list.Size = UDim2.new(1, -40, 0.6, 0)
    list.Position = UDim2.new(0, 20, 0.25, 0)
    list.BackgroundTransparency = 1
    list.Text = buildItemsList()
    list.TextColor3 = Color3.fromRGB(160, 160, 170)
    list.Font = Enum.Font.Gotham
    list.TextSize = 14
    list.TextWrapped = true
    list.TextYAlignment = Enum.TextYAlignment.Top
    list.ZIndex = 2
    list.Parent = bg

    local stats = Instance.new("TextLabel")
    stats.Size = UDim2.new(1, 0, 0, 24)
    stats.Position = UDim2.new(0, 0, 0.93, 0)
    stats.BackgroundTransparency = 1
    stats.Text = "Собрано: " .. totalPicked .. " | ТП: " .. totalTPs
    stats.TextColor3 = Color3.fromRGB(120, 120, 130)
    stats.Font = Enum.Font.Gotham
    stats.TextSize = 16
    stats.ZIndex = 2
    stats.Parent = bg

    threeDOverlay = gui
    overlayLabels = {lastItem = lastItem, list = list, stats = stats}
end

local function disable3DOff()
    threeDDisabled = false
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then obj.LocalTransparencyModifier = 0 end
        end
    end)
    if threeDOverlay then
        threeDOverlay:Destroy()
        threeDOverlay = nil
        overlayLabels = nil
    end
end

local function set3DOff(state)
    if state then enable3DOff() else disable3DOff() end
end

local function update3DOverlay()
    if not threeDOverlay or not overlayLabels then return end
    if overlayLabels.lastItem then overlayLabels.lastItem.Text = lastPickedItem end
    if overlayLabels.list then overlayLabels.list.Text = buildItemsList() end
    if overlayLabels.stats then
        overlayLabels.stats.Text = "Собрано: " .. totalPicked .. " | ТП: " .. totalTPs
    end
end

local function enableAnim()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID
    pcall(function()
        animTrack = animator:LoadAnimation(anim)
        animTrack.Priority = Enum.AnimationPriority.Action
        animTrack.Looped = false
        animTrack:Play()
        animTrack.TimePosition = ANIM_START_TIME
    end)
    if animConnection then animConnection:Disconnect() end
    animConnection = animTrack.Stopped:Connect(function()
        if not autofarmEnabled then return end
        task.wait(0.05)
        if animTrack and autofarmEnabled then
            pcall(function()
                animTrack:Play()
                animTrack.TimePosition = ANIM_START_TIME
            end)
        end
    end)
end

local function disableAnim()
    if animConnection then
        animConnection:Disconnect()
        animConnection = nil
    end
    if animTrack then
        pcall(function() animTrack:Stop() end)
        animTrack = nil
    end
end

local function waitForPickup(item, timeout)
    timeout = timeout or 5
    local startTime = tick()
    while autofarmEnabled do
        if not item or not item.Parent then return true end
        if not isItemAvailable(item) then return true end
        if tick() - startTime >= timeout then return false end
        task.wait(0.05)
    end
    return false
end

local function autofarmLoop()
    while autofarmEnabled do
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(0.3)
        else
            local allItems = getAllItems()
            local collected = false
            if #allItems > 0 then
                for _, entry in ipairs(allItems) do
                    if not autofarmEnabled then break end
                    if isItemAvailable(entry.item) then
                        currentTarget = entry.item
                        lockToPosition(entry.pos)
                        if cameraInItemEnabled then
                            lockCameraToItem(entry.item)
                        end
                        collected = true

                        task.wait(Config.TPSpeed)

                        local prox = getItemProximityPrompt(entry.item)
                        if prox then
                            pcall(function()
                                fireproximityprompt(prox)
                            end)
                        end

                        local picked = waitForPickup(entry.item, 5)
                        if picked then
                            totalPicked = totalPicked + 1
                            local itemName = entry.name or entry.item.Name
                            table.insert(pickedItems, itemName)
                            lastPickedItem = itemName
                            update3DOverlay()
                        end
                        currentTarget = nil
                        if cameraInItemEnabled then
                            unlockCamera()
                        end
                    end
                end
            end
            if not collected and randomTPEnabled then
                for i = 1, 3 do
                    if not autofarmEnabled then break end
                    randomTeleport()
                    task.wait(Config.TPSpeed)
                end
            end
        end
        task.wait(0.1)
    end
end

local function startAutofarm()
    if autofarmEnabled then return end
    autofarmEnabled = true
    totalTPs = 0
    totalPicked = 0
    pickedItems = {}
    lastPickedItem = "—"
    enableAnim()
    farmCoroutine = task.spawn(autofarmLoop)
    update3DOverlay()
    sendCustomWebhook("**Autofarm: ВКЛЮЧЕН** | Ник: " .. LocalPlayer.Name .. " | Игра: " .. game.PlaceId)
end

local function stopAutofarm()
    if not autofarmEnabled then return end
    autofarmEnabled = false
    unlockPosition()
    unlockCamera()
    disableAnim()
    currentTarget = nil
    sendCustomWebhook("**Autofarm: ВЫКЛЮЧЕН** | Ник: " .. LocalPlayer.Name .. " | Собрано: " .. totalPicked .. " | ТП: " .. totalTPs)
end

local function setNoclip(state)
    noclipEnabled = state
    if state then enableNoclip() else disableNoclip() end
end

local function setRandomTP(state)
    randomTPEnabled = state
end

local function tpToMerchant()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(MERCHANT_POS)
    hrp.Velocity = Vector3.zero
end

local function setWeather(value)
    task.spawn(function()
        pcall(function()
            local weather = workspace:WaitForChild("Weather", 15)
            if weather and weather:IsA("StringValue") then
                weather.Value = value
            end
        end)
    end)
end

local function doServerHop()
    local servers = {}
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(game:HttpGet(url))
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(servers, s.id)
            end
        end
    end)
    if #servers > 0 then
        local chosen = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, LocalPlayer)
    else
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end

local function startServerHop()
    if hopConnection then task.cancel(hopConnection) end
    hopConnection = task.spawn(function()
        while Config.ServerHop do
            task.wait(300)
            if Config.ServerHop then doServerHop() end
        end
    end)
end

local function skipLoading()
    task.spawn(function()
        if Lighting:FindFirstChild("DepthOfField") then
            Lighting.DepthOfField:Destroy()
        end
    end)
    pcall(function()
        if workspace.Map and workspace.Map.IMPORTANT and workspace.Map.IMPORTANT.OceanFloor then
            local of = workspace.Map.IMPORTANT.OceanFloor
            if of:FindFirstChild("OceanFloor_Sand_6") then
                of.OceanFloor_Sand_6.Size = Vector3.new(2048, 89, 2048)
            end
            if of:FindFirstChild("OceanFloor_Sand_4") then
                of.OceanFloor_Sand_4.Size = Vector3.new(2048, 89, 2048)
            end
        end
    end)
    task.spawn(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            local ok, result = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 10) end)
            if ok then playerGui = result end
        end
        if not playerGui then return end
        if playerGui:FindFirstChild("LoadingScreen1") then playerGui.LoadingScreen1:Destroy() end
        if playerGui:FindFirstChild("LoadingScreen") then playerGui.LoadingScreen:Destroy() end
    end)
end

skipLoading()

local function ForceClick(optionName)
    local DialogueGui = LocalPlayer.PlayerGui:FindFirstChild("DialogueGui")
    if not DialogueGui then return end
    
    local Frame = DialogueGui:FindFirstChild("Frame")
    if not Frame then return end
    
    local Options = Frame:FindFirstChild("Options")
    if not Options then return end
    
    local Option = Options:FindFirstChild(optionName)
    if not Option then return end
    
    local TextButton = Option:FindFirstChild("TextButton")
    if not TextButton or not TextButton.Visible then return end
    
    for _, connection in pairs(getconnections(TextButton.MouseButton1Click)) do
        if connection.Function then
            pcall(function()
                connection.Function()
            end)
        else
            pcall(function()
                connection:Fire()
            end)
        end
    end
    
    pcall(function()
        TextButton:Activated()
    end)
end

local function normalizeText(text)
    text = tostring(text or ""):lower()
    text = text:gsub("[%c%p]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$") or ""
end

local function findMerchantPrompt()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local matched = false
            local depth = 0
            while parent and parent ~= workspace and depth < 6 do
                if tostring(parent.Name):lower():find("merchant", 1, true) then
                    matched = true
                    break
                end
                parent = parent.Parent
                depth = depth + 1
            end
            local otext = normalizeText(obj.ObjectText)
            local atext = normalizeText(obj.ActionText)
            if matched or otext:find("merchant", 1, true) or atext:find("merchant", 1, true) then
                return obj
            end
        end
    end
    return nil
end

local function equipSellTool(itemName)
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end
    
    local tool = LocalPlayer.Backpack:FindFirstChild(itemName)
    if not tool then
        tool = char:FindFirstChild(itemName)
    end
    if not tool then return nil end
    
    if tool.Parent == LocalPlayer.Backpack then
        local ok = pcall(function() hum:EquipTool(tool) end)
        if not ok then return nil end
        task.wait(0.15)
    end
    
    local deadline = tick() + 1
    while tool.Parent ~= char and tick() < deadline do task.wait() end
    return tool
end

local function startAutoSell()
    if autoSellLoopThread then return end
    autoSellLoopThread = task.spawn(function()
        while Config.AutoSell do
            task.wait(0.1)
            
            local DialogueGui = LocalPlayer.PlayerGui:FindFirstChild("DialogueGui")
            
            if not DialogueGui then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local equipped = false
                    for _, itemName in ipairs(SELL_ITEMS_DEFAULT) do
                        if SellItems[itemName] and countItem(itemName) > 0 then
                            equipSellTool(itemName)
                            equipped = true
                            break
                        end
                    end
                    
                    if equipped then
                        local prompt = findMerchantPrompt()
                        if prompt then
                            pcall(function()
                                fireproximityprompt(prompt)
                            end)
                        end
                        task.wait(0.5)
                    end
                end
            else
                local targetOption = "Option1"
                if currentClickCount >= 2 then
                    targetOption = "Option5"
                end
                
                local Options = DialogueGui.Frame and DialogueGui.Frame:FindFirstChild("Options")
                if Options and Options:FindFirstChild(targetOption) then
                    ForceClick(targetOption)
                    
                    if targetOption == "Option1" then
                        currentClickCount = currentClickCount + 1
                    elseif targetOption == "Option5" then
                        currentClickCount = 0
                    end
                    
                    task.wait(0.3)
                end
            end
        end
    end)
end

local function stopAutoSell()
    if autoSellLoopThread then
        pcall(function() task.cancel(autoSellLoopThread) end)
        autoSellLoopThread = nil
    end
    currentClickCount = 0
end

local function autoStealLoop()
    while true do
        task.wait(0.05)
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local money = plr.Character:FindFirstChild("Money")
                    if money and money:IsA("BasePart") then
                        firetouchinterest(hrp, money, 0)
                        firetouchinterest(hrp, money, 1)
                    end
                end
            end
        end)
    end
end

local function startAutoSteal()
    if autoStealThread then return end
    autoStealThread = task.spawn(autoStealLoop)
end

local kickConn = CoreGui.DescendantAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local GrabError = child:FindFirstChild("ErrorMessage", true)
        if GrabError then
            repeat task.wait() until GrabError.Text ~= "Label"
            local Reason = GrabError.Text
            if Reason:match("kick") or Reason:match("You") or Reason:match("conn") or Reason:match("rejoin") then
                sendCustomWebhook("**КИКНУТ** | Ник: " .. LocalPlayer.Name .. " | Причина: " .. Reason)

                if writefile then
                    pcall(function()
                        writefile("void_yba_rejoined.flag", tostring(tick()))
                    end)
                end

                task.wait(0.5)

                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                end)
            end
        end
    end
end)
table.insert(_G.VoidYBAFarm.connections, kickConn)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VoidYBAFarm"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 10
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

_G.VoidYBAFarm.gui = ScreenGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 480, 0, 436)
Main.Position = UDim2.new(0.5, -240, 0.5, -218)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "VOID | YBA FARM"
Title.TextColor3 = Color3.fromRGB(220, 50, 50)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 24)
CloseBtn.Position = UDim2.new(1, -34, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar
local CC = Instance.new("UICorner") CC.CornerRadius = UDim.new(0, 6) CC.Parent = CloseBtn

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 28, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -66, 0, 4)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.Parent = TopBar
local MC = Instance.new("UICorner") MC.CornerRadius = UDim.new(0, 6) MC.Parent = MinimizeBtn

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 120, 1, -40)
TabBar.Position = UDim2.new(0, 8, 0, 36)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main
local TBC = Instance.new("UICorner") TBC.CornerRadius = UDim.new(0, 6) TBC.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -144, 1, -44)
Content.Position = UDim2.new(0, 136, 0, 40)
Content.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
Content.BorderSizePixel = 0
Content.Parent = Main
local CNC = Instance.new("UICorner") CNC.CornerRadius = UDim.new(0, 6) CNC.Parent = Content

local function makeTabButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 30)
    btn.Position = UDim2.new(0, 4, 0, 4 + (order * 34))
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = TabBar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = btn
    return btn
end

local function makePage(name)
    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, -12, 1, -12)
    page.Position = UDim2.new(0, 6, 0, 6)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = Content
    return page
end

local function makeScrollingPage(name)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -12, 1, -12)
    holder.Position = UDim2.new(0, 6, 0, 6)
    holder.BackgroundTransparency = 1
    holder.Visible = false
    holder.Parent = Content

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(180, 40, 40)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = holder

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.Parent = scroll

    return holder, scroll
end

local function makeToggleScrolling(parent, text, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, 28)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 22)
    btn.Position = UDim2.new(1, -54, 0, 3)
    btn.BackgroundColor3 = default and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(80, 80, 90)
    btn.BorderSizePixel = 0
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = holder
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = btn

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(80, 80, 90)
        if callback then callback(state) end
    end)
    return holder
end

local function makeToggle(parent, text, yPos, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, 28)
    holder.Position = UDim2.new(0, 4, 0, yPos)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 22)
    btn.Position = UDim2.new(1, -54, 0, 3)
    btn.BackgroundColor3 = default and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(80, 80, 90)
    btn.BorderSizePixel = 0
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = holder
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = btn

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(80, 80, 90)
        if callback then callback(state) end
    end)
    return holder
end

local function makeSlider(parent, text, yPos, min, max, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, 42)
    holder.Position = UDim2.new(0, 4, 0, yPos)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local valBox = Instance.new("TextBox")
    valBox.Size = UDim2.new(0, 60, 0, 20)
    valBox.Position = UDim2.new(1, -64, 0, 0)
    valBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    valBox.BorderSizePixel = 0
    valBox.Text = tostring(default)
    valBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    valBox.Font = Enum.Font.Gotham
    valBox.TextSize = 12
    valBox.Parent = holder
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = valBox

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -8, 0, 8)
    bar.Position = UDim2.new(0, 4, 0, 26)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bar.BorderSizePixel = 0
    bar.Parent = holder
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 4) fc.Parent = fill

    local dragging = false

    local function setValue(v)
        v = math.clamp(v, min, max)
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        valBox.Text = tostring(v)
        if callback then callback(v) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            setValue(min + rel * (max - min))
        end
    end)
    valBox.FocusLost:Connect(function()
        local n = tonumber(valBox.Text)
        if n then setValue(n) else valBox.Text = tostring(default) end
    end)
end

local function makeButton(parent, text, yPos, callback, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 30)
    btn.Position = UDim2.new(0, 4, 0, yPos)
    btn.BackgroundColor3 = color or Color3.fromRGB(45, 45, 58)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local FarmPage = makePage("Farm")
local InfoPage = makePage("Info")
local OptPage = makePage("Opt")
local SellPageHolder, SellScroll = makeScrollingPage("Sell")

makeToggle(FarmPage, "Autofarm", 8, false, function(state)
    if state then startAutofarm() else stopAutofarm() end
end)

makeToggle(FarmPage, "Noclip", 40, true, function(state)
    setNoclip(state)
end)

makeToggle(FarmPage, "Camera Noclip", 72, false, function(state)
    setCameraNoclip(state)
end)

makeToggle(FarmPage, "3D OFF (Black Screen)", 104, false, function(state)
    set3DOff(state)
end)

makeToggle(FarmPage, "Camera in Item", 136, Config.CameraInItem, function(state)
    Config.CameraInItem = state
    saveConfig()
    setCameraInItem(state)
end)

makeToggle(FarmPage, "Random TP", 168, true, function(state)
    setRandomTP(state)
end)

makeToggle(FarmPage, "Server Hop (5 min)", 200, false, function(state)
    Config.ServerHop = state
    saveConfig()
    if state then startServerHop() end
end)

makeSlider(FarmPage, "TP Offset", 240, 0, 40, Config.TPOffset, function(v)
    Config.TPOffset = v
    saveConfig()
end)

makeSlider(FarmPage, "TP Speed (s)", 282, 0.8, 1.2, Config.TPSpeed, function(v)
    Config.TPSpeed = math.floor(v * 100) / 100
    saveConfig()
end)

makeButton(FarmPage, "TP TO MERCHANT", 336, function()
    tpToMerchant()
end, Color3.fromRGB(40, 90, 200))

makeButton(FarmPage, "Set Sunny Weather", 370, function()
    setWeather("Sunny")
end, Color3.fromRGB(230, 180, 40))

makeButton(FarmPage, "Save Config", 404, function()
    saveConfig()
end)

local infoHeader = Instance.new("TextLabel")
infoHeader.Size = UDim2.new(1, -8, 0, 24)
infoHeader.BackgroundTransparency = 1
infoHeader.Text = "⚙ INFO"
infoHeader.TextColor3 = Color3.fromRGB(220, 50, 50)
infoHeader.Font = Enum.Font.GothamBold
infoHeader.TextSize = 13
infoHeader.TextXAlignment = Enum.TextXAlignment.Left
infoHeader.Parent = InfoPage

makeToggle(InfoPage, "Show Item Count", 32, Config.InfoEnabled, function(state)
    Config.InfoEnabled = state
    saveConfig()
    if state then
        infoEnabled = true
        if not infoConnection then
            infoConnection = RunService.Heartbeat:Connect(function()
                if not infoEnabled or not infoLabel then return end
                local folder = getItemFolder()
                local count = 0
                if folder then
                    for _, item in ipairs(folder:GetChildren()) do
                        if isItemAvailable(item) then
                            count = count + 1
                        end
                    end
                end
                infoLabel.Text = "Items on map: " .. count
            end)
        end
    else
        infoEnabled = false
        if infoConnection then
            infoConnection:Disconnect()
            infoConnection = nil
        end
    end
end)

infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -8, 0, 24)
infoLabel.Position = UDim2.new(0, 4, 0, 68)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Items on map: 0"
infoLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 13
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = InfoPage

local creditsHolder = Instance.new("Frame")
creditsHolder.Size = UDim2.new(1, -8, 0, 100)
creditsHolder.Position = UDim2.new(0, 4, 0, 110)
creditsHolder.BackgroundTransparency = 1
creditsHolder.Parent = InfoPage

local ownerLabel = Instance.new("TextLabel")
ownerLabel.Size = UDim2.new(1, 0, 0, 22)
ownerLabel.BackgroundTransparency = 1
ownerLabel.Text = "Owner: Borat"
ownerLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
ownerLabel.Font = Enum.Font.Gotham
ownerLabel.TextSize = 13
ownerLabel.TextXAlignment = Enum.TextXAlignment.Left
ownerLabel.Parent = creditsHolder

local ideasLabel = Instance.new("TextLabel")
ideasLabel.Size = UDim2.new(1, 0, 0, 22)
ideasLabel.Position = UDim2.new(0, 0, 0, 26)
ideasLabel.BackgroundTransparency = 1
ideasLabel.Text = "Ideas: Artmit"
ideasLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
ideasLabel.Font = Enum.Font.Gotham
ideasLabel.TextSize = 13
ideasLabel.TextXAlignment = Enum.TextXAlignment.Left
ideasLabel.Parent = creditsHolder

local niggaLabel = Instance.new("TextLabel")
niggaLabel.Size = UDim2.new(1, 0, 0, 22)
niggaLabel.Position = UDim2.new(0, 0, 0, 52)
niggaLabel.BackgroundTransparency = 1
niggaLabel.Text = "Nigga: Artmit"
niggaLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
niggaLabel.Font = Enum.Font.Gotham
niggaLabel.TextSize = 13
niggaLabel.TextXAlignment = Enum.TextXAlignment.Left
niggaLabel.Parent = creditsHolder

makeSlider(OptPage, "FPS Cap", 8, 30, 240, Config.FPSCap, function(v)
    Config.FPSCap = v
    applyFPSCap(v)
end)

makeSlider(OptPage, "Render Distance", 56, 1, 20, Config.RenderDistance, function(v)
    Config.RenderDistance = v
    applyRenderDistance(v)
end)

makeToggle(OptPage, "Remove Trees/Bushes", 104, Config.RemoveTrees, function(state)
    Config.RemoveTrees = state
    if state then removeTreesAndBushes() end
    saveConfig()
end)

local sellHeader = Instance.new("TextLabel")
sellHeader.Size = UDim2.new(1, -8, 0, 24)
sellHeader.BackgroundTransparency = 1
sellHeader.Text = "⚙ SELL SETTINGS"
sellHeader.TextColor3 = Color3.fromRGB(220, 50, 50)
sellHeader.Font = Enum.Font.GothamBold
sellHeader.TextSize = 13
sellHeader.TextXAlignment = Enum.TextXAlignment.Left
sellHeader.Parent = SellScroll

makeToggleScrolling(SellScroll, "Auto Sell Loop", Config.AutoSell, function(state)
    Config.AutoSell = state
    saveConfig()
    if state then
        startAutoSell()
    else
        stopAutoSell()
    end
end)

local sellStatusLabel = Instance.new("TextLabel")
sellStatusLabel.Size = UDim2.new(1, -8, 0, 20)
sellStatusLabel.BackgroundTransparency = 1
sellStatusLabel.Text = ""
sellStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
sellStatusLabel.Font = Enum.Font.Gotham
sellStatusLabel.TextSize = 11
sellStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
sellStatusLabel.Parent = SellScroll

local webhookHeader = Instance.new("TextLabel")
webhookHeader.Size = UDim2.new(1, -8, 0, 24)
webhookHeader.BackgroundTransparency = 1
webhookHeader.Text = "⚙ WEBHOOK"
webhookHeader.TextColor3 = Color3.fromRGB(220, 50, 50)
webhookHeader.Font = Enum.Font.GothamBold
webhookHeader.TextSize = 13
webhookHeader.TextXAlignment = Enum.TextXAlignment.Left
webhookHeader.Parent = SellScroll

local webhookHolder = Instance.new("Frame")
webhookHolder.Size = UDim2.new(1, -8, 0, 50)
webhookHolder.BackgroundTransparency = 1
webhookHolder.Parent = SellScroll

local webhookBox = Instance.new("TextBox")
webhookBox.Size = UDim2.new(1, 0, 0, 24)
webhookBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
webhookBox.BorderSizePixel = 0
webhookBox.Text = Config.WebhookURL or ""
webhookBox.PlaceholderText = "https://discord.com/api/webhooks/..."
webhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
webhookBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
webhookBox.Font = Enum.Font.Gotham
webhookBox.TextSize = 11
webhookBox.ClearTextOnFocus = false
webhookBox.Parent = webhookHolder
local wbc = Instance.new("UICorner") wbc.CornerRadius = UDim.new(0, 4) wbc.Parent = webhookBox

local saveWebhookBtn = Instance.new("TextButton")
saveWebhookBtn.Size = UDim2.new(0.49, -2, 0, 22)
saveWebhookBtn.Position = UDim2.new(0, 0, 0, 26)
saveWebhookBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
saveWebhookBtn.BorderSizePixel = 0
saveWebhookBtn.Text = "SAVE WEBHOOK"
saveWebhookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveWebhookBtn.Font = Enum.Font.GothamBold
saveWebhookBtn.TextSize = 11
saveWebhookBtn.Parent = webhookHolder
local swbc = Instance.new("UICorner") swbc.CornerRadius = UDim.new(0, 4) swbc.Parent = saveWebhookBtn

local testWebhookBtn = Instance.new("TextButton")
testWebhookBtn.Size = UDim2.new(0.49, -2, 0, 22)
testWebhookBtn.Position = UDim2.new(0.51, 0, 0, 26)
testWebhookBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 200)
testWebhookBtn.BorderSizePixel = 0
testWebhookBtn.Text = "TEST WEBHOOK"
testWebhookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
testWebhookBtn.Font = Enum.Font.GothamBold
testWebhookBtn.TextSize = 11
testWebhookBtn.Parent = webhookHolder
local twbc = Instance.new("UICorner") twbc.CornerRadius = UDim.new(0, 4) twbc.Parent = testWebhookBtn

saveWebhookBtn.MouseButton1Click:Connect(function()
    Config.WebhookURL = webhookBox.Text or ""
    saveConfig()
    saveWebhookBtn.Text = "SAVED ✓"
    task.wait(1.5)
    saveWebhookBtn.Text = "SAVE WEBHOOK"
end)

testWebhookBtn.MouseButton1Click:Connect(function()
    local url = webhookBox.Text or ""
    if url == "" then
        testWebhookBtn.Text = "NO URL"
        task.wait(1.5)
        testWebhookBtn.Text = "TEST WEBHOOK"
        return
    end
    Config.WebhookURL = url
    sendCustomWebhook("**ТЕСТ ВЕБХУКА** | Ник: " .. LocalPlayer.Name .. " | Если видишь это — вебхук работает")
    testWebhookBtn.Text = "SENT ✓"
    task.wait(1.5)
    testWebhookBtn.Text = "TEST WEBHOOK"
end)

local itemsHeader = Instance.new("TextLabel")
itemsHeader.Size = UDim2.new(1, -8, 0, 24)
itemsHeader.BackgroundTransparency = 1
itemsHeader.Text = "⚙ ITEMS TO SELL"
itemsHeader.TextColor3 = Color3.fromRGB(220, 50, 50)
itemsHeader.Font = Enum.Font.GothamBold
itemsHeader.TextSize = 13
itemsHeader.TextXAlignment = Enum.TextXAlignment.Left
itemsHeader.Parent = SellScroll

for _, itemName in ipairs(SELL_ITEMS_DEFAULT) do
    makeToggleScrolling(SellScroll, itemName, SellItems[itemName] ~= false, function(state)
        SellItems[itemName] = state
        saveConfig()
    end)
end

local currentTab = nil
local function switchTab(name)
    FarmPage.Visible = false
    InfoPage.Visible = false
    OptPage.Visible = false
    SellPageHolder.Visible = false
    if name == "Farm" then FarmPage.Visible = true
    elseif name == "Info" then InfoPage.Visible = true
    elseif name == "Opt" then OptPage.Visible = true
    elseif name == "Sell" then SellPageHolder.Visible = true end
    currentTab = name
end

local FarmTabBtn = makeTabButton("Autofarm", 0)
local InfoTabBtn = makeTabButton("Info", 1)
local OptTabBtn = makeTabButton("Optimization", 2)
local SellTabBtn = makeTabButton("Auto Sell", 3)
switchTab("Farm")

FarmTabBtn.MouseButton1Click:Connect(function() switchTab("Farm") end)
InfoTabBtn.MouseButton1Click:Connect(function() switchTab("Info") end)
OptTabBtn.MouseButton1Click:Connect(function() switchTab("Opt") end)
SellTabBtn.MouseButton1Click:Connect(function() switchTab("Sell") end)

local minimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Content.Visible = false
        TabBar.Visible = false
        Main.Size = UDim2.new(0, 480, 0, 32)
    else
        Content.Visible = true
        TabBar.Visible = true
        Main.Size = UDim2.new(0, 480, 0, 436)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = false
end)

local openKey = Enum.KeyCode.RightShift
local keyConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == openKey then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)
table.insert(_G.VoidYBAFarm.connections, keyConn)

local charConn = LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(2)
    if autofarmEnabled then
        disableAnim()
        unlockPosition()
        task.wait(0.5)
        startAutofarm()
    end
    setNoclip(noclipEnabled)
end)
table.insert(_G.VoidYBAFarm.connections, charConn)

applyFPSCap(Config.FPSCap)
applyRenderDistance(Config.RenderDistance)
if Config.RemoveTrees then removeTreesAndBushes() end
if Config.ServerHop then startServerHop() end
if Config.AutoSell then
    startAutoSell()
end
setNoclip(true)
setWeather(WEATHER_VALUE)

if Config.InfoEnabled then
    infoEnabled = true
    infoConnection = RunService.Heartbeat:Connect(function()
        if not infoEnabled or not infoLabel then return end
        local folder = getItemFolder()
        local count = 0
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                if isItemAvailable(item) then
                    count = count + 1
                end
            end
        end
        infoLabel.Text = "Items on map: " .. count
    end)
end

task.spawn(function()
    repeat task.wait(0.5) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    repeat task.wait(0.5) until workspace:FindFirstChild("Item_Spawns") and workspace.Item_Spawns:FindFirstChild("Items")
    task.wait(2)
    startAutofarm()
end)

startAutoSteal()

_G.VoidYBAFarm.cleanup = function()
    autofarmEnabled = false
    sellingNow = false
    infoEnabled = false

    for _, conn in ipairs(_G.VoidYBAFarm.connections) do
        pcall(function() conn:Disconnect() end)
    end
    _G.VoidYBAFarm.connections = {}

    if lockConnection then pcall(function() lockConnection:Disconnect() end) end
    if cameraLockConnection then pcall(function() cameraLockConnection:Disconnect() end) end
    if mouseInputConn then pcall(function() mouseInputConn:Disconnect() end) end
    if noclipConnection then pcall(function() noclipConnection:Disconnect() end) end
    if animConnection then pcall(function() animConnection:Disconnect() end) end
    if hopConnection then pcall(function() task.cancel(hopConnection) end) end
    if infoConnection then pcall(function() infoConnection:Disconnect() end) end

    if farmCoroutine then pcall(function() task.cancel(farmCoroutine) end) end
    if autoSellLoopThread then pcall(function() task.cancel(autoSellLoopThread) end) end
    if autoStealThread then pcall(function() task.cancel(autoStealThread) end) end

    if cameraNoclipEnabled then pcall(disableCameraNoclip) end
    if threeDDisabled then pcall(disable3DOff) end

    cameraLockConnection = nil
    mouseInputConn = nil
    cameraTargetItem = nil
    infoConnection = nil
    infoLabel = nil

    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
    end)

    if _G.VoidYBAFarm.gui then
        pcall(function() _G.VoidYBAFarm.gui:Destroy() end)
    end
end
