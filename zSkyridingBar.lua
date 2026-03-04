-- zSkyridingBar - A standalone skyriding information addon

-- Initialize Ace addon
local zSkyridingBar = LibStub("AceAddon-3.0"):NewAddon("zSkyridingBar", "AceTimer-3.0")
local BuildVersion, BuildBuild, BuildDate, BuildInterface = GetBuildInfo()

local L = LibStub("AceLocale-3.0"):GetLocale("zSkyridingBar")
local LEM = LibStub("LibEditMode")

function zSkyridingBar.print(...)
    local args = { ... }
    DEFAULT_CHAT_FRAME:AddMessage("|cff0b808fzSkyridingBar:|r " .. table.concat(args, " "))
end

-- Constants
local ASCENT_SPELL_ID = 372610
local THRILL_BUFF_ID = 377234
local STATIC_CHARGE_BUFF_ID = 418590
local SURGE_FORWARD_SPELL_ID = 372608
local SECOND_WIND_SPELL_ID = 425782
local WHIRLING_SURGE_SPELL_ID = 361584 -- Whirling Surge ability
local LIGHTNING_RUSH_SPELL_ID = 418592 -- Lightning Rush ability
local SLOW_SKYRIDING_RATIO = 705 / 830
local ASCENT_DURATION = 3.5
local BAR_TICK_RATE = 1 / 15 -- seconds per tick for text/color/ability checks
local BAR_MULTIPLIER = 0.5

-- Second Wind constants
local SECOND_WIND_MAX_CHARGES = 3
local SECOND_WIND_RECHARGE_TIME = 180 -- 3 minutes

-- Whirling Surge constants
local WHIRLING_SURGE_COOLDOWN = 60 -- 60 second cooldown

-- Fast flying zones (where full speed is available)
local FAST_FLYING_ZONES = {
    [2444] = true, -- Dragon Isles
    [2454] = true, -- Zaralek Cavern
    [2548] = true, -- Emerald Dream
    [2516] = true, -- Nokhud Offensive
    [2522] = true, -- Vault of the Incarnates
    [2569] = true, -- Aberrus, the Shadowed Crucible
}

-- Speed thresholds (in yd/s) for color detection
local SLOW_ZONE_MAX_GLIDE = 55.2 -- Max gliding speed in normal zones (789%)
local FAST_ZONE_MAX_GLIDE = 65.0 -- Max gliding speed in Dragonflight zones (929%)

local CompatCheck = false

if BuildInterface <= 110205 then
    CompatCheck = true
    UIWidgetPowerBarContainerFrame = UIWidgetPowerBarContainerFrame
end

local function getDefaultTexture()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local textures = LSM:List("statusbar")
        for _, texture in ipairs(textures) do
            if texture == "Clean" then
                return "Clean"
            end
        end
        for _, texture in ipairs(textures) do
            if texture == "Solid" then
                return "Solid"
            end
        end
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

-- Default settings
local defaults = {
    profile = {
        enabled = true,
        speedShow = true,
        speedUnits = 2, -- 1 = yd/s, 2 = move%
        hideDefaultSpeedUI = true,

        -- Position settings
        masterMoveFramePoint = "CENTER",
        masterMoveFrameX = 0,
        masterMoveFrameY = -160,
        masterMoveFrameScales = {},
        singleFrameMode = true,
        speedBarX = 0,
        speedBarY = 0,
        chargesBarX = 0,
        chargesBarY = 0,
        speedAbilityX = -8,
        speedAbilityY = -4,
        secondWindX = 0,
        secondWindY = -32,
        -- Multi-frame mode: each frame anchored to UIParent independently
        multiSpeedBarPoint = "CENTER",
        multiSpeedBarX = 0,
        multiSpeedBarY = -150,
        multiChargesBarPoint = "CENTER",
        multiChargesBarX = 0,
        multiChargesBarY = -180,
        multiSpeedAbilityPoint = "CENTER",
        multiSpeedAbilityX = -148,
        multiSpeedAbilityY = -150,
        multiSecondWindPoint = "CENTER",
        multiSecondWindX = 0,
        multiSecondWindY = -210,
        multiSpeedBarScales = {},
        multiChargesBarScales = {},
        multiSpeedAbilityScales = {},
        multiSecondWindScales = {},
        frameStrata = "MEDIUM",

        -- Speed bar settings
        hideSpeedBar = false,
        hideChargeBar = false,
        hideSecondWindBar = false,
        hideSpeedAbility = false,
        speedBarWidth = 256,
        speedBarHeight = 28,
        speedBarTexture = getDefaultTexture(),
        speedBarBackgroundColor = { 0, 0, 0, 0.4 },
        speedBarNormalColor = { 0.749, 0.439, 0.173, 1 },
        speedBarThrillColor = { 0.482, 0.667, 1, 1 },
        speedBarBoostColor = { 0.314, 0.537, 0.157, 1 },

        -- Charge bar settings
        chargeBarWidth = 256,
        chargeBarHeight = 20,
        chargeBarSpacing = 0,
        speedIndicatorHeight = 30,
        chargeBarTexture = getDefaultTexture(),
        chargeBarBackgroundColor = { 0, 0, 0, 0.4 },
        chargeBarNormalRechargeColor = { 0.53, 0.29, 0.2, 1 },
        chargeBarFastRechargeColor = { 0.25, 0.9, 0.6, 1 },
        chargeBarFullColor = { 0.2, 0.5, 0.8, 1 },
        chargeBarBorderSize = 1,

        -- Speed indicator settings
        showSpeedIndicator = true,
        speedIndicatorColor = { 1, 1, 1, 1 },

        -- Second Wind bar settings
        secondWindBarWidth = 100,
        secondWindBarHeight = 18,
        secondWindBarTexture = getDefaultTexture(),
        secondWindNoChargeColor = { 0, 0, 0, 0.4 },        -- background for 0 charges
        secondWindOneChargeColor = { 0.53, 0.29, 0.2, 1 }, -- background for 1 charge, fill for charging to 1
        secondWindTwoChargeColor = { 0.25, 0.9, 0.6, 1 },  -- background for 2 charges, fill for charging to 2
        secondWindThreeChargeColor = { 0.2, 0.5, 0.8, 1 }, -- background for 3 charges, fill for charging to 3
        -- Speed ability settings
        showAbilityCooldownText = false,
        -- Whirling Surge settings
        whirlingSurgeSize = 40,
        whirlingSurgeTexture = getDefaultTexture(),

        -- Font settings
        fontSize = 13,
        fontFace = "Homespun",
        fontFlag = "OUTLINE",
        fontColor = { 1, 1, 1, 1 },

        -- Sound settings
        chargeRefreshSound = true,
        chargeRefreshSoundId = 39516,
    }
}

local active = false
local ascentStart = 0
local isSlowSkyriding = true
local hasSkyriding = false

local masterMoveFrame = nil
local speedBarFrame = nil
local chargesBarFrame = nil
local speedAbilityFrame = nil
local secondWindFrame = nil

local speedBar = nil
local speedText = nil
local angleText = nil
local chargeFrame = nil
local staticChargeIcon = nil
local staticChargeText = nil
local secondWindBar = nil
local secondWindText = nil
local whirlingSurgeIcon = nil

-- State tracking
local previousChargeCount = 0
local chargesInitialized = false
local secondWindStartTime = 0
local whirlingSurgeStartTime = 0

local thrillActive = false          -- synced via UNIT_AURA
local abilityFrameDirty = true      -- set by UNIT_AURA / SPELL_UPDATE_COOLDOWN

local speedBarElapsed    = 0
local smoothedSpeed      = 0
local lastSpeedBarColorKey = nil    -- "boost"|"thrill"|"normal"

local vigorRechargeTimer     = nil
local secondWindRechargeTimer = nil


-- Localized functions
local GetTime = GetTime
local C_PlayerInfo = C_PlayerInfo
local GetGlidingInfo = C_PlayerInfo.GetGlidingInfo
local C_UnitAuras = C_UnitAuras

local function playChargeSound(soundId)
    if not soundId or soundId == 0 then return end
    PlaySound(soundId, "Master")
end

function zSkyridingBar:PreviewChargeSound()
    if self.db.profile.chargeRefreshSound then
        playChargeSound(self.db.profile.chargeRefreshSoundId)
    end
end

local function setBarRechargeTimer(bar, startTime, cooldownDuration, existing)
    local timer = existing or C_DurationUtil.CreateDuration()
    timer:SetTimeFromStart(startTime, cooldownDuration)
    bar:SetTimerDuration(timer)
    return timer
end

local function getFontPath(fontName)
    local LSM = LibStub("LibSharedMedia-3.0")
    return LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
end

local SNAP_THRESHOLD = 10 -- pixels

local function snapToNearbyFrames(draggedFrame)
    local frames = { speedBarFrame, chargesBarFrame, speedAbilityFrame, secondWindFrame }
    local x, y = draggedFrame:GetLeft(), draggedFrame:GetTop()
    for _, otherFrame in ipairs(frames) do
        if otherFrame ~= draggedFrame and otherFrame:IsShown() then
            local ox, oy = otherFrame:GetLeft(), otherFrame:GetTop()
            -- Snap left edge
            if math.abs(x - ox) < SNAP_THRESHOLD then
                draggedFrame:ClearAllPoints()
                draggedFrame:SetPoint("TOPLEFT", otherFrame, "TOPLEFT", 0, 0)
                break
            end
            -- Snap top edge
            if math.abs(y - oy) < SNAP_THRESHOLD then
                draggedFrame:ClearAllPoints()
                draggedFrame:SetPoint("TOPLEFT", otherFrame, "TOPLEFT", x - ox, 0)
                break
            end
        end
    end
