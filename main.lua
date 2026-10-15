-- making scripts sense 2020
-- enjoy the source made this for fun i was bored cheifin on my geekbar miami mint - sudo6 (@jn8g)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

if getgenv and getgenv().TTK_Unload then
    pcall(getgenv().TTK_Unload)
end

print("[TTK] Initializing core modules...")

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Connections = {}
local function registerConn(c)
    table.insert(Connections, c)
    return c
end

local controllers = RepStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers")
local GunController = nil
local BulletController = nil

pcall(function() GunController = require(controllers:WaitForChild("GunController")) end)
pcall(function() BulletController = require(controllers:WaitForChild("BulletController")) end)

local State = {
    Enabled = true,
    CurrentMaterial = Enum.Material.ForceField,
    Transparency = 0,

    WeaponColor = Color3.fromRGB(0, 255, 200),
    ArmColor = Color3.fromRGB(180, 50, 255),
    TracerColor = Color3.fromRGB(0, 255, 200),

    TracersEnabled = true,
    ImpactSparksEnabled = true,
    MuzzleLightEnabled = true,
    RainbowCycle = false,
    TracerWidth = 0.08,
    TracerLifetime = 0.25,

    RecoilDampener = 0,
    ZeroBloom = false,
    InstantADS = false,

    VmOffsetsEnabled = false,
    DisableOffsetOnADS = true,
    OffsetX = 0,
    OffsetY = 0,
    OffsetZ = 0,
    RollAngle = 0,

    Blacklist = {
        ["ArmsRootPart"] = true, ["RootPart"] = true, ["GunAttacher"] = true,
        ["MagAttacher"] = true, ["gun"] = true, ["gun.002"] = true, ["Casing"] = true,
        ["omeo3root"] = true, ["PointRearSight"] = true, ["PointFrontSight"] = true,
        ["RearSight"] = true, ["FrontSight"] = true, ["romeo5root"] = true,
        ["eotech_root"] = true, ["eotech553_root"] = true, ["acrop2_root"] = true
    },

    GlassPreserve = {
        ["omeo3glass"] = true,
        ["lens"] = true
    }
}

local GLOVE_SKINS = {
    "DesertTan", "DefaultBlack", "OliveDrab", "CoyoteTan", "Sahara", "RangerTan",
    "Khaki", "Sage", "Foliage", "DarkEarth", "LightGrey", "WolfGrey", "Plum",
    "Sandstorm", "BlackCamo", "GreenCamo", "GreenDigital", "GreenDigitalCoyoto",
    "Flecktarn", "M82"
}

local ignoreRoot = workspace:FindFirstChild("_CosmeticProjectiles") or workspace:FindFirstChild("Ignore") or workspace
local FX_CONTAINER = Instance.new("Folder")
FX_CONTAINER.Name = "TTK_FX_Storage"
FX_CONTAINER.Parent = ignoreRoot

local TRACER_POOL_SIZE = 20
local TracerPool = {}
local tracerIdx = 1

for i = 1, TRACER_POOL_SIZE do
    local p = Instance.new("Part")
    p.Name = "Tracer"
    p.Material = Enum.Material.Neon
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Transparency = 1
    p.Size = Vector3.new(0.01, 0.01, 1)
    p.CFrame = CFrame.new(0, -600, 0)
    p.Parent = FX_CONTAINER
    table.insert(TracerPool, p)
end

local IMPACT_POOL_SIZE = 12
local ImpactPool = {}
local impactIdx = 1

for i = 1, IMPACT_POOL_SIZE do
    local disc = Instance.new("Part")
    disc.Name = "ImpactRing"
    disc.Shape = Enum.PartType.Cylinder
    disc.Material = Enum.Material.Neon
    disc.Anchored = true
    disc.CanCollide = false
    disc.CanTouch = false
    disc.CanQuery = false
    disc.CastShadow = false
    disc.Transparency = 1
    disc.Size = Vector3.new(0.04, 0.1, 0.1)
    disc.CFrame = CFrame.new(0, -600, 0)
    disc.Parent = FX_CONTAINER
    table.insert(ImpactPool, disc)
