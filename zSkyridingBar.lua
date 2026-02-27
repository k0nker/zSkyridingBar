-- zSkyridingBar - A standalone skyriding information addon
-- REFACTORED: Separate frames for each UI element

-- Initialize Ace addon
local zSkyridingBar = LibStub("AceAddon-3.0"):NewAddon("zSkyridingBar", "AceTimer-3.0")
local BuildVersion, BuildBuild, BuildDate, BuildInterface = GetBuildInfo()

-- Get localization from AceLocale
local L = LibStub("AceLocale-3.0"):GetLocale("zSkyridingBar")

-- LibEditMode for in-game frame repositioning via EditMode
local LEM = LibStub("LibEditMode")

-- print function that accepts everything normal print would, like args and variables etc. I can  pass multiple args and concatenated strings
function zSkyridingBar.print(...)
    local args = { ... }
    DEFAULT_CHAT_FRAME:AddMessage("|cff0b808fzSkyridingBar:|r " .. table.concat(args, " "))
end

-- Constants
local ASCENT_SPELL_ID = 372610
local THRILL_BUFF_ID = 377234
local STATIC_CHARGE_BUFF_ID = 418590
local SURGE_FORWARD_SPELL_ID = 372608
local SECOND_WIND_SPELL_ID = 1227950
local WHIRLING_SURGE_SPELL_ID = 361584 -- Whirling Surge ability
local LIGHTNING_RUSH_SPELL_ID = 418592 -- Lightning Rush ability
local SLOW_SKYRIDING_RATIO = 705 / 830
local ASCENT_DURATION = 3.5
local TICK_RATE = 1 / 20 -- 20 FPS updates

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
    SECOND_WIND_SPELL_ID = 425782 -- Compatibility mode spell ID
end

-- Function to get default texture based on availability
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
        theme = "thick",

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
        speedBarWidth = 256,
        speedBarHeight = 18,
        speedBarTexture = getDefaultTexture(),
        speedBarBackgroundColor = { 0, 0, 0, 0.4 },
        speedBarNormalColor = { 0.749, 0.439, 0.173, 1 },
        speedBarThrillColor = { 0.482, 0.667, 1, 1 },
        speedBarBoostColor = { 0.314, 0.537, 0.157, 1 },

        -- Charge bar settings
        chargeBarWidth = 256,
        chargeBarHeight = 12,
        chargeBarSpacing = 2,
        speedIndicatorHeight = 18,
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

-- Theme definitions
local THEMES = {
    classic = {
        name = "Classic",
        speedBarHeight = 18,
        chargeBarHeight = 12,
        chargeBarSpacing = 2,
        speedIndicatorHeight = 20,
        chargeBarTexture = "default",
        chargeBarBorderSize = 1,
        chargesBarX = 0,
        chargesBarY = -5,
    },
    thick = {
        name = "Thick",
        speedBarHeight = 28,
        chargeBarHeight = 20,
        chargeBarSpacing = 0,
        speedIndicatorHeight = 30,
        chargeBarTexture = "default",
        chargeBarBorderSize = 1,
        chargesBarX = 0,
        chargesBarY = 0,
    },
}

local framevars = {
    speedBarFrame = {
    },
    chargeBarFrame = {
    },
    staticChargeFrame = {
    },
    secondWindFrame = {
    },
    whirlingSurgeFrame = {
    },
    masterMoveFrame = {
    },
}

-- Apply theme settings to profile
local function applyTheme(themeName)
    if not themeName or not THEMES[themeName] then
        themeName = "classic"
    end

    local theme = THEMES[themeName]
    local profile = zSkyridingBar.db.profile

    profile.speedBarHeight = theme.speedBarHeight
    profile.chargeBarHeight = theme.chargeBarHeight
    profile.chargeBarSpacing = theme.chargeBarSpacing
    profile.speedIndicatorHeight = theme.speedIndicatorHeight
    profile.chargesBarX = theme.chargesBarX
    profile.chargesBarY = theme.chargesBarY
    profile.chargeBarBorderSize = theme.chargeBarBorderSize
end

-- Local variables
local active = false
local updateHandle = nil
local ascentStart = 0
local isSlowSkyriding = true
local hasSkyriding = false

-- Frame references
local masterMoveFrame = nil
local speedBarFrame = nil
local chargesBarFrame = nil
local speedAbilityFrame = nil
local secondWindFrame = nil

-- UI element references
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
local speedBarAnimSpeed = 5
local chargeBarAnimSpeed = 10
local vigorAnimSpeed = 5

-- Localized functions
local GetTime = GetTime
local C_PlayerInfo = C_PlayerInfo
local C_UnitAuras = C_UnitAuras
local InCombatLockdown = InCombatLockdown

-- Helper: Play sound
local function playChargeSound(soundId)
    if not soundId or soundId == 0 then return end
    PlaySound(soundId, "Master")
end

-- Helper: Preview charge sound (called from options)
function zSkyridingBar:PreviewChargeSound()
    if self.db.profile.chargeRefreshSound then
        playChargeSound(self.db.profile.chargeRefreshSoundId)
    end
end

-- Helper: Get font path from LibSharedMedia font name
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
            -- Add more edge checks as needed (right, bottom, etc.)
        end
    end
end

-- Helper: Update charge bar color
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

local function AnimateStatusBar(bar, targetValue, smoothFactor)
    if not bar or not hasSkyriding then return end

    -- Initialize current value if needed
    if not bar.currentValue then
        bar.currentValue = bar:GetValue()
    end

    bar.targetValue = targetValue

    if not bar.animating then
        bar.animating = true

        bar:SetScript("OnUpdate", function(self, elapsed)
            if not self.targetValue then
                self:SetScript("OnUpdate", nil)
                self.animating = false
                return
            end

            -- Exponential smoothing (lerp)
            -- Lower smoothFactor = smoother but slower
            -- Higher smoothFactor = faster but more jittery
            local factor = math.min(1, (smoothFactor or 8) * elapsed)
            local diff = self.targetValue - self.currentValue

            if math.abs(diff) < 0.01 then
                self.currentValue = self.targetValue
                self:SetValue(self.targetValue)
                self:SetScript("OnUpdate", nil)
                self.animating = false
                return
            end

            self.currentValue = self.currentValue + (diff * factor)
            self:SetValue(self.currentValue)
        end)
    else
        -- Animation already running, just update target
        -- The OnUpdate script will smoothly transition to new target
    end
end