end

local function updateChargeBarColor(bar, isFull, isRecharging)
    if not bar then return end

    local color
    if isFull then
        color = zSkyridingBar.db.profile.chargeBarFullColor
    elseif isRecharging then
        local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
        if thrill then
            color = zSkyridingBar.db.profile.chargeBarFastRechargeColor
        else
            color = zSkyridingBar.db.profile.chargeBarNormalRechargeColor
        end
    else
        color = zSkyridingBar.db.profile.chargeBarNormalRechargeColor
    end

    bar:SetStatusBarColor(unpack(color))
end

local function AddBorderLines(frame, size)
    for _, spec in ipairs({
        { "TOPLEFT",    "TOPRIGHT"   },
        { "BOTTOMLEFT", "BOTTOMRIGHT"},
        { "TOPLEFT",    "BOTTOMLEFT" },
        { "TOPRIGHT",   "BOTTOMRIGHT"},
    }) do
        local line = frame:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(0, 0, 0, 1)
        line:SetPoint(spec[1], frame, spec[1], 0, 0)
        line:SetPoint(spec[2], frame, spec[2], 0, 0)
        -- Top/bottom edges: constrain height; left/right edges: constrain width.
        if spec[1]:find("LEFT") and spec[2]:find("RIGHT") then
            line:SetHeight(size)
        else
            line:SetWidth(size)
        end
    end
end

-- Registers a frame with LibEditMode (multi-frame mode) and wires up the per-layout scale slider.
local function RegisterMultiFrameWithLEM(frame, displayName, pointKey, xKey, yKey, scalesKey, defaultPoint, defaultX, defaultY)
    frame.editModeName = displayName
    LEM:AddFrame(frame, function(f, layoutName, point, x, y)
        zSkyridingBar.db.profile[pointKey] = point
        zSkyridingBar.db.profile[xKey]     = x
        zSkyridingBar.db.profile[yKey]     = y
    end, { point = defaultPoint, x = defaultX, y = defaultY })
    local activeLayout = LEM:GetActiveLayoutName()
    frame:SetScale((activeLayout and zSkyridingBar.db.profile[scalesKey][activeLayout]) or 1.0)
    LEM:AddFrameSettings(frame, { {
        kind      = LEM.SettingType.Slider,
        name      = L["Scale"],
        default   = 1.0,
        minValue  = 0.5,
        maxValue  = 3.0,
        valueStep = 0.05,
        get = function(layoutName)
            return zSkyridingBar.db.profile[scalesKey][layoutName] or 1.0
        end,
        set = function(layoutName, value)
            zSkyridingBar.db.profile[scalesKey][layoutName] = value
            frame:SetScale(value)
        end,
    } })
end

local function SetupFadeAnimations(frame, inDuration, outDuration)
    local fadeIn = frame:CreateAnimationGroup()
    fadeIn:SetToFinalAlpha(true)
    local fadeInAnim = fadeIn:CreateAnimation("Alpha")
    fadeInAnim:SetFromAlpha(0)
    fadeInAnim:SetToAlpha(1)
    fadeInAnim:SetDuration(inDuration)
    fadeIn:SetScript("OnPlay", function() frame:Show() end)
    frame.fadeIn = fadeIn

    local fadeOut = frame:CreateAnimationGroup()
    fadeOut:SetToFinalAlpha(true)
    local fadeOutAnim = fadeOut:CreateAnimation("Alpha")
    fadeOutAnim:SetFromAlpha(1)
    fadeOutAnim:SetToAlpha(0)
    fadeOutAnim:SetDuration(outDuration)
    fadeOut:SetScript("OnFinished", function() frame:Hide() end)
    frame.fadeOut = fadeOut
end

local function ShowWithFade(frame)
    if not frame then return end
    if frame.fadeOut and frame.fadeOut:IsPlaying() then frame.fadeOut:Stop() end
    if frame.fadeIn then
        frame:SetAlpha(0)
        frame.fadeIn:Play()
    else
        frame:Show()
    end
end

local function HideWithFade(frame)
    if not frame then return end
    if frame.fadeIn and frame.fadeIn:IsPlaying() then frame.fadeIn:Stop() end
    if frame.fadeOut and frame:IsShown() then
        frame.fadeOut:Play()
    else
        frame:Hide()
    end
end

local function CreateFadeAnimGroup(target, duration, onFinished)
    local group = target:CreateAnimationGroup()
    local anim  = group:CreateAnimation("Alpha")
    anim:SetDuration(duration)
    anim:SetFromAlpha(1)
    anim:SetToAlpha(0)
    anim:SetOrder(1)
    if onFinished then
        group:SetScript("OnFinished", onFinished)
    end
    return group
end

-- Drives the reverse-fill overlay and end-of-cooldown shine on speedAbilityFrame.
-- Returns true while still animating (keep abilityFrameDirty set while true).
local function ApplyCooldownFill(startTime, duration, icon, iconFadeGroup, fadeIconAlways)
    local saf = speedAbilityFrame  -- confirmed non-nil by caller
    if not saf.whirlingSurgeReverseFill then
        saf._shineActive = false
        return false
    end
    saf.cooldown:SetCooldown(startTime, duration)
    saf.cooldown:Show()
    local now = GetTime()
    local progress   = math.min(1, math.max(0, (now - startTime) / duration))
    local fillHeight = 36 * (1 - progress)
    saf.whirlingSurgeReverseFill:SetHeight(fillHeight)
    saf.whirlingSurgeReverseFill:Show()
    if fillHeight <= 1 and not saf._shineActive then
        saf._shineActive = true
        saf.whirlingSurgeShine:SetAlpha(1)
        if icon then icon:SetAlpha(1) end
        saf.whirlingSurgeShineAnimGroup:Play()
        saf.shineFadeAnimGroup:Stop()
        saf.shineFadeAnimGroup:Play()
        local doFade = fadeIconAlways
        if not doFade then
            -- Only fade the icon if no Static Charge stacks remain (SC+LR branch)
            local sc = C_UnitAuras.GetPlayerAuraBySpellID(STATIC_CHARGE_BUFF_ID)
            doFade = not sc or (sc.applications or 0) == 0
        end
        if doFade and iconFadeGroup then
            iconFadeGroup:Stop()
            iconFadeGroup:Play()
        end
        C_Timer.After(1, function()
            if speedAbilityFrame then speedAbilityFrame._shineActive = false end
        end)
    end
    return fillHeight > 1
end


-- Addon lifecycle
function zSkyridingBar:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("zSkyridingBarDB", defaults, "Default")
    self:SeedBuiltinProfiles()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    if CompatCheck then
        eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
    end

    eventFrame:SetScript("OnEvent", function(frame, event, ...)
        if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
        if event == "ADDON_LOADED" and select(1, ...) == "zSkyridingBar" then
            zSkyridingBar:OnAddonLoaded()
        elseif event == "PLAYER_ENTERING_WORLD" then
            zSkyridingBar:OnPlayerEnteringWorld()
        elseif event == "PLAYER_LOGIN" then
            zSkyridingBar:OnPlayerLogin()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            zSkyridingBar:OnSpellcastSucceeded(event, ...)
        elseif event == "UNIT_AURA" then
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            local unitTarget = select(1, ...)
            zSkyridingBar:OnUnitAura(unitTarget)
        elseif event == "UNIT_POWER_UPDATE" then
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            local unitTarget, powerType = select(1, ...), select(2, ...)
            zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)
        elseif event == "PLAYER_CAN_GLIDE_CHANGED" then
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            zSkyridingBar:CheckSkyridingAvailability()
        elseif event == "UPDATE_UI_WIDGET" then
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            if CompatCheck then
                local widgetInfo = select(1, ...)
                zSkyridingBar:UpdateVigorFromWidget(widgetInfo)
            end
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            abilityFrameDirty = true
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            isSlowSkyriding = not FAST_FLYING_ZONES[select(8, GetInstanceInfo())]
        elseif event == "SPELL_UPDATE_CHARGES" then
            if active then
                zSkyridingBar:UpdateChargeBars()
                zSkyridingBar:UpdateSecondWind()
            end
        end
    end)

    C_Timer.After(10, function()
        self:CreateAllFrames()
        -- Reset so StartTracking re-runs now that frames actually exist.
        active = false
        self:CheckSkyridingAvailability()
    end)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

-- Seed built-in profiles on first load (Classic and Thick only, widths excluded).
local BUILTIN_PRESETS = {
    Classic = {
        speedBarHeight = 18,
        chargeBarHeight = 12,
        chargeBarSpacing = 2,
        speedIndicatorHeight = 20,
        chargesBarX = 0,
        chargesBarY = -5,
        chargeBarBorderSize = 1,
    },
    Thick = {
        speedBarHeight = 28,
        chargeBarHeight = 20,
        chargeBarSpacing = 0,
        speedIndicatorHeight = 30,
        chargesBarX = 0,
        chargesBarY = 0,
        chargeBarBorderSize = 1,
    },
}