end

local MuzzleAnchor = Instance.new("Part")
MuzzleAnchor.Name = "MuzzleAnchor"
MuzzleAnchor.Transparency = 1
MuzzleAnchor.Anchored = true
MuzzleAnchor.CanCollide = false
MuzzleAnchor.CanTouch = false
MuzzleAnchor.CanQuery = false
MuzzleAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
MuzzleAnchor.CFrame = CFrame.new(0, -600, 0)
MuzzleAnchor.Parent = FX_CONTAINER

local MuzzleLight = Instance.new("PointLight")
MuzzleLight.Range = 22
MuzzleLight.Brightness = 0
MuzzleLight.Shadows = false
MuzzleLight.Color = State.TracerColor
MuzzleLight.Parent = MuzzleAnchor

local CachedGunParts = {}
local CachedArmParts = {}
local activeRootMotor = nil

local function getActiveViewModel()
    for _, child in ipairs(camera:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("ArmsRootPart") then
            return child
        end
    end
    return nil
end

local function getRootMotor()
    if activeRootMotor and activeRootMotor.Parent and activeRootMotor.Part0 and activeRootMotor.Part1 then
        return activeRootMotor
    end

    local vm = getActiveViewModel()
    if not vm then return nil end

    for _, obj in ipairs(vm:GetDescendants()) do
        if obj:IsA("Motor6D") and obj.Part0 and obj.Part1 then
            if obj.Part0.Name == "RootPart" and obj.Part1.Name == "ArmsRootPart" then
                activeRootMotor = obj
                return activeRootMotor
            end
        end
    end
    return nil
end

local function applyVisuals()
    if not State.Enabled then return end

    local wCol = State.WeaponColor
    local aCol = State.ArmColor
    local mat = State.CurrentMaterial
    local trans = State.Transparency

    for i = 1, #CachedGunParts do
        local p = CachedGunParts[i]
        if p and p.Parent then
            p.Material = mat
            p.Color = wCol
            p.Transparency = trans
        end
    end

    for i = 1, #CachedArmParts do
        local p = CachedArmParts[i]
        if p and p.Parent then
            p.Material = mat
            p.Color = aCol
            p.Transparency = trans
        end
    end
end

local function parseViewModel(vm)
    table.clear(CachedGunParts)
    table.clear(CachedArmParts)
    activeRootMotor = nil

    if not vm or not vm:IsA("Model") then return end

    for _, obj in ipairs(vm:GetDescendants()) do
        local name = obj.Name

        if obj:IsA("Motor6D") and obj.Part0 and obj.Part1 then
            if obj.Part0.Name == "RootPart" and obj.Part1.Name == "ArmsRootPart" then
                activeRootMotor = obj
            end
        end

        if name == "omeo3glass" and obj:IsA("BasePart") then
            obj.Transparency = 0.95
            obj.Material = Enum.Material.SmoothPlastic
        elseif name == "lens" and obj:IsA("BasePart") then
            obj.Transparency = 1.00
            obj.Material = Enum.Material.ForceField
        end

        if not State.Blacklist[name] and not State.GlassPreserve[name] then
            if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                local sa = obj:FindFirstChildOfClass("SurfaceAppearance")
                if sa then pcall(function() sa:Destroy() end) end

                if obj:IsA("MeshPart") and obj.TextureID ~= "" then
                    obj.TextureID = ""
                end

                if string.sub(name, 1, 3) == "SK_" then
                    table.insert(CachedArmParts, obj)
                else
                    table.insert(CachedGunParts, obj)
                end
            end
        end
    end

    applyVisuals()
end

registerConn(camera.ChildAdded:Connect(function(child)
    if child:IsA("Model") then
        task.wait(0.08)
        if child:FindFirstChild("ArmsRootPart") then
            parseViewModel(child)
        end
    end
end))

local function bindCharacter(char)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.Died:Connect(function()
            table.clear(CachedGunParts)
            table.clear(CachedArmParts)
            activeRootMotor = nil
        end)
    end
end

if player.Character then bindCharacter(player.Character) end
registerConn(player.CharacterAdded:Connect(function(newChar)
    table.clear(CachedGunParts)
    table.clear(CachedArmParts)
    activeRootMotor = nil
    bindCharacter(newChar)
    task.wait(0.3)
    local vm = getActiveViewModel()
    if vm then parseViewModel(vm) end
end))

local function playImpactEffect(pos, normal)
    if not State.ImpactSparksEnabled then return end

    local disc = ImpactPool[impactIdx]
    impactIdx = (impactIdx % IMPACT_POOL_SIZE) + 1

    disc.Color = State.TracerColor
    disc.Size = Vector3.new(0.04, 0.2, 0.2)
    disc.CFrame = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, math.rad(90), 0)
    disc.Transparency = 0.1

    TweenService:Create(disc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.02, 1.4, 1.4),
        Transparency = 1
    }):Play()
