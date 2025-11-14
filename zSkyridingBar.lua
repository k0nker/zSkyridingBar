-- zSkyridingBar - A standalone skyriding information addon

-- Initialize Ace addon
local zSkyridingBar = LibStub("AceAddon-3.0"):NewAddon("zSkyridingBar", "AceTimer-3.0")

-- Constants
local ASCENT_SPELL_ID = 372610
local THRILL_BUFF_ID = 377234
local STATIC_CHARGE_BUFF_ID = 418590
local SLOW_SKYRIDING_RATIO = 705 / 830
local ASCENT_DURATION = 3.5
local TICK_RATE = 1 / 20 -- 20 FPS updates

-- Fast flying zones (where full speed is available)
-- Note: If a zone is not in this list, it will default to slow skyriding (70.5% speed)
local FAST_FLYING_ZONES = {
    [2444] = true, -- Dragon Isles
    [2454] = true, -- Zaralek Cavern
    [2548] = true, -- Emerald Dream
    [2516] = true, -- Nokhud Offensive
    [2522] = true, -- Vault of the Incarnates
    [2569] = true, -- Aberrus, the Shadowed Crucible
}

-- Speed thresholds (in yd/s) for color detection
local SLOW_ZONE_MAX_GLIDE = 55.2   -- Max gliding speed in normal zones (789%)
local FAST_ZONE_MAX_GLIDE = 65.0   -- Max gliding speed in Dragonflight zones (929%)

-- Function to get default texture based on availability
local function getDefaultTexture()
    -- Try to get LibSharedMedia-3.0
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        -- Check if "Clean" texture is available
        local textures = LSM:List("statusbar")
        for _, texture in ipairs(textures) do
            if texture == "Clean" then
                return "Clean"
            end
        end

        -- Check if "Solid" texture is available as fallback
        for _, texture in ipairs(textures) do
            if texture == "Solid" then
                return "Solid"
            end
        end
    end

    -- Ultimate fallback to Blizzard default
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

-- Default settings
local defaults = {
    profile = {
        enabled = true,
        speedShow = true,
        speedUnits = 2,    -- 1 = yd/s, 2 = move%
        hideDefaultSpeedUI = true,
        theme = "classic", -- "classic" or "modern"

        -- Position settings
        frameX = 0,
        frameY = -167,
        frameScale = 1,
        frameStrata = "MEDIUM",

        -- Speed bar settings
        speedBarWidth = 256,
        speedBarHeight = 18,
        speedBarTexture = getDefaultTexture(),
        speedBarColor = { 0.749, 0.439, 0.173, 1 },       -- not recharging
        speedBarThrillColor = { 0.314, 0.537, 0.157, 1 }, -- recharging, but at an optimal speed
        speedBarBoostColor = { 0.2, 0.4, 0.45, 1 },       -- super fast color
        speedBarBackgroundColor = { 0, 0, 0, 0.4 },

        -- Vigor bar settings
        chargeBarWidth = 256,
        chargeBarHeight = 12,
        chargeBarSpacing = 2,
        speedChargeSpacing = 5,    -- Space between speed bar and charge bars
        speedIndicatorHeight = 18, -- Height of speed indicator (should match speedBarHeight)
        chargeBarTexture = getDefaultTexture(),
        chargeBarFullColor = { 0.2, 0.37, 0.8, 1 },
        chargeBarFastRechargeColor = { 0.314, 0.537, 0.3, 1 },
        chargeBarSlowRechargeColor = { 0.53, 0.29, 0.2, 1 },
        chargeBarEmptyColor = { 0.15, 0.15, 0.15, 0.8 },
        chargeBarBackgroundColor = { 0, 0, 0, 0.4 },

        -- Speed indicator settings
        showSpeedIndicator = true,
        speedIndicatorColor = { 1, 1, 1, 1 }, -- White indicator

        -- Font settings
        fontSize = 12,
        fontFace = "Fonts\\FRIZQT__.TTF",
        fontFlags = "OUTLINE",

        -- Sound settings
        chargeRefreshSound = true,
        chargeRefreshSoundId = 39516, -- Default: Store Purchase sound
    }
}

-- Theme definitions - each theme defines bar dimensions and styling
local THEMES = {
    classic = {
        name = "Classic",
        speedBarHeight = 18,
        chargeBarHeight = 12,
        chargeBarSpacing = 2,
        speedChargeSpacing = -10,
        speedIndicatorHeight = 20,
        chargeBarTexture = "default", -- Will use current texture
        borderSize = 2,
    },
    modern = {
        name = "Modern",
        speedBarHeight = 28,
        chargeBarHeight = 22,
        chargeBarSpacing = 0,
        speedChargeSpacing = 0,
        speedIndicatorHeight = 28,
        chargeBarTexture = "Solid", -- Use Solid texture for modern look
        borderSize = 0,
    },
}

-- Apply theme settings to profile
local function applyTheme(themeName)
    if not themeName or not THEMES[themeName] then
        themeName = "classic"
    end

    local theme = THEMES[themeName]
    local profile = zSkyridingBar.db.profile

    -- Apply theme dimensions
    profile.speedBarHeight = theme.speedBarHeight
    profile.chargeBarHeight = theme.chargeBarHeight
    profile.chargeBarSpacing = theme.chargeBarSpacing
    profile.speedChargeSpacing = theme.speedChargeSpacing
    profile.speedIndicatorHeight = theme.speedIndicatorHeight
    profile.chargeBarSpacing = theme.chargeBarSpacing

    -- Apply texture if specified
    if theme.chargeBarTexture == "Solid" then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM then
            profile.chargeBarTexture = "Solid"
        end
    end
