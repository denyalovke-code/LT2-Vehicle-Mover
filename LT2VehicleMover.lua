
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Очистка предыдущего запуска
if _G.LT2VM_Cleanup then
    pcall(_G.LT2VM_Cleanup)
end

local alive = true
local connections = {}

local function keepConnection(connection)
    table.insert(connections, connection)
    return connection
end

-- Загрузка Rayfield
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not ok or not Rayfield then
    warn("[LT2VM] Не удалось загрузить Rayfield: " .. tostring(Rayfield))
    return
end

local Window = Rayfield:CreateWindow({
    Name = "LT2 Vehicle Mover Ultimate",
    LoadingTitle = "LT2 Vehicle Mover",
    LoadingSubtitle = "Оптимизированная русская версия",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Главная", 4483362458)
local VehicleTab = Window:CreateTab("Машина", 4483362458)
local VisualTab = Window:CreateTab("Визуал", 4483362458)
local FlightTab = Window:CreateTab("Полёт", 4483362458)

local function notify(title, message)
    pcall(function()
        Rayfield:Notify({
            Title = tostring(title),
            Content = tostring(message),
            Duration = 5
        })
    end)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

--==================================================
-- ИГРОКИ
--==================================================

local selectedPlayerName

local function getPlayerNames()
    local names = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end

    table.sort(names)
    return names
end

local PlayerDropdown = MainTab:CreateDropdown({
    Name = "Выбрать игрока",
    Options = getPlayerNames(),
    CurrentOption = {},
    MultipleOptions = false,

    Callback = function(options)
        selectedPlayerName = options and options[1] or nil
    end
})

local function refreshPlayers()
    task.defer(function()
        if not alive then return end

        pcall(function()
            PlayerDropdown:Refresh(getPlayerNames(), true)
        end)
    end)
end

MainTab:CreateButton({
    Name = "Обновить список игроков",

    Callback = function()
        refreshPlayers()
        notify("Игроки", "Список обновлён")
    end
})

keepConnection(Players.PlayerAdded:Connect(refreshPlayers))

keepConnection(Players.PlayerRemoving:Connect(function(player)
    if player.Name == selectedPlayerName then
        selectedPlayerName = nil
    end

    refreshPlayers()
end))

local function getSelectedPlayer()
    if not selectedPlayerName then
        notify("Ошибка", "Сначала выбери игрока")
        return nil
    end

    local player = Players:FindFirstChild(selectedPlayerName)

    if not player then
        notify("Ошибка", "Игрок уже вышел с сервера")
        return nil
    end

    return player
end

MainTab:CreateButton({
    Name = "Переместиться к игроку",

    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local targetRoot = getRoot(target.Character)
        local myRoot = getRoot(getCharacter())

        if not targetRoot or not myRoot then
            notify("Ошибка", "Персонаж ещё не загружен")
            return
        end

        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -5)
    end
})

--==================================================
-- ОСВЕЩЕНИЕ
--==================================================

local originalClockTime = Lighting.ClockTime
local originalTimeOfDay = Lighting.TimeOfDay
local originalBrightness = Lighting.Brightness
local originalGlobalShadows = Lighting.GlobalShadows

local lightingMode = "День"
local shadowsDisabled = true
local lightingApplying = false

local function applyLighting()
    if lightingApplying or not alive then return end

    lightingApplying = true

    pcall(function()
        if lightingMode == "День" then
            Lighting.ClockTime = 14
            Lighting.TimeOfDay = "14:00:00"
            Lighting.Brightness = 3

        elseif lightingMode == "Ночь" then
            Lighting.ClockTime = 0
            Lighting.TimeOfDay = "00:00:00"
            Lighting.Brightness = 2

        else
            Lighting.ClockTime = originalClockTime
            Lighting.TimeOfDay = originalTimeOfDay
            Lighting.Brightness = originalBrightness
        end

        if lightingMode == "Обычное" and not shadowsDisabled then
            Lighting.GlobalShadows = originalGlobalShadows
        else
            Lighting.GlobalShadows = not shadowsDisabled
        end
    end)

    lightingApplying = false
end

VisualTab:CreateDropdown({
    Name = "Время суток",
    Options = {"День", "Ночь", "Обычное"},
    CurrentOption = {"День"},
    MultipleOptions = false,

    Callback = function(options)
        lightingMode = options and options[1] or "День"
        applyLighting()
        notify("Освещение", "Режим: " .. lightingMode)
    end
})

VisualTab:CreateToggle({
    Name = "Отключить тени",
    CurrentValue = true,

    Callback = function(value)
        shadowsDisabled = value
        applyLighting()
    end
})

local function lightingNeedsCorrection()
    if lightingMode == "День" then
        return math.abs(Lighting.ClockTime - 14) > 0.1
            or Lighting.Brightness < 2.9

    elseif lightingMode == "Ночь" then
        return math.abs(Lighting.ClockTime) > 0.1
            or Lighting.Brightness < 1.9
    end

    return false
end

-- Если игра меняет время, повторно применяем выбранный режим.
keepConnection(
    Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
        if alive and not lightingApplying and lightingMode ~= "Обычное" then
            task.defer(function()
                if alive and lightingNeedsCorrection() then
                    applyLighting()
                end
            end)
        end
    end)
)