end

local function emitPoolTracer()
    if not State.TracersEnabled then return end

    local origin
    if GunController and typeof(GunController.GetActiveProjectileMuzzleWorldCFrame) == "function" then
        origin = GunController:GetActiveProjectileMuzzleWorldCFrame().Position
    elseif GunController and typeof(GunController.GetMuzzleWorldPosition) == "function" then
        origin = GunController:GetMuzzleWorldPosition()
    else
        origin = camera.CFrame.Position + (camera.CFrame.RightVector * 0.7) - (camera.CFrame.UpVector * 0.4) + (camera.CFrame.LookVector * 1.5)
    end

    local direction
    if GunController and typeof(GunController.GetFireDirection) == "function" then
        direction = GunController:GetFireDirection().Unit * 1200
    else
        direction = camera.CFrame.LookVector * 1200
    end

    if State.MuzzleLightEnabled then
        MuzzleAnchor.Position = origin
        MuzzleLight.Color = State.TracerColor
        MuzzleLight.Brightness = 4.5
        task.delay(0.04, function()
            if MuzzleLight and MuzzleLight.Brightness > 0 then
                TweenService:Create(MuzzleLight, TweenInfo.new(0.06), { Brightness = 0 }):Play()
            end
        end)
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { camera, player.Character, FX_CONTAINER, ignoreRoot }

    local hit = workspace:Raycast(origin, direction, rayParams)
    local targetPos = hit and hit.Position or (origin + direction)
    local distance = (targetPos - origin).Magnitude

    if distance < 1 then return end

    local tracer = TracerPool[tracerIdx]
    tracerIdx = (tracerIdx % TRACER_POOL_SIZE) + 1

    tracer.Color = State.TracerColor
    tracer.Size = Vector3.new(State.TracerWidth, State.TracerWidth, distance)
    tracer.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -distance / 2)
    tracer.Transparency = 0

    TweenService:Create(tracer, TweenInfo.new(State.TracerLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.01, 0.01, distance)
    }):Play()

    if hit then
        playImpactEffect(hit.Position, hit.Normal)
    end
end

local originalGetBloomFraction = nil
local originalFireWeapon = nil

if GunController then
    if typeof(GunController.GetEffectiveBloomFraction) == "function" then
        originalGetBloomFraction = GunController.GetEffectiveBloomFraction
        GunController.GetEffectiveBloomFraction = function(...)
            if State.ZeroBloom then return 0 end
            return originalGetBloomFraction(...)
        end
    end

    if typeof(GunController.FireWeapon) == "function" then
        originalFireWeapon = GunController.FireWeapon
        GunController.FireWeapon = function(...)
            local results = { originalFireWeapon(...) }
            if State.TracersEnabled then
                task.defer(emitPoolTracer)
            end
            return unpack(results)
        end
    end
end