end

-- Local variables
local active = false
local updateHandle = nil
local ascentStart = 0
local isSlowSkyriding = true
local mainFrame = nil
local speedBar = nil
local previousChargeCount = 0    -- Track previous charge count for sound notifications
local chargesInitialized = false -- Flag to skip sound on first check
local speedBarRef = nil          -- Module-level reference for RefreshConfig
-- Main addon table
zSkyridingBar = LibStub("AceAddon-3.0"):GetAddon("zSkyridingBar", true) or
    LibStub("AceAddon-3.0"):NewAddon("zSkyridingBar", "AceEvent-3.0", "AceTimer-3.0")

local chargeFrame = nil
local speedText = nil
local speedBarBorder = nil
local angleText = nil
local eventFrame = nil
local moveMode = false
local staticChargeFrame = nil
local staticChargeIcon = nil
local staticChargeText = nil
local currentStaticChargeStacks = 0

-- Localized functions
local GetTime = GetTime
local C_PlayerInfo = C_PlayerInfo
local C_UnitAuras = C_UnitAuras


-- Get vigor recharge speed based on current buffs/conditions
local function getVigorRechargeSpeed()
    -- Check for Thrill of the Skies buff
    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    if thrill then
        return "fast"
    end

    return "normal"
end

-- Update bar color based on state
local function updateChargeBarColor(bar, isFull, isRecharging)
    if not bar then return end

    local color
    if isFull then
        color = zSkyridingBar.db.profile.chargeBarFullColor
        bar.isFull = true
    elseif isRecharging then
        local rechargeSpeed = getVigorRechargeSpeed()
        bar.rechargeSpeed = rechargeSpeed

        if rechargeSpeed == "fast" then
            color = zSkyridingBar.db.profile.chargeBarFastRechargeColor
        else -- "normal"
            color = zSkyridingBar.db.profile.chargeBarSlowRechargeColor
        end
        bar.isFull = false
    else
        -- Empty bar - use empty color
        color = zSkyridingBar.db.profile.chargeBarEmptyColor
        bar.isFull = false
    end

    bar:SetStatusBarColor(unpack(color))
end

-- Smooth bar animation function
local function smoothSetValue(bar, targetValue)
    if not bar then return end

    bar.targetValue = targetValue

    if not bar.currentValue then
        bar.currentValue = targetValue
        bar:SetValue(targetValue)
        return
    end

    -- Cancel existing timer
    if bar.smoothTimer then
        zSkyridingBar:CancelTimer(bar.smoothTimer)
    end

    -- If values are very close, just set directly
    if math.abs(bar.currentValue - targetValue) < 1 then
        bar.currentValue = targetValue
        bar:SetValue(targetValue)
        return
    end

    -- Start smooth animation
    local startValue = bar.currentValue
    local startTime = GetTime()
    local duration = 0.05 -- 100ms animation

    bar.smoothTimer = zSkyridingBar:ScheduleRepeatingTimer(function()
        local elapsed = GetTime() - startTime
        local progress = math.min(elapsed / duration, 1.0)

        -- Smooth easing function
        local easedProgress = progress * progress * (3.0 - 2.0 * progress)

        bar.currentValue = startValue + (targetValue - startValue) * easedProgress
        bar:SetValue(bar.currentValue)

        if progress >= 1.0 then
            zSkyridingBar:CancelTimer(bar.smoothTimer)
            bar.smoothTimer = nil
            bar.currentValue = targetValue
        end
    end, 1 / 60) -- 60 FPS updates
end

-- Play charge sound
local function playChargeSound(soundId)
    if not soundId or soundId == 0 then return end
    -- Use PlaySound() to play sounds by their sound ID
    PlaySound(soundId, "Master")
end
function zSkyridingBar:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("zSkyridingBarDB", defaults, true)

    -- Create event frame for event handling
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "ADDON_LOADED" and select(1, ...) == "zSkyridingBar" then
            zSkyridingBar:OnAddonLoaded()
        elseif event == "PLAYER_ENTERING_WORLD" then
            zSkyridingBar:OnPlayerEnteringWorld()
        elseif event == "PLAYER_LOGIN" then
            zSkyridingBar:OnPlayerLogin()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            zSkyridingBar:OnSpellcastSucceeded(event, ...)
        elseif event == "UNIT_AURA" then
            local unitTarget = select(1, ...)
            zSkyridingBar:OnUnitAura(unitTarget)
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
            zSkyridingBar:OnZoneChanged()
        elseif event == "UNIT_POWER_UPDATE" then
            local unitTarget, powerType = select(1, ...), select(2, ...)
            zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)
        end
    end)

    -- Create the UI
    self:CreateUI()

    -- Register for profile changes
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

function zSkyridingBar:OnPlayerLogin()
    -- Initialize options after everything is loaded
    self:InitializeOptions()
end