-- Addon lifecycle
function zSkyridingBar:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("zSkyridingBarDB", defaults, true)

    -- Event frame for event handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    if CompatCheck then
        eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
    end

    eventFrame:SetScript("OnEvent", function(frame, event, ...)
        -- if InCombatLockdown() then return end
        if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
        if event == "ADDON_LOADED" and select(1, ...) == "zSkyridingBar" then
            zSkyridingBar:OnAddonLoaded()
            if InCombatLockdown() then return end
        elseif event == "PLAYER_ENTERING_WORLD" then
            zSkyridingBar:OnPlayerEnteringWorld()
            if InCombatLockdown() then return end
        elseif event == "PLAYER_LOGIN" then
            zSkyridingBar:OnPlayerLogin()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if InCombatLockdown() then return end
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            zSkyridingBar:OnSpellcastSucceeded(event, ...)
        elseif event == "UNIT_AURA" then
            if InCombatLockdown() then return end
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            local unitTarget = select(1, ...)
            zSkyridingBar:OnUnitAura(unitTarget)
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
            zSkyridingBar:OnZoneChanged()
        elseif event == "UNIT_POWER_UPDATE" then
            if InCombatLockdown() then return end
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            local unitTarget, powerType = select(1, ...), select(2, ...)
            zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)
        elseif event == "PLAYER_CAN_GLIDE_CHANGED" then
            -- if InCombatLockdown() then return end
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            zSkyridingBar:CheckSkyridingAvailability()
            local isGliding, isFlying, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
            if not isGliding and not isFlying then
                hasSkyriding = false
            else
                hasSkyriding = true
            end
        elseif event == "UPDATE_UI_WIDGET" then
            if InCombatLockdown() then return end
            if EditModeManagerFrame and EditModeManagerFrame.editModeActive then return end
            if CompatCheck then
                local widgetInfo = select(1, ...)
                zSkyridingBar:UpdateVigorFromWidget(widgetInfo)
            end
        end
    end)

    C_Timer.After(3, function()
            self:CreateAllFrames()
    end)
    --self:CreateAllFrames()

    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
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

-- Helper: Release and hide all UI frames
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
    -- Also clear references to bars and icons
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
            chargesBarFrame:SetPoint("TOP", speedBarFrame, "BOTTOM", profile.chargesBarX, profile.chargesBarY)
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
    applyTheme(self.db.profile.theme)
    -- Update frame positions and appearance without destroying
    --self:UpdateFramePositions()
    if InCombatLockdown() then
        zSkyridingBar.print(L["Combat lockdown active. UI updates paused."])
        return
    end
    self:UpdateAllFrameAppearance()
    self:UpdateFonts()
    -- Update default vigor UI visibility
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame:IsVisible() then
            UIWidgetPowerBarContainerFrame:Hide()
        end
    end
end

function zSkyridingBar:CreateAllFrames()
    -- Pause for a few seconds, then continue

    applyTheme(self.db.profile.theme)
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
    if InCombatLockdown() then
        zSkyridingBar.print(L["Combat lockdown active. UI updates paused."])
        return
    end
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame:IsVisible() then
            UIWidgetPowerBarContainerFrame:Hide()
        end
    end
end

