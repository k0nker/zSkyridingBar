-- zSkyridingBar - A standalone skyriding information addon
-- Ported from Liroo - Dragonriding WeakAuras

-- Initialize Ace addon
local zSkyridingBar = LibStub("AceAddon-3.0"):NewAddon("zSkyridingBar", "AceTimer-3.0")

-- Constants from WeakAuras
local ASCENT_SPELL_ID = 372610
local THRILL_BUFF_ID = 377234
local SLOW_SKYRIDING_RATIO = 705 / 830
local ASCENT_DURATION = 3.5
local TICK_RATE = 1 / 20  -- 20 FPS updates

-- Fast flying zones (where full speed is available)
local FAST_FLYING_ZONES = {
  [2444] = true,   -- Dragon Isles
  [2454] = true,   -- Zaralek Cavern
  [2548] = true,   -- Emerald Dream
  [2516] = true,   -- Nokhud Offensive
  [2522] = true,   -- Vault of the Incarnates
  [2569] = true,   -- Aberrus, the Shadowed Crucible
}

-- Default settings
local defaults = {
  profile = {
    enabled = true,
    speedShow = true,
    speedUnits = 2, -- 1 = yd/s, 2 = move%
    hideDefaultVigorUI = true,
    
    -- Position settings
    frameX = 0,
    frameY = -167,
    frameScale = 1,
    frameStrata = "MEDIUM",
    
    -- Speed bar settings
    speedBarWidth = 256,
    speedBarHeight = 18,
    speedBarTexture = "Clean",
    speedBarColor = {0.749, 0.439, 0.173, 1}, -- Default/normal speed (orange)
    speedBarBoostColor = {0.314, 0.537, 0.157, 1}, -- Boosting speed (green)
    speedBarThrillColor = {0.482, 0.667, 1, 1}, -- Thrill speed (blue)
    speedBarBackgroundColor = {0, 0, 0, 0.4},
    
    -- Vigor bar settings
    vigorBarWidth = 256,
    vigorBarHeight = 12,
    vigorBarSpacing = 2,
    vigorBarTexture = "Clean",
    vigorBarColor = {0.2, 0.5, 0.8, 1}, -- Default recharging color (blue)
    vigorBarFullColor = {0.2, 0.5, 0.8, 1}, -- Full charge color (green)
    vigorBarFastRechargeColor = {0.25, 0.9, 0.6, 1}, -- Fast recharge color (yellow/orange - Thrill buff)
    vigorBarSlowRechargeColor = {0.53, 0.29, 0.2, 1}, -- Slow recharge color (yellow-orange)
    vigorBarEmptyColor = {0, 0, 1, 1}, -- Empty vigor color (blue)
    vigorBarBackgroundColor = {0, 0, 0, 0.4},
    
    -- Speed indicator settings
    showSpeedIndicator = true,
    speedIndicatorColor = {1, 1, 1, 1}, -- White indicator
    
    -- Font settings
    fontSize = 12,
    fontFace = "Fonts\\FRIZQT__.TTF",
    fontFlags = "OUTLINE",
  }
}

-- Local variables
local active = false
local updateHandle = nil
local ascentStart = 0
local isSlowSkyriding = true
local mainFrame = nil
local speedBar = nil
local vigorFrame = nil
local speedText = nil
local angleText = nil
local eventFrame = nil
local moveMode = false

-- Localized functions
local GetTime = GetTime
local C_PlayerInfo = C_PlayerInfo
local C_UnitAuras = C_UnitAuras
local UIWidgetPowerBarContainerFrame = UIWidgetPowerBarContainerFrame

-- Get vigor recharge speed based on current buffs/conditions
local function getVigorRechargeSpeed()
    -- Simple approach like WeakAuras - just check for Thrill of the Skies buff
    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    if thrill then
        return "fast"
    end
    
    return "normal"
end

-- Update bar color based on state
local function updateVigorBarColor(bar, isFull, isRecharging)
    if not bar then return end
    
    local color
    if isFull then
        color = zSkyridingBar.db.profile.vigorBarFullColor
        bar.isFull = true
    elseif isRecharging then
        -- Check for Thrill of the Skies buff like WeakAuras does
        local rechargeSpeed = getVigorRechargeSpeed()
        bar.rechargeSpeed = rechargeSpeed
        
        if rechargeSpeed == "fast" then
            color = zSkyridingBar.db.profile.vigorBarFastRechargeColor
        else -- "normal"
            color = zSkyridingBar.db.profile.vigorBarSlowRechargeColor
        end
        bar.isFull = false
    else
        -- Empty bar - use empty color
        color = zSkyridingBar.db.profile.vigorBarEmptyColor
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
    local duration = 0.3 -- 300ms animation
    
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
    end, 1/60) -- 60 FPS updates
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
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
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
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            zSkyridingBar:OnZoneChanged()
        elseif event == "UPDATE_UI_WIDGET" then
            local widgetInfo = select(1, ...)
            zSkyridingBar:OnUpdateUIWidget(widgetInfo)
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
    active = true
    self:StartTracking()