function zSkyridingBar:InitializeOptions()
    -- Get options table from Options.lua
    local optionsTable = self:GetOptionsTable()
    if optionsTable then
        -- Register options with Ace Config
        LibStub("AceConfig-3.0"):RegisterOptionsTable("zSkyridingBar", optionsTable)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("zSkyridingBar", "zSkyridingBar")

        -- Store reference
        self.optionsRegistered = true
    end
end

function zSkyridingBar:OnEnable()
    -- Check if skyriding is available before activating
    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnDisable()
    self:StopTracking()
    if mainFrame then
        mainFrame:Hide()
    end
    active = false
end

function zSkyridingBar:RefreshConfig()
    -- Apply theme if it's being changed
    applyTheme(self.db.profile.theme)
    
    -- Show/Hide border lines based on theme for speed bar
    if speedBarRef and speedBarRef.borderLines then
        if self.db.profile.theme == "classic" then
            for _, line in ipairs(speedBarRef.borderLines) do
                line:Show()
            end
        else
            for _, line in ipairs(speedBarRef.borderLines) do
                line:Hide()
            end
            -- For modern theme, show only the bottom line
            speedBarRef.borderLines[2]:Show()
        end
    end

    -- Update UI based on new settings
    if mainFrame then
        self:UpdateFramePosition()
        self:UpdateFrameAppearance()

        -- Update scale
        mainFrame:SetScale(self.db.profile.frameScale)

        -- Update speed bar settings if they changed
        if speedBar then
            speedBar:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
            speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarColor))

            -- Update speed bar texture
            local speedTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or
                "Interface\\TargetingFrame\\UI-StatusBar"
            speedBar:SetStatusBarTexture(speedTexture)

            if speedBar.bg then
                speedBar.bg:SetTexture(speedTexture)
                speedBar.bg:SetVertexColor(unpack(self.db.profile.speedBarBackgroundColor))
            end

            -- Update speed indicator visibility
            if speedBar.speedIndicator then
                if self.db.profile.showSpeedIndicator then
                    speedBar.speedIndicator:Show()
                else
                    speedBar.speedIndicator:Hide()
                end
            end
        end

        -- Update speed text visibility
        if speedText then
            if self.db.profile.speedShow then
                speedText:Show()
            else
                speedText:Hide()
            end
        end

        -- Update vigor frame size, position, and textures
        if chargeFrame then
            chargeFrame:SetSize(self.db.profile.speedBarWidth, self.db.profile.chargeBarHeight)
            chargeFrame:ClearAllPoints()
            chargeFrame:SetPoint("TOPRIGHT", speedBar, "BOTTOMRIGHT", 0, self.db.profile.speedChargeSpacing)

            -- Update vigor bar textures and background colors
            local vigorTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.chargeBarTexture) or
                "Interface\\TargetingFrame\\UI-StatusBar"
            for i = 1, 6 do
                local bar = chargeFrame["bar" .. i]
                if bar then
                    bar:SetStatusBarTexture(vigorTexture)
                    bar:SetSize((self.db.profile.speedBarWidth - ((6 - 1) * self.db.profile.chargeBarSpacing)) / 6,
                        self.db.profile.chargeBarHeight)
                    if bar.bg then
                        bar.bg:SetTexture(vigorTexture)
                        bar.bg:SetVertexColor(unpack(self.db.profile.chargeBarBackgroundColor))
                    end
                end
            end
        end

        -- Update main frame size using theme values
        local totalHeight = self.db.profile.speedBarHeight + self.db.profile.speedChargeSpacing +
            self.db.profile.chargeBarHeight
        mainFrame:SetSize(self.db.profile.speedBarWidth, totalHeight)

        -- Update default vigor UI visibility
    end
end

-- Public function for preview sound from options
function zSkyridingBar:PreviewChargeSound()
    playChargeSound(self.db.profile.chargeRefreshSoundId)
end