function zSkyridingBar:CreateMasterMoveFrame()
    masterMoveFrame = CreateFrame("Frame", nil, UIParent)
    masterMoveFrame:SetSize(300, 200)

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

    -- Add a Scale slider to the EditMode dialog for this frame
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
        speedBarFrame.editModeName = "zSkyridingBar - Speed Bar"
        LEM:AddFrame(speedBarFrame, function(frame, layoutName, point, x, y)
            zSkyridingBar.db.profile.multiSpeedBarPoint = point
            zSkyridingBar.db.profile.multiSpeedBarX = x
            zSkyridingBar.db.profile.multiSpeedBarY = y
        end, { point = defaults.profile.multiSpeedBarPoint, x = defaults.profile.multiSpeedBarX, y = defaults.profile.multiSpeedBarY })
        local activeLayout = LEM:GetActiveLayoutName()
        speedBarFrame:SetScale((activeLayout and profile.multiSpeedBarScales[activeLayout]) or 1.0)
        LEM:AddFrameSettings(speedBarFrame, { {
            kind = LEM.SettingType.Slider,
            name = L["Scale"],
            default = 1.0,
            minValue = 0.5,
            maxValue = 3.0,
            valueStep = 0.05,
            get = function(layoutName)
                return zSkyridingBar.db.profile.multiSpeedBarScales[layoutName] or 1.0
            end,
            set = function(layoutName, value)
                zSkyridingBar.db.profile.multiSpeedBarScales[layoutName] = value
                if speedBarFrame then speedBarFrame:SetScale(value) end
            end,
        } })
    end
    speedBarFrame:SetSize(profile.speedBarWidth, profile.speedBarHeight)
    speedBarFrame:SetFrameStrata(profile.frameStrata)
    speedBarFrame:SetFrameLevel(10)

    -- Speed bar (status bar)
    speedBar = CreateFrame("StatusBar", nil, speedBarFrame)
    speedBar:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
    speedBar:SetPoint("TOP", speedBarFrame, "TOP", 0, 0)

    local speedTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    speedBar:SetStatusBarTexture(speedTexture)
    speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarNormalColor))
    speedBar:SetMinMaxValues(20, 100)
    speedBar:SetValue(0)
    speedBar:SetClipsChildren(true)

    -- Background
    local speedBarBG = speedBar:CreateTexture(nil, "BACKGROUND")
    speedBarBG:SetAllPoints()
    speedBarBG:SetTexture(speedTexture)
    speedBarBG:SetVertexColor(unpack(self.db.profile.speedBarBackgroundColor))
    speedBar.bg = speedBarBG

    -- Borders (for classic theme)
    local borders = {}

    local topLine = speedBar:CreateTexture(nil, "OVERLAY")
    topLine:SetColorTexture(0, 0, 0, 1)
    topLine:SetPoint("TOPLEFT", speedBar, "TOPLEFT", 0, 0)
    topLine:SetPoint("TOPRIGHT", speedBar, "TOPRIGHT", 0, 0)
    topLine:SetHeight(1)
    table.insert(borders, topLine)

    local bottomLine = speedBar:CreateTexture(nil, "OVERLAY")
    bottomLine:SetColorTexture(0, 0, 0, 1)
    bottomLine:SetPoint("BOTTOMLEFT", speedBar, "BOTTOMLEFT", 0, 0)
    bottomLine:SetPoint("BOTTOMRIGHT", speedBar, "BOTTOMRIGHT", 0, 0)
    bottomLine:SetHeight(1)
    table.insert(borders, bottomLine)

    local leftLine = speedBar:CreateTexture(nil, "OVERLAY")
    leftLine:SetColorTexture(0, 0, 0, 1)
    leftLine:SetPoint("TOPLEFT", speedBar, "TOPLEFT", 0, 0)
    leftLine:SetPoint("BOTTOMLEFT", speedBar, "BOTTOMLEFT", 0, 0)
    leftLine:SetWidth(1)
    table.insert(borders, leftLine)

    local rightLine = speedBar:CreateTexture(nil, "OVERLAY")
    rightLine:SetColorTexture(0, 0, 0, 1)
    rightLine:SetPoint("TOPRIGHT", speedBar, "TOPRIGHT", 0, 0)
    rightLine:SetPoint("BOTTOMRIGHT", speedBar, "BOTTOMRIGHT", 0, 0)
    rightLine:SetWidth(1)
    table.insert(borders, rightLine)

    speedBar.borderLines = borders

    -- Always show borders for now
    for _, line in ipairs(borders) do
        line:Show()
    end

    -- Speed text
    speedText = speedBar:CreateFontString(nil, "OVERLAY")
    speedText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
    speedText:SetPoint("LEFT", speedBar, "LEFT", 5, 0)
    speedText:SetTextColor(unpack(self.db.profile.fontColor))
    speedText:SetText("")

    -- Angle text
    angleText = speedBar:CreateFontString(nil, "OVERLAY")
    angleText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
    angleText:SetPoint("RIGHT", speedBar, "RIGHT", -5, 0)
    angleText:SetTextColor(unpack(self.db.profile.fontColor))
    angleText:SetText("")

    -- Speed indicator
    if self.db.profile.showSpeedIndicator then
        local speedIndicator = speedBar:CreateTexture(nil, "ARTWORK")
        speedIndicator:SetTexture("Interface\\Buttons\\WHITE8x8")
        speedIndicator:SetSize(2, self.db.profile.speedIndicatorHeight)
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
        chargesBarFrame:SetPoint("TOP", speedBarFrame, "BOTTOM", profile.chargesBarX, profile.chargesBarY)
    else
        chargesBarFrame = CreateFrame("Frame", nil, UIParent)
        local pt = profile.multiChargesBarPoint or "CENTER"
        chargesBarFrame:SetPoint(pt, UIParent, pt, profile.multiChargesBarX, profile.multiChargesBarY)
        chargesBarFrame.editModeName = "zSkyridingBar - Charges"
        LEM:AddFrame(chargesBarFrame, function(frame, layoutName, point, x, y)
            zSkyridingBar.db.profile.multiChargesBarPoint = point
            zSkyridingBar.db.profile.multiChargesBarX = x
            zSkyridingBar.db.profile.multiChargesBarY = y
        end, { point = defaults.profile.multiChargesBarPoint, x = defaults.profile.multiChargesBarX, y = defaults.profile.multiChargesBarY })
        local activeLayout = LEM:GetActiveLayoutName()
        chargesBarFrame:SetScale((activeLayout and profile.multiChargesBarScales[activeLayout]) or 1.0)
        LEM:AddFrameSettings(chargesBarFrame, { {
            kind = LEM.SettingType.Slider,
            name = L["Scale"],
            default = 1.0,
            minValue = 0.5,
            maxValue = 3.0,
            valueStep = 0.05,
            get = function(layoutName)
                return zSkyridingBar.db.profile.multiChargesBarScales[layoutName] or 1.0
            end,
            set = function(layoutName, value)
                zSkyridingBar.db.profile.multiChargesBarScales[layoutName] = value
                if chargesBarFrame then chargesBarFrame:SetScale(value) end
            end,
        } })
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
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)

        bar.currentValue = 0
        bar.targetValue = 0
        bar.smoothTimer = nil

        -- Background
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(chargeTexture)
        bg:SetVertexColor(unpack(self.db.profile.chargeBarBackgroundColor))
        bar.bg = bg

        -- Borders for all themes
        for _, point in ipairs({
            { "TOPLEFT",    "TOPRIGHT",    10, "horizontal" },
            { "BOTTOMLEFT", "BOTTOMRIGHT", 10, "horizontal" },
            { "TOPLEFT",    "BOTTOMLEFT",  10, "vertical" },
            { "TOPRIGHT",   "BOTTOMRIGHT", 10, "vertical" },
        }) do
            local line = bar:CreateTexture(nil, "OVERLAY")
            line:SetColorTexture(0, 0, 0, 1)
            line:SetPoint(point[1], bar, point[1], 0, 0)
            line:SetPoint(point[2], bar, point[2], 0, 0)
            if point[4] == "horizontal" then
                line:SetHeight(self.db.profile.chargeBarBorderSize or 0)
            else
                line:SetWidth(self.db.profile.chargeBarBorderSize or 0)
            end
        end

        updateChargeBarColor(bar, false, false)
        chargeFrame.bars[i] = bar
        bar:Hide()
    end

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
        speedAbilityFrame.editModeName = "zSkyridingBar - Ability"
        LEM:AddFrame(speedAbilityFrame, function(frame, layoutName, point, x, y)
            zSkyridingBar.db.profile.multiSpeedAbilityPoint = point
            zSkyridingBar.db.profile.multiSpeedAbilityX = x
            zSkyridingBar.db.profile.multiSpeedAbilityY = y
        end, { point = defaults.profile.multiSpeedAbilityPoint, x = defaults.profile.multiSpeedAbilityX, y = defaults.profile.multiSpeedAbilityY })
        local activeLayout = LEM:GetActiveLayoutName()
        speedAbilityFrame:SetScale((activeLayout and profile.multiSpeedAbilityScales[activeLayout]) or 1.0)
        LEM:AddFrameSettings(speedAbilityFrame, { {
            kind = LEM.SettingType.Slider,
            name = L["Scale"],
            default = 1.0,
            minValue = 0.5,
            maxValue = 3.0,
            valueStep = 0.05,
            get = function(layoutName)
                return zSkyridingBar.db.profile.multiSpeedAbilityScales[layoutName] or 1.0
            end,
            set = function(layoutName, value)
                zSkyridingBar.db.profile.multiSpeedAbilityScales[layoutName] = value
                if speedAbilityFrame then speedAbilityFrame:SetScale(value) end
            end,
        } })
    end
    speedAbilityFrame:SetSize(40, 40)
    speedAbilityFrame:SetFrameStrata(profile.frameStrata)
    speedAbilityFrame:SetFrameLevel(10)

    -- Icon for Static Charge
    staticChargeIcon = speedAbilityFrame:CreateTexture(nil, "ARTWORK")
    staticChargeIcon:SetSize(36, 36)
    staticChargeIcon:SetPoint("CENTER", speedAbilityFrame, "CENTER", 0, 0)
    staticChargeIcon:Hide()

    -- Icon for Whirling Surge (separate texture for unified frame display)
    whirlingSurgeIcon = speedAbilityFrame:CreateTexture(nil, "ARTWORK")
    whirlingSurgeIcon:SetSize(36, 36)
    whirlingSurgeIcon:SetPoint("CENTER", speedAbilityFrame, "CENTER", 0, 0)
    whirlingSurgeIcon:Hide()

    -- Whirling Surge cooldown reverse fill overlay
    local whirlingSurgeReverseFill = speedAbilityFrame:CreateTexture(nil, "OVERLAY")
    whirlingSurgeReverseFill:SetColorTexture(0, 0, 0, 0.5)
    whirlingSurgeReverseFill:SetPoint("TOP", speedAbilityFrame, "TOP", 0, -2)
    whirlingSurgeReverseFill:SetPoint("LEFT", speedAbilityFrame, "LEFT", 2, 0)
    whirlingSurgeReverseFill:SetPoint("RIGHT", speedAbilityFrame, "RIGHT", -2, 0)
    whirlingSurgeReverseFill:SetHeight(36)
    whirlingSurgeReverseFill:Hide()
    speedAbilityFrame.whirlingSurgeReverseFill = whirlingSurgeReverseFill

    -- Whirling Surge shine overlay (must be after speedAbilityFrame is initialized)
    local whirlingSurgeShine = speedAbilityFrame:CreateTexture(nil, "OVERLAY")
    whirlingSurgeShine:SetTexture("Interface\\Cooldown\\star4")
    whirlingSurgeShine:SetBlendMode("ADD")
    whirlingSurgeShine:SetSize(64, 64)
    whirlingSurgeShine:SetPoint("CENTER", speedAbilityFrame, "CENTER", 0, 0)
    whirlingSurgeShine:SetAlpha(0)
    speedAbilityFrame.whirlingSurgeShine = whirlingSurgeShine

    -- Shine rotation animation
    local shineAnimGroup = whirlingSurgeShine:CreateAnimationGroup()
    local shineRotation = shineAnimGroup:CreateAnimation("Rotation")
    shineRotation:SetDuration(1.5)
    shineRotation:SetDegrees(320)
    speedAbilityFrame.whirlingSurgeShineAnimGroup = shineAnimGroup

    -- Border glow
    local staticChargeBorder = speedAbilityFrame:CreateTexture(nil, "BORDER")
    staticChargeBorder:SetSize(44, 44)
    staticChargeBorder:SetPoint("CENTER", staticChargeIcon, "CENTER", 0, 0)
    staticChargeBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    staticChargeBorder:SetBlendMode("ADD")
    staticChargeBorder:SetVertexColor(1, 1, 0.3, 0.3)
    staticChargeBorder:Hide()
    speedAbilityFrame.border = staticChargeBorder

    -- Stack count text
    staticChargeText = speedAbilityFrame:CreateFontString(nil, "OVERLAY")
    staticChargeText:SetFont(getFontPath(self.db.profile.fontFace), 14, self.db.profile.fontFlag)
    staticChargeText:SetPoint("BOTTOM", staticChargeIcon, "BOTTOM", 0, -5)
    staticChargeText:SetTextColor(1, 1, 1, 1)
    staticChargeText:SetText("")
    staticChargeText:Hide()

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
        secondWindFrame.editModeName = "zSkyridingBar - Second Wind"
        LEM:AddFrame(secondWindFrame, function(frame, layoutName, point, x, y)
            zSkyridingBar.db.profile.multiSecondWindPoint = point
            zSkyridingBar.db.profile.multiSecondWindX = x
            zSkyridingBar.db.profile.multiSecondWindY = y
        end, { point = defaults.profile.multiSecondWindPoint, x = defaults.profile.multiSecondWindX, y = defaults.profile.multiSecondWindY })
        local activeLayout = LEM:GetActiveLayoutName()
        secondWindFrame:SetScale((activeLayout and profile.multiSecondWindScales[activeLayout]) or 1.0)
        LEM:AddFrameSettings(secondWindFrame, { {
            kind = LEM.SettingType.Slider,
            name = L["Scale"],
            default = 1.0,
            minValue = 0.5,
            maxValue = 3.0,
            valueStep = 0.05,
            get = function(layoutName)
                return zSkyridingBar.db.profile.multiSecondWindScales[layoutName] or 1.0
            end,
            set = function(layoutName, value)
                zSkyridingBar.db.profile.multiSecondWindScales[layoutName] = value
                if secondWindFrame then secondWindFrame:SetScale(value) end
            end,
        } })
    end
    secondWindFrame:SetSize(profile.secondWindBarWidth, profile.secondWindBarHeight)
    secondWindFrame:SetFrameStrata(profile.frameStrata)
    secondWindFrame:SetFrameLevel(10)

    -- Second Wind bar (status bar for the single charge display)
    secondWindBar = CreateFrame("StatusBar", nil, secondWindFrame)
    secondWindBar:SetSize(self.db.profile.secondWindBarWidth, self.db.profile.secondWindBarHeight)
    secondWindBar:SetPoint("TOP", secondWindFrame, "TOP", 0, 0)

    local secondWindTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.secondWindBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    secondWindBar:SetStatusBarTexture(secondWindTexture)
    secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindNoChargeColor))
    secondWindBar:SetMinMaxValues(0, 100)
    secondWindBar:SetValue(0)

    -- Borders for all themes
    for _, point in ipairs({
        { "TOPLEFT",    "TOPRIGHT",    1, "horizontal" },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 1, "horizontal" },
        { "TOPLEFT",    "BOTTOMLEFT",  1, "vertical" },
        { "TOPRIGHT",   "BOTTOMRIGHT", 1, "vertical" },
    }) do
        local line = secondWindBar:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(0, 0, 0, 1)
        line:SetPoint(point[1], secondWindBar, point[1], 0, 0)
        line:SetPoint(point[2], secondWindBar, point[2], 0, 0)
        if point[4] == "horizontal" then
            line:SetHeight(1)
        else
            line:SetWidth(1)
        end
    end


    -- Background
    local secondWindBG = secondWindBar:CreateTexture(nil, "BACKGROUND")
    secondWindBG:SetAllPoints()
    secondWindBG:SetTexture(secondWindTexture)
    secondWindBG:SetVertexColor(unpack(self.db.profile.secondWindNoChargeColor))
    secondWindBar.bg = secondWindBG

    -- Charge count text (centered)
    secondWindText = secondWindBar:CreateFontString(nil, "OVERLAY")
    secondWindText:SetFont(getFontPath(self.db.profile.fontFace), self.db.profile.fontSize, self.db.profile.fontFlag)
    secondWindText:SetPoint("CENTER", secondWindBar, "CENTER", 0, 0)
    secondWindText:SetTextColor(unpack(self.db.profile.fontColor))
    secondWindText:SetText("0/3")

    secondWindBar.currentValue = 0
    secondWindBar.targetValue = 0
    secondWindBar.smoothTimer = nil

    secondWindFrame:Hide()