keepConnection(
    Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
        if alive and not lightingApplying and lightingMode ~= "Обычное" then
            task.defer(function()
                if alive and lightingNeedsCorrection() then
                    applyLighting()
                end
            end)
        end
    end)
)

keepConnection(
    Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
        if alive and not lightingApplying then
            task.defer(function()
                if not alive or lightingApplying then return end

                local expectedShadows

                if lightingMode == "Обычное" and not shadowsDisabled then
                    expectedShadows = originalGlobalShadows
                else
                    expectedShadows = not shadowsDisabled
                end

                if Lighting.GlobalShadows ~= expectedShadows then
                    applyLighting()
                end
            end)
        end
    end)
)

-- Резервная проверка раз в секунду, без постоянного цикла каждый кадр.
task.spawn(function()
    while alive and LocalPlayer.Parent do
        task.wait(1)

        if not alive then break end

        if lightingMode ~= "Обычное" then
            if lightingNeedsCorrection() then
                applyLighting()
            end
        else
            local expectedShadows

            if shadowsDisabled then
                expectedShadows = false
            else
                expectedShadows = originalGlobalShadows
            end

            if Lighting.GlobalShadows ~= expectedShadows then
                pcall(function()
                    Lighting.GlobalShadows = expectedShadows
                end)
            end
        end
    end
end)

applyLighting()

--==================================================
-- МАШИНА
--==================================================

local function getVehicle()
    local character = getCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart

    if not seat then return nil end

    local current = seat

    while current and current ~= workspace do
        if current:IsA("Model") then
            return current
        end

        current = current.Parent
    end

    return seat
end

VehicleTab:CreateButton({
    Name = "Найти мою машину",

    Callback = function()
        local vehicle = getVehicle()

        if vehicle then
            notify("Машина найдена", vehicle:GetFullName())
        else
            notify("Машина", "Сядь на водительское сиденье")
        end
    end
})

--==================================================
-- ПОИСК УЧАСТКА
--==================================================

local plotWords = {
    "plot", "land", "slot", "claim", "tycoon",
    "property", "base", "участ", "земля",
    "playerland", "playerplot"
}

local ownerWords = {
    "owner", "player", "userid", "user_id",
    "claimedby", "plotowner", "ownername",
    "ownerid", "claimed", "occupant"
}

local function containsAny(value, words)
    local lower = string.lower(tostring(value or ""))

    for _, word in ipairs(words) do
        if string.find(lower, word, 1, true) then
            return true
        end
    end

    return false
end