local rainbowTick = 0
registerConn(RunService.RenderStepped:Connect(function(dt)
    if GunController and GunController.CameraFX then
        local recoilScale = math.clamp(1.7 * (1 - State.RecoilDampener), 0, 1.7)
        if typeof(GunController.CameraFX.SetRecoilAttackScale) == "function" then
            GunController.CameraFX:SetRecoilAttackScale(recoilScale)
        end
    end

    if GunController and GunController._attachmentStats then
        if State.InstantADS then
            GunController._attachmentStats.AimSpeedMult = 3.5
        else
            GunController._attachmentStats.AimSpeedMult = 0.97
        end
    end

    local motor = getRootMotor()
    if motor then
        if State.VmOffsetsEnabled then
            local adsFactor = 0
            if GunController then
                if typeof(GunController.AimAmount) == "number" then
                    adsFactor = math.clamp(GunController.AimAmount, 0, 1)
                elseif GunController.Weapon and GunController.Weapon.IsAiming then
                    adsFactor = 1
                end
            end

            local mult = State.DisableOffsetOnADS and (1 - adsFactor) or 1
            if mult > 0.005 then
                motor.C0 = CFrame.new(
                    State.OffsetX * mult,
                    State.OffsetY * mult,
                    State.OffsetZ * mult
                ) * CFrame.Angles(0, 0, math.rad(State.RollAngle * mult))
            else
                motor.C0 = CFrame.new()
            end
        else
            motor.C0 = CFrame.new()
        end
    end

    if State.RainbowCycle and State.Enabled then
        rainbowTick = (rainbowTick + dt * 0.4) % 1
        local cycleColor = Color3.fromHSV(rainbowTick, 0.9, 1)
        State.WeaponColor = cycleColor
        State.TracerColor = cycleColor
        for i = 1, #CachedGunParts do
            local p = CachedGunParts[i]
            if p and p.Parent then p.Color = cycleColor end
        end
    end
end))

local function saveConfig()
    if not writefile then return end
    local data = {
        Enabled = State.Enabled,
        Material = tostring(State.CurrentMaterial.Name),
        Transparency = State.Transparency,
        WeaponColor = { State.WeaponColor.R, State.WeaponColor.G, State.WeaponColor.B },
        ArmColor = { State.ArmColor.R, State.ArmColor.G, State.ArmColor.B },
        TracerColor = { State.TracerColor.R, State.TracerColor.G, State.TracerColor.B },
        TracersEnabled = State.TracersEnabled,
        ImpactSparksEnabled = State.ImpactSparksEnabled,
        MuzzleLightEnabled = State.MuzzleLightEnabled,
        RecoilDampener = State.RecoilDampener,
        ZeroBloom = State.ZeroBloom,
        InstantADS = State.InstantADS,
        VmOffsetsEnabled = State.VmOffsetsEnabled,
        DisableOffsetOnADS = State.DisableOffsetOnADS,
        OffsetX = State.OffsetX,
        OffsetY = State.OffsetY,
        OffsetZ = State.OffsetZ,
        RollAngle = State.RollAngle
    }
    writefile("TTK_visuals_config.json", HttpService:JSONEncode(data))
    print("[TTK] Config saved.")
end