end

-- Update functions
function zSkyridingBar:UpdateSpeedBarAppearance()
    if not speedBar then return end

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
            local speedIndicator = speedBar:CreateTexture(nil, "ARTWORK")
            speedIndicator:SetTexture("Interface\\Buttons\\WHITE8x8")
            speedIndicator:SetSize(2, self.db.profile.speedIndicatorHeight)
            speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))
            speedBar.speedIndicator = speedIndicator
        end
        speedBar.speedIndicator:SetSize(2, self.db.profile.speedIndicatorHeight)
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

    -- Recalculate bar widths and spacing
    local numBars = #chargeFrame.bars
    local barWidth = (self.db.profile.chargeBarWidth - ((numBars - 1) * self.db.profile.chargeBarSpacing)) / numBars

    local chargeTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.chargeBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"

    for i, bar in ipairs(chargeFrame.bars) do
        -- Update size
        bar:SetSize(barWidth, self.db.profile.chargeBarHeight)

        -- Reposition with proper spacing
        if i == 1 then
            bar:SetPoint("LEFT", chargeFrame, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", chargeFrame.bars[i - 1], "RIGHT", self.db.profile.chargeBarSpacing, 0)
        end

        -- Update texture
        bar:SetStatusBarTexture(chargeTexture)

        -- Update background
        if bar.bg then
            bar.bg:SetTexture(chargeTexture)
            bar.bg:SetVertexColor(unpack(self.db.profile.chargeBarBackgroundColor))
        end
        -- Update borders
        local borderTextures = bar:GetRegions()
        for _, texture in ipairs({ borderTextures }) do
            if texture and texture:GetObjectType() == "Texture" and texture:GetDrawLayer() == "OVERLAY" then
                -- This is a border texture
                local height = texture:GetHeight()
                local width = texture:GetWidth()
                if height == 1 or width == 1 then
                    -- This is a border line
                    if height == 1 then
                        texture:SetHeight(self.db.profile.chargeBarBorderSize or 0)
                    else
                        texture:SetWidth(self.db.profile.chargeBarBorderSize or 0)
                    end
                end
            end
        end
        -- Update color based on current state
        local isFull = (i <= previousChargeCount)
        local isRecharging = (i == previousChargeCount + 1)
        updateChargeBarColor(bar, isFull, isRecharging)
    end
end

function zSkyridingBar:UpdateSecondWindBarAppearance()
    if not secondWindBar then return end

    secondWindBar:SetSize(self.db.profile.secondWindBarWidth, self.db.profile.secondWindBarHeight)
    local secondWindTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or
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
end

-- Event handlers
function zSkyridingBar:OnAddonLoaded()
    -- Register custom font with LibSharedMedia
    local LSM = LibStub("LibSharedMedia-3.0")
    LSM:Register("font", "Homespun", "Interface\\Addons\\zSkyridingBar\\Assets\\Fonts\\homespun.ttf")

    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnPlayerEnteringWorld()
    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnZoneChanged()
    self:ScheduleTimer(function() self:CheckSkyridingAvailability() end, 0.1)
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
    -- Handled by UpdateTracking
end

function zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)
    if InCombatLockdown() then return end
    if unitTarget == "player" and powerType == "ALTERNATE" then
        self:UpdateChargeBars()
    end