local function matchesPlayer(value, player)
    if typeof(value) == "Instance" then
        if value == player then
            return true
        end

        if value:IsA("ObjectValue") then
            value = value.Value

            if value == player then
                return true
            end

        elseif value:IsA("ValueBase") then
            value = value.Value
        else
            return false
        end
    end

    if value == nil then return false end

    local text = string.lower(tostring(value))

    return text == string.lower(player.Name)
        or text == string.lower(player.DisplayName)
        or text == tostring(player.UserId)
end

local function objectHasOwner(object, player)
    for name, value in pairs(object:GetAttributes()) do
        if containsAny(name, ownerWords) and matchesPlayer(value, player) then
            return true
        end
    end

    for _, child in ipairs(object:GetChildren()) do
        if child:IsA("ValueBase")
            and containsAny(child.Name, ownerWords)
            and matchesPlayer(child, player) then
            return true
        end

        for name, value in pairs(child:GetAttributes()) do
            if containsAny(name, ownerWords) and matchesPlayer(value, player) then
                return true
            end
        end
    end

    return false
end

local function findPlayerPlot(player, allObjects)
    local owned = {}
    local namedCandidates = {}

    for _, object in ipairs(allObjects) do
        if object:IsA("Model") or object:IsA("Folder") then
            if objectHasOwner(object, player) then
                table.insert(owned, object)
            end

            if object:IsA("Model") and containsAny(object.Name, plotWords) then
                table.insert(namedCandidates, object)
            end
        end
    end

    for _, object in ipairs(owned) do
        local current = object

        while current and current ~= workspace do
            if current:IsA("Model") and containsAny(current.Name, plotWords) then
                print("[LT2VM] Участок " .. player.Name .. ": " .. current:GetFullName())
                return current
            end

            current = current.Parent
        end
    end

    for _, model in ipairs(namedCandidates) do
        for _, descendant in ipairs(model:GetDescendants()) do
            if objectHasOwner(descendant, player) then
                print("[LT2VM] Участок " .. player.Name .. ": " .. model:GetFullName())
                return model
            end
        end
    end

    warn("[LT2VM] Участок не найден для " .. player.Name
        .. ". Кандидатов по названию: " .. #namedCandidates
        .. "; объектов с данными владельца: " .. #owned)

    for i, model in ipairs(namedCandidates) do
        if i > 12 then break end
        print("[LT2VM] Возможный участок: " .. model:GetFullName())
    end

    return nil
end

VehicleTab:CreateButton({
    Name = "Диагностика участков",

    Callback = function()
        task.spawn(function()
            notify("Диагностика", "Сканирую объекты игры...")

            local allObjects = workspace:GetDescendants()
            local mine = findPlayerPlot(LocalPlayer, allObjects)
            local target = getSelectedPlayer()

            if not target then return end

            local theirs = findPlayerPlot(target, allObjects)

            notify("Результат",
                "Мой участок: " .. (mine and "найден" or "не найден")
                .. " | Игрока: " .. (theirs and "найден" or "не найден")
                .. ". Подробности — в консоли.")
        end)
    end
})

--==================================================
-- ПОИСК ГРУЗА В МАШИНЕ
--==================================================

local itemNameHints = {
    "gift", "present", "подар", "axe", "топор",
    "box", "короб", "painting", "картина", "log",
    "wood", "plank", "доска", "wooden", "item",
    "tool", "crate", "cabin", "furniture"
}

local function getObjectPivot(object)
    if object:IsA("Model") then
        return object:GetPivot()
    elseif object:IsA("BasePart") then
        return object.CFrame
    end

    return nil
end

local function getObjectBounds(object)
    if object:IsA("Model") then
        local success, cf, size = pcall(function()
            return object:GetBoundingBox()
        end)

        if success then
            return cf, size
        end

    elseif object:IsA("BasePart") then
        return object.CFrame, object.Size
    end

    return nil, nil
end

local function hasUnanchoredPart(object)
    if object:IsA("BasePart") and not object.Anchored then
        return true
    end

    for _, descendant in ipairs(object:GetDescendants()) do
        if descendant:IsA("BasePart") and not descendant.Anchored then
            return true
        end
    end

    return false
end

local function hasItemName(object)
    return containsAny(object.Name, itemNameHints)
end

local function isCharacterModel(object)
    return object:IsA("Model")
        and object:FindFirstChildOfClass("Humanoid") ~= nil
end

local function collectCargo(vehicle, allObjects)
    local vehiclePivot = vehicle:GetPivot()
    local boxCF, boxSize = vehicle:GetBoundingBox()
    local cargo = {}
    local seen = {}

    allObjects = allObjects or workspace:GetDescendants()

    for _, object in ipairs(allObjects) do
        if (object:IsA("Model") or object:IsA("BasePart"))
            and object ~= vehicle
            and not object:IsDescendantOf(vehicle)
            and not isCharacterModel(object)
            and not seen[object] then

            local ancestor = object.Parent
            local nestedInModel = false

            while ancestor and ancestor ~= workspace do
                if ancestor == vehicle or ancestor:IsA("Model") then
                    nestedInModel = true
                    break
                end

                ancestor = ancestor.Parent
            end

            if not nestedInModel then
                local objectCF, objectSize = getObjectBounds(object)

                if objectCF and objectSize then
                    local localPos = boxCF:PointToObjectSpace(objectCF.Position)

                    local within =
                        math.abs(localPos.X) <= boxSize.X / 2 + 1.5
                        and math.abs(localPos.Y) <= boxSize.Y / 2 + 1.5
                        and math.abs(localPos.Z) <= boxSize.Z / 2 + 1.5

                    local reasonableSize =
                        objectSize.X <= boxSize.X + 4
                        and objectSize.Y <= boxSize.Y + 4
                        and objectSize.Z <= boxSize.Z + 4

                    local movable = hasUnanchoredPart(object)
                    local namedItem = hasItemName(object)

                    if within and reasonableSize and (movable or namedItem) then
                        seen[object] = true

                        local pivot = getObjectPivot(object)

                        if pivot then
                            table.insert(cargo, {
                                object = object,
                                relative = vehiclePivot:ToObjectSpace(pivot)
                            })
                        end
                    end
                end
            end
        end
    end

    return cargo
end

local function moveObjectTo(object, cf)
    if not object or not object.Parent then
        return false
    end

    return pcall(function()
        if object:IsA("Model") then
            object:PivotTo(cf)
        elseif object:IsA("BasePart") then
            object.CFrame = cf
        end
    end)
end

VehicleTab:CreateButton({
    Name = "Перенести машину и весь груз на участок",

    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local vehicle = getVehicle()

        if not vehicle then
            notify("Ошибка", "Сядь на сиденье машины перед переносом")
            return
        end

        task.spawn(function()
            local success, err = pcall(function()
                notify("Перенос", "Ищу участки и предметы в кузове...")

                local allObjects = workspace:GetDescendants()
                local sourcePlot = findPlayerPlot(LocalPlayer, allObjects)
                local targetPlot = findPlayerPlot(target, allObjects)

                if not sourcePlot then
                    notify("Участок не найден", "Запусти диагностику и проверь консоль")
                    return
                end

                if not targetPlot then
                    notify("Участок не найден", "Участок выбранного игрока не распознан")
                    return
                end

                local sourceCF = sourcePlot:GetPivot()
                local targetCF = targetPlot:GetPivot()
                local vehicleCF = vehicle:GetPivot()

                local relativeVehicle = sourceCF:ToObjectSpace(vehicleCF)
                local destination = targetCF * relativeVehicle

                local cargo = collectCargo(vehicle, allObjects)

                vehicle:PivotTo(destination)

                local moved = 0

                for _, entry in ipairs(cargo) do
                    if moveObjectTo(entry.object, destination * entry.relative) then
                        moved += 1
                    end
                end

                notify("Запрос выполнен",
                    "Предметов в кузове: " .. #cargo
                    .. "; запросов перемещения: " .. moved
                    .. ". Проверь, сохранил ли сервер результат.")
            end)

            if not success then
                warn("[LT2VM] Ошибка переноса: " .. tostring(err))
                notify("Ошибка переноса", tostring(err))
            end
        end)
    end
})

--==================================================
-- ПОИСК ПРЕДМЕТОВ ПО НАЗВАНИЮ
--==================================================

local searchQuery = ""

VehicleTab:CreateInput({
    Name = "Название предмета для поиска",
    PlaceholderText = "Например: Gift, Axe, Box",
    RemoveTextAfterFocusLost = false,

    Callback = function(value)
        searchQuery = tostring(value or "")
    end
})

VehicleTab:CreateButton({
    Name = "Найти предметы по названию",

    Callback = function()
        if searchQuery == "" then
            notify("Поиск", "Сначала введи название")
            return
        end

        task.spawn(function()
            local count = 0
            local query = string.lower(searchQuery)

            for _, object in ipairs(workspace:GetDescendants()) do
                if (object:IsA("Model") or object:IsA("BasePart"))
                    and string.find(string.lower(object.Name), query, 1, true) then
                    count += 1
                end
            end

            notify("Поиск", "Совпадений: " .. count)
        end)
    end
})

--==================================================
-- ПОЛЁТ
--==================================================

local flying = false
local flySpeed = 180
local flyConnection
local bodyVelocity
local bodyGyro

local function stopFlight(silent)
    flying = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end

    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end

    if not silent then
        notify("Полёт", "Выключен")
    end
end

local function startFlight()
    if flying then return end

    local character = getCharacter()
    local root = getRoot(character)

    if not root then
        notify("Полёт", "Персонаж не загружен")
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if humanoid and humanoid.SeatPart then
        notify("Полёт", "Сначала выйди из машины")
        return
    end

    flying = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "LTVM_Velocity"
    bodyVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "LTVM_Gyro"
    bodyGyro.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
    bodyGyro.P = 1e5
    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
    bodyGyro.Parent = root

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying or not root.Parent or not bodyVelocity or not bodyGyro then
            stopFlight(true)
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then return end

        local direction = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction += camera.CFrame.LookVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction -= camera.CFrame.LookVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction += camera.CFrame.RightVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction -= camera.CFrame.RightVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction += Vector3.yAxis
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            direction -= Vector3.yAxis
        end

        if direction.Magnitude > 0 then
            direction = direction.Unit
        end

        bodyVelocity.Velocity = direction * flySpeed
        bodyGyro.CFrame = camera.CFrame
    end)

    notify("Полёт", "WASD — движение; Space — вверх; Ctrl — вниз; Q — вкл./выкл.")