local function loadConfig()
    if not (readfile and isfile and isfile("TTK_visuals_config.json")) then return end
    local ok, raw = pcall(readfile, "TTK_visuals_config.json")
    if not ok then return end
    local parseOk, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not parseOk or type(data) ~= "table" then return end

    if data.Enabled ~= nil then State.Enabled = data.Enabled end
    if data.Material and Enum.Material[data.Material] then State.CurrentMaterial = Enum.Material[data.Material] end
    if data.Transparency ~= nil then State.Transparency = data.Transparency end
    if data.WeaponColor then State.WeaponColor = Color3.new(unpack(data.WeaponColor)) end
    if data.ArmColor then State.ArmColor = Color3.new(unpack(data.ArmColor)) end
    if data.TracerColor then State.TracerColor = Color3.new(unpack(data.TracerColor)) end
    if data.TracersEnabled ~= nil then State.TracersEnabled = data.TracersEnabled end
    if data.ImpactSparksEnabled ~= nil then State.ImpactSparksEnabled = data.ImpactSparksEnabled end
    if data.MuzzleLightEnabled ~= nil then State.MuzzleLightEnabled = data.MuzzleLightEnabled end
    if data.RecoilDampener ~= nil then State.RecoilDampener = data.RecoilDampener end
    if data.ZeroBloom ~= nil then State.ZeroBloom = data.ZeroBloom end
    if data.InstantADS ~= nil then State.InstantADS = data.InstantADS end
    if data.VmOffsetsEnabled ~= nil then State.VmOffsetsEnabled = data.VmOffsetsEnabled end
    if data.DisableOffsetOnADS ~= nil then State.DisableOffsetOnADS = data.DisableOffsetOnADS end
    if data.OffsetX ~= nil then State.OffsetX = data.OffsetX end
    if data.OffsetY ~= nil then State.OffsetY = data.OffsetY end
    if data.OffsetZ ~= nil then State.OffsetZ = data.OffsetZ end
    if data.RollAngle ~= nil then State.RollAngle = data.RollAngle end

    applyVisuals()
    print("[TTK] Config loaded.")
end

local Window = WindUI:CreateWindow({
    Title = "TTK self visuals - sudo6",
    Icon = "crosshair",
    Author = "sudo6",
    Folder = "TTK_Visuals",
    Size = UDim2.fromOffset(630, 510),
    Keybind = Enum.KeyCode.RightShift,
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 195,
    HasOutline = true
})

local Tabs = {
    Chams     = Window:Tab({ Title = "Chams & Optics", Icon = "sparkles" }),
    Viewmodel = Window:Tab({ Title = "Offsets", Icon = "move" }),
    Combat    = Window:Tab({ Title = "Combat Engine", Icon = "target" }),
    Tracers   = Window:Tab({ Title = "Ballistics", Icon = "zap" }),
    Colors    = Window:Tab({ Title = "Colors", Icon = "palette" }),
    Settings  = Window:Tab({ Title = "Config", Icon = "settings" })
}

Tabs.Chams:Section({ Title = "Visual Overrides" })

Tabs.Chams:Toggle({
    Title = "Enable Chams",
    Desc = "Applies custom materials and styling across weapon, scopes, and arms",
    Value = State.Enabled,
    Callback = function(val)
        State.Enabled = val
        applyVisuals()
    end
})

Tabs.Chams:Dropdown({
    Title = "Material Shader",
    Desc = "Select surface finish",
    Values = { "ForceField", "Neon", "Glass" },
    Value = "ForceField",
    Callback = function(val)
        State.CurrentMaterial = Enum.Material[val]
        applyVisuals()
    end
})

Tabs.Chams:Slider({
    Title = "Chams Transparency",
    Desc = "Mesh opacity",
    Step = 0.05,
    Value = { Min = 0, Max = 0.9, Default = State.Transparency },
    Callback = function(val)
        State.Transparency = val
        applyVisuals()
    end
})

Tabs.Chams:Section({ Title = "Glove Overrides" })

Tabs.Chams:Dropdown({
    Title = "Select Glove Model",
    Desc = "Client-side unlock for active glove textures",
    Values = GLOVE_SKINS,
    Value = "DesertTan",
    Callback = function(val)
        if GunController and typeof(GunController.SetEquippedGlove) == "function" then
            GunController:SetEquippedGlove(val)
            task.wait(0.05)
            local vm = getActiveViewModel()
            if vm then parseViewModel(vm) end
        end
    end
})

Tabs.Viewmodel:Section({ Title = "First-Person Alignments" })

Tabs.Viewmodel:Toggle({
    Title = "Enable Viewmodel Offsets",
    Desc = "Transform first-person model coordinates",
    Value = State.VmOffsetsEnabled,
    Callback = function(val)
        State.VmOffsetsEnabled = val
        local motor = getRootMotor()
        if not val and motor then
            motor.C0 = CFrame.new()
        end
    end
})