function zSkyridingBar:SeedBuiltinProfiles()
    local currentProfile = self.db:GetCurrentProfile()
    self._seeding = true

    local CLASSIC_SETTINGS = BUILTIN_PRESETS.Classic
    local THICK_SETTINGS   = BUILTIN_PRESETS.Thick

    if not self.db.profiles["Classic"] then
        self.db:SetProfile("Classic")
        for k, v in pairs(CLASSIC_SETTINGS) do
            self.db.profile[k] = v
        end
    end

    if not self.db.profiles["Thick"] then
        self.db:SetProfile("Thick")
        for k, v in pairs(THICK_SETTINGS) do
            self.db.profile[k] = v
        end
    end

    if self.db:GetCurrentProfile() ~= currentProfile then
        self.db:SetProfile(currentProfile)
    end
    self._seeding = false
end

-- Built-in profiles restore their preset height/spacing on top of AceDB defaults.
-- User profiles reset to AceDB defaults only.
function zSkyridingBar:ResetCurrentProfile()
    self.db:ResetProfile()  -- resets everything to AceDB defaults (Thick values)
    local preset = BUILTIN_PRESETS[self.db:GetCurrentProfile()]
    if preset then
        for k, v in pairs(preset) do
            self.db.profile[k] = v
        end
    end
    self:RefreshConfig()
    zSkyridingBar.print(L["Reset all settings to default."])
end

function zSkyridingBar:CreateNewProfile(name)
    if not name or name == "" then
        zSkyridingBar.print(L["Profile name cannot be empty"])
        return false
    end
    if self.db.profiles[name] then
        self.db:SetProfile(name)
        zSkyridingBar.print(L["Profile already exists, switched to it"] .. ": " .. name)
        self:RefreshConfig()
        return false
    end
    self.db:SetProfile(name)
    zSkyridingBar.print(L["Profile created"] .. ": " .. name)
    self:RefreshConfig()
    return true
end

-- Delete the currently active profile and fall back to "Default".
-- Classic and Thick are protected and cannot be deleted.
function zSkyridingBar:DeleteCurrentProfile()
    local current = self.db:GetCurrentProfile()
    if current == "Classic" or current == "Thick" then
        zSkyridingBar.print(L["Cannot delete Classic or Thick profiles"])
        return
    end
    -- Switch away first (triggers RefreshConfig via OnProfileChanged)
    self.db:SetProfile("Default")
    self.db:DeleteProfile(current, true)
    zSkyridingBar.print(L["Profile deleted"] .. ": " .. current)
end

function zSkyridingBar:CopyProfile(sourceName)
    if not sourceName or not self.db.profiles[sourceName] then
        zSkyridingBar.print(L["Profile does not exist"])
        return false
    end
    self.db:CopyProfile(sourceName)
    self:RefreshConfig()
    zSkyridingBar.print(L["Settings copied."])
    return true
end

-- Delete any profile by name (except Classic/Thick).
-- Switches to "Default" first if the target is currently active.
function zSkyridingBar:DeleteProfile(name)
    if not name or name == "Classic" or name == "Thick" then
        zSkyridingBar.print(L["Cannot delete Classic or Thick profiles"])
        return false
    end
    if not self.db.profiles[name] then
        return false
    end
    if self.db:GetCurrentProfile() == name then
        self.db:SetProfile("Default")
    end
    self.db:DeleteProfile(name, true)
    zSkyridingBar.print(L["Profile deleted"] .. ": " .. name)
    return true
end

function zSkyridingBar:OnPlayerLogin()
    -- Apply fonts after a short delay to ensure LibSharedMedia is ready
    C_Timer.After(2.5, function()
        self:UpdateFonts()
        zSkyridingBar.print(L["Detected interface version "] .. BuildInterface)
        if CompatCheck then
            zSkyridingBar.print(L["Compatibility mode enabled"])
        end
    end)
    self:InitializeOptions()
end

function zSkyridingBar:InitializeOptions()
    local optionsTable = self:GetOptionsTable()
    if optionsTable then
        LibStub("AceConfig-3.0"):RegisterOptionsTable("zSkyridingBar", optionsTable)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("zSkyridingBar", "zSkyridingBar")
        self.optionsRegistered = true
    end
end

function zSkyridingBar:OnEnable()
    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnDisable()
    self:StopTracking()
    if speedBarFrame then speedBarFrame:Hide() end
    if chargesBarFrame then chargesBarFrame:Hide() end
    if speedAbilityFrame then speedAbilityFrame:Hide() end
    if secondWindFrame then secondWindFrame:Hide() end
    active = false
end

local function releaseAllFrames()
    if speedBarFrame then
        speedBarFrame:Hide()
        speedBarFrame = nil
    end
    if chargesBarFrame then
        chargesBarFrame:Hide()
        chargesBarFrame = nil
    end
    if speedAbilityFrame then
        speedAbilityFrame:Hide()
        speedAbilityFrame = nil
    end
    if secondWindFrame then
        secondWindFrame:Hide()
        secondWindFrame = nil
    end
    if masterMoveFrame then
        masterMoveFrame:Hide()
        masterMoveFrame = nil
    end
    speedBar = nil
    speedText = nil
    angleText = nil
    chargeFrame = nil
    staticChargeIcon = nil
    staticChargeText = nil
    secondWindBar = nil
    secondWindText = nil
    whirlingSurgeIcon = nil
end

function zSkyridingBar:UpdateFramePositions()
    local profile = self.db.profile
    local activeLayout = LEM:GetActiveLayoutName()
    if profile.singleFrameMode then
        -- Single Frame Mode: reposition child frames relative to masterMoveFrame
        if speedBarFrame then
            speedBarFrame:ClearAllPoints()
            speedBarFrame:SetSize(profile.speedBarWidth, profile.speedBarHeight)
            speedBarFrame:SetPoint("CENTER", masterMoveFrame, "CENTER", profile.speedBarX, profile.speedBarY)
            speedBarFrame:SetFrameStrata(profile.frameStrata)
        end
        if chargesBarFrame then
            chargesBarFrame:ClearAllPoints()
            chargesBarFrame:SetSize(profile.chargeBarWidth, profile.chargeBarHeight)
            chargesBarFrame:SetPoint("CENTER", speedBarFrame, "CENTER", profile.chargesBarX, profile.chargesBarY - (profile.speedBarHeight/2) - (profile.chargeBarHeight/2) )
            chargesBarFrame:SetFrameStrata(profile.frameStrata)
        end
        if speedAbilityFrame then
            speedAbilityFrame:ClearAllPoints()
            speedAbilityFrame:SetSize(40, 40)
            speedAbilityFrame:SetPoint("TOPRIGHT", speedBarFrame, "TOPLEFT", profile.speedAbilityX, profile.speedAbilityY)
            speedAbilityFrame:SetFrameStrata(profile.frameStrata)
        end
        if secondWindFrame then
            secondWindFrame:ClearAllPoints()
            secondWindFrame:SetSize(profile.secondWindBarWidth, profile.secondWindBarHeight)
            secondWindFrame:SetPoint("CENTER", chargesBarFrame, "CENTER", profile.secondWindX, profile.secondWindY)
            secondWindFrame:SetFrameStrata(profile.frameStrata)
        end
        if masterMoveFrame then
            masterMoveFrame:SetScale((activeLayout and profile.masterMoveFrameScales[activeLayout]) or 1.0)
            masterMoveFrame:SetFrameStrata(profile.frameStrata)
        end
    else
        -- Multi-frame Mode: LEM owns positions; only update strata and per-frame scale
        if speedBarFrame then
            speedBarFrame:SetFrameStrata(profile.frameStrata)
            speedBarFrame:SetScale((activeLayout and profile.multiSpeedBarScales[activeLayout]) or 1.0)
        end
        if chargesBarFrame then
            chargesBarFrame:SetFrameStrata(profile.frameStrata)
            chargesBarFrame:SetScale((activeLayout and profile.multiChargesBarScales[activeLayout]) or 1.0)
        end
        if speedAbilityFrame then
            speedAbilityFrame:SetFrameStrata(profile.frameStrata)
            speedAbilityFrame:SetScale((activeLayout and profile.multiSpeedAbilityScales[activeLayout]) or 1.0)
        end
        if secondWindFrame then
            secondWindFrame:SetFrameStrata(profile.frameStrata)
            secondWindFrame:SetScale((activeLayout and profile.multiSecondWindScales[activeLayout]) or 1.0)
        end
    end
end

function zSkyridingBar:UpdateFonts()
    if speedText then
        speedText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
        speedText:SetTextColor(unpack(self.db.profile.fontColor))
    end
    if angleText then
        angleText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
        angleText:SetTextColor(unpack(self.db.profile.fontColor))
    end
    if staticChargeText then
        staticChargeText:SetFont(getFontPath(self.db.profile.fontFace), 14, self.db.profile.fontFlag)
        staticChargeText:SetTextColor(unpack(self.db.profile.fontColor))
    end
    if secondWindText then
        secondWindText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile
            .fontFlag)
        secondWindText:SetTextColor(unpack(self.db.profile.fontColor))
    end
end