end

FlightTab:CreateSlider({
    Name = "Скорость полёта",
    Range = {50, 300},
    Increment = 10,
    Suffix = " speed",
    CurrentValue = 180,

    Callback = function(value)
        flySpeed = value
    end
})

FlightTab:CreateToggle({
    Name = "Полёт",
    CurrentValue = false,

    Callback = function(value)
        if value then
            startFlight()
        else
            stopFlight()
        end
    end
})

FlightTab:CreateParagraph({
    Title = "Управление",
    Content = "W/A/S/D — движение; Space — вверх; Left Ctrl — вниз; Q — переключение."
})

keepConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.Q then
        if flying then
            stopFlight()
        else
            startFlight()
        end
    end
end))

keepConnection(LocalPlayer.CharacterAdded:Connect(function()
    if flying then
        stopFlight(true)
    end
end))

--==================================================
-- ЗАВЕРШЕНИЕ И ОЧИСТКА
--==================================================

_G.LT2VM_Cleanup = function()
    alive = false
    stopFlight(true)

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    pcall(function()
        Lighting.ClockTime = originalClockTime
        Lighting.TimeOfDay = originalTimeOfDay
        Lighting.Brightness = originalBrightness
        Lighting.GlobalShadows = originalGlobalShadows
    end)

    pcall(function()
        Rayfield:Destroy()
    end)

    _G.LT2VM_Cleanup = nil
end

notify("LT2 Vehicle Mover Ultimate", "Хаб загружен")