Tabs.Viewmodel:Toggle({
    Title = "ADS Auto-Center",
    Desc = "Zeroes offsets during aim-down-sight alignment",
    Value = State.DisableOffsetOnADS,
    Callback = function(val)
        State.DisableOffsetOnADS = val
    end
})

Tabs.Viewmodel:Slider({
    Title = "Horizontal (X)",
    Step = 0.05,
    Value = { Min = -1.2, Max = 1.2, Default = State.OffsetX },
    Callback = function(val) State.OffsetX = val end
})

Tabs.Viewmodel:Slider({
    Title = "Vertical (Y)",
    Step = 0.05,
    Value = { Min = -1.2, Max = 1.2, Default = State.OffsetY },
    Callback = function(val) State.OffsetY = val end
})

Tabs.Viewmodel:Slider({
    Title = "Depth (Z)",
    Step = 0.05,
    Value = { Min = -1.2, Max = 1.2, Default = State.OffsetZ },
    Callback = function(val) State.OffsetZ = val end
})

Tabs.Viewmodel:Slider({
    Title = "Weapon Cant (Roll)",
    Step = 1,
    Value = { Min = -35, Max = 35, Default = State.RollAngle },
    Callback = function(val) State.RollAngle = val end
})

Tabs.Combat:Section({ Title = "Spring Recoil Hooks" })

Tabs.Combat:Slider({
    Title = "Recoil Attack Scale",
    Desc = "Direct CameraFX spring suppression",
    Step = 0.05,
    Value = { Min = 0, Max = 1.0, Default = State.RecoilDampener },
    Callback = function(val)
        State.RecoilDampener = val
    end
})

Tabs.Combat:Toggle({
    Title = "Zero Spread / Bloom",
    Desc = "Forces GetEffectiveBloomFraction return value to 0",
    Value = State.ZeroBloom,
    Callback = function(val)
        State.ZeroBloom = val
    end
})

Tabs.Combat:Toggle({
    Title = "Fast ADS Transition",
    Desc = "Scales internal AimSpeedMult coefficient",
    Value = State.InstantADS,
    Callback = function(val)
        State.InstantADS = val
    end
})

Tabs.Combat:Section({ Title = "Weapon Attachments" })

Tabs.Combat:Toggle({
    Title = "Laser Pointer",
    Desc = "Engine-native laser emitter state",
    Value = false,
    Callback = function(val)
        if GunController and typeof(GunController.SetLaser) == "function" then
            GunController:SetLaser(val)
        end
    end
})

Tabs.Combat:Toggle({
    Title = "Flashlight",
    Desc = "Engine-native barrel illumination",
    Value = false,
    Callback = function(val)
        if GunController and typeof(GunController.ToggleFlashlight) == "function" then
            GunController:ToggleFlashlight()
        end
    end
})

Tabs.Tracers:Section({ Title = "Ballistic Tracers" })

Tabs.Tracers:Toggle({
    Title = "Enable Tracers",
    Desc = "Emits zero-allocation pooled laser lines on fire",
    Value = State.TracersEnabled,
    Callback = function(val) State.TracersEnabled = val end
})

Tabs.Tracers:Toggle({
    Title = "Surface Impact Discs",
    Desc = "Shockwave rings on geometry raycast intercept",
    Value = State.ImpactSparksEnabled,
    Callback = function(val) State.ImpactSparksEnabled = val end
})

Tabs.Tracers:Toggle({
    Title = "Dynamic Muzzle Flash",
    Desc = "Illuminates rooms on discharge",
    Value = State.MuzzleLightEnabled,
    Callback = function(val) State.MuzzleLightEnabled = val end
})

Tabs.Tracers:Slider({
    Title = "Beam Thickness",
    Step = 0.01,
    Value = { Min = 0.02, Max = 0.25, Default = State.TracerWidth },
    Callback = function(val) State.TracerWidth = val end
})