end

function zSkyridingBar:OnDisable()
    self:StopTracking()
    if mainFrame then
        mainFrame:Hide()
    end
    active = false
end

function zSkyridingBar:RefreshConfig()
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
            local speedTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
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
        
        -- Update vigor frame size and textures
        if vigorFrame then
            vigorFrame:SetSize(self.db.profile.speedBarWidth, 30)
            
            -- Update vigor bar textures and background colors
            local vigorTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.vigorBarTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
            for i = 1, 4 do
                local bar = vigorFrame["bar" .. i]
                if bar then
                    bar:SetStatusBarTexture(vigorTexture)
                    if bar.bg then
                        bar.bg:SetTexture(vigorTexture)
                        bar.bg:SetVertexColor(unpack(self.db.profile.vigorBarBackgroundColor))
                    end
                end
            end
        end
        
        -- Update main frame size
        local totalHeight = self.db.profile.speedBarHeight + 5 + 30
        mainFrame:SetSize(self.db.profile.speedBarWidth, totalHeight)
        
        -- Update default vigor UI visibility
        if UIWidgetPowerBarContainerFrame then
            if self.db.profile.hideDefaultVigorUI then
                UIWidgetPowerBarContainerFrame:Hide()
            else
                UIWidgetPowerBarContainerFrame:Show()
            end
        end
    end
end

function zSkyridingBar:CreateUI()
    -- Create main frame (sized to encompass speed bar + gap + vigor frame)
    local totalHeight = self.db.profile.speedBarHeight + 5 + 30 -- speed bar + gap + vigor frame
    mainFrame = CreateFrame("Frame", "zSkyridingBarMainFrame", UIParent)
    mainFrame:SetSize(self.db.profile.speedBarWidth, totalHeight)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", self.db.profile.frameX, self.db.profile.frameY)
    mainFrame:SetFrameStrata(self.db.profile.frameStrata)
    mainFrame:SetFrameLevel(10)
    mainFrame:SetScale(self.db.profile.frameScale)
    
    -- Create speed bar
    speedBar = CreateFrame("StatusBar", "zSkyridingBarSpeedBar", mainFrame)
    speedBar:SetSize(self.db.profile.speedBarWidth, self.db.profile.speedBarHeight)
    speedBar:SetPoint("TOP", mainFrame, "TOP", 0, 0)
    local speedTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.speedBarTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
    speedBar:SetStatusBarTexture(speedTexture)
    speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarColor))
    speedBar:SetMinMaxValues(20, 100)  -- Min/Max from WeakAuras
    speedBar:SetValue(0)
    
    -- Speed bar background
    local speedBarBG = speedBar:CreateTexture(nil, "BACKGROUND")
    speedBarBG:SetAllPoints()
    speedBarBG:SetTexture(speedTexture)
    speedBarBG:SetVertexColor(unpack(self.db.profile.speedBarBackgroundColor))
    speedBar.bg = speedBarBG
    
    -- Speed bar border
    local speedBarBorder = CreateFrame("Frame", nil, speedBar, "BackdropTemplate")
    speedBarBorder:SetAllPoints()
    speedBarBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    speedBarBorder:SetBackdropBorderColor(0, 0, 0, 1)
    
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
        speedIndicator:SetSize(2, self.db.profile.speedBarHeight + 4)
        speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))
        
        -- Position at 60% (convert from 20-100 range to 0-1 position)
        local indicatorPos = (60 - 20) / (100 - 20)
        speedIndicator:SetPoint("LEFT", speedBar, "LEFT", indicatorPos * self.db.profile.speedBarWidth, 0)
        
        speedBar.speedIndicator = speedIndicator
    end
    
    -- Create vigor frame (will hold multiple vigor bars)
    vigorFrame = CreateFrame("Frame", "zSkyridingBarVigorFrame", mainFrame)
    vigorFrame:SetSize(self.db.profile.speedBarWidth, 30)
    vigorFrame:SetPoint("TOP", speedBar, "BOTTOM", 0, -5)
    
    self:CreateVigorBars()
    
    -- Initially hide the frame
    mainFrame:Hide()
end