function zSkyridingBar:CreateUI()
    -- Apply theme FIRST before creating any UI elements
    applyTheme(self.db.profile.theme)

    local totalHeight = self.db.profile.speedBarHeight + self.db.profile.speedChargeSpacing +
        self.db.profile.chargeBarHeight
    mainFrame = CreateFrame("Frame", "zSkyridingBarMainFrame", UIParent)
    mainFrame:SetSize(self.db.profile.speedBarWidth, totalHeight)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", self.db.profile.frameX, self.db.profile.frameY)
    mainFrame:SetFrameStrata(self.db.profile.frameStrata)
    mainFrame:SetFrameLevel(10)
    mainFrame:SetScale(self.db.profile.frameScale)

    -- Create speed bar
    speedBar = CreateFrame("StatusBar", "zSkyridingBarSpeedBar", mainFrame)
    speedBarRef = speedBar  -- Store reference for RefreshConfig access
    speedBar:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
    speedBar:SetPoint("TOP", mainFrame, "TOP", 0, 0)
    local speedTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    speedBar:SetStatusBarTexture(speedTexture)
    speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarColor))
    speedBar:SetMinMaxValues(20, 100)
    speedBar:SetValue(0)

    -- Speed bar background
    local speedBarBG = speedBar:CreateTexture(nil, "BACKGROUND")
    speedBarBG:SetAllPoints()
    speedBarBG:SetTexture(speedTexture)
    speedBarBG:SetVertexColor(unpack(self.db.profile.speedBarBackgroundColor))
    speedBar.bg = speedBarBG

    -- Speed bar border using Blizzard's DialogBox-Border
    -- Speed bar border - draw lines directly
    -- Top line
    local speedBarTopLine = speedBar:CreateTexture(nil, "OVERLAY")
    speedBarTopLine:SetColorTexture(0, 0, 0, 1)
    speedBarTopLine:SetPoint("TOPLEFT", speedBar, "TOPLEFT", 0, 0)
    speedBarTopLine:SetPoint("TOPRIGHT", speedBar, "TOPRIGHT", 0, 0)
    speedBarTopLine:SetHeight(1)

    -- Bottom line
    local speedBarBottomLine = speedBar:CreateTexture(nil, "OVERLAY")
    speedBarBottomLine:SetColorTexture(0, 0, 0, 1)
    speedBarBottomLine:SetPoint("BOTTOMLEFT", speedBar, "BOTTOMLEFT", 0, 0)
    speedBarBottomLine:SetPoint("BOTTOMRIGHT", speedBar, "BOTTOMRIGHT", 0, 0)
    speedBarBottomLine:SetHeight(1)

    -- Left line
    local speedBarLeftLine = speedBar:CreateTexture(nil, "OVERLAY")
    speedBarLeftLine:SetColorTexture(0, 0, 0, 1)
    speedBarLeftLine:SetPoint("TOPLEFT", speedBar, "TOPLEFT", 0, 0)
    speedBarLeftLine:SetPoint("BOTTOMLEFT", speedBar, "BOTTOMLEFT", 0, 0)
    speedBarLeftLine:SetWidth(1)

    -- Right line
    local speedBarRightLine = speedBar:CreateTexture(nil, "OVERLAY")
    speedBarRightLine:SetColorTexture(0, 0, 0, 1)
    speedBarRightLine:SetPoint("TOPRIGHT", speedBar, "TOPRIGHT", 0, 0)
    speedBarRightLine:SetPoint("BOTTOMRIGHT", speedBar, "BOTTOMRIGHT", 0, 0)
    speedBarRightLine:SetWidth(1)

    -- Store references for theme visibility control
    speedBar.borderLines = { speedBarTopLine, speedBarBottomLine, speedBarLeftLine, speedBarRightLine }

    -- Show/Hide border lines based on theme
    if self.db.profile.theme == "classic" then
        for _, line in ipairs(speedBar.borderLines) do
            line:Show()
        end
    else
        for _, line in ipairs(speedBar.borderLines) do
            line:Hide()
        end
        -- For modern theme, show only the bottom line (index 2)
        speedBar.borderLines[2]:Show()
    end


    -- Speed text
    speedText = speedBar:CreateFontString(nil, "OVERLAY")
    speedText:SetFont(self.db.profile.fontFace, self.db.profile.fontSize, self.db.profile.fontFlags)
    speedText:SetPoint("LEFT", speedBar, "LEFT", 5, 0)
    speedText:SetTextColor(1, 1, 1, 1)
    speedText:SetText("")

    -- Hide speed bar initially (shown when skyriding)
    speedBar:Hide()

    -- Angle text
    angleText = speedBar:CreateFontString(nil, "OVERLAY")
    angleText:SetFont(self.db.profile.fontFace, self.db.profile.fontSize, self.db.profile.fontFlags)
    angleText:SetPoint("RIGHT", speedBar, "RIGHT", -5, 0)
    angleText:SetTextColor(1, 1, 1, 1)
    angleText:SetText("")

    -- Speed indicator (white tick mark)
    if self.db.profile.showSpeedIndicator then
        local speedIndicator = speedBar:CreateTexture(nil, "OVERLAY")
        speedIndicator:SetTexture("Interface\\Buttons\\WHITE8x8")
        speedIndicator:SetSize(2, self.db.profile.speedIndicatorHeight)
        speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))

        -- Position at 60% (convert from 20-100 range to 0-1 position)
        local indicatorPos = (60 - 20) / (100 - 20)
        speedIndicator:SetPoint("LEFT", speedBar, "LEFT", indicatorPos * self.db.profile.speedBarWidth, 0)

        speedBar.speedIndicator = speedIndicator
    end

    -- Create Static Charge frame (to the left of speed bar)
    staticChargeFrame = CreateFrame("Frame", "zSkyridingBarStaticChargeFrame", mainFrame)
    staticChargeFrame:SetSize(40, self.db.profile.speedBarHeight)
    staticChargeFrame:SetPoint("RIGHT", mainFrame, "LEFT", -5, 4)

    -- Static Charge icon
    staticChargeIcon = staticChargeFrame:CreateTexture(nil, "ARTWORK")
    staticChargeIcon:SetSize(36, 36)
    staticChargeIcon:SetPoint("CENTER", staticChargeFrame, "CENTER", 0, 0)
    staticChargeIcon:Hide()

    -- Static Charge lightning border (for 10 stacks effect)
    staticChargeBorder = staticChargeFrame:CreateTexture(nil, "OVERLAY")
    staticChargeBorder:SetSize(44, 44)
    staticChargeBorder:SetPoint("CENTER", staticChargeIcon, "CENTER", 0, 0)
    staticChargeBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    staticChargeBorder:SetBlendMode("ADD")
    staticChargeBorder:SetVertexColor(1, 1, 0.3, 0.3)
    staticChargeBorder:Hide()

    -- Create a glow effect layer for the border (animation is achieved through vertex color changes)
    staticChargeGlow = staticChargeFrame:CreateTexture(nil, "OVERLAY")
    staticChargeGlow:SetSize(48, 48)
    staticChargeGlow:SetPoint("CENTER", staticChargeIcon, "CENTER", 0, 0)
    staticChargeGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    staticChargeGlow:SetBlendMode("ADD")
    staticChargeGlow:SetVertexColor(1, 0.8, 0, 0.1)
    staticChargeGlow:Hide()

    -- Static Charge stack count text
    staticChargeText = staticChargeFrame:CreateFontString(nil, "OVERLAY")
    staticChargeText:SetFont(self.db.profile.fontFace, 14, self.db.profile.fontFlags)
    staticChargeText:SetPoint("BOTTOM", staticChargeIcon, "BOTTOM", 0, -5)
    staticChargeText:SetTextColor(1, 1, 1, 1)
    staticChargeText:SetText("")
    staticChargeText:Hide()

    -- Create vigor frame (will hold multiple vigor bars)
    chargeFrame = CreateFrame("Frame", "zSkyridingBarVigorFrame", mainFrame)
    chargeFrame:SetSize(self.db.profile.speedBarWidth, self.db.profile.chargeBarHeight)
    chargeFrame:SetPoint("TOPRIGHT", speedBar, "BOTTOMRIGHT", 0, self.db.profile.speedChargeSpacing)

    self:CreateChargeBars()

    -- Initially hide the frame
    mainFrame:Hide()