Tabs.Tracers:Slider({
    Title = "Beam Duration",
    Step = 0.02,
    Value = { Min = 0.08, Max = 0.5, Default = State.TracerLifetime },
    Callback = function(val) State.TracerLifetime = val end
})

Tabs.Tracers:Toggle({
    Title = "Rainbow Chroma Wave",
    Desc = "Real-time hue rotation across weapon and ballistics",
    Value = State.RainbowCycle,
    Callback = function(val)
        State.RainbowCycle = val
        if not val then applyVisuals() end
    end
})

Tabs.Colors:Section({ Title = "Color Palette" })

Tabs.Colors:Colorpicker({
    Title = "Chassis & Scope Finish",
    Default = State.WeaponColor,
    Callback = function(col)
        State.WeaponColor = col
        applyVisuals()
    end
})

Tabs.Colors:Colorpicker({
    Title = "Sleeve & Glove Finish",
    Default = State.ArmColor,
    Callback = function(col)
        State.ArmColor = col
        applyVisuals()
    end
})

Tabs.Colors:Colorpicker({
    Title = "Ballistics & Tracer Color",
    Default = State.TracerColor,
    Callback = function(col)
        State.TracerColor = col
    end
})

Tabs.Settings:Section({ Title = "Profile Management" })

Tabs.Settings:Button({
    Title = "Save Settings",
    Desc = "Writes profile to disk",
    Callback = function()
        saveConfig()
        WindUI:Notify({ Title = "Config", Content = "Saved profile to disk.", Duration = 2 })
    end
})

Tabs.Settings:Button({
    Title = "Load Settings",
    Desc = "Restores profile from disk",
    Callback = function()
        loadConfig()
        WindUI:Notify({ Title = "Config", Content = "Restored saved profile.", Duration = 2 })
    end
})

Tabs.Settings:Section({ Title = "Process Control" })

Tabs.Settings:Button({
    Title = "Terminate Script",
    Desc = "Restores engine state and unloads UI",
    Callback = function()
        if getgenv().TTK_Unload then
            getgenv().TTK_Unload()
        end
    end
})

local function unloadScript()
    for _, conn in ipairs(Connections) do
        if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
    end
    Connections = {}

    if originalFireWeapon and GunController then
        GunController.FireWeapon = originalFireWeapon
    end

    if originalGetBloomFraction and GunController then
        GunController.GetEffectiveBloomFraction = originalGetBloomFraction
    end

    if GunController and GunController.CameraFX and typeof(GunController.CameraFX.SetRecoilAttackScale) == "function" then
        GunController.CameraFX:SetRecoilAttackScale(1.7)
    end

    local motor = getRootMotor()
    if motor then motor.C0 = CFrame.new() end

    for i = 1, #CachedGunParts do
        local p = CachedGunParts[i]
        if p and p.Parent then
            p.Material = Enum.Material.SmoothPlastic
            p.Color = Color3.fromRGB(200, 200, 200)
            p.Transparency = 0
        end
    end

    for i = 1, #CachedArmParts do
        local p = CachedArmParts[i]
        if p and p.Parent then
            p.Material = Enum.Material.SmoothPlastic
            p.Color = Color3.fromRGB(200, 200, 200)
            p.Transparency = 0
        end
    end

    if FX_CONTAINER then pcall(function() FX_CONTAINER:Destroy() end) end

    pcall(function()
        local core = (gethui and gethui()) or game:GetService("CoreGui")
        for _, gui in ipairs(core:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name:find("WindUI") or gui.Name:find("TTK")) then
                gui:Destroy()
            end
        end
    end)

    print("[TTK] Core unloaded.")
end

if getgenv then getgenv().TTK_Unload = unloadScript end

registerConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        if Window and Window.Toggle then
            pcall(function() Window:Toggle() end)
        end
    end
end))

local initialVm = getActiveViewModel()
if initialVm then parseViewModel(initialVm) end

print("[TTK] Visual suite active.")