function zSkyridingBar:RefreshConfig()
    if self._seeding then return end
    self:UpdateAllFrameAppearance()
    -- Re-apply current bar state; SetStatusBarTexture resets fill value to 0
    self:UpdateSecondWind()
    self:UpdateFonts()
    -- Sync countdown text visibility on the native Cooldown frame
    if speedAbilityFrame and speedAbilityFrame.cooldown then
        speedAbilityFrame.cooldown:SetHideCountdownNumbers(not self.db.profile.showAbilityCooldownText)
    end
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame:IsVisible() then
            UIWidgetPowerBarContainerFrame:Hide()
        end
    end
end

function zSkyridingBar:CreateAllFrames()
    releaseAllFrames()
    -- Register LEM callbacks once (guarded so they survive CreateAllFrames re-calls)
    if not zSkyridingBar.lemCallbacksRegistered then
        zSkyridingBar.lemCallbacksRegistered = true

        -- Show all frames while in EditMode so they can be repositioned even when not skyriding
        LEM:RegisterCallback('enter', function()
            if masterMoveFrame then masterMoveFrame:Show() end
            if speedBarFrame then speedBarFrame:Show() end
            if chargesBarFrame then chargesBarFrame:Show() end
            if speedAbilityFrame then speedAbilityFrame:Show() end
            if secondWindFrame then secondWindFrame:Show() end
        end)

        -- Restore frames to their correct visibility when EditMode closes
        LEM:RegisterCallback('exit', function()
            -- Use CheckSkyridingAvailability to correctly handle the case where the player
            -- mounted up while Edit Mode was open (the normal PLAYER_CAN_GLIDE_CHANGED handler
            -- is suppressed while Edit Mode is active, so active/hasSkyriding may be stale)
            zSkyridingBar:CheckSkyridingAvailability()
        end)

        -- Apply per-layout scales whenever the active EditMode layout changes
        LEM:RegisterCallback('layout', function(layoutName)
            if zSkyridingBar.db.profile.singleFrameMode then
                if masterMoveFrame then
                    masterMoveFrame:SetScale(zSkyridingBar.db.profile.masterMoveFrameScales[layoutName] or 1.0)
                end
            else
                if speedBarFrame then speedBarFrame:SetScale(zSkyridingBar.db.profile.multiSpeedBarScales[layoutName] or 1.0) end
                if chargesBarFrame then chargesBarFrame:SetScale(zSkyridingBar.db.profile.multiChargesBarScales[layoutName] or 1.0) end
                if speedAbilityFrame then speedAbilityFrame:SetScale(zSkyridingBar.db.profile.multiSpeedAbilityScales[layoutName] or 1.0) end
                if secondWindFrame then secondWindFrame:SetScale(zSkyridingBar.db.profile.multiSecondWindScales[layoutName] or 1.0) end
            end
        end)
    end
    if self.db.profile.singleFrameMode then
        -- Single Frame Mode: all sub-frames parented under one master frame
        self:CreateMasterMoveFrame()
    end
    self:CreateSpeedBarFrame()
    self:CreateChargesBarFrame()
    self:CreateSpeedAbilityFrame()
    self:CreateSecondWindFrame()
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame:IsVisible() then
            UIWidgetPowerBarContainerFrame:Hide()
        end
    end
end

function zSkyridingBar:CreateMasterMoveFrame()
    masterMoveFrame = CreateFrame("Frame", nil, UIParent)
    local profile = self.db.profile
    local masterWidth = math.max(profile.speedBarWidth, profile.chargeBarWidth, profile.secondWindBarWidth) + 50
    masterMoveFrame:SetSize(masterWidth, 200)

    local savedPoint = self.db.profile.masterMoveFramePoint or "CENTER"
    masterMoveFrame:SetPoint(savedPoint, UIParent, savedPoint,
        self.db.profile.masterMoveFrameX,
        self.db.profile.masterMoveFrameY)

    masterMoveFrame:SetFrameStrata(self.db.profile.frameStrata)
    masterMoveFrame:SetFrameLevel(5)
    local activeLayout = LEM:GetActiveLayoutName()
    masterMoveFrame:SetScale((activeLayout and self.db.profile.masterMoveFrameScales[activeLayout]) or 1.0)
    masterMoveFrame:EnableMouse(false)
    masterMoveFrame:SetClampedToScreen(true)

    -- Register with Blizzard EditMode so users can reposition via the in-game UI
    masterMoveFrame.editModeName = "zSkyridingBar"
    LEM:AddFrame(masterMoveFrame, function(frame, layoutName, point, x, y)
        zSkyridingBar.db.profile.masterMoveFramePoint = point
        zSkyridingBar.db.profile.masterMoveFrameX = x
        zSkyridingBar.db.profile.masterMoveFrameY = y
    end, {
        point = defaults.profile.masterMoveFramePoint,
        x = defaults.profile.masterMoveFrameX,
        y = defaults.profile.masterMoveFrameY,
    })

    LEM:AddFrameSettings(masterMoveFrame, {
        {
            kind = LEM.SettingType.Slider,
            name = L["Scale"],
            default = 1.0,
            minValue = 0.5,
            maxValue = 3.0,
            valueStep = 0.05,
            get = function(layoutName)
                return zSkyridingBar.db.profile.masterMoveFrameScales[layoutName] or 1.0
            end,
            set = function(layoutName, value)
                zSkyridingBar.db.profile.masterMoveFrameScales[layoutName] = value
                if masterMoveFrame then
                    masterMoveFrame:SetScale(value)
                end
            end,
        }
    })

end

function zSkyridingBar:CreateSpeedBarFrame()
    local profile = self.db.profile
    if profile.singleFrameMode then
        speedBarFrame = CreateFrame("Frame", nil, masterMoveFrame)
        speedBarFrame:SetPoint("CENTER", masterMoveFrame, "CENTER", profile.speedBarX, profile.speedBarY)
    else
        speedBarFrame = CreateFrame("Frame", nil, UIParent)
        local pt = profile.multiSpeedBarPoint or "CENTER"
        speedBarFrame:SetPoint(pt, UIParent, pt, profile.multiSpeedBarX, profile.multiSpeedBarY)
        RegisterMultiFrameWithLEM(speedBarFrame,
            "zSkyridingBar - Speed Bar",
            "multiSpeedBarPoint", "multiSpeedBarX", "multiSpeedBarY",
            "multiSpeedBarScales",
            defaults.profile.multiSpeedBarPoint, defaults.profile.multiSpeedBarX, defaults.profile.multiSpeedBarY)
    end
    speedBarFrame:SetSize(profile.speedBarWidth, profile.speedBarHeight)
    speedBarFrame:SetFrameStrata(profile.frameStrata)
    speedBarFrame:SetFrameLevel(10)

    speedBar = CreateFrame("StatusBar", nil, speedBarFrame)
    speedBar:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
    speedBar:SetPoint("TOP", speedBarFrame, "TOP", 0, 0)

    local speedTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    speedBar:SetStatusBarTexture(speedTexture)
    speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarNormalColor))
    speedBar:SetMinMaxValues(20 * BAR_MULTIPLIER, 100 * BAR_MULTIPLIER)
    speedBar:SetValue(0)
    speedBar:SetClipsChildren(true)

    local speedBarBG = speedBar:CreateTexture(nil, "BACKGROUND")
    speedBarBG:SetAllPoints()
    speedBarBG:SetTexture(speedTexture)
    speedBarBG:SetVertexColor(unpack(self.db.profile.speedBarBackgroundColor))
    speedBar.bg = speedBarBG

    AddBorderLines(speedBar, 1)
    SetupFadeAnimations(speedBarFrame, 0.3, 0.8)

    speedText = speedBar:CreateFontString(nil, "OVERLAY")
    speedText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
    speedText:SetPoint("LEFT", speedBar, "LEFT", 5, 0)
    speedText:SetTextColor(unpack(self.db.profile.fontColor))
    speedText:SetText("")

    angleText = speedBar:CreateFontString(nil, "OVERLAY")
    angleText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
    angleText:SetPoint("RIGHT", speedBar, "RIGHT", -5, 0)
    angleText:SetTextColor(unpack(self.db.profile.fontColor))
    angleText:SetText("")

    if self.db.profile.showSpeedIndicator then
        local speedIndicator = speedBar:CreateTexture(nil, "OVERLAY", nil, -1)
        speedIndicator:SetTexture("Interface\\Buttons\\WHITE8x8")
        speedIndicator:SetSize(2, self.db.profile.speedBarHeight + 4)
        speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))

        local indicatorPos = (60 - 20) / (100 - 20)
        speedIndicator:SetPoint("LEFT", speedBar, "LEFT", indicatorPos * self.db.profile.speedBarWidth, 0)

        speedBar.speedIndicator = speedIndicator
    end

    speedBarFrame:Hide()
end

