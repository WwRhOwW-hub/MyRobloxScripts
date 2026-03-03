--[[
    ULTIMATE Auto Dig + Auto Teleport для Bee Swarm Simulator
    Версия для загрузчика
]]

-- Ждем загрузки игрока
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Функция, которая запустит наш скрипт после загрузки игры
local function loadFarmScript()
    -- Все сервисы Roblox
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    
    -- Переменные
    local digging = false
    local autoTeleport = true
    local digDelay = 0.15
    local lastClickTime = 0
    local diggableObjects = {}
    local spawnPosition = nil
    local backpackFull = false
    
    -- Функция для получения позиции на экране
    local function getScreenPosition(part)
        if not part or not part.Parent then return nil end
        
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        
        local success, result = pcall(function()
            return camera:WorldToViewportPoint(part.Position)
        end)
        
        if success and result then
            local screenPoint, onScreen = result, result
            if onScreen then
                return Vector2.new(screenPoint.X, screenPoint.Y)
            end
        end
        return nil
    end
    
    -- Функция клика
    local function clickAtPosition(position)
        if not position then return end
        if tick() - lastClickTime < digDelay then return end
        
        lastClickTime = tick()
        
        VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, true, game, 0)
        task.wait()
        VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, false, game, 0)
    end
    
    -- Проверка на заполненность рюкзака
    local function isBackpackFull()
        local inventory = player.PlayerGui:FindFirstChild("Inventory") or 
                          player.PlayerGui:FindFirstChild("Backpack") or
                          player.PlayerGui:FindFirstChild("HUD")
        
        if inventory then
            local backpackBar = inventory:FindFirstChild("BackpackBar") or
                               inventory:FindFirstChild("PollinationBar") or
                               inventory:FindFirstChild("BackpackFill")
            
            if backpackBar and backpackBar:IsA("Frame") then
                local fillFrame = backpackBar:FindFirstChild("Fill")
                if fillFrame and fillFrame:IsA("Frame") then
                    if fillFrame.Size.X.Scale > 0.95 then
                        return true
                    end
                end
            end
        end
        
        local stats = player:FindFirstChild("leaderstats") or player:FindFirstChild("Stats")
        if stats then
            local backpackStat = stats:FindFirstChild("Backpack") or 
                                stats:FindFirstChild("Inventory") or
                                stats:FindFirstChild("Pollen")
            if backpackStat and backpackStat.Value then
                if backpackStat.Value > 95 then
                    return true
                end
            end
        end
        
        return false
    end
    
    -- Функция телепортации на спавн
    local function teleportToSpawn()
        if not spawnPosition then
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                spawnPosition = player.Character.HumanoidRootPart.Position
            else
                return
            end
        end
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local rootPart = player.Character.HumanoidRootPart
            
            if humanoid and humanoid.Health > 0 then
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local goal = {CFrame = CFrame.new(spawnPosition)}
                local tween = TweenService:Create(rootPart, tweenInfo, goal)
                tween:Play()
                tween.Completed:Wait()
                task.wait(0.2)
            end
        end
    end
    
    -- Проверка на наличие объектов для копания
    local function isDiggable(obj)
        if not obj:IsA("BasePart") then return false end
        if obj.Transparency > 0.9 then return false end
        
        local name = obj.Name:lower()
        
        local firstChars = name:sub(1, 4)
        if firstChars == "moun" or firstChars == "dig" or firstChars == "hole" or firstChars == "dirt" then
            return true
        end
        
        local keywords = {"mound", "dig", "hole", "hill", "dirt", "beetle", "spider", "ant", "bug", "crack"}
        for _, keyword in ipairs(keywords) do
            if name:find(keyword, 1, true) then
                return true
            end
        end
        
        return false
    end
    
    -- Трекер объектов
    local function setupObjectTracker()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isDiggable(obj) then
                diggableObjects[obj] = true
            end
        end
        
        workspace.DescendantAdded:Connect(function(obj)
            if isDiggable(obj) then
                diggableObjects[obj] = true
            end
        end)
        
        workspace.DescendantRemoving:Connect(function(obj)
            diggableObjects[obj] = nil
        end)
    end
    
    -- Главная функция
    local function startDigging()
        local heartbeatConn = RunService.Heartbeat:Connect(function()
            if not digging then return end
            
            if autoTeleport and isBackpackFull() and not backpackFull then
                backpackFull = true
                task.spawn(function()
                    local wasDigging = digging
                    digging = false
                    teleportToSpawn()
                    digging = wasDigging
                    backpackFull = false
                end)
                return
            end
            
            local objectsToClick = {}
            local character = player.Character
            
            if not character then return end
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end
            
            for obj, _ in pairs(diggableObjects) do
                if obj and obj.Parent then
                    local distance = (obj.Position - rootPart.Position).Magnitude
                    if distance < 80 then
                        local screenPos = getScreenPosition(obj)
                        if screenPos then
                            table.insert(objectsToClick, {obj = obj, pos = screenPos, dist = distance})
                        end
                    end
                else
                    diggableObjects[obj] = nil
                end
            end
            
            table.sort(objectsToClick, function(a, b) return a.dist < b.dist end)
            
            for _, data in ipairs(objectsToClick) do
                if digging then
                    clickAtPosition(data.pos)
                    task.wait(digDelay)
                else
                    break
                end
            end
        end)
        
        return heartbeatConn
    end
    
    -- Создание меню
    local function createUI()
        local oldGui = player.PlayerGui:FindFirstChild("AutoDigGUI")
        if oldGui then oldGui:Destroy() end
        
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "AutoDigGUI"
        screenGui.Parent = player:WaitForChild("PlayerGui")
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 300, 0, 250)
        mainFrame.Position = UDim2.new(0.5, -150, 0.5, -125)
        mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        mainFrame.Parent = screenGui
        
        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1, 0, 0, 35)
        titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        titleBar.BorderSizePixel = 0
        titleBar.Parent = mainFrame
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 1, 0)
        title.BackgroundTransparency = 1
        title.Text = "🐝 BEE FARM MANAGER 🐝"
        title.TextColor3 = Color3.fromRGB(255, 215, 0)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Parent = titleBar
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -35, 0, 2.5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.TextScaled = true
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.BorderSizePixel = 0
        closeBtn.Parent = titleBar
        
        closeBtn.MouseButton1Click:Connect(function()
            screenGui:Destroy()
        end)
        
        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, -20, 1, -45)
        content.Position = UDim2.new(0, 10, 0, 40)
        content.BackgroundTransparency = 1
        content.Parent = mainFrame
        
        local digTitle = Instance.new("TextLabel")
        digTitle.Size = UDim2.new(1, 0, 0, 25)
        digTitle.Position = UDim2.new(0, 0, 0, 0)
        digTitle.Text = "⚡ AUTO DIG SETTINGS"
        digTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        digTitle.TextScaled = true
        digTitle.Font = Enum.Font.GothamBold
        digTitle.BackgroundTransparency = 1
        digTitle.TextXAlignment = Enum.TextXAlignment.Left
        digTitle.Parent = content
        
        local digButton = Instance.new("TextButton")
        digButton.Size = UDim2.new(0.7, 0, 0, 35)
        digButton.Position = UDim2.new(0, 0, 0, 30)
        digButton.Text = "🔴 AUTO DIG OFF"
        digButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        digButton.TextScaled = true
        digButton.Font = Enum.Font.Gotham
        digButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        digButton.BorderSizePixel = 2
        digButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
        digButton.Parent = content
        
        local speedLabel = Instance.new("TextLabel")
        speedLabel.Size = UDim2.new(0.25, 0, 0, 35)
        speedLabel.Position = UDim2.new(0.75, 0, 0, 30)
        speedLabel.Text = "0.15s"
        speedLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        speedLabel.TextScaled = true
        speedLabel.Font = Enum.Font.Gotham
        speedLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        speedLabel.BorderSizePixel = 2
        speedLabel.BorderColor3 = Color3.fromRGB(100, 100, 100)
        speedLabel.Parent = content
        
        local speedUp = Instance.new("TextButton")
        speedUp.Size = UDim2.new(0.25, 0, 0, 20)
        speedUp.Position = UDim2.new(0.75, 0, 0, 70)
        speedUp.Text = "▲"
        speedUp.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedUp.TextScaled = true
        speedUp.Font = Enum.Font.Gotham
        speedUp.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        speedUp.BorderSizePixel = 2
        speedUp.BorderColor3 = Color3.fromRGB(100, 100, 100)
        speedUp.Parent = content
        
        local speedDown = Instance.new("TextButton")
        speedDown.Size = UDim2.new(0.25, 0, 0, 20)
        speedDown.Position = UDim2.new(0.75, 0, 0, 95)
        speedDown.Text = "▼"
        speedDown.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedDown.TextScaled = true
        speedDown.Font = Enum.Font.Gotham
        speedDown.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        speedDown.BorderSizePixel = 2
        speedDown.BorderColor3 = Color3.fromRGB(100, 100, 100)
        speedDown.Parent = content
        
        local separator = Instance.new("Frame")
        separator.Size = UDim2.new(1, 0, 0, 2)
        separator.Position = UDim2.new(0, 0, 0, 125)
        separator.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        separator.BorderSizePixel = 0
        separator.Parent = content
        
        local teleportTitle = Instance.new("TextLabel")
        teleportTitle.Size = UDim2.new(1, 0, 0, 25)
        teleportTitle.Position = UDim2.new(0, 0, 0, 135)
        teleportTitle.Text = "🚀 AUTO TELEPORT"
        teleportTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        teleportTitle.TextScaled = true
        teleportTitle.Font = Enum.Font.GothamBold
        teleportTitle.BackgroundTransparency = 1
        teleportTitle.TextXAlignment = Enum.TextXAlignment.Left
        teleportTitle.Parent = content
        
        local teleportButton = Instance.new("TextButton")
        teleportButton.Size = UDim2.new(1, 0, 0, 35)
        teleportButton.Position = UDim2.new(0, 0, 0, 165)
        teleportButton.Text = "🟢 TELEPORT ON"
        teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        teleportButton.TextScaled = true
        teleportButton.Font = Enum.Font.Gotham
        teleportButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        teleportButton.BorderSizePixel = 2
        teleportButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
        teleportButton.Parent = content
        
        local spawnInfo = Instance.new("TextLabel")
        spawnInfo.Size = UDim2.new(1, 0, 0, 20)
        spawnInfo.Position = UDim2.new(0, 0, 0, 205)
        spawnInfo.Text = "Спавн: не запомнен"
        spawnInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
        spawnInfo.TextScaled = true
        spawnInfo.Font = Enum.Font.Gotham
        spawnInfo.BackgroundTransparency = 1
        spawnInfo.TextXAlignment = Enum.TextXAlignment.Left
        spawnInfo.Parent = content
        
        local setSpawnBtn = Instance.new("TextButton")
        setSpawnBtn.Size = UDim2.new(1, 0, 0, 25)
        setSpawnBtn.Position = UDim2.new(0, 0, 0, 225)
        setSpawnBtn.Text = "📍 ЗАПОМНИТЬ ТЕКУЩУЮ ПОЗИЦИЮ"
        setSpawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        setSpawnBtn.TextScaled = true
        setSpawnBtn.Font = Enum.Font.Gotham
        setSpawnBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 180)
        setSpawnBtn.BorderSizePixel = 2
        setSpawnBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
        setSpawnBtn.Parent = content
        
        local heartbeatConn = nil
        
        digButton.MouseButton1Click:Connect(function()
            digging = not digging
            
            if digging then
                digButton.Text = "🟢 AUTO DIG ON"
                digButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
                
                if not heartbeatConn then
                    heartbeatConn = startDigging()
                end
            else
                digButton.Text = "🔴 AUTO DIG OFF"
                digButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                
                if heartbeatConn then
                    heartbeatConn:Disconnect()
                    heartbeatConn = nil
                end
            end
        end)
        
        teleportButton.MouseButton1Click:Connect(function()
            autoTeleport = not autoTeleport
            
            if autoTeleport then
                teleportButton.Text = "🟢 TELEPORT ON"
                teleportButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
            else
                teleportButton.Text = "🔴 TELEPORT OFF"
                teleportButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            end
        end)
        
        setSpawnBtn.MouseButton1Click:Connect(function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                spawnPosition = player.Character.HumanoidRootPart.Position
                spawnInfo.Text = string.format("Спавн: X=%.1f Y=%.1f Z=%.1f", spawnPosition.X, spawnPosition.Y, spawnPosition.Z)
                
                setSpawnBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                task.wait(0.2)
                setSpawnBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 180)
            end
        end)
        
        speedUp.MouseButton1Click:Connect(function()
            digDelay = math.min(0.5, digDelay + 0.01)
            speedLabel.Text = string.format("%.2fs", digDelay)
        end)
        
        speedDown.MouseButton1Click:Connect(function()
            digDelay = math.max(0.05, digDelay - 0.01)
            speedLabel.Text = string.format("%.2fs", digDelay)
        end)
        
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            if input.KeyCode == Enum.KeyCode.F1 then
                mainFrame.Visible = not mainFrame.Visible
            elseif input.KeyCode == Enum.KeyCode.F2 then
                digging = not digging
                if digging then
                    digButton.Text = "🟢 AUTO DIG ON"
                    digButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
                    if not heartbeatConn then
                        heartbeatConn = startDigging()
                    end
                else
                    digButton.Text = "🔴 AUTO DIG OFF"
                    digButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                    if heartbeatConn then
                        heartbeatConn:Disconnect()
                        heartbeatConn = nil
                    end
                end
            end
        end)
    end
    
    -- Запуск всего
    setupObjectTracker()
    createUI()
    
    print("✅ Ultimate Farm Manager загружен!")
    print("📌 F1 - показать/скрыть меню")
    print("📌 F2 - быстрое вкл/выкл авто-копание")
end

-- Ждем, пока игрок полностью загрузится в игру
if player then
    if player.Character then
        loadFarmScript()
    else
        player.CharacterAdded:Connect(loadFarmScript)
    end
end