function zSkyridingBar:CreateVigorBars()
    -- Create individual vigor charge bars
    if not vigorFrame then
        return
    end
    
    -- Initialize bars array
    vigorFrame.bars = vigorFrame.bars or {}
    
    -- Clear existing bars
    for i, bar in ipairs(vigorFrame.bars) do
        if bar then
            bar:Hide()
            bar:SetParent(nil)
        end
    end
    vigorFrame.bars = {}
    
    -- Create new bars (typically 3-6 charges for skyriding)
    local numBars = 6  -- Max possible vigor charges
    local barWidth = (self.db.profile.vigorBarWidth - ((numBars - 1) * self.db.profile.vigorBarSpacing)) / numBars
    
    for i = 1, numBars do
        local bar = CreateFrame("StatusBar", "zSkyridingBarVigorBar" .. i, vigorFrame)
        bar:SetSize(barWidth, self.db.profile.vigorBarHeight)
        
        if i == 1 then
            bar:SetPoint("LEFT", vigorFrame, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", vigorFrame.bars[i-1], "RIGHT", self.db.profile.vigorBarSpacing, 0)
        end
        
        local vigorTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.vigorBarTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
        bar:SetStatusBarTexture(vigorTexture)
        bar:SetStatusBarColor(unpack(self.db.profile.vigorBarColor))
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
        bg:SetVertexColor(unpack(self.db.profile.vigorBarBackgroundColor))
        bar.bg = bg
        
        -- Border
        local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        border:SetBackdropBorderColor(0, 0, 0, 1)
        
        vigorFrame.bars[i] = bar
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
    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnUpdateUIWidget(widgetInfo)
    -- Handle UI widget updates for vigor bars
    if widgetInfo and widgetInfo.widgetSetID == 283 then
        -- Debug: print("Vigor widget update received:", widgetInfo.widgetID)
        self:UpdateVigorFromWidget(widgetInfo)
    end
end

function zSkyridingBar:OnUnitPowerUpdate(unitTarget, powerType)
    -- Handle power updates for vigor
    if unitTarget == "player" and powerType == "ALTERNATE" then
        self:UpdateVigorBars()
    end
end

function zSkyridingBar:OnSpellcastSucceeded(event, unitTarget, castGUID, spellId)
    if unitTarget == "player" and spellId == ASCENT_SPELL_ID then
        ascentStart = GetTime()
    end
end

function zSkyridingBar:CheckSkyridingAvailability()
    -- Check if dragonriding/skyriding is available
    local hasSkyriding = C_SpellBook.IsSpellInSpellBook(372610) -- Skyriding spell
    local instanceType = select(2, GetInstanceInfo())
    local mapID = C_Map.GetBestMapForUnit("player")
    
    -- Only show in outdoor areas where skyriding is available
    if hasSkyriding and (instanceType == "none" or instanceType == "scenario") then
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
    if not updateHandle and active then
        -- Hide default vigor UI if enabled
        if self.db.profile.hideDefaultVigorUI and UIWidgetPowerBarContainerFrame:IsVisible() then
            self.hiddenDefaultUI = true
            UIWidgetPowerBarContainerFrame:Hide()
        end
        
        -- Start update ticker
        updateHandle = self:ScheduleRepeatingTimer("UpdateTracking", TICK_RATE)
        
        -- Show main frame
        if mainFrame then
            mainFrame:Show()
        end
        
        -- Initial vigor update
        self:UpdateVigorBars()
    end
end

function zSkyridingBar:StopTracking()
    if updateHandle then
        self:CancelTimer(updateHandle)
        updateHandle = nil
    end
    
    -- Restore default UI if we hid it
    if self.hiddenDefaultUI then
        UIWidgetPowerBarContainerFrame:Show()
        self.hiddenDefaultUI = false
    end
    
    -- Hide main frame
    if mainFrame then
        mainFrame:Hide()
    end
end

function zSkyridingBar:UpdateTracking()
    if not active or not mainFrame or not speedBar then
        return
    end
    
    -- Get current skyriding info
    local isGliding, isFlying, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
    
    -- Show/hide speed frame and vigor frame based on skyriding state
    if not isGliding and not isFlying then
        if speedBar then
            speedBar:Hide()
        end
        if vigorFrame then
            vigorFrame:Hide()
        end
        return
    else
        if speedBar then
            speedBar:Show()
        end
        if vigorFrame then
            vigorFrame:Show()
        end
    end
    
    -- Check for Thrill of the Skies buff
    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    local time = GetTime()
    local boosting = thrill and time < ascentStart + ASCENT_DURATION
    
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
    
    -- Update color based on state
    if boosting then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarBoostColor)) -- Green for boosting
    elseif thrill then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarThrillColor)) -- Blue for thrill
    else
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarColor)) -- Default orange
    end
    
    -- Note: Vigor bars are updated via UPDATE_UI_WIDGET and UNIT_POWER_UPDATE events only
