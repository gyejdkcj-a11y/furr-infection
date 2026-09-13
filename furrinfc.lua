--[[
    FUR INFECTION HUB v1.0  |  Rayfield Edition
    Auto Hit • Aimbot • Hitbox Calc • Target Selector
    RightShift = скрыть/показать
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UIS              = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LP               = Players.LocalPlayer
local Cam              = workspace.CurrentCamera

-- ══ CONFIG ══════════════════════════════════
local Cfg = {
    -- Aimbot
    Aimbot       = false,
    AimKey       = "Q",
    FOV          = 160,
    Smooth       = 0.15,
    HitPart      = "HumanoidRootPart",
    ShowFOV      = true,
    Prediction   = 0.08,
    -- Auto Hit
    AutoHit      = false,
    HitRange     = 8,
    HitCooldown  = 0.35,
    HitPart2     = "HumanoidRootPart",
    -- Hitbox Expand
    HitboxExpand = false,
    HitboxSize   = 6,
    -- Target Lock
    TargetLock   = false,
    LockedTarget = nil,
    -- ESP
    ESP          = false,
    BoxESP       = true,
    HealthBar    = true,
    DistESP      = true,
    NameESP      = true,
    SkeletonESP  = false,
    -- Team detection
    EnemyTeam    = "Furries", -- автодетект ниже
}

-- ══ ENEMY TEAM DETECT ═══════════════════════
-- Fur Infection использует Team objects
local function GetEnemyTeam()
    local myTeam = LP.Team
    for _, team in pairs(game:GetService("Teams"):GetTeams()) do
        if team ~= myTeam then return team end
    end
    return nil
end

local function IsEnemy(player)
    if player == LP then return false end
    if Cfg.TargetLock and Cfg.LockedTarget then
        return player == Cfg.LockedTarget
    end
    local enemyTeam = GetEnemyTeam()
    if enemyTeam then return player.Team == enemyTeam end
    -- fallback: если нет Team system, все враги
    return player.Team ~= LP.Team
end

local function GetEnemies()
    local list = {}
    for _, pl in pairs(Players:GetPlayers()) do
        if IsEnemy(pl) then
            local ch  = pl.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if ch and hum and hum.Health > 0 then
                table.insert(list, pl)
            end
        end
    end
    return list
end

-- ══ HITBOX EXPAND ═══════════════════════════
local HitboxCache = {}

local function ExpandHitboxes(player, size)
    if not player.Character then return end
    for _, part in pairs(player.Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if not HitboxCache[part] then
                HitboxCache[part] = part.Size
            end
            part.Size = Vector3.new(size, size, size)
            part.Transparency = 0.5
        end
    end
end

local function RestoreHitboxes(player)
    if not player.Character then return end
    for _, part in pairs(player.Character:GetDescendants()) do
        if part:IsA("BasePart") and HitboxCache[part] then
            part.Size = HitboxCache[part]
            part.Transparency = part.Name == "HumanoidRootPart" and 1 or 0
        end
    end
end

RunService.RenderStepped:Connect(function()
    if Cfg.HitboxExpand then
        for _, pl in pairs(GetEnemies()) do
            ExpandHitboxes(pl, Cfg.HitboxSize)
        end
    else
        for _, pl in pairs(Players:GetPlayers()) do
            RestoreHitboxes(pl)
        end
        HitboxCache = {}
    end
end)

-- ══ HITBOX CALC (реальный размер модели) ════
local function GetModelHitbox(character)
    if not character then return Vector3.new(2,5,2) end
    local parts = {}
    local minV  = Vector3.new(math.huge,math.huge,math.huge)
    local maxV  = Vector3.new(-math.huge,-math.huge,-math.huge)
    for _, p in pairs(character:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            local pos  = p.Position
            local half = p.Size/2
            minV = Vector3.new(
                math.min(minV.X, pos.X-half.X),
                math.min(minV.Y, pos.Y-half.Y),
                math.min(minV.Z, pos.Z-half.Z))
            maxV = Vector3.new(
                math.max(maxV.X, pos.X+half.X),
                math.max(maxV.Y, pos.Y+half.Y),
                math.max(maxV.Z, pos.Z+half.Z))
        end
    end
    return maxV - minV
end

-- ══ DRAWING ═════════════════════════════════
local Pool = {}
local BoneLinks = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"LowerTorso","LeftUpperLeg"},{"LowerTorso","RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"RightUpperLeg","RightLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},{"RightLowerLeg","RightFoot"},
    {"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"RightUpperArm","RightLowerArm"},
    {"LeftLowerArm","LeftHand"},{"RightLowerArm","RightHand"},
}

local function D(t, p)
    local o = Drawing.new(t)
    for k,v in pairs(p) do o[k]=v end
    return o
end

local function MkESP(pl)
    if pl == LP then return end
    local bones = {}
    for i=1,14 do
        bones[i] = D("Line",{Visible=false,Thickness=1,Color=Color3.fromRGB(255,100,50)})
    end
    Pool[pl] = {
        BoxOL = D("Square",{Visible=false,Thickness=3,Color=Color3.new(0,0,0),Filled=false}),
        Box   = D("Square",{Visible=false,Thickness=1.5,Filled=false,Color=Color3.fromRGB(255,80,80)}),
        Name  = D("Text",  {Visible=false,Size=13,Color=Color3.new(1,1,1),Outline=true,OutlineColor=Color3.new(0,0,0),Center=true,Font=Drawing.Fonts.UI}),
        HPbg  = D("Square",{Visible=false,Thickness=1,Color=Color3.new(0,0,0),Filled=true}),
        HP    = D("Square",{Visible=false,Thickness=1,Filled=true,Color=Color3.fromRGB(80,210,115)}),
        Dist  = D("Text",  {Visible=false,Size=10,Color=Color3.fromRGB(255,200,60),Outline=true,OutlineColor=Color3.new(0,0,0),Center=true,Font=Drawing.Fonts.UI}),
        Lock  = D("Circle",{Visible=false,Thickness=2,NumSides=32,Color=Color3.fromRGB(255,60,60),Filled=false,Radius=20}),
        Bones = bones,
    }
end

local function KillESP(pl)
    if Pool[pl] then
        for _, o in pairs(Pool[pl]) do
            if type(o)=="table" then for _,b in pairs(o) do if b and b.Remove then b:Remove() end end
            elseif o and o.Remove then o:Remove() end
        end
        Pool[pl] = nil
    end
end

local function HideObj(o)
    if not o then return end
    for _,v in pairs(o) do
        if type(v)=="table" then for _,b in pairs(v) do if b then b.Visible=false end end
        elseif v then v.Visible=false end
    end
end

local function HPColor(h,m)
    local r=h/m
    return r>.6 and Color3.fromRGB(80,210,115) or r>.3 and Color3.fromRGB(255,185,50) or Color3.fromRGB(220,70,70)
end

local FOVC = D("Circle",{Visible=false,Thickness=1.5,NumSides=80,
    Color=Color3.fromRGB(255,120,80),Filled=false,Radius=160})

local function UpdESP()
    for _, pl in pairs(Players:GetPlayers()) do
        if pl == LP then continue end
        if not Pool[pl] then MkESP(pl) end
        local o  = Pool[pl]
        local ch = pl.Character
        local enemy = IsEnemy(pl)

        if not Cfg.ESP or not ch or not enemy then HideObj(o) continue end

        local root = ch:FindFirstChild("HumanoidRootPart")
        local head = ch:FindFirstChild("Head")
        local hum  = ch:FindFirstChildOfClass("Humanoid")
        if not root or not head or not hum or hum.Health <= 0 then HideObj(o) continue end

        -- use real model hitbox size
        local modelSize = GetModelHitbox(ch)

        local tp,tv = Cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y/2+.1, 0))
        local bp,_  = Cam:WorldToViewportPoint(root.Position - Vector3.new(0, modelSize.Y/2+.2, 0))
        if not tv then HideObj(o) continue end

        local t2   = Vector2.new(tp.X, tp.Y)
        local b2   = Vector2.new(bp.X, bp.Y)
        local h    = math.abs(b2.Y - t2.Y)
        -- scale box width by actual model width
        local wScale = math.clamp(modelSize.X / 2, 0.4, 1.2)
        local w    = h * wScale
        local dist = (Cam.CFrame.Position - root.Position).Magnitude

        -- BOX
        if Cfg.BoxESP then
            local bx,by = t2.X-w/2, t2.Y
            o.BoxOL.Position=Vector2.new(bx-1,by-1) o.BoxOL.Size=Vector2.new(w+2,h+2) o.BoxOL.Visible=true
            o.Box.Position=Vector2.new(bx,by) o.Box.Size=Vector2.new(w,h)
            o.Box.Color = (pl == Cfg.LockedTarget) and Color3.fromRGB(255,220,50) or Color3.fromRGB(255,80,80)
            o.Box.Visible=true
        else o.Box.Visible=false o.BoxOL.Visible=false end

        -- NAME
        if Cfg.NameESP then
            o.Name.Position=Vector2.new(t2.X,t2.Y-18)
            o.Name.Text=pl.DisplayName
            o.Name.Visible=true
        else o.Name.Visible=false end

        -- HP BAR
        if Cfg.HealthBar then
            local bx2=t2.X-w/2-7 local ratio=math.clamp(hum.Health/hum.MaxHealth,0,1)
            o.HPbg.Position=Vector2.new(bx2,t2.Y) o.HPbg.Size=Vector2.new(4,h) o.HPbg.Visible=true
            o.HP.Position=Vector2.new(bx2,t2.Y+h*(1-ratio)) o.HP.Size=Vector2.new(4,h*ratio)
            o.HP.Color=HPColor(hum.Health,hum.MaxHealth) o.HP.Visible=true
        else o.HPbg.Visible=false o.HP.Visible=false end

        -- DISTANCE
        if Cfg.DistESP then
            o.Dist.Position=Vector2.new(t2.X,b2.Y+3)
            o.Dist.Text=string.format("%.0fm",dist) o.Dist.Visible=true
        else o.Dist.Visible=false end

        -- SKELETON
        if Cfg.SkeletonESP then
            local links = ch:FindFirstChild("UpperTorso") and BoneLinks
                or {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
            for i, link in ipairs(links) do
                local p1=ch:FindFirstChild(link[1]) local p2=ch:FindFirstChild(link[2])
                local bone=o.Bones[i]
                if bone then
                    if p1 and p2 then
                        local s1,v1=Cam:WorldToViewportPoint(p1.Position)
                        local s2,v2=Cam:WorldToViewportPoint(p2.Position)
                        if v1 and v2 then
                            bone.From=Vector2.new(s1.X,s1.Y)
                            bone.To=Vector2.new(s2.X,s2.Y)
                            bone.Color = (pl==Cfg.LockedTarget) and Color3.fromRGB(255,220,50)
                                        or Color3.fromRGB(255,100,50)
                            bone.Visible=true
                        else bone.Visible=false end
                    else bone.Visible=false end
                end
            end
        else for _,b in pairs(o.Bones) do if b then b.Visible=false end end end

        -- LOCK INDICATOR
        if pl == Cfg.LockedTarget then
            o.Lock.Position=Vector2.new(t2.X,t2.Y)
            local sp=Cam:WorldToViewportPoint(head.Position)
            o.Lock.Position=Vector2.new(sp.X,sp.Y)
            o.Lock.Visible=true
        else o.Lock.Visible=false end
    end
end

-- ══ AIMBOT ══════════════════════════════════
local function IsKey(k)
    local ok,kc=pcall(function() return Enum.KeyCode[k] end)
    return ok and kc and UIS:IsKeyDown(kc)
end

local function GetClosest()
    local best, bD = nil, Cfg.FOV
    local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    for _, pl in pairs(GetEnemies()) do
        local ch  = pl.Character if not ch then continue end
        local part = ch:FindFirstChild(Cfg.HitPart) or ch:FindFirstChild("HumanoidRootPart")
        local hum  = ch:FindFirstChildOfClass("Humanoid")
        if not part or not hum or hum.Health<=0 then continue end
        local sp,vis = Cam:WorldToViewportPoint(part.Position)
        if not vis then continue end
        local d = (Vector2.new(sp.X,sp.Y)-center).Magnitude
        if d < bD then bD=d best=pl end
    end
    return best
end

local function UpdAim()
    local vp = Cam.ViewportSize
    FOVC.Visible  = Cfg.Aimbot and Cfg.ShowFOV
    FOVC.Position = Vector2.new(vp.X/2, vp.Y/2)
    FOVC.Radius   = Cfg.FOV
    if not Cfg.Aimbot or not IsKey(Cfg.AimKey) then return end

    local tgt = Cfg.LockedTarget or GetClosest()
    if not tgt then return end
    local ch  = tgt.Character if not ch then return end
    local part = ch:FindFirstChild(Cfg.HitPart) or ch:FindFirstChild("HumanoidRootPart")
    if not part then return end

    local pred = part.Velocity * Cfg.Prediction
    local aimPos = part.Position + pred
    Cam.CFrame = Cam.CFrame:Lerp(
        CFrame.new(Cam.CFrame.Position, aimPos), 1-Cfg.Smooth)
end

-- ══ AUTO HIT (Kill Aura) ════════════════════
local lastHit = 0

local function UpdAutoHit()
    if not Cfg.AutoHit then return end
    local now = tick()
    if now - lastHit < Cfg.HitCooldown then return end

    local lpChar = LP.Character if not lpChar then return end
    local lpRoot = lpChar:FindFirstChild("HumanoidRootPart")
    if not lpRoot then return end

    -- find equipped tool
    local tool = LP.Character:FindFirstChildOfClass("Tool")

    local closest, closestDist = nil, Cfg.HitRange
    for _, pl in pairs(GetEnemies()) do
        local ch  = pl.Character if not ch then continue end
        local root = ch:FindFirstChild("HumanoidRootPart")
        local hum  = ch:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 then continue end
        local dist = (lpRoot.Position - root.Position).Magnitude
        if dist < closestDist then closestDist=dist closest=pl end
    end

    if not closest then return end
    local ch = closest.Character
    local targetPart = ch:FindFirstChild(Cfg.HitPart2)
                    or ch:FindFirstChild("HumanoidRootPart")
    if not targetPart then return end

    -- simulate click at target position
    if tool then
        -- face target
        local tCF = CFrame.new(lpRoot.Position, targetPart.Position)
        Cam.CFrame = CFrame.new(Cam.CFrame.Position, targetPart.Position)
        -- activate tool
        local remotes = tool:GetDescendants()
        for _, r in pairs(remotes) do
            if r:IsA("RemoteEvent") and
               (r.Name:lower():find("hit") or r.Name:lower():find("attack") or r.Name:lower():find("damage")) then
                r:FireServer(targetPart, targetPart.Position)
                break
            end
        end
        -- also try Tool:Activate
        pcall(function() tool:Activate() end)
    else
        -- no tool — try direct HitRemote scan in workspace remotes
        for _, r in pairs(workspace:GetDescendants()) do
            if r:IsA("RemoteEvent") and
               (r.Name:lower():find("hit") or r.Name:lower():find("damage")) then
                pcall(function() r:FireServer(closest, targetPart.Position) end)
            end
        end
    end
    lastHit = now
end

-- ══ RAYFIELD ════════════════════════════════
local R = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local W = R:CreateWindow({
    Name              = "FUR INFECTION HUB",
    LoadingTitle      = "FUR INFECTION HUB  v1.0",
    LoadingSubtitle   = "Auto Hit • Aimbot • Hitbox • ESP",
    Theme             = "Amethyst",
    DisableRayfieldPrompts  = false,
    DisableBuildWarnings    = true,
    ConfigurationSaving = {Enabled=true, FolderName="FurHub", FileName="cfg"},
})

-- ── 🎯 AIMBOT TAB ─────────────────────────
local AT = W:CreateTab("Аимбот","crosshair")
AT:CreateSection("Основное")
AT:CreateToggle({Name="Аимбот",CurrentValue=false,Flag="Aim",
    Callback=function(v) Cfg.Aimbot=v end})
AT:CreateToggle({Name="Показать FOV",CurrentValue=true,Flag="SFOV",
    Callback=function(v) Cfg.ShowFOV=v end})
AT:CreateSection("Настройки")
AT:CreateSlider({Name="FOV",Range={30,400},Increment=5,Suffix=" px",
    CurrentValue=160,Flag="FOV",Callback=function(v) Cfg.FOV=v end})
AT:CreateSlider({Name="Плавность",Range={1,30},Increment=1,CurrentValue=15,Flag="Smooth",
    Callback=function(v) Cfg.Smooth=v/100 end})
AT:CreateSlider({Name="Предсказание",Range={0,30},Increment=1,CurrentValue=8,Flag="Pred",
    Callback=function(v) Cfg.Prediction=v/100 end})
AT:CreateDropdown({Name="Часть тела",
    Options={"HumanoidRootPart","Head","UpperTorso","LowerTorso"},
    CurrentOption={"HumanoidRootPart"},Flag="HP",
    Callback=function(v) Cfg.HitPart=v[1] end})
AT:CreateKeybind({Name="Клавиша аима",CurrentKeybind="Q",
    HoldToInteract=false,Flag="AimKey",
    Callback=function(k) Cfg.AimKey=k end})

-- ── 👊 AUTO HIT TAB ───────────────────────
local HT = W:CreateTab("Авто Удар","zap")
HT:CreateSection("Kill Aura")
HT:CreateToggle({Name="Авто Удар",CurrentValue=false,Flag="AH",
    Callback=function(v) Cfg.AutoHit=v end})
HT:CreateSection("Настройки")
HT:CreateSlider({Name="Радиус",Range={3,50},Increment=1,Suffix=" st",
    CurrentValue=8,Flag="HR",Callback=function(v) Cfg.HitRange=v end})
HT:CreateSlider({Name="Задержка (сек×100)",Range={5,100},Increment=1,
    CurrentValue=35,Flag="HC",Callback=function(v) Cfg.HitCooldown=v/100 end})
HT:CreateDropdown({Name="Цель удара",
    Options={"HumanoidRootPart","Head","UpperTorso"},
    CurrentOption={"HumanoidRootPart"},Flag="HP2",
    Callback=function(v) Cfg.HitPart2=v[1] end})

-- ── 📦 HITBOX TAB ─────────────────────────
local BT = W:CreateTab("Хитбокс","box")
BT:CreateSection("Расширение хитбокса")
BT:CreateToggle({Name="Hitbox Expand",CurrentValue=false,Flag="HBE",
    Callback=function(v) Cfg.HitboxExpand=v end})
BT:CreateSlider({Name="Размер хитбокса",Range={2,20},Increment=1,Suffix=" st",
    CurrentValue=6,Flag="HBS",Callback=function(v) Cfg.HitboxSize=v end})
BT:CreateSection("Инфо о моделях")
BT:CreateButton({Name="Показать размер моделей фуррей",Callback=function()
    local info = ""
    for _, pl in pairs(GetEnemies()) do
        local sz = GetModelHitbox(pl.Character)
        info = info .. pl.DisplayName .. ": "
            .. string.format("%.1fx%.1fx%.1f\n", sz.X, sz.Y, sz.Z)
    end
    R:Notify({Title="Размеры фуррей",Content=info~="" and info or "Фурри не найдены",Duration=6,Image=4483362458})
end})

-- ── 🎯 TARGET TAB ─────────────────────────
local TGT = W:CreateTab("Цель","target")
TGT:CreateSection("Выбор цели")
TGT:CreateToggle({Name="Target Lock",CurrentValue=false,Flag="TL",
    Callback=function(v) Cfg.TargetLock=v if not v then Cfg.LockedTarget=nil end end})
TGT:CreateButton({Name="Заблокировать ближайшего фурри",Callback=function()
    local closest = GetClosest()
    if closest then
        Cfg.LockedTarget = closest
        Cfg.TargetLock   = true
        R:Notify({Title="Target Lock",Content="Цель: "..closest.DisplayName,Duration=3,Image=4483362458})
    else
        R:Notify({Title="Target Lock",Content="Фурри не найдены рядом",Duration=2,Image=4483362458})
    end
end})
TGT:CreateButton({Name="Сбросить цель",Callback=function()
    Cfg.LockedTarget=nil Cfg.TargetLock=false
    R:Notify({Title="Target Lock",Content="Цель сброшена",Duration=2,Image=4483362458})
end})
TGT:CreateSection("Список фуррей")
TGT:CreateButton({Name="Показать список фуррей",Callback=function()
    local list = ""
    for i, pl in pairs(GetEnemies()) do
        list = list .. i .. ". " .. pl.DisplayName .. "\n"
    end
    R:Notify({Title="Фурри онлайн",Content=list~="" and list or "Нет фуррей",Duration=5,Image=4483362458})
end})

-- ── 👁 ESP TAB ────────────────────────────
local ET = W:CreateTab("ESP","eye")
ET:CreateSection("ESP")
ET:CreateToggle({Name="Включить ESP",CurrentValue=false,Flag="ESP",
    Callback=function(v) Cfg.ESP=v end})
ET:CreateToggle({Name="Box ESP",CurrentValue=true,Flag="BESP",
    Callback=function(v) Cfg.BoxESP=v end})
ET:CreateToggle({Name="Скелет",CurrentValue=false,Flag="SESP",
    Callback=function(v) Cfg.SkeletonESP=v end})
ET:CreateToggle({Name="HP бар",CurrentValue=true,Flag="HBESP",
    Callback=function(v) Cfg.HealthBar=v end})
ET:CreateToggle({Name="Дистанция",CurrentValue=true,Flag="DESP",
    Callback=function(v) Cfg.DistESP=v end})
ET:CreateToggle({Name="Имена",CurrentValue=true,Flag="NESP",
    Callback=function(v) Cfg.NameESP=v end})

-- ── ℹ INFO ────────────────────────────────
local IT = W:CreateTab("Инфо","info")
IT:CreateSection("Управление")
IT:CreateLabel("🎯  Аимбот — Q (зажать)")
IT:CreateLabel("👊  Авто удар — авто по кулдауну")
IT:CreateLabel("🎯  Target Lock — фиксирует цель")
IT:CreateLabel("📦  Hitbox — расширяет хитбокс фуррей")
IT:CreateLabel("⌨  RightShift — скрыть/показать")
IT:CreateSection("Статус")
IT:CreateLabel("✅  FUR INFECTION HUB v1.0")
IT:CreateLabel("✅  Автодетект команды фуррей")
IT:CreateLabel("✅  Просчёт реального хитбокса модели")

-- ══ PLAYER EVENTS ═══════════════════════════
Players.PlayerAdded:Connect(MkESP)
Players.PlayerRemoving:Connect(function(pl)
    KillESP(pl)
    if Cfg.LockedTarget == pl then
        Cfg.LockedTarget = nil
        R:Notify({Title="Target Lost",Content="Цель вышла из игры",Duration=3,Image=4483362458})
    end
end)
for _, p in pairs(Players:GetPlayers()) do MkESP(p) end

-- ══ MAIN LOOP ═══════════════════════════════
RunService.RenderStepped:Connect(function()
    UpdESP()
    UpdAim()
end)

RunService.Heartbeat:Connect(function()
    UpdAutoHit()
end)

-- RightShift toggle
UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        -- Rayfield toggle built-in
    end
end)

R:Notify({
    Title   = "FUR INFECTION HUB",
    Content = "Загружено! Авто удар и аимбот готовы.",
    Duration = 5,
    Image   = 4483362458,
})