end

function zSkyridingBar:OnSpellcastSucceeded(event, unitTarget, castGUID, spellId)
    if InCombatLockdown() then return end
    if unitTarget == "player" and spellId == ASCENT_SPELL_ID then
        ascentStart = GetTime()
    end
end

function zSkyridingBar:CheckSkyridingAvailability()
    local isGliding, isFlying, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
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
        if active then
            active = false
            self:StopTracking()
        end
    end
end

function zSkyridingBar:StartTracking()
    if InCombatLockdown() then return end
    if not updateHandle then
        active = true
        updateHandle = self:ScheduleRepeatingTimer("UpdateTracking", TICK_RATE)

        if speedBarFrame then speedBarFrame:Show() end
        if speedBar then speedBar:Show() end
        if chargesBarFrame then chargesBarFrame:Show() end
        if speedAbilityFrame then speedAbilityFrame:Show() end
        if secondWindFrame then secondWindFrame:Show() end
        if secondWindBar then secondWindBar:Show() end

        self:UpdateChargeBars()
        self:UpdateStaticChargeAndWhirlingSurge()
        self:UpdateSecondWind()
    end
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame:IsVisible() then
            UIWidgetPowerBarContainerFrame:Hide()
        end
    end
end

function zSkyridingBar:StopTracking()
    if updateHandle then
        self:CancelTimer(updateHandle)
        updateHandle = nil
    end

    previousChargeCount = 0
    chargesInitialized = false

    if speedBarFrame and not LEM:IsInEditMode() then speedBarFrame:Hide() end
    if chargesBarFrame and not LEM:IsInEditMode() then chargesBarFrame:Hide() end
    if speedAbilityFrame and not LEM:IsInEditMode() then speedAbilityFrame:Hide() end
    if secondWindFrame and not LEM:IsInEditMode() then secondWindFrame:Hide() end
    if InCombatLockdown() then return end
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame then UIWidgetPowerBarContainerFrame:Show() end
    end
end

function zSkyridingBar:UpdateTracking()
    if not active then
        self:CheckSkyridingAvailability()
        if not active then
            return
        end
    end

    if not speedBar then return end
    if InCombatLockdown() then return end
    if CompatCheck then
        if UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame:IsVisible() then
            UIWidgetPowerBarContainerFrame:Hide()
        end
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    isSlowSkyriding = not FAST_FLYING_ZONES[select(8, GetInstanceInfo())]

    local isGliding, isFlying, forwardSpeed = C_PlayerInfo.GetGlidingInfo()

    if not isGliding and not isFlying then
        if LEM:IsInEditMode() then return end
        if speedBar then speedBar:Hide() end
        if speedBarFrame then speedBarFrame:Hide() end
        if chargesBarFrame then chargesBarFrame:Hide() end
        if chargeFrame then chargeFrame:Hide() end
        if speedAbilityFrame then speedAbilityFrame:Hide() end
        if staticChargeIcon then staticChargeIcon:Hide() end
        if whirlingSurgeIcon then whirlingSurgeIcon:Hide() end
        if secondWindBar then secondWindBar:Hide() end
        if secondWindFrame then secondWindFrame:Hide() end
        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
            speedAbilityFrame.whirlingSurgeReverseFill:Hide()
        end
        return
    else
        if speedBar then speedBar:Show() end
        if speedBarFrame then speedBarFrame:Show() end
        if chargesBarFrame then chargesBarFrame:Show() end
        if chargeFrame then chargeFrame:Show() end
        if secondWindFrame then secondWindFrame:Show() end
        if secondWindBar then secondWindBar:Show() end
    end

    local adjustedSpeed = forwardSpeed
    if isSlowSkyriding then
        adjustedSpeed = adjustedSpeed / SLOW_SKYRIDING_RATIO
    end

    AnimateStatusBar(speedBar, math.min(100, math.max(20, adjustedSpeed)), speedBarAnimSpeed)

    if speedText and self.db.profile.speedShow then
        local speedTextFormat, speedTextFactor = "", 1
        if self.db.profile.speedUnits == 1 then
            speedTextFormat = "%.1fyd/s"
        else
            speedTextFormat = "%.0f%%"
            speedTextFactor = 100 / 7
        end

        local speedDisplay = forwardSpeed < 1 and "" or string.format(speedTextFormat, forwardSpeed * speedTextFactor)
        speedText:SetText(speedDisplay)
    end

    self:UpdatespeedBarNormalColors(forwardSpeed)

    if not InCombatLockdown() then
        self:UpdateChargeBars()
        self:UpdateStaticChargeAndWhirlingSurge()
        self:UpdateSecondWind()
        -- self:UpdateWhirlingSurge() -- unified in UpdateStaticChargeAndWhirlingSurge
    end
end

function zSkyridingBar:UpdatespeedBarNormalColors(currentSpeed)
    if not speedBar or InCombatLockdown() then return end

    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    local maxGlideSpeed = isSlowSkyriding and SLOW_ZONE_MAX_GLIDE or FAST_ZONE_MAX_GLIDE
    local inFastMode = currentSpeed and currentSpeed > (maxGlideSpeed + 0.1) or false

    if inFastMode then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarBoostColor))
    elseif thrill then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarThrillColor))
    else
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarNormalColor))
    end
end