function zSkyridingBar:CreateChargesBarFrame()
    local profile = self.db.profile
    if profile.singleFrameMode then
        chargesBarFrame = CreateFrame("Frame", nil, masterMoveFrame)
        chargesBarFrame:SetPoint("CENTER", speedBarFrame, "CENTER", profile.chargesBarX, profile.chargesBarY - (profile.speedBarHeight/2) - (profile.chargeBarHeight/2) )
    else
        chargesBarFrame = CreateFrame("Frame", nil, UIParent)
        local pt = profile.multiChargesBarPoint or "CENTER"
        chargesBarFrame:SetPoint(pt, UIParent, pt, profile.multiChargesBarX, profile.multiChargesBarY)
        RegisterMultiFrameWithLEM(chargesBarFrame,
            "zSkyridingBar - Charges",
            "multiChargesBarPoint", "multiChargesBarX", "multiChargesBarY",
            "multiChargesBarScales",
            defaults.profile.multiChargesBarPoint, defaults.profile.multiChargesBarX, defaults.profile.multiChargesBarY)
    end
    chargesBarFrame:SetSize(profile.chargeBarWidth, profile.chargeBarHeight)
    chargesBarFrame:SetFrameStrata(profile.frameStrata)
    chargesBarFrame:SetFrameLevel(10)

    chargeFrame = CreateFrame("Frame", nil, chargesBarFrame)
    chargeFrame:SetSize(self.db.profile.chargeBarWidth, self.db.profile.chargeBarHeight)
    chargeFrame:SetPoint("TOP", chargesBarFrame, "TOP", 0, 0)

    chargeFrame.bars = {}

    local numBars = 6
    local barWidth = (self.db.profile.chargeBarWidth - ((numBars - 1) * self.db.profile.chargeBarSpacing)) / numBars

    for i = 1, numBars do
        local bar = CreateFrame("StatusBar", nil, chargeFrame)
        bar:SetSize(barWidth, self.db.profile.chargeBarHeight)

        if i == 1 then
            bar:SetPoint("LEFT", chargeFrame, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", chargeFrame.bars[i - 1], "RIGHT", self.db.profile.chargeBarSpacing, 0)
        end

        local chargeTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.chargeBarTexture) or
            "Interface\\TargetingFrame\\UI-StatusBar"
        bar:SetStatusBarTexture(chargeTexture)
        bar:SetMinMaxValues(0, 100 * BAR_MULTIPLIER)
        bar:SetValue(0)

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(chargeTexture)
        bg:SetVertexColor(unpack(self.db.profile.chargeBarBackgroundColor))
        bar.bg = bg

        AddBorderLines(bar, self.db.profile.chargeBarBorderSize or 0)

        updateChargeBarColor(bar, false, false)
        chargeFrame.bars[i] = bar
        bar:Hide()
    end

    SetupFadeAnimations(chargesBarFrame, 0.3, 0.8)
    chargesBarFrame:Hide()
end

function zSkyridingBar:CreateSpeedAbilityFrame()
    local profile = self.db.profile
    if profile.singleFrameMode then
        speedAbilityFrame = CreateFrame("Frame", nil, masterMoveFrame)
        speedAbilityFrame:SetPoint("TOPRIGHT", speedBarFrame, "TOPLEFT", profile.speedAbilityX, profile.speedAbilityY)
    else
        speedAbilityFrame = CreateFrame("Frame", nil, UIParent)
        local pt = profile.multiSpeedAbilityPoint or "CENTER"
        speedAbilityFrame:SetPoint(pt, UIParent, pt, profile.multiSpeedAbilityX, profile.multiSpeedAbilityY)
        RegisterMultiFrameWithLEM(speedAbilityFrame,
            "zSkyridingBar - Ability",
            "multiSpeedAbilityPoint", "multiSpeedAbilityX", "multiSpeedAbilityY",
            "multiSpeedAbilityScales",
            defaults.profile.multiSpeedAbilityPoint, defaults.profile.multiSpeedAbilityX, defaults.profile.multiSpeedAbilityY)
    end
    speedAbilityFrame:SetSize(40, 40)
    speedAbilityFrame:SetFrameStrata(profile.frameStrata)
    speedAbilityFrame:SetFrameLevel(10)

    -- Icon for Static Charge
    staticChargeIcon = speedAbilityFrame:CreateTexture(nil, "ARTWORK")
    staticChargeIcon:SetSize(36, 36)
    staticChargeIcon:SetPoint("CENTER", speedAbilityFrame, "CENTER", 0, 0)
    staticChargeIcon:Hide()

    -- Whirling Surge icon (shares frame with Static Charge)
    whirlingSurgeIcon = speedAbilityFrame:CreateTexture(nil, "ARTWORK")
    whirlingSurgeIcon:SetSize(36, 36)
    whirlingSurgeIcon:SetPoint("CENTER", speedAbilityFrame, "CENTER", 0, 0)
    whirlingSurgeIcon:Hide()

    -- Whirling Surge cooldown reverse fill overlay
    local whirlingSurgeReverseFill = speedAbilityFrame:CreateTexture(nil, "OVERLAY")
    whirlingSurgeReverseFill:SetColorTexture(0, 0, 0, 0.5)
    -- Anchored to BOTTOM so SetHeight alone drives the fill from bottom up (no per-tick SetPoint needed)
    whirlingSurgeReverseFill:SetPoint("BOTTOM", speedAbilityFrame, "BOTTOM", 0, 2)
    whirlingSurgeReverseFill:SetPoint("LEFT", speedAbilityFrame, "LEFT", 2, 0)
    whirlingSurgeReverseFill:SetPoint("RIGHT", speedAbilityFrame, "RIGHT", -2, 0)
    whirlingSurgeReverseFill:SetHeight(36)
    whirlingSurgeReverseFill:Hide()
    speedAbilityFrame.whirlingSurgeReverseFill = whirlingSurgeReverseFill

    local whirlingSurgeShine = speedAbilityFrame:CreateTexture(nil, "OVERLAY")
    whirlingSurgeShine:SetTexture("Interface\\Cooldown\\star4")
    whirlingSurgeShine:SetBlendMode("ADD")
    whirlingSurgeShine:SetSize(64, 64)
    whirlingSurgeShine:SetPoint("CENTER", speedAbilityFrame, "CENTER", 0, 0)
    whirlingSurgeShine:SetAlpha(0)
    speedAbilityFrame.whirlingSurgeShine = whirlingSurgeShine

    local shineAnimGroup = whirlingSurgeShine:CreateAnimationGroup()
    local shineRotation = shineAnimGroup:CreateAnimation("Rotation")
    shineRotation:SetDuration(1.5)
    shineRotation:SetDegrees(320)
    speedAbilityFrame.whirlingSurgeShineAnimGroup = shineAnimGroup

    speedAbilityFrame.shineFadeAnimGroup = CreateFadeAnimGroup(whirlingSurgeShine, 1, function()
        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
            speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
        end
    end)

    -- Border glow
    local staticChargeBorder = speedAbilityFrame:CreateTexture(nil, "BORDER")
    staticChargeBorder:SetSize(44, 44)
    staticChargeBorder:SetPoint("CENTER", staticChargeIcon, "CENTER", 0, 0)
    staticChargeBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    staticChargeBorder:SetBlendMode("ADD")
    staticChargeBorder:SetVertexColor(1, 1, 0.3, 0.3)
    staticChargeBorder:Hide()
    speedAbilityFrame.border = staticChargeBorder

    speedAbilityFrame.staticChargeIconFadeAnimGroup = CreateFadeAnimGroup(staticChargeIcon, 1, function()
        staticChargeIcon:SetAlpha(0)
        staticChargeIcon:Hide()
    end)

    speedAbilityFrame.whirlingSurgeIconFadeAnimGroup = CreateFadeAnimGroup(whirlingSurgeIcon, 1, function()
        whirlingSurgeIcon:SetAlpha(0)
        whirlingSurgeIcon:Hide()
    end)

    staticChargeText = speedAbilityFrame:CreateFontString(nil, "OVERLAY")
    staticChargeText:SetFont(getFontPath(self.db.profile.fontFace), 14, self.db.profile.fontFlag)
    staticChargeText:SetPoint("BOTTOM", staticChargeIcon, "BOTTOM", 0, -5)
    staticChargeText:SetTextColor(1, 1, 1, 1)
    staticChargeText:SetText("")
    staticChargeText:Hide()

    -- Native Cooldown frame: WoW updates its countdown text every game frame, so it never freezes during GCD
    local cooldownFrame = CreateFrame("Cooldown", nil, speedAbilityFrame, "CooldownFrameTemplate")
    cooldownFrame:SetAllPoints(speedAbilityFrame)
    cooldownFrame:SetDrawSwipe(false)   -- we use our own reverse-fill overlay
    cooldownFrame:SetDrawEdge(false)
    cooldownFrame:SetHideCountdownNumbers(not self.db.profile.showAbilityCooldownText)
    -- Fire an ability-frame re-evaluation when a cooldown expires naturally
    cooldownFrame:HookScript("OnCooldownDone", function()
        abilityFrameDirty = true
        zSkyridingBar:UpdateStaticChargeAndWhirlingSurge()
    end)
    speedAbilityFrame.cooldown = cooldownFrame

    speedAbilityFrame:Hide()
end