end

function zSkyridingBar:UpdateVigorFromWidget(widgetInfo)
    -- Use UI widget system like WeakAuras does
    if not widgetInfo or not widgetInfo.widgetID then
        return
    end
    
    local widgetData = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetInfo.widgetID)
    
    if not widgetData or not vigorFrame or not vigorFrame.bars then
        return
    end
    
    -- Hide all bars first
    for i = 1, 6 do
        local bar = vigorFrame.bars[i]
        if bar then
            bar:Hide()
        end
    end
    
    -- Update bars based on widget data  
    for i = 1, math.min(widgetData.numTotalFrames, 6) do
        local bar = vigorFrame.bars[i]
        if bar then
            bar:Show()
            
            -- Set up the bar range (0-100 for percentage-like display)
            bar:SetMinMaxValues(0, 100)
            
            if widgetData.numFullFrames >= i then
                -- Full charge - instantly fill to 100%
                updateVigorBarColor(bar, true, false)
                smoothSetValue(bar, 100)
            elseif widgetData.numFullFrames + 1 == i then
                -- Currently regenerating charge - show smooth progress
                local progress = 0
                if widgetData.fillMax > widgetData.fillMin then
                    progress = ((widgetData.fillValue - widgetData.fillMin) / (widgetData.fillMax - widgetData.fillMin)) * 100
                end
                updateVigorBarColor(bar, false, true)
                smoothSetValue(bar, math.max(0, math.min(100, progress)))
            else
                -- Empty charge
                updateVigorBarColor(bar, false, false)
                smoothSetValue(bar, 0)
            end
        end
    end
end

function zSkyridingBar:UpdateVigorBars()
    if not vigorFrame or not vigorFrame.bars then
        return
    end
    
    -- Get vigor information from power type as fallback
    local vigorType = Enum.PowerType.AlternateMount or 99 -- Skyriding vigor
    local currentVigor = UnitPower("player", vigorType)
    local maxVigor = UnitPowerMax("player", vigorType)
    
    if maxVigor <= 0 then
        -- Hide all vigor bars if no vigor system active
        for i, bar in ipairs(vigorFrame.bars) do
            if bar then
                bar:Hide()
            end
        end
        return
    end
    
    -- If we're at full vigor, hide the bars (like WeakAuras does)
    if currentVigor == maxVigor then
        for i, bar in ipairs(vigorFrame.bars) do
            if bar then
                bar:Hide()
            end
        end
        return
    end
    
    -- Calculate charges (each charge is typically 100 vigor)
    local chargeSize = math.floor(maxVigor / 6) -- Assume max 6 charges
    if chargeSize <= 0 then chargeSize = 100 end
    
    local numCharges = math.floor(maxVigor / chargeSize)
    local currentCharge = math.floor(currentVigor / chargeSize)
    local partialCharge = (currentVigor % chargeSize) / chargeSize
    
    -- Update visible bars (fallback method)
    for i = 1, 6 do
        local bar = vigorFrame.bars[i]
        if bar then
            if i <= numCharges then
                bar:Show()
                bar:SetMinMaxValues(0, 100)
                if i <= currentCharge then
                    updateVigorBarColor(bar, true, false)
                    smoothSetValue(bar, 100) -- Full charge
                elseif i == currentCharge + 1 then
                    updateVigorBarColor(bar, false, true)
                    smoothSetValue(bar, partialCharge * 100) -- Partial charge as percentage
                else
                    updateVigorBarColor(bar, false, false)
                    smoothSetValue(bar, 0) -- Empty charge
                end
            else
                bar:Hide()
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
        print("|cff00ff00zSkyridingBar|r: |cffFFFFFFMove mode enabled|r - Drag the frame to reposition. Type |cffFFFFFF/zsb move|r again to disable.")
        
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
    
    if vigorFrame then
        self:CreateVigorBars()
    end
    
    -- Update speed indicator
    if speedBar and speedBar.speedIndicator then
        speedBar.speedIndicator:SetColorTexture(unpack(self.db.profile.speedIndicatorColor))
        speedBar.speedIndicator:SetSize(2, self.db.profile.speedBarHeight + 4)
        
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
    else
        print("|cff00ff00zSkyridingBar|r commands:")
        print("  |cffFFFFFF/zsb|r - Open options panel")
        print("  |cffFFFFFF/zsb move|r - Toggle move mode")
        print("  |cffFFFFFF/zsb toggle|r - Toggle the addon")
    end
end
