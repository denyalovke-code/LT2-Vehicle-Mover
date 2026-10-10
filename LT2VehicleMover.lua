
--[[
    LT2 VEHICLE MOVER ULTIMATE
    Lumber Tycoon 2
    Единый русскоязычный хаб

    Вкладки:
    Главная | Машина | Визуал | Полёт

    Важно:
    Клиентское перемещение не гарантирует подтверждение сервером LT2.
]]

--==================================================
-- 1. СЛУЖБЫ И ЗАГРУЗКА
--==================================================

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local oldGui = game:GetService("CoreGui"):FindFirstChild("LT2VM_Ultimate")
if oldGui then
    oldGui:Destroy()
end

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not ok or not Rayfield then
    warn("[LT2VM] Не удалось загрузить Rayfield")
    return
end

local Window = Rayfield:CreateWindow({
    Name = "LT2 Vehicle Mover Ultimate",
    LoadingTitle = "LT2 Vehicle Mover",
    LoadingSubtitle = "Единый русскоязычный хаб",
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
-- 2. ВЫБОР ИГРОКА
--==================================================

local selectedPlayerName

local function getPlayerNames()
    local result = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(result, player.Name)
        end
    end

    table.sort(result)
    return result
end

local PlayerDropdown = MainTab:CreateDropdown({
    Name = "Выбрать игрока",
    Options = getPlayerNames(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(options)
        selectedPlayerName = options and options[1]
    end
})

local function refreshPlayers()
    task.defer(function()
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

Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(function(player)
    if player.Name == selectedPlayerName then
        selectedPlayerName = nil
    end
    refreshPlayers()
end)

local function getSelectedPlayer()
    if not selectedPlayerName then
        notify("Ошибка", "Сначала выбери игрока")
        return nil
    end

    local player = Players:FindFirstChild(selectedPlayerName)

    if not player then
        notify("Ошибка", "Игрок вышел с сервера")
        return nil
    end

    return player
end

--==================================================
-- 3. ОСВЕЩЕНИЕ
--==================================================

local originalClockTime = Lighting.ClockTime
local originalBrightness = Lighting.Brightness
local originalShadows = Lighting.GlobalShadows
local lightingMode = "День"
local shadowsDisabled = true
local lightingWorkerRunning = false

local function applyLighting()
    if lightingMode == "День" then
        Lighting.ClockTime = 14
        Lighting.Brightness = 3
        Lighting.GlobalShadows = not shadowsDisabled
    elseif lightingMode == "Ночь" then
        Lighting.ClockTime = 0
        Lighting.Brightness = 2
        Lighting.GlobalShadows = not shadowsDisabled
    else
        Lighting.ClockTime = originalClockTime
        Lighting.Brightness = originalBrightness
        Lighting.GlobalShadows = shadowsDisabled and false
            or originalShadows
    end
end

local function setLightingMode(mode)
    lightingMode = mode
    applyLighting()
    notify("Освещение", "Режим: " .. mode)
end

VisualTab:CreateDropdown({
    Name = "Время суток",
    Options = {"День", "Ночь", "Обычное"},
    CurrentOption = {"День"},
    MultipleOptions = false,
    Callback = function(options)
        setLightingMode(options and options[1] or "День")
    end
})

VisualTab:CreateToggle({
    Name = "Отключить тени",
    CurrentValue = true,
    Callback = function(value)
        shadowsDisabled = value
        applyLighting()
        notify("Тени", value and "Отключены" or "Включены")
    end
})

-- Не запускаем тяжёлый цикл каждый кадр.
-- Настройки периодически восстанавливаются, если игра их меняет.
if not lightingWorkerRunning then
    lightingWorkerRunning = true

    task.spawn(function()
        while task.wait(0.5) do
            if not LocalPlayer.Parent then
                break
            end

            if lightingMode ~= "Обычное" then
                pcall(applyLighting)
            end
        end
    end)
end

applyLighting()

--==================================================
-- 4. ТЕЛЕПОРТАЦИЯ ПЕРСОНАЖА
--==================================================

MainTab:CreateButton({
    Name = "Переместиться к выбранному игроку",
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
        notify("Телепортация", "Положение персонажа изменено")
    end
})

--==================================================
-- 5. ПОИСК МАШИНЫ
--==================================================

local function getVehicle()
    local character = getCharacter()
    if not character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart

    if not seat then
        return nil
    end

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
            notify("Машина", "Сядь на сиденье своей машины")
        end
    end
})

--==================================================
-- 6. ПОИСК УЧАСТКА
--==================================================

local plotWords = {
    "plot", "land", "slot", "claim",
    "tycoon", "property", "base",
    "участ", "земля"
}

local ownerWords = {
    "owner", "player", "userid",
    "user_id", "claimedby", "plotowner",
    "ownername"
}

local function containsAny(value, words)
    local text = string.lower(tostring(value or ""))

    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then
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

    if value == nil then
        return false
    end

    local text = string.lower(tostring(value))

    return text == string.lower(player.Name)
        or text == string.lower(player.DisplayName)
        or text == tostring(player.UserId)
end

local function hasOwnerInfo(object, player)
    for name, value in pairs(object:GetAttributes()) do
        if containsAny(name, ownerWords)
            and matchesPlayer(value, player) then
            return true
        end
    end

    for _, item in ipairs(object:GetChildren()) do
        if item:IsA("ValueBase")
            and containsAny(item.Name, ownerWords)
            and matchesPlayer(item, player) then
            return true
        end

        for name, value in pairs(item:GetAttributes()) do
            if containsAny(name, ownerWords)
                and matchesPlayer(value, player) then
                return true
            end
        end
    end

    return false
end

local function findPlayerPlot(player)
    local candidates = {}
    local ownedObjects = {}

    -- Сканируем один раз, чтобы уменьшить число обходов.
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Model") or object:IsA("Folder") then
            if hasOwnerInfo(object, player) then
                table.insert(ownedObjects, object)
            end

            if object:IsA("Model")
                and containsAny(object.Name, plotWords) then
                table.insert(candidates, object)
            end
        end
    end

    -- Ищем модель участка выше объекта с данными владельца.
    for _, owned in ipairs(ownedObjects) do
        local current = owned

        while current and current ~= workspace do
            if current:IsA("Model")
                and containsAny(current.Name, plotWords) then
                print(
                    "[LT2VM] Участок:",
                    current:GetFullName(),
                    "Игрок:",
                    player.Name
                )
                return current
            end

            current = current.Parent
        end
    end

    -- Проверяем кандидатов с подходящим названием.
    for _, model in ipairs(candidates) do
        for _, descendant in ipairs(model:GetDescendants()) do
            if hasOwnerInfo(descendant, player) then
                print("[LT2VM] Участок:", model:GetFullName())
                return model
            end
        end
    end

    warn(
        "[LT2VM] Участок не найден:",
        player.Name,
        "Моделей-кандидатов:",
        #candidates,
        "Объектов владельца:",
        #ownedObjects
    )

    for i, model in ipairs(candidates) do
        if i > 15 then break end
        print("[LT2VM] Кандидат:", model:GetFullName())
    end

    return nil
end

VehicleTab:CreateButton({
    Name = "Проверить поиск участков",
    Callback = function()
        task.spawn(function()
            local myPlot = findPlayerPlot(LocalPlayer)
            local target = getSelectedPlayer()

            if not target then return end

            local targetPlot = findPlayerPlot(target)

            notify(
                "Диагностика участков",
                "Мой: " .. (myPlot and "найден" or "не найден")
                .. " | Игрока: "
                .. (targetPlot and "найден" or "не найден")
                .. ". Подробности — в консоли."
            )
        end)
    end
})

--==================================================
-- 7. ПОИСК ПОДАРКОВ
--==================================================

local function isGiftName(name)
    name = string.lower(name)

    return name:find("gift", 1, true) ~= nil
        or name:find("present", 1, true) ~= nil
        or name:find("подар", 1, true) ~= nil
end

local function getPivot(object)
    if object:IsA("Model") then
        return object:GetPivot()
    elseif object:IsA("BasePart") then
        return object.CFrame
    end

    return nil
end

local function setPivot(object, cf)
    if object:IsA("Model") then
        object:PivotTo(cf)
    elseif object:IsA("BasePart") then
        object.CFrame = cf
    end
end

local function collectGifts(vehicle)
    local vehicleCF = vehicle:GetPivot()
    local boxCF, boxSize = vehicle:GetBoundingBox()
    local gifts = {}
    local seen = {}

    for _, object in ipairs(workspace:GetDescendants()) do
        if (object:IsA("Model") or object:IsA("BasePart"))
            and not object:IsDescendantOf(vehicle)
            and isGiftName(object.Name) then

            local cf = getPivot(object)

            if cf then
                local p = boxCF:PointToObjectSpace(cf.Position)

                local inside =
                    math.abs(p.X) <= boxSize.X / 2 + 2
                    and math.abs(p.Y) <= boxSize.Y / 2 + 2
                    and math.abs(p.Z) <= boxSize.Z / 2 + 2

                if inside and not seen[object] then
                    local parent = object.Parent
                    local nested = false

                    while parent and parent ~= workspace do
                        if parent:IsA("Model")
                            and isGiftName(parent.Name) then
                            nested = true
                            break
                        end
                        parent = parent.Parent
                    end

                    if not nested then
                        seen[object] = true

                        table.insert(gifts, {
                            object = object,
                            relative = vehicleCF:ToObjectSpace(cf)
                        })
                    end
                end
            end
        end
    end

    return gifts
end

--==================================================
-- 8. ПЕРЕНОС МАШИНЫ
--==================================================

VehicleTab:CreateButton({
    Name = "Перенести машину на участок игрока",
    Callback = function()
        local target = getSelectedPlayer()
        if not target then return end

        local vehicle = getVehicle()

        if not vehicle then
            notify("Ошибка", "Сначала сядь в машину")
            return
        end

        task.spawn(function()
            local successMove, err = pcall(function()
                notify("Поиск", "Определяю участки игроков...")

                local myPlot = findPlayerPlot(LocalPlayer)
                local targetPlot = findPlayerPlot(target)

                if not myPlot then
                    notify(
                        "Ошибка",
                        "Твой участок не найден. Нужна диагностика структуры LT2."
                    )
                    return
                end

                if not targetPlot then
                    notify(
                        "Ошибка",
                        "Участок игрока не найден. Проверь консоль."
                    )
                    return
                end

                local sourceCF = myPlot:GetPivot()
                local targetCF = targetPlot:GetPivot()
                local vehicleCF = vehicle:GetPivot()

                -- Сохраняем позицию и ориентацию относительно участка.
                local relativeVehicle = sourceCF:ToObjectSpace(vehicleCF)
                local destination = targetCF * relativeVehicle

                local gifts = collectGifts(vehicle)

                vehicle:PivotTo(destination)

                for _, gift in ipairs(gifts) do
                    if gift.object and gift.object.Parent then
                        pcall(function()
                            setPivot(
                                gift.object,
                                destination * gift.relative
                            )
                        end)
                    end
                end

                notify(
                    "Запрос выполнен",
                    "Подарков распознано: " .. #gifts
                    .. ". Проверь, принял ли сервер перемещение."
                )
            end)

            if not successMove then
                warn("[LT2VM] Ошибка переноса:", err)
                notify("Ошибка переноса", tostring(err))
            end
        end)
    end
})

--==================================================
-- 9. ПОИСК ОБЪЕКТОВ
--==================================================

VehicleTab:CreateInput({
    Name = "Поиск объекта",
    PlaceholderText = "Tree, Log, Gift...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if not text or text == "" then return end

        local count = 0
        local query = string.lower(text)

        for _, object in ipairs(workspace:GetDescendants()) do
            if (object:IsA("Model") or object:IsA("BasePart"))
                and string.find(
                    string.lower(object.Name),
                    query,
                    1,
                    true
                ) then
                count += 1
            end
        end

        notify("Поиск", "Найдено совпадений: " .. count)
    end
})

--==================================================
-- 10. ПОЛЁТ
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
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "LTVM_Gyro"
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 1e5
    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
    bodyGyro.Parent = root

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying or not root.Parent
            or not bodyVelocity or not bodyGyro then
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

    notify("Полёт", "WASD — движение, Space — вверх, Ctrl — вниз")
end

FlightTab:CreateSlider({
    Name = "Скорость полёта",
    Range = {135, 350},
    Increment = 5,
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

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.Q then
        if flying then
            stopFlight()
        else
            startFlight()
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if flying then
        stopFlight(true)
    end
end)

notify("LT2 Vehicle Mover Ultimate", "Хаб загружен")