function zSkyridingBar:CreateSecondWindFrame()
    local profile = self.db.profile
    if profile.singleFrameMode then
        secondWindFrame = CreateFrame("Frame", nil, masterMoveFrame)
        secondWindFrame:SetPoint("CENTER", chargesBarFrame, "CENTER", profile.secondWindX, profile.secondWindY)
    else
        secondWindFrame = CreateFrame("Frame", nil, UIParent)
        local pt = profile.multiSecondWindPoint or "CENTER"
        secondWindFrame:SetPoint(pt, UIParent, pt, profile.multiSecondWindX, profile.multiSecondWindY)
        RegisterMultiFrameWithLEM(secondWindFrame,
            "zSkyridingBar - Second Wind",
            "multiSecondWindPoint", "multiSecondWindX", "multiSecondWindY",
            "multiSecondWindScales",
            defaults.profile.multiSecondWindPoint, defaults.profile.multiSecondWindX, defaults.profile.multiSecondWindY)
    end
    secondWindFrame:SetSize(profile.secondWindBarWidth, profile.secondWindBarHeight)
    secondWindFrame:SetFrameStrata(profile.frameStrata)
    secondWindFrame:SetFrameLevel(10)

    secondWindBar = CreateFrame("StatusBar", nil, secondWindFrame)
    secondWindBar:SetSize(self.db.profile.secondWindBarWidth, self.db.profile.secondWindBarHeight)
    secondWindBar:SetPoint("TOP", secondWindFrame, "TOP", 0, 0)

    local secondWindTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.secondWindBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    secondWindBar:SetStatusBarTexture(secondWindTexture)
    secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindNoChargeColor))
    secondWindBar:SetMinMaxValues(0, 100 * BAR_MULTIPLIER)
    secondWindBar:SetValue(0)

    AddBorderLines(secondWindBar, 1)


    local secondWindBG = secondWindBar:CreateTexture(nil, "BACKGROUND")
    secondWindBG:SetAllPoints()
    secondWindBG:SetTexture(secondWindTexture)
    secondWindBG:SetVertexColor(unpack(self.db.profile.secondWindNoChargeColor))
    secondWindBar.bg = secondWindBG

    secondWindText = secondWindBar:CreateFontString(nil, "OVERLAY")
    secondWindText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
    secondWindText:SetPoint("CENTER", secondWindBar, "CENTER", 0, 0)
    secondWindText:SetTextColor(unpack(self.db.profile.fontColor))
    secondWindText:SetText("0/3")

    SetupFadeAnimations(secondWindFrame, 0.3, 0.8)
    secondWindFrame:Hide()
end

-- Update functions
function zSkyridingBar:UpdateSpeedBarAppearance()
    if not speedBar then return end

    if speedBarFrame then
        speedBarFrame:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
    end
    speedBar:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
    local speedTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    speedBar:SetStatusBarTexture(speedTexture)
    speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarNormalColor))

    if speedBar.bg then
        speedBar.bg:SetTexture(speedTexture)
        speedBar.bg:SetVertexColor(unpack(self.db.profile.speedBarBackgroundColor))
    end

    -- Update speed indicator if enabled
    if self.db.profile.showSpeedIndicator then
        if not speedBar.speedIndicator then
            local speedIndicator = speedBar:CreateTexture(nil, "OVERLAY", nil, -1)
            speedIndicator:SetTexture("Interface\\Buttons\\WHITE8x8")
            speedIndicator:SetSize(2, self.db.profile.speedBarHeight)
            speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))
            speedBar.speedIndicator = speedIndicator
        end
        speedBar.speedIndicator:SetSize(2, self.db.profile.speedBarHeight)
        speedBar.speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))
        local indicatorPos = (60 - 20) / (100 - 20)
        speedBar.speedIndicator:SetPoint("LEFT", speedBar, "LEFT", indicatorPos * self.db.profile.speedBarWidth, 0)
        speedBar.speedIndicator:Show()
    elseif speedBar.speedIndicator then
        speedBar.speedIndicator:Hide()
    end
end

function zSkyridingBar:UpdateChargesBarAppearance()
    if not chargeFrame or not chargeFrame.bars then return end

    if chargesBarFrame then
        chargesBarFrame:SetSize(self.db.profile.chargeBarWidth, self.db.profile.chargeBarHeight)
    end

    if chargeFrame then
        chargeFrame:SetSize(self.db.profile.chargeBarWidth, self.db.profile.chargeBarHeight)
    end

    local numBars = #chargeFrame.bars
    local barWidth = (self.db.profile.chargeBarWidth - ((numBars - 1) * self.db.profile.chargeBarSpacing)) / numBars

    local chargeTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.chargeBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"

    for i, bar in ipairs(chargeFrame.bars) do
        bar:SetSize(barWidth, self.db.profile.chargeBarHeight)

        if i == 1 then
            bar:SetPoint("LEFT", chargeFrame, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", chargeFrame.bars[i - 1], "RIGHT", self.db.profile.chargeBarSpacing, 0)
        end

        bar:SetStatusBarTexture(chargeTexture)

        if bar.bg then
            bar.bg:SetTexture(chargeTexture)
            bar.bg:SetVertexColor(unpack(self.db.profile.chargeBarBackgroundColor))
        end
        local borderTextures = bar:GetRegions()
        for _, texture in ipairs({ borderTextures }) do
            if texture and texture:GetObjectType() == "Texture" and texture:GetDrawLayer() == "OVERLAY" then
                local height = texture:GetHeight()
                local width = texture:GetWidth()
                if height == 1 or width == 1 then
                    if height == 1 then
                        texture:SetHeight(self.db.profile.chargeBarBorderSize or 0)
                    else
                        texture:SetWidth(self.db.profile.chargeBarBorderSize or 0)
                    end
                end
            end
        end
        local isFull = (i <= previousChargeCount)
        local isRecharging = (i == previousChargeCount + 1)
        updateChargeBarColor(bar, isFull, isRecharging)
    end
end

function zSkyridingBar:UpdateSecondWindBarAppearance()
    if not secondWindBar then return end

    if secondWindFrame then
        secondWindFrame:SetSize(self.db.profile.secondWindBarWidth, self.db.profile.secondWindBarHeight)
    end
    secondWindBar:SetSize(self.db.profile.secondWindBarWidth, self.db.profile.secondWindBarHeight)
    local secondWindTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.secondWindBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    secondWindBar:SetStatusBarTexture(secondWindTexture)
    secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindNoChargeColor))

    if secondWindBar.bg then
        secondWindBar.bg:SetTexture(secondWindTexture)
        secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindNoChargeColor))
    end
end

function zSkyridingBar:UpdateAllFrameAppearance()
    self:UpdateSpeedBarAppearance()
    self:UpdateChargesBarAppearance()
    self:UpdateSecondWindBarAppearance()
    -- Respect hide flags while tracking is active
    if active then
        if speedBarFrame then
            if self.db.profile.hideSpeedBar then speedBarFrame:Hide() else speedBarFrame:Show() end
        end
        if chargesBarFrame then
            if self.db.profile.hideChargeBar then chargesBarFrame:Hide() else chargesBarFrame:Show() end
        end
        if secondWindFrame then
            if self.db.profile.hideSecondWindBar then secondWindFrame:Hide() else secondWindFrame:Show() end
        end
    end
    -- Keep master frame wide enough to encompass the widest bar
    if self.db.profile.singleFrameMode and masterMoveFrame then
        local profile = self.db.profile
        local masterWidth = math.max(profile.speedBarWidth, profile.chargeBarWidth, profile.secondWindBarWidth) + 50
        masterMoveFrame:SetSize(masterWidth, masterMoveFrame:GetHeight())
    end
end

-- Event handlers
function zSkyridingBar:OnAddonLoaded()
    -- Register custom font with LibSharedMedia
    local LSM = LibStub("LibSharedMedia-3.0")
    LSM:Register("font", "Homespun", "Interface\\Addons\\zSkyridingBar\\Assets\\Fonts\\homespun.ttf")

    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnPlayerEnteringWorld()
    isSlowSkyriding = not FAST_FLYING_ZONES[select(8, GetInstanceInfo())]
    self:CheckSkyridingAvailability()
end

if CompatCheck then
    function zSkyridingBar:OnUpdateUIWidget(widgetInfo)
        -- Handle UI widget updates for vigor bars
        if widgetInfo and widgetInfo.widgetSetID == 283 then
            -- Debug: print("Vigor widget update received:", widgetInfo.widgetID)
            --zSkyridingBar.print("Vigor widget update received: " .. widgetInfo.widgetID)
            self:UpdateVigorFromWidget(widgetInfo)
        end
    end
end

function zSkyridingBar:OnUnitAura(unitTarget)
    if unitTarget == "player" then
        abilityFrameDirty = true
        local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
        thrillActive = thrill ~= nil
    end
end

function zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)
    if unitTarget == "player" and powerType == "ALTERNATE" then
        self:UpdateChargeBars()
    end
end

function zSkyridingBar:OnSpellcastSucceeded(event, unitTarget, castGUID, spellId)
    if unitTarget == "player" and spellId == ASCENT_SPELL_ID then
        ascentStart = GetTime()
    end
end