end

function zSkyridingBar:CreateChargeBars()
    -- Create individual vigor charge bars
    if not chargeFrame then
        return
    end

    -- Initialize bars array
    chargeFrame.bars = chargeFrame.bars or {}

    -- Clear existing bars
    for i, bar in ipairs(chargeFrame.bars) do
        if bar then
            bar:Hide()
            bar:SetParent(nil)
        end
    end
    chargeFrame.bars = {}

    -- Create new bars (typically 3-6 charges for skyriding)
    local numBars = 6 -- Max possible vigor charges
    local barWidth = (self.db.profile.chargeBarWidth - ((numBars - 1) * self.db.profile.chargeBarSpacing)) / numBars

    for i = 1, numBars do
        local bar = CreateFrame("StatusBar", "zSkyridingBarChargeBar" .. i, chargeFrame)
        bar:SetSize(barWidth, self.db.profile.chargeBarHeight)

        if i == 1 then
            bar:SetPoint("LEFT", chargeFrame, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", chargeFrame.bars[i - 1], "RIGHT", self.db.profile.chargeBarSpacing, 0)
        end

        local vigorTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.chargeBarTexture) or
            "Interface\\TargetingFrame\\UI-StatusBar"
        bar:SetStatusBarTexture(vigorTexture)
        -- Don't set initial color here - let updateChargeBarColor handle it
        bar:SetMinMaxValues(0, 100) -- Use 0-100 range for better precision
        bar:SetValue(0)

        -- Store current and target values for smooth animation
        bar.currentValue = 0
        bar.targetValue = 0
        bar.smoothTimer = nil
        bar.isFull = false
        bar.rechargeSpeed = "normal"

        -- Background
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(vigorTexture)
        bg:SetVertexColor(unpack(self.db.profile.chargeBarBackgroundColor))
        bar.bg = bg

        -- Border - draw lines directly for classic theme
        if self.db.profile.theme == "classic" then
            -- Top line
            local topLine = bar:CreateTexture(nil, "OVERLAY")
            topLine:SetColorTexture(0, 0, 0, 1)
            topLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            topLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            topLine:SetHeight(1)

            -- Bottom line
            local bottomLine = bar:CreateTexture(nil, "OVERLAY")
            bottomLine:SetColorTexture(0, 0, 0, 1)
            bottomLine:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
            bottomLine:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            bottomLine:SetHeight(1)

            -- Left line
            local leftLine = bar:CreateTexture(nil, "OVERLAY")
            leftLine:SetColorTexture(0, 0, 0, 1)
            leftLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            leftLine:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
            leftLine:SetWidth(1)

            -- Right line
            local rightLine = bar:CreateTexture(nil, "OVERLAY")
            rightLine:SetColorTexture(0, 0, 0, 1)
            rightLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            rightLine:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            rightLine:SetWidth(1)
        end

        if self.db.profile.theme == "modern" and i ~= 1 then
            local chargeIndicator = bar:CreateTexture(nil, "OVERLAY")
            chargeIndicator:SetTexture("Interface\\Buttons\\WHITE8x8")
            chargeIndicator:SetSize(1, self.db.profile.chargeBarHeight)
            chargeIndicator:SetVertexColor(0, 0, 0, 0.6)

            -- Position at 60% (convert from 20-100 range to 0-1 position)
            local indicatorPos = (60 - 20) / (100 - 20)
            chargeIndicator:SetPoint("LEFT", bar, "LEFT", 0, 0)

            bar.chargeIndicator = chargeIndicator
        end


        chargeFrame.bars[i] = bar

        -- Set initial empty state color to prevent flashing
        updateChargeBarColor(bar, false, false)

        bar:Hide() -- Initially hidden
    end