if CompatCheck then
    function zSkyridingBar:UpdateVigorFromWidget(widgetInfo)
        if InCombatLockdown() then return end
        -- Use UI widget system like WeakAuras does
        if not widgetInfo or not widgetInfo.widgetID then
            return
        end

        local widgetData = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetInfo.widgetID)

        if not widgetData or not chargeFrame or not chargeFrame.bars then
            return
        end

        -- Hide all bars first
        for i = 1, 6 do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Hide()
            end
        end

        -- Update bars based on widget data
        for i = 1, math.min(widgetData.numTotalFrames, 6) do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Show()

                -- Set up the bar range (0-100 for percentage-like display)
                bar:SetMinMaxValues(0, 100)

                if widgetData.numFullFrames >= i then
                    -- Full charge - instantly fill to 100%
                    updateChargeBarColor(bar, true, false)
                    AnimateStatusBar(bar, 100, vigorAnimSpeed)
                elseif widgetData.numFullFrames + 1 == i then
                    -- Currently regenerating charge - show smooth progress
                    local progress = 0
                    if widgetData.fillMax > widgetData.fillMin then
                        progress = ((widgetData.fillValue - widgetData.fillMin) / (widgetData.fillMax - widgetData.fillMin)) * 100
                    end
                    updateChargeBarColor(bar, false, true)
                    AnimateStatusBar(bar, math.max(0, math.min(100, progress)), vigorAnimSpeed)
                else
                    -- Empty charge
                    updateChargeBarColor(bar, false, false)
                    AnimateStatusBar(bar, 0, vigorAnimSpeed)
                end
            end
        end
    end
end