-- OnUpdate handler attached to the speed bar frame while skyriding; detached on dismount.
-- The speed bar value is eased every frame for fluid animation. Text, color, and ability
-- frame checks are throttled at BAR_TICK_RATE since they don't benefit from per-frame updates.
local function speedBarOnUpdate(_, elapsed)
    local isGliding, isFlying, forwardSpeed = GetGlidingInfo()
    if not isGliding and not isFlying then
        -- Not gliding/flying: ensure we stop tracking in cases where the
        -- PLAYER_CAN_GLIDE_CHANGED event may not have fired (eg. ridealong
        -- passenger dismounts). Re-check availability to trigger StopTracking().
        zSkyridingBar:CheckSkyridingAvailability()
        return
    end

    -- Ease displayed speed toward actual speed each frame (frame-rate independent).
    -- Factor derived from: desired half-life of ~4 frames at 60 fps.
    local easeT = 1.0 - 0.82 ^ (elapsed * 60)
    smoothedSpeed = smoothedSpeed + (forwardSpeed - smoothedSpeed) * easeT
    local adjustedSpeed = smoothedSpeed
    if isSlowSkyriding then
        adjustedSpeed = adjustedSpeed / SLOW_SKYRIDING_RATIO
    end
    speedBar:SetValue(math.min(100, math.max(20, adjustedSpeed)) * BAR_MULTIPLIER)

    -- Throttled: text, color, ability frame (no need to run every frame)
    speedBarElapsed = speedBarElapsed + elapsed
    if speedBarElapsed < BAR_TICK_RATE then return end
    speedBarElapsed = 0

    -- Speed text (change-gated)
    if speedText and zSkyridingBar.db.profile.speedShow then
        local speedTextFormat, speedTextFactor
        if zSkyridingBar.db.profile.speedUnits == 1 then
            speedTextFormat = "%.1fyd/s"
            speedTextFactor = 1
        else
            speedTextFormat = "%.0f%%"
            speedTextFactor = 100 / 7
        end
        local speedDisplay = forwardSpeed < 1 and "" or string.format(speedTextFormat, forwardSpeed * speedTextFactor)
        if speedDisplay ~= speedText:GetText() then
            speedText:SetText(speedDisplay)
        end
    end

    -- Speed bar color (change-gated via colorKey)
    do
        local maxGlideSpeed = isSlowSkyriding and SLOW_ZONE_MAX_GLIDE or FAST_ZONE_MAX_GLIDE
        local colorKey
        if forwardSpeed > (maxGlideSpeed + 0.1) then
            colorKey = "boost"
        elseif thrillActive then
            colorKey = "thrill"
        else
            colorKey = "normal"
        end
        if colorKey ~= lastSpeedBarColorKey then
            lastSpeedBarColorKey = colorKey
            local color
            if colorKey == "boost" then
                color = zSkyridingBar.db.profile.speedBarBoostColor
            elseif colorKey == "thrill" then
                color = zSkyridingBar.db.profile.speedBarThrillColor
            else
                color = zSkyridingBar.db.profile.speedBarNormalColor
            end
            speedBar:SetStatusBarColor(unpack(color))
        end
    end

    -- Ability frame (only when dirty)
    if abilityFrameDirty then
        zSkyridingBar:UpdateStaticChargeAndWhirlingSurge()
    end
end

function zSkyridingBar:CheckSkyridingAvailability()
    local isGliding, isFlying, forwardSpeed = GetGlidingInfo()
    if not isGliding and not isFlying then
        hasSkyriding = false
    else
        hasSkyriding = true
    end

    if hasSkyriding then
        isSlowSkyriding = not FAST_FLYING_ZONES[select(8, GetInstanceInfo())]

        if not active then
            active = true
            self:StartTracking()
        end
    else
        active = false
        self:StopTracking()
    end
end

function zSkyridingBar:StartTracking()
    active = true

    if speedBar then
        speedBarElapsed = 0
        smoothedSpeed = 0
        lastSpeedBarColorKey = nil
        speedBar:SetScript("OnUpdate", speedBarOnUpdate)
    end

    if speedBarFrame then
        if self.db.profile.hideSpeedBar then speedBarFrame:Hide() else ShowWithFade(speedBarFrame) end
    end
    if speedBar then speedBar:Show() end
    if chargesBarFrame then
        if self.db.profile.hideChargeBar then chargesBarFrame:Hide() else ShowWithFade(chargesBarFrame) end
    end
    -- Do NOT pre-show speedAbilityFrame here.
    -- UpdateStaticChargeAndWhirlingSurge (called below) owns its visibility entirely.
    -- Pre-showing it would cause the stale Cooldown child frame to flash for one render frame.
    if speedAbilityFrame then
        if self.db.profile.hideSpeedAbility then speedAbilityFrame:Hide() end
    end
    if secondWindFrame then
        if self.db.profile.hideSecondWindBar then secondWindFrame:Hide() else ShowWithFade(secondWindFrame) end
    end
    if secondWindBar then
        if self.db.profile.hideSecondWindBar then secondWindBar:Hide() else secondWindBar:Show() end
    end

    -- Sync event-driven caches before first tick
    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    thrillActive = thrill ~= nil
    abilityFrameDirty = true   -- ensure initial ability frame check runs this tick
    self:UpdateChargeBars()
    self:UpdateStaticChargeAndWhirlingSurge()
    self:UpdateSecondWind()
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame:IsVisible() then
            UIWidgetPowerBarContainerFrame:Hide()
        end
    end
end

function zSkyridingBar:StopTracking()
    if speedBar then
        speedBar:SetScript("OnUpdate", nil)
    end
    speedBarElapsed = 0
    smoothedSpeed = 0
    lastSpeedBarColorKey = nil

    previousChargeCount = 0
    chargesInitialized = false

    if speedBarFrame and not LEM:IsInEditMode() then HideWithFade(speedBarFrame) end
    if chargesBarFrame and not LEM:IsInEditMode() then HideWithFade(chargesBarFrame) end
    if speedAbilityFrame and not LEM:IsInEditMode() then
        -- Wipe stale cooldown data so it cannot flash when the frame is next shown on remount
        if speedAbilityFrame.cooldown then
            speedAbilityFrame.cooldown:SetCooldown(0, 0)
            speedAbilityFrame.cooldown:Hide()
        end
        if speedAbilityFrame.whirlingSurgeReverseFill then
            speedAbilityFrame.whirlingSurgeReverseFill:Hide()
        end
        if staticChargeIcon then staticChargeIcon:Hide() end
        if whirlingSurgeIcon then whirlingSurgeIcon:Hide() end
        speedAbilityFrame:Hide()
    end
    if secondWindFrame and not LEM:IsInEditMode() then HideWithFade(secondWindFrame) end
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame then UIWidgetPowerBarContainerFrame:Show() end
    end
end

if CompatCheck then
    function zSkyridingBar:UpdateVigorFromWidget(widgetInfo)
        -- Use UI widget system like WeakAuras does
        if not widgetInfo or not widgetInfo.widgetID then
            return
        end

        local widgetData = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetInfo.widgetID)

        if not widgetData or not chargeFrame or not chargeFrame.bars then
            return
        end

        for i = 1, 6 do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Hide()
            end
        end

        for i = 1, math.min(widgetData.numTotalFrames, 6) do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Show()

                bar:SetMinMaxValues(0, 100 * BAR_MULTIPLIER)

                if widgetData.numFullFrames >= i then
                    -- full charge
                    updateChargeBarColor(bar, true, false)
                    bar:SetValue(100 * BAR_MULTIPLIER, Enum.StatusBarInterpolation.ExponentialEaseOut)
                elseif widgetData.numFullFrames + 1 == i then
                    -- recharging
                    local progress = 0
                    if widgetData.fillMax > widgetData.fillMin then
                        progress = ((widgetData.fillValue - widgetData.fillMin) / (widgetData.fillMax - widgetData.fillMin)) * 100
                    end
                    updateChargeBarColor(bar, false, true)
                    bar:SetValue(math.max(0, math.min(100, progress)) * BAR_MULTIPLIER, Enum.StatusBarInterpolation.ExponentialEaseOut)
                else
                    -- Empty charge
                    updateChargeBarColor(bar, false, false)
                    bar:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
                end
            end
        end
    end
end

function zSkyridingBar:UpdateChargeBars()
    if not chargeFrame or not chargeFrame.bars then return end

    if CompatCheck then
        return
    end

    local spellChargeInfo = C_Spell.GetSpellCharges(SURGE_FORWARD_SPELL_ID)

    if spellChargeInfo and spellChargeInfo.currentCharges and spellChargeInfo.maxCharges then
        local charges = spellChargeInfo.currentCharges
        local maxCharges = spellChargeInfo.maxCharges
        local start = spellChargeInfo.cooldownStartTime
        local duration = spellChargeInfo.cooldownDuration

        if self.db.profile.chargeRefreshSound and charges > previousChargeCount and chargesInitialized then
            playChargeSound(self.db.profile.chargeRefreshSoundId)
        end
        previousChargeCount = charges
        chargesInitialized = true

        for i = 1, math.min(maxCharges, 6) do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Show()
                bar:SetMinMaxValues(0, 100 * BAR_MULTIPLIER)

                if i <= charges then
                    updateChargeBarColor(bar, true, false)
                    bar:SetValue(100 * BAR_MULTIPLIER, Enum.StatusBarInterpolation.ExponentialEaseOut)
                    bar:GetStatusBarTexture():SetAlpha(1)
                elseif i == charges + 1 and start and duration and duration > 0 then
                    updateChargeBarColor(bar, false, true)
                    bar:SetMinMaxValues(0, 1)
                    vigorRechargeTimer = setBarRechargeTimer(bar, start, duration, vigorRechargeTimer)
                    bar:GetStatusBarTexture():SetAlpha(1)
                else
                    updateChargeBarColor(bar, false, false)
                    bar:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut)
                    bar:GetStatusBarTexture():SetAlpha(0)
                end
            end
        end

        for i = maxCharges + 1, 6 do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Hide()
                bar.lastProgress = nil
            end
        end
    end
end