end

function zSkyridingBar:OnAddonLoaded()
    -- Addon loaded, perform any post-load initialization
    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnPlayerEnteringWorld()
    -- Check if we're in a skyriding zone
    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnZoneChanged()
    -- Update zone-specific settings
    -- Add small delay to ensure zone data is fully loaded
    self:ScheduleTimer(function() self:CheckSkyridingAvailability() end, 0.1)
end

function zSkyridingBar:OnUnitAura(unitTarget)
    -- Speed-based color logic is handled every frame by UpdateTracking
    -- No need to manually update here since UpdateTracking runs at 20 FPS
end

function zSkyridingBar:UpdateSpeedBarColors(currentSpeed)
    -- Lightweight function to update speed bar colors immediately
    if not active or not speedBar then
        return
    end

    -- Don't update UI during combat lockdown to avoid taint
    if InCombatLockdown() then
        return
    end

    -- Check for Thrill of the Skies buff (indicates vigour recharging)
    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    
    -- Determine max gliding speed based on zone
    local maxGlideSpeed = isSlowSkyriding and SLOW_ZONE_MAX_GLIDE or FAST_ZONE_MAX_GLIDE
    
    -- Check if we're in fast flying mode (speed exceeds max gliding speed)
    local inFastMode = currentSpeed and currentSpeed > (maxGlideSpeed+.1) or false

    -- Update color based on state (priority: fast flying > thrill (optimal) > default)
    if inFastMode then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarBoostColor))  -- Fast color when flying faster than gliding cap
    elseif thrill then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarThrillColor)) -- Thrill color when recharging but gliding normally
    else
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarColor))       -- Default color for normal gliding
    end
end

function zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)
    -- Handle power updates for vigor
    if unitTarget == "player" and powerType == "ALTERNATE" then
        self:UpdateChargeBars()
    end
end

function zSkyridingBar:OnSpellcastSucceeded(event, unitTarget, castGUID, spellId)
    if unitTarget == "player" and spellId == ASCENT_SPELL_ID then
        ascentStart = GetTime()
        -- Color update will happen in UpdateTracking which runs at 20 FPS
        -- The next frame will detect the new ascent timer and update color immediately
    end
end

function zSkyridingBar:CheckSkyridingAvailability()
    -- Check if dragonriding/skyriding is available
    local hasSkyriding = C_SpellBook.IsSpellInSpellBook(372610) -- Skyriding spell
    local mapID = C_Map.GetBestMapForUnit("player")

    -- Show anywhere skyriding is available - let the game handle location restrictions
    if hasSkyriding then
        isSlowSkyriding = not FAST_FLYING_ZONES[mapID]

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
    if not updateHandle then
        active = true

        -- Start update ticker
        updateHandle = self:ScheduleRepeatingTimer("UpdateTracking", TICK_RATE)

        -- Show main frame
        if mainFrame then
            mainFrame:Show()
        end

        -- Initial vigor update
        self:UpdateChargeBars()
    end
end

function zSkyridingBar:StopTracking()
    if updateHandle then
        self:CancelTimer(updateHandle)
        updateHandle = nil
    end

    previousChargeCount = 0    -- Reset charge tracking when stopping
    chargesInitialized = false -- Reset init flag so sound doesn't play on next login

    -- Hide main frame
    if mainFrame then
        mainFrame:Hide()
    end
end

function zSkyridingBar:UpdateTracking()
    -- Periodically check if we should be active (catches reload scenarios)
    if not active then
        self:CheckSkyridingAvailability()
        if not active then
            return
        end
    end

    if not mainFrame or not speedBar then
        return
    end

    -- Update zone check to ensure isSlowSkyriding is current
    local mapID = C_Map.GetBestMapForUnit("player")
    
    isSlowSkyriding = not FAST_FLYING_ZONES[select(8, GetInstanceInfo())]

    -- Get current skyriding info
    local isGliding, isFlying, forwardSpeed = C_PlayerInfo.GetGlidingInfo()

    -- Show/hide speed frame based on skyriding state
    if not isGliding and not isFlying then
        if speedBar then
            speedBar:Hide()
        end
        if chargeFrame then
            chargeFrame:Hide()
        end
        if staticChargeFrame then
            staticChargeFrame:Hide()
        end
        return
    else
        if speedBar then
            speedBar:Show()
        end
        if chargeFrame then
            chargeFrame:Show()
        end
        if staticChargeFrame then
            staticChargeFrame:Show()
        end
    end

    -- Adjust speed for slow skyriding zones
    local adjustedSpeed = forwardSpeed
    if isSlowSkyriding then
        adjustedSpeed = adjustedSpeed / SLOW_SKYRIDING_RATIO
    end

    -- Update speed bar
    speedBar:SetValue(math.min(100, math.max(20, adjustedSpeed)))

    -- Update speed text
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
    elseif speedText then
        speedText:SetText("")
    end

    -- Update color based on state using dedicated function with current speed
    -- Pass forwardSpeed so we can check if we're at optimal speed threshold
    self:UpdateSpeedBarColors(forwardSpeed)

    -- Also update vigor/charge bars periodically (for 11.2.7 charge system)
    self:UpdateChargeBars()

    -- Update Static Charge display
    self:UpdateStaticCharge()