function zSkyridingBar:UpdateChargeBars()
    if InCombatLockdown() then return end
    if not chargeFrame or not chargeFrame.bars or InCombatLockdown() then return end

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
                bar:SetMinMaxValues(0, 100)

                if i <= charges then
                    updateChargeBarColor(bar, true, false)
                    if bar.targetValue ~= 100 then
                        bar:SetValue(100)
                        bar.currentValue = 100
                        bar.targetValue = 100
                    end
                    bar:GetStatusBarTexture():SetAlpha(1)
                elseif i == charges + 1 and start and duration and duration > 0 then
                    local elapsed = GetTime() - start
                    local progress = math.min(100, (elapsed / duration) * 100)
                    updateChargeBarColor(bar, false, true)
                    -- Only animate if progress changed by more than 0.5%
                    if not bar.lastProgress or math.abs(bar.lastProgress - progress) > 0.5 then
                        AnimateStatusBar(bar, progress, chargeBarAnimSpeed)
                        bar.lastProgress = progress
                    end
                    bar:GetStatusBarTexture():SetAlpha(1)
                else
                    updateChargeBarColor(bar, false, false)
                    if bar.targetValue ~= 0 then
                        bar:SetValue(0)
                        bar.currentValue = 0
                        bar.targetValue = 0
                    end
                    bar:GetStatusBarTexture():SetAlpha(0)
                    bar.lastProgress = nil
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
    if InCombatLockdown() then return end
    if not speedAbilityFrame or InCombatLockdown() then return end

    local isGliding, isFlying = C_PlayerInfo.GetGlidingInfo()
    if not isGliding and not isFlying then
        if speedAbilityFrame then speedAbilityFrame:Hide() end
        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
            speedAbilityFrame.whirlingSurgeReverseFill:Hide()
        end
        return
    end

    -- Check for Static Charge buff
    local staticChargeAura = C_UnitAuras.GetPlayerAuraBySpellID(STATIC_CHARGE_BUFF_ID)
    if staticChargeAura and (staticChargeAura.applications or 0) > 0 then
        if speedAbilityFrame then speedAbilityFrame:Show() end
        if staticChargeIcon then staticChargeIcon:Show() end
        if staticChargeText then staticChargeText:Show() end
        if staticChargeText then staticChargeText:SetText(staticChargeAura.applications or 0) end
        if speedAbilityFrame and speedAbilityFrame.border then speedAbilityFrame.border:Hide() end
        if whirlingSurgeIcon then whirlingSurgeIcon:Hide() end
        -- hide the whirling surge reverse fill if lightning surge isn't on cooldown currently
        local lightningSurgeCooldownInfo = C_Spell.GetSpellCooldown(LIGHTNING_RUSH_SPELL_ID)
        if lightningSurgeCooldownInfo and not lightningSurgeCooldownInfo.isEnabled then
            if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
                speedAbilityFrame.whirlingSurgeReverseFill:Hide()
            end
            if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
            end
        end
        if staticChargeAura.icon and staticChargeIcon then
            staticChargeIcon:SetTexture(staticChargeAura.icon)
            staticChargeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if (staticChargeAura.applications or 0) == 10 then
            if speedAbilityFrame and speedAbilityFrame.border then speedAbilityFrame.border:Show() end
        else
            if staticChargeIcon then staticChargeIcon:SetVertexColor(1, 1, 1) end
            if speedAbilityFrame and speedAbilityFrame.border then speedAbilityFrame.border:Hide() end
        end
        if speedAbilityFrame and speedAbilityFrame.cooldown then
            speedAbilityFrame.cooldown:Hide()
        end
        local lightningRushCooldownInfo = C_Spell.GetSpellCooldown(LIGHTNING_RUSH_SPELL_ID)
        if lightningRushCooldownInfo and lightningRushCooldownInfo.isEnabled and lightningRushCooldownInfo.duration > 0 and lightningRushCooldownInfo.startTime > 0 then
            if lightningRushCooldownInfo.duration < 2 then
                return
            end
            if speedAbilityFrame and speedAbilityFrame.cooldown then
                speedAbilityFrame.cooldown:SetCooldown(lightningRushCooldownInfo.startTime,
                    lightningRushCooldownInfo.duration)
                speedAbilityFrame.cooldown:Show()
            end
            -- Show and update reverse fill overlay
            if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
                local now = GetTime()
                local elapsed = now - lightningRushCooldownInfo.startTime
                local progress = math.min(1, math.max(0, elapsed / lightningRushCooldownInfo.duration))
                local fillHeight = 36 * (1 - progress)
                speedAbilityFrame.whirlingSurgeReverseFill:SetHeight(fillHeight)
                speedAbilityFrame.whirlingSurgeReverseFill:ClearAllPoints()
                speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("BOTTOM", speedAbilityFrame, "BOTTOM", 0, 2)
                speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("LEFT", speedAbilityFrame, "LEFT", 2, 0)
                speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("RIGHT", speedAbilityFrame, "RIGHT", -2, 0)
                speedAbilityFrame.whirlingSurgeReverseFill:Show()
                -- Trigger shine when cooldown just ends
                if fillHeight and fillHeight <= 1 and not speedAbilityFrame._shineActive then
                    speedAbilityFrame._shineActive = true
                    if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                        speedAbilityFrame
                            .whirlingSurgeShine:SetAlpha(1)
                    end
                    if staticChargeIcon then staticChargeIcon:SetAlpha(1) end
                    if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShineAnimGroup then
                        speedAbilityFrame.whirlingSurgeShineAnimGroup:Play()
                    end
                    -- Fade out both shine and icon over 1s if no Static Charge stacks remain
                    local staticChargeCheck = C_UnitAuras.GetPlayerAuraBySpellID(STATIC_CHARGE_BUFF_ID)
                    if not staticChargeCheck or (staticChargeCheck.applications or 0) == 0 then
                        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                            local fadeAnimGroup = speedAbilityFrame.whirlingSurgeShine:CreateAnimationGroup()
                            local fadeAnim = fadeAnimGroup:CreateAnimation("Alpha")
                            fadeAnim:SetDuration(1)
                            fadeAnim:SetFromAlpha(1)
                            fadeAnim:SetToAlpha(0)
                            fadeAnim:SetOrder(1)
                            fadeAnimGroup:SetScript("OnFinished", function()
                                speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
                            end)
                            fadeAnimGroup:Play()
                        end
                        if staticChargeIcon then
                            local iconFadeAnimGroup = staticChargeIcon:CreateAnimationGroup()
                            local iconFadeAnim = iconFadeAnimGroup:CreateAnimation("Alpha")
                            iconFadeAnim:SetDuration(1)
                            iconFadeAnim:SetFromAlpha(1)
                            iconFadeAnim:SetToAlpha(0)
                            iconFadeAnim:SetOrder(1)
                            iconFadeAnimGroup:SetScript("OnFinished", function()
                                staticChargeIcon:SetAlpha(0)
                                staticChargeIcon:Hide()
                            end)
                            iconFadeAnimGroup:Play()
                        end
                    else
                        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                            local fadeAnimGroup = speedAbilityFrame.whirlingSurgeShine:CreateAnimationGroup()
                            local fadeAnim = fadeAnimGroup:CreateAnimation("Alpha")
                            fadeAnim:SetDuration(1)
                            fadeAnim:SetFromAlpha(1)
                            fadeAnim:SetToAlpha(0)
                            fadeAnim:SetOrder(1)
                            fadeAnimGroup:SetScript("OnFinished", function()
                                speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
                            end)
                            fadeAnimGroup:Play()
                        end
                    end
                    C_Timer.After(1, function()
                        if speedAbilityFrame then speedAbilityFrame._shineActive = false end
                    end)
                end
            else
                if speedAbilityFrame then speedAbilityFrame._shineActive = false end
            end
        end

        return
    end

    -- If no Static Charge, check Lightning Rush cooldown
    local lightningRushCooldownInfo = C_Spell.GetSpellCooldown(LIGHTNING_RUSH_SPELL_ID)
    if lightningRushCooldownInfo and lightningRushCooldownInfo.isEnabled and lightningRushCooldownInfo.duration > 0 and lightningRushCooldownInfo.startTime > 0 then
        if lightningRushCooldownInfo.duration < 2 then
            return
        end
        if speedAbilityFrame then speedAbilityFrame:Show() end
        if staticChargeIcon then staticChargeIcon:Show() end
        if staticChargeText then staticChargeText:Hide() end
        if whirlingSurgeIcon then whirlingSurgeIcon:Hide() end
        if speedAbilityFrame and speedAbilityFrame.border then speedAbilityFrame.border:Hide() end
        local staticChargeSpellInfo = C_Spell.GetSpellInfo(STATIC_CHARGE_BUFF_ID)
        if staticChargeSpellInfo and staticChargeSpellInfo.iconID and staticChargeIcon then
            staticChargeIcon:SetTexture(staticChargeSpellInfo.iconID)
            staticChargeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if staticChargeIcon then staticChargeIcon:SetVertexColor(1, 1, 1) end
        if speedAbilityFrame and speedAbilityFrame.cooldown then
            speedAbilityFrame.cooldown:SetCooldown(lightningRushCooldownInfo.startTime,
                lightningRushCooldownInfo.duration)
            speedAbilityFrame.cooldown:Show()
        end
        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
            local now = GetTime()
            local elapsed = now - lightningRushCooldownInfo.startTime
            local progress = math.min(1, math.max(0, elapsed / lightningRushCooldownInfo.duration))
            local fillHeight = 36 * (1 - progress)
            speedAbilityFrame.whirlingSurgeReverseFill:SetHeight(fillHeight)
            speedAbilityFrame.whirlingSurgeReverseFill:ClearAllPoints()
            speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("BOTTOM", speedAbilityFrame, "BOTTOM", 0, 2)
            speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("LEFT", speedAbilityFrame, "LEFT", 2, 0)
            speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("RIGHT", speedAbilityFrame, "RIGHT", -2, 0)
            speedAbilityFrame.whirlingSurgeReverseFill:Show()
            if fillHeight and fillHeight <= 1 and not (speedAbilityFrame and speedAbilityFrame._shineActive) then
                if speedAbilityFrame then speedAbilityFrame._shineActive = true end
                if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                    speedAbilityFrame.whirlingSurgeShine
                        :SetAlpha(1)
                end
                if staticChargeIcon then staticChargeIcon:SetAlpha(1) end
                if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShineAnimGroup then
                    speedAbilityFrame.whirlingSurgeShineAnimGroup:Play()
                end
                local staticChargeCheck = C_UnitAuras.GetPlayerAuraBySpellID(STATIC_CHARGE_BUFF_ID)
                if not staticChargeCheck or (staticChargeCheck.applications or 0) == 0 then
                    if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                        local fadeAnimGroup = speedAbilityFrame.whirlingSurgeShine:CreateAnimationGroup()
                        local fadeAnim = fadeAnimGroup:CreateAnimation("Alpha")
                        fadeAnim:SetDuration(1)
                        fadeAnim:SetFromAlpha(1)
                        fadeAnim:SetToAlpha(0)
                        fadeAnim:SetOrder(1)
                        fadeAnimGroup:SetScript("OnFinished", function()
                            speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
                        end)
                        fadeAnimGroup:Play()
                    end
                    if staticChargeIcon then
                        local iconFadeAnimGroup = staticChargeIcon:CreateAnimationGroup()
                        local iconFadeAnim = iconFadeAnimGroup:CreateAnimation("Alpha")
                        iconFadeAnim:SetDuration(1)
                        iconFadeAnim:SetFromAlpha(1)
                        iconFadeAnim:SetToAlpha(0)
                        iconFadeAnim:SetOrder(1)
                        iconFadeAnimGroup:SetScript("OnFinished", function()
                            staticChargeIcon:SetAlpha(0)
                            staticChargeIcon:Hide()
                        end)
                        iconFadeAnimGroup:Play()
                    end
                else
                    if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                        local fadeAnimGroup = speedAbilityFrame.whirlingSurgeShine:CreateAnimationGroup()
                        local fadeAnim = fadeAnimGroup:CreateAnimation("Alpha")
                        fadeAnim:SetDuration(1)
                        fadeAnim:SetFromAlpha(1)
                        fadeAnim:SetToAlpha(0)
                        fadeAnim:SetOrder(1)
                        fadeAnimGroup:SetScript("OnFinished", function()
                            speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
                        end)
                        fadeAnimGroup:Play()
                    end
                end
                C_Timer.After(1, function()
                    if speedAbilityFrame then speedAbilityFrame._shineActive = false end
                end)
            end
        else
            if speedAbilityFrame then speedAbilityFrame._shineActive = false end
        end
        return
    end

    local cooldownInfo = C_Spell.GetSpellCooldown(WHIRLING_SURGE_SPELL_ID)
    local shineTriggered = false
    if cooldownInfo and cooldownInfo.isEnabled and cooldownInfo.duration > 0 and cooldownInfo.startTime > 0 then
        if cooldownInfo.duration < 2 then
            return
        end
        if speedAbilityFrame then speedAbilityFrame:Show() end
        if whirlingSurgeIcon then whirlingSurgeIcon:Show() end
        if staticChargeIcon then staticChargeIcon:Hide() end
        if staticChargeText then staticChargeText:Hide() end
        if speedAbilityFrame and speedAbilityFrame.border then speedAbilityFrame.border:Hide() end
        local spellInfo = C_Spell.GetSpellInfo(WHIRLING_SURGE_SPELL_ID)
        if spellInfo and spellInfo.iconID and whirlingSurgeIcon then
            whirlingSurgeIcon:SetTexture(spellInfo.iconID)
            whirlingSurgeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if speedAbilityFrame and speedAbilityFrame.cooldown then
            speedAbilityFrame.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
            speedAbilityFrame.cooldown:Show()
        end
        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
            local now = GetTime()
            local elapsed = now - cooldownInfo.startTime
            local progress = math.min(1, math.max(0, elapsed / cooldownInfo.duration))
            local fillHeight = 36 * (1 - progress)
            speedAbilityFrame.whirlingSurgeReverseFill:SetHeight(fillHeight)
            speedAbilityFrame.whirlingSurgeReverseFill:ClearAllPoints()
            speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("BOTTOM", speedAbilityFrame, "BOTTOM", 0, 2)
            speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("LEFT", speedAbilityFrame, "LEFT", 2, 0)
            speedAbilityFrame.whirlingSurgeReverseFill:SetPoint("RIGHT", speedAbilityFrame, "RIGHT", -2, 0)
            speedAbilityFrame.whirlingSurgeReverseFill:Show()
            if fillHeight and fillHeight <= 1 and not (speedAbilityFrame and speedAbilityFrame._shineActive) then
                if speedAbilityFrame then speedAbilityFrame._shineActive = true end
                if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                    speedAbilityFrame.whirlingSurgeShine
                        :SetAlpha(1)
                end
                if whirlingSurgeIcon then whirlingSurgeIcon:SetAlpha(1) end
                if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShineAnimGroup then
                    speedAbilityFrame.whirlingSurgeShineAnimGroup:Play()
                end
                if whirlingSurgeIcon then
                    local iconFadeAnimGroup = whirlingSurgeIcon:CreateAnimationGroup()
                    local iconFadeAnim = iconFadeAnimGroup:CreateAnimation("Alpha")
                    iconFadeAnim:SetDuration(1)
                    iconFadeAnim:SetFromAlpha(1)
                    iconFadeAnim:SetToAlpha(0)
                    iconFadeAnim:SetOrder(1)
                    iconFadeAnimGroup:SetScript("OnFinished", function()
                        whirlingSurgeIcon:SetAlpha(0)
                        whirlingSurgeIcon:Hide()
                    end)
                    iconFadeAnimGroup:Play()
                end
                if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
                    local fadeAnimGroup = speedAbilityFrame.whirlingSurgeShine:CreateAnimationGroup()
                    local fadeAnim = fadeAnimGroup:CreateAnimation("Alpha")
                    fadeAnim:SetDuration(1)
                    fadeAnim:SetFromAlpha(1)
                    fadeAnim:SetToAlpha(0)
                    fadeAnim:SetOrder(1)
                    fadeAnimGroup:SetScript("OnFinished", function()
                        speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
                    end)
                    fadeAnimGroup:Play()
                end
                C_Timer.After(1, function()
                    if speedAbilityFrame then speedAbilityFrame._shineActive = false end
                end)
            end
        else
            if speedAbilityFrame then speedAbilityFrame._shineActive = false end
        end
        return
    else
        if whirlingSurgeIcon then whirlingSurgeIcon:SetAlpha(1) end
        if whirlingSurgeIcon then whirlingSurgeIcon:Hide() end
        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
            speedAbilityFrame.whirlingSurgeReverseFill:Hide()
        end
        if speedAbilityFrame and speedAbilityFrame.whirlingSurgeShine then
            speedAbilityFrame.whirlingSurgeShine:SetAlpha(0)
        end
        if speedAbilityFrame then speedAbilityFrame._shineActive = false end
    end

    -- If neither, hide the frame and overlay
    if speedAbilityFrame then speedAbilityFrame:Hide() end
    if speedAbilityFrame and speedAbilityFrame.whirlingSurgeReverseFill then
        speedAbilityFrame.whirlingSurgeReverseFill:Hide()
    end