function zSkyridingBar:UpdateStaticChargeAndWhirlingSurge()
    if not speedAbilityFrame then return end
    if self.db.profile.hideSpeedAbility then speedAbilityFrame:Hide() abilityFrameDirty = false return end
    abilityFrameDirty = false  -- cleared each call; set true below only if fill animation still in progress
    local fillActive = false   -- tracks whether a cooldown fill needs another tick

    local isGliding, isFlying = GetGlidingInfo()
    if not isGliding and not isFlying then
        speedAbilityFrame:Hide()
        speedAbilityFrame.whirlingSurgeReverseFill:Hide()
        return
    end

    -- Branch 1: Static Charge buff is active
    local staticChargeAura = C_UnitAuras.GetPlayerAuraBySpellID(STATIC_CHARGE_BUFF_ID)
    if staticChargeAura and (staticChargeAura.applications or 0) > 0 then
        speedAbilityFrame:Show()
        staticChargeIcon:Show()
        staticChargeText:Show()
        staticChargeText:SetText(staticChargeAura.applications or 0)
        whirlingSurgeIcon:Hide()

        if staticChargeAura.icon then
            staticChargeIcon:SetTexture(staticChargeAura.icon)
            staticChargeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if (staticChargeAura.applications or 0) == 10 then
            speedAbilityFrame.border:Show()
        else
            staticChargeIcon:SetVertexColor(1, 1, 1)
            speedAbilityFrame.border:Hide()
        end

        -- Check LR cooldown once; hide overlay if not on CD, show fill if it is
        local lrCooldown = C_Spell.GetSpellCooldown(LIGHTNING_RUSH_SPELL_ID)
        if not lrCooldown or lrCooldown.duration <= 0 or lrCooldown.startTime <= 0 then
            speedAbilityFrame.whirlingSurgeReverseFill:Hide()
            speedAbilityFrame.cooldown:Hide()
            speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
        else
            if lrCooldown.duration < 2 then
                abilityFrameDirty = true  -- GCD still active; keep polling until real cooldown registers
                return
            end
            -- Cancel any in-progress icon fade so a quick re-cast restores full visibility
            speedAbilityFrame.staticChargeIconFadeAnimGroup:Stop()
            staticChargeIcon:SetAlpha(1)
            fillActive = ApplyCooldownFill(
                lrCooldown.startTime, lrCooldown.duration,
                staticChargeIcon, speedAbilityFrame.staticChargeIconFadeAnimGroup,
                false)  -- only fade icon if no SC stacks remain at cooldown end
        end

        abilityFrameDirty = fillActive
        return
    end

    -- Branch 2: No Static Charge stacks, but Lightning Rush is on cooldown
    local lrCooldown = C_Spell.GetSpellCooldown(LIGHTNING_RUSH_SPELL_ID)
    if lrCooldown and lrCooldown.duration > 0 and lrCooldown.startTime > 0 then
        if lrCooldown.duration < 2 then
            abilityFrameDirty = true  -- GCD still active; keep polling until real cooldown registers
            return
        end
        speedAbilityFrame:Show()
        -- Cancel any in-progress icon fades so a quick re-cast restores full visibility
        speedAbilityFrame.staticChargeIconFadeAnimGroup:Stop()
        speedAbilityFrame.whirlingSurgeIconFadeAnimGroup:Stop()
        staticChargeIcon:SetAlpha(1)
        staticChargeIcon:Show()
        staticChargeText:Hide()
        whirlingSurgeIcon:Hide()
        speedAbilityFrame.border:Hide()
        local spellInfo = C_Spell.GetSpellInfo(STATIC_CHARGE_BUFF_ID)
        if spellInfo and spellInfo.iconID then
            staticChargeIcon:SetTexture(spellInfo.iconID)
            staticChargeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        staticChargeIcon:SetVertexColor(1, 1, 1)
        fillActive = ApplyCooldownFill(
            lrCooldown.startTime, lrCooldown.duration,
            staticChargeIcon, speedAbilityFrame.staticChargeIconFadeAnimGroup,
            true)  -- always fade icon when cooldown expires
        abilityFrameDirty = fillActive
        return
    end

    -- Branch 3: Whirling Surge is on cooldown
    local cooldownInfo = C_Spell.GetSpellCooldown(WHIRLING_SURGE_SPELL_ID)
    if cooldownInfo and cooldownInfo.duration > 0 and cooldownInfo.startTime > 0 then
        if cooldownInfo.duration < 2 then
            abilityFrameDirty = true  -- GCD still active; keep polling until real cooldown registers
            return
        end
        speedAbilityFrame:Show()
        -- Cancel any in-progress icon/shine fades so a quick re-cast restores full visibility
        speedAbilityFrame.whirlingSurgeIconFadeAnimGroup:Stop()
        speedAbilityFrame.shineFadeAnimGroup:Stop()
        speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
        whirlingSurgeIcon:SetAlpha(1)
        whirlingSurgeIcon:Show()
        staticChargeIcon:Hide()
        staticChargeText:Hide()
        speedAbilityFrame.border:Hide()
        local spellInfo = C_Spell.GetSpellInfo(WHIRLING_SURGE_SPELL_ID)
        if spellInfo and spellInfo.iconID then
            whirlingSurgeIcon:SetTexture(spellInfo.iconID)
            whirlingSurgeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        fillActive = ApplyCooldownFill(
            cooldownInfo.startTime, cooldownInfo.duration,
            whirlingSurgeIcon, speedAbilityFrame.whirlingSurgeIconFadeAnimGroup,
            true)  -- always fade icon when cooldown expires
        abilityFrameDirty = fillActive
        return
    end

    -- No ability active: reset everything and hide
    whirlingSurgeIcon:SetAlpha(1)
    whirlingSurgeIcon:Hide()
    speedAbilityFrame.whirlingSurgeReverseFill:Hide()
    speedAbilityFrame.cooldown:Hide()
    speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
    speedAbilityFrame._shineActive = false
    speedAbilityFrame:Hide()
end

function zSkyridingBar:UpdateSecondWind()
    if not secondWindBar or not secondWindFrame then return end

    local spellChargeInfo = C_Spell.GetSpellCharges(SECOND_WIND_SPELL_ID)

    if spellChargeInfo and spellChargeInfo.currentCharges ~= nil then
        local charges = spellChargeInfo.currentCharges
        local maxCharges = SECOND_WIND_MAX_CHARGES
        local start = spellChargeInfo.cooldownStartTime
        local duration = spellChargeInfo.cooldownDuration

        if secondWindFrame then secondWindFrame:Show() end

        if charges >= maxCharges then
            secondWindBar:SetValue(100 * BAR_MULTIPLIER, Enum.StatusBarInterpolation.ExponentialEaseOut)
            secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindThreeChargeColor))
        elseif charges > 0 and charges < maxCharges then
            -- Partial charges: fill bar shows progress toward the next recharge
            secondWindBar:SetMinMaxValues(0, 100 * BAR_MULTIPLIER)
            if start and duration and duration > 0 then
                secondWindRechargeTimer = setBarRechargeTimer(secondWindBar, start, duration, secondWindRechargeTimer)
            else
                secondWindBar:SetValue(100 * BAR_MULTIPLIER)
            end
            if charges == 1 then
                secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindTwoChargeColor))
                secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindOneChargeColor))
            else
                secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindThreeChargeColor))
                secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindTwoChargeColor))
            end
        else
            -- No charges: fill bar shows progress toward the first recharge
            secondWindBar:SetMinMaxValues(0, 100 * BAR_MULTIPLIER)
            if start and duration and duration > 0 then
                secondWindRechargeTimer = setBarRechargeTimer(secondWindBar, start, duration, secondWindRechargeTimer)
            else
                secondWindBar:SetValue(0)
            end
            secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindOneChargeColor))
            secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindNoChargeColor))
        end

        if secondWindText then
            local newText = charges .. "/" .. maxCharges
            if newText ~= secondWindText:GetText() then
                secondWindText:SetText(newText)
            end
        end
    else
        if secondWindFrame then secondWindFrame:Hide() end
    end
end

-- Opens EditMode after closing the options panel
function zSkyridingBar:OpenEditMode()
    LibStub("AceConfigDialog-3.0"):Close("zSkyridingBar")
    ShowUIPanel(EditModeManagerFrame)
end

-- Chat commands
SLASH_ZSKYRIDINGBAR1 = "/zskyridingbar"
SLASH_ZSKYRIDINGBAR2 = "/zskyriding"
SLASH_ZSKYRIDINGBAR3 = "/skybar"
SLASH_ZSKYRIDINGBAR4 = "/zsb"

SlashCmdList["ZSKYRIDINGBAR"] = function(msg)
    if msg == "toggle" then
        if zSkyridingBar.db.profile.enabled then
            zSkyridingBar:Disable()
        else
            zSkyridingBar:Enable()
        end
    elseif msg == "config" or msg == "options" or msg == "" then
        if LibStub and LibStub("AceConfigDialog-3.0", true) and zSkyridingBar.optionsRegistered then
            LibStub("AceConfigDialog-3.0"):Open("zSkyridingBar")
        else
            zSkyridingBar.print(L["Options not ready yet."])
        end
    elseif msg == "move" then
        zSkyridingBar:OpenEditMode()
    else
        zSkyridingBar.print(L["Commands:"])
        zSkyridingBar.print("  /zsb - " .. L["Open options"])
        zSkyridingBar.print("  /zsb move - " .. L["Open EditMode to reposition"])
        zSkyridingBar.print("  /zsb toggle - " .. L["Toggle addon"])
    end
end