end

function zSkyridingBar:UpdateStaticCharge()
    if not staticChargeFrame or not staticChargeIcon then
        return
    end

    -- Don't update UI during combat lockdown
    if InCombatLockdown() then
        return
    end

    -- Get Static Charge buff info
    local staticChargeAura = C_UnitAuras.GetPlayerAuraBySpellID(STATIC_CHARGE_BUFF_ID)

    if staticChargeAura then
        -- Static Charge uses 'applications' field for stack count
        local stacks = staticChargeAura.applications or 0

        if stacks and stacks > 0 then
            -- Show the icon and stack count
            staticChargeIcon:Show()
            staticChargeText:Show()
            staticChargeText:SetText(stacks)

            -- Set the icon texture to the buff icon
            -- Use texture coordinates to get the circular portion (standard 0.08 inset for circular icons)
            if staticChargeAura.icon then
                staticChargeIcon:SetTexture(staticChargeAura.icon)
                staticChargeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            -- At 10 stacks, brighten the icon and show lightning border
            if stacks == 10 then
                staticChargeIcon:SetVertexColor(1.2, 1.2, 1.0)
                staticChargeBorder:Show()
            else
                staticChargeIcon:SetVertexColor(1, 1, 1)
                staticChargeBorder:Hide()
            end

            currentStaticChargeStacks = stacks
            return
        end
    end

    -- No static charge - hide everything
    staticChargeIcon:Hide()
    staticChargeText:Hide()
    staticChargeBorder:Hide()
    staticChargeGlow:Hide()
    currentStaticChargeStacks = 0
end

function zSkyridingBar:UpdateChargeBars()
    if not chargeFrame or not chargeFrame.bars then
        return
    end

    -- Don't update UI during combat lockdown to avoid secret value issues in Midnight
    if InCombatLockdown() then
        return
    end

    local surgeForwardID = 372608 -- Surge Forward spell
    local spellChargeInfo = C_Spell.GetSpellCharges(surgeForwardID)

    -- Debug output (can be removed later)
    -- print(string.format("zSkyRidingBar: Charges: %s/%s",
    --     spellChargeInfo and spellChargeInfo.currentCharges or "?",
    --     spellChargeInfo and spellChargeInfo.maxCharges or "?"))

    if spellChargeInfo and spellChargeInfo.currentCharges and spellChargeInfo.maxCharges then
        local charges = spellChargeInfo.currentCharges
        local maxCharges = spellChargeInfo.maxCharges
        local start = spellChargeInfo.cooldownStartTime
        local duration = spellChargeInfo.cooldownDuration

        -- Check if a charge refreshed and play sound if enabled
        if self.db.profile.chargeRefreshSound and charges > previousChargeCount and chargesInitialized then
            -- Play the selected charge sound
            playChargeSound(self.db.profile.chargeRefreshSoundId)
        end
        previousChargeCount = charges
        chargesInitialized = true

        -- Show bars up to maxCharges (should be 6)
        for i = 1, math.min(maxCharges, 6) do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Show()
                bar:SetMinMaxValues(0, 100)

                if i <= charges then
                    -- Full charge - set instantly
                    updateChargeBarColor(bar, true, false)
                    bar:SetValue(100)
                    bar.currentValue = 100
                    bar.targetValue = 100
                    bar:GetStatusBarTexture():SetAlpha(1)
                elseif i == charges + 1 and start and duration and duration > 0 then
                    -- Currently recharging (next charge) - smooth animation
                    local elapsed = GetTime() - start
                    local progress = math.min(100, (elapsed / duration) * 100)
                    updateChargeBarColor(bar, false, true)
                    smoothSetValue(bar, progress)
                    bar:GetStatusBarTexture():SetAlpha(1)
                else
                    -- Empty charge - set instantly
                    updateChargeBarColor(bar, false, false)
                    bar:SetValue(0)
                    bar.currentValue = 0
                    bar.targetValue = 0
                    -- Hide the bar with SetAlpha
                    bar:GetStatusBarTexture():SetAlpha(0)
                end
            end
        end

        -- Hide any extra bars beyond maxCharges
        for i = maxCharges + 1, 6 do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Hide()
            end
        end
    else
        -- Fallback: Show test bars if spell charges not available
        -- print("zSkyRidingBar: Spell charges not available, showing test bars")
        for i = 1, 6 do
            local bar = chargeFrame.bars[i]
            if bar then
                bar:Show()
                bar:SetMinMaxValues(0, 100)
                -- Show first 3 as full, rest as empty for testing
                if i <= 3 then
                    updateChargeBarColor(bar, true, false)
                    bar:SetValue(100)
                    bar.currentValue = 100
                    bar.targetValue = 100
                else
                    updateChargeBarColor(bar, false, false)
                    bar:SetValue(0)
                    bar.currentValue = 0
                    bar.targetValue = 0
                end
            end
        end
    end
end

function zSkyridingBar:UpdateFramePosition()
    if mainFrame then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", self.db.profile.frameX, self.db.profile.frameY)
        mainFrame:SetScale(self.db.profile.frameScale)
        mainFrame:SetFrameStrata(self.db.profile.frameStrata)
    end
end