end

function zSkyridingBar:UpdateSecondWind()
    if InCombatLockdown() then return end
    if not secondWindBar or not secondWindFrame or InCombatLockdown() then return end

    local spellChargeInfo = C_Spell.GetSpellCharges(SECOND_WIND_SPELL_ID)

    if spellChargeInfo and spellChargeInfo.currentCharges ~= nil then
        local charges = spellChargeInfo.currentCharges
        local maxCharges = SECOND_WIND_MAX_CHARGES
        local start = spellChargeInfo.cooldownStartTime
        local duration = spellChargeInfo.cooldownDuration

        if secondWindFrame then secondWindFrame:Show() end

        if charges >= maxCharges then
            secondWindBar:SetValue(100)
            secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindThreeChargeColor))
        elseif charges > 0 and charges < maxCharges then
            -- Has some charges, show progress of next recharge
            if start and duration and duration > 0 then
                local elapsed = GetTime() - start
                local progress = math.min(100, (elapsed / duration) * 100)
                secondWindBar:SetValue(progress)
                if charges == 0 then
                    secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindOneChargeColor))
                    secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindNoChargeColor))
                elseif charges == 1 then
                    secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindTwoChargeColor))
                    secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindOneChargeColor))
                else
                    secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindThreeChargeColor))
                    secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindTwoChargeColor))
                end
            else
                secondWindBar:SetValue(100)
                secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindThreeChargeColor))
                secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindTwoChargeColor))
            end
        else
            -- No charges, show cooldown
            if start and duration and duration > 0 then
                local elapsed = GetTime() - start
                local progress = math.min(100, (elapsed / duration) * 100)
                secondWindBar:SetValue(progress)
                secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindOneChargeColor))
                secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindNoChargeColor))
            else
                secondWindBar:SetValue(0)
                secondWindBar:SetStatusBarColor(unpack(self.db.profile.secondWindNoChargeColor))
                secondWindBar.bg:SetVertexColor(unpack(self.db.profile.secondWindNoChargeColor))
            end
        end

        if secondWindText then secondWindText:SetText(charges .. "/" .. maxCharges) end
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