function zSkyridingBar:ToggleMoveMode()
    if not mainFrame then
        print("|cff00ff00zSkyridingBar|r: Frame not available")
        return
    end

    moveMode = not moveMode

    if moveMode then
        -- Enable move mode
        print(
            "|cff00ff00zSkyridingBar|r: |cffFFFFFFMove mode enabled|r - Drag the frame to reposition. Type |cffFFFFFF/zsb move|r again to disable.")

        -- Make the frame draggable
        mainFrame:SetMovable(true)
        mainFrame:EnableMouse(true)
        mainFrame:RegisterForDrag("LeftButton")

        -- Show a background so the frame is visible and draggable
        if not mainFrame.moveBackground then
            mainFrame.moveBackground = mainFrame:CreateTexture(nil, "BACKGROUND")
            mainFrame.moveBackground:SetAllPoints(mainFrame)
            mainFrame.moveBackground:SetColorTexture(0, 0, 0, 0.5)
        end
        mainFrame.moveBackground:Show()

        -- Set up drag handlers
        mainFrame:SetScript("OnDragStart", function()
            mainFrame:StartMoving()
        end)

        mainFrame:SetScript("OnDragStop", function()
            mainFrame:StopMovingOrSizing()
            -- Save the new position
            local point, _, _, xOfs, yOfs = mainFrame:GetPoint()
            self.db.profile.frameX = xOfs
            self.db.profile.frameY = yOfs
        end)

        -- Make sure the frame is visible
        mainFrame:Show()
    else
        -- Disable move mode
        print("|cff00ff00zSkyridingBar|r: |cffFFFFFFMove mode disabled|r")

        -- Make the frame non-draggable
        mainFrame:SetMovable(false)
        mainFrame:EnableMouse(false)
        mainFrame:RegisterForDrag()

        -- Hide the background
        if mainFrame.moveBackground then
            mainFrame.moveBackground:Hide()
        end

        -- Remove drag handlers
        mainFrame:SetScript("OnDragStart", nil)
        mainFrame:SetScript("OnDragStop", nil)
    end
end

function zSkyridingBar:UpdateFrameAppearance()
    if speedBar then
        speedBar:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarColor))
        speedBar.bg:SetVertexColor(unpack(self.db.profile.speedBarBackgroundColor))
    end

    if speedText then
        speedText:SetFont(self.db.profile.fontFace, self.db.profile.fontSize, self.db.profile.fontFlags)
    end

    if angleText then
        angleText:SetFont(self.db.profile.fontFace, self.db.profile.fontSize, self.db.profile.fontFlags)
    end

    if chargeFrame then
        self:CreateChargeBars()

        angleText:SetFont(self.db.profile.fontFace, self.db.profile.fontSize, self.db.profile.fontFlags)
    end

    -- if classic, show the speed bar borders, else hide them
    if self.db.profile.theme == "classic" then
        if speedBar and speedBar.borderLines then
            for _, line in ipairs(speedBar.borderLines) do
                line:Show()
            end
        end
    else
        if speedBar and speedBar.borderLines then
            for _, line in ipairs(speedBar.borderLines) do
                line:Hide()
            end
            -- For modern theme, show only the bottom line
            speedBar.borderLines[2]:Show()
        end
    end

    -- Update speed indicator
    if speedBar and speedBar.speedIndicator then
        speedBar.speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))
        speedBar.speedIndicator:SetSize(2, self.db.profile.speedIndicatorHeight)

        -- Reposition indicator at 60%
        local indicatorPos = (60 - 20) / (100 - 20)
        speedBar.speedIndicator:ClearAllPoints()
        speedBar.speedIndicator:SetPoint("LEFT", speedBar, "LEFT", indicatorPos * self.db.profile.speedBarWidth, 0)
    end
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
        -- Open config panel
        if LibStub and LibStub("AceConfigDialog-3.0", true) and zSkyridingBar.optionsRegistered then
            LibStub("AceConfigDialog-3.0"):Open("zSkyridingBar")
        else
            print("|cff00ff00zSkyridingBar|r: Options not ready yet, please try again in a moment.")
        end
    elseif msg == "move" then
        zSkyridingBar:ToggleMoveMode()
    elseif msg == "debug" then
        -- Debug command to check buff status
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(STATIC_CHARGE_BUFF_ID)
        if aura then
            print("|cff00ff00zSkyridingBar|r: Static Charge found!")
            print("  Icon:", aura.icon)
            print("  Charges:", aura.charges)
            print("  NumStacks:", aura.numStacks)
            print("  Stacks:", aura.stacks)
            print("  Applications:", aura.applications)
            print("  ExpirationTime:", aura.expirationTime)
            print("  Duration:", aura.duration)
            -- Print all keys
            print("  All aura keys:")
            for k, v in pairs(aura) do
                print("    " .. tostring(k) .. " = " .. tostring(v))
            end
        else
            print("|cff00ff00zSkyridingBar|r: Static Charge NOT found")
        end
    else
        print("|cff00ff00zSkyridingBar|r commands:")
        print("  |cffFFFFFF/zsb|r - Open options panel")
        print("  |cffFFFFFF/zsb move|r - Toggle move mode")
        print("  |cffFFFFFF/zsb toggle|r - Toggle the addon")
    end
end
