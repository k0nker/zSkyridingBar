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
    speedUnits = 2, -- 1 = yd/s, 2 = move%
    hideDefaultSpeedUI = true,
    
    -- Position settings
    frameX = 0,
    frameY = -167,
    frameScale = 1,
    frameStrata = "MEDIUM",
    
    -- Speed bar settings
    speedBarWidth = 256,
    speedBarHeight = 18,
    speedBarTexture = getDefaultTexture(),
    speedBarColor = {0.749, 0.439, 0.173, 1}, -- not recharging
    speedBarThrillColor = {0.314, 0.537, 0.157, 1}, -- recharging, but at an optimal speed
    speedBarBoostColor = {0.2, 0.4, 0.45, 1}, -- super fast color
    speedBarBackgroundColor = {0, 0, 0, 0.4},
    
    -- Vigor bar settings
    chargeBarWidth = 256,
    chargeBarHeight = 12,
    chargeBarSpacing = 2,
    chargeBarTexture = getDefaultTexture(),
    chargeBarFullColor = {0.2, 0.37, 0.8, 1},
    chargeBarFastRechargeColor = {0.314, 0.537, 0.3, 1},
    chargeBarSlowRechargeColor = {0.53, 0.29, 0.2, 1},
    chargeBarEmptyColor = {0.15, 0.15, 0.15, 0.8},
    chargeBarBackgroundColor = {0, 0, 0, 0.4},
    
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
-- Main addon table
zSkyridingBar = LibStub("AceAddon-3.0"):GetAddon("zSkyridingBar", true) or LibStub("AceAddon-3.0"):NewAddon("zSkyridingBar", "AceEvent-3.0", "AceTimer-3.0")

local chargeFrame = nil
local speedText = nil
local angleText = nil
local eventFrame = nil
local moveMode = false

-- Localized functions
local GetTime = GetTime
local C_PlayerInfo = C_PlayerInfo
local C_UnitAuras = C_UnitAuras


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
local function updateChargeBarColor(bar, isFull, isRecharging)
    if not bar then return end
    
    local color
    if isFull then
        color = zSkyridingBar.db.profile.chargeBarFullColor
        bar.isFull = true
    elseif isRecharging then
        -- Check for Thrill of the Skies buff like WeakAuras does
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
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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
        elseif event == "ZONE_CHANGED_NEW_AREA" then
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
        if chargeFrame then
            chargeFrame:SetSize(self.db.profile.speedBarWidth, 30)
            
            -- Update vigor bar textures and background colors
            local vigorTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.chargeBarTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
            for i = 1, 4 do
                local bar = chargeFrame["bar" .. i]
                if bar then
                    bar:SetStatusBarTexture(vigorTexture)
                    if bar.bg then
                        bar.bg:SetTexture(vigorTexture)
                        bar.bg:SetVertexColor(unpack(self.db.profile.chargeBarBackgroundColor))
                    end
                end
            end
        end
        
        -- Update main frame size
        local totalHeight = self.db.profile.speedBarHeight + 5 + 30
        mainFrame:SetSize(self.db.profile.speedBarWidth, totalHeight)
        
        -- Update default vigor UI visibility

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
    chargeFrame = CreateFrame("Frame", "zSkyridingBarVigorFrame", mainFrame)
    chargeFrame:SetSize(self.db.profile.speedBarWidth, 30)
    chargeFrame:SetPoint("TOP", speedBar, "BOTTOM", 0, -5)
    
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
    local numBars = 6  -- Max possible vigor charges
    local barWidth = (self.db.profile.chargeBarWidth - ((numBars - 1) * self.db.profile.chargeBarSpacing)) / numBars
    
    for i = 1, numBars do
        local bar = CreateFrame("StatusBar", "zSkyridingBarChargeBar" .. i, chargeFrame)
        bar:SetSize(barWidth, self.db.profile.chargeBarHeight)
        
        if i == 1 then
            bar:SetPoint("LEFT", chargeFrame, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", chargeFrame.bars[i-1], "RIGHT", self.db.profile.chargeBarSpacing, 0)
        end
        
        local vigorTexture = LibStub("LibSharedMedia-3.0"):Fetch("statusbar", self.db.profile.chargeBarTexture) or "Interface\\TargetingFrame\\UI-StatusBar"
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
        
        -- Border
        local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        border:SetBackdropBorderColor(0, 0, 0, 1)
        
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
    self:CheckSkyridingAvailability()
end

function zSkyridingBar:OnUnitAura(unitTarget)
    -- Handle aura changes for immediate speed bar color updates
    if unitTarget == "player" and active and speedBar then
        -- Force an immediate color update when player auras change
        -- This will catch Thrill of the Skies appearing/disappearing instantly
        self:UpdateSpeedBarColors()
    end
end

function zSkyridingBar:UpdateSpeedBarColors()
    -- Lightweight function to update speed bar colors immediately
    if not active or not speedBar then
        return
    end
    
    -- Check for Thrill of the Skies buff (same logic as Liroo)
    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(THRILL_BUFF_ID)
    local time = GetTime()
    local boosting = thrill and time < ascentStart + ASCENT_DURATION
    
    -- Update color based on state (matching Liroo's priority)
    if boosting then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarBoostColor)) -- Green for boosting
    elseif thrill then
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarThrillColor)) -- Blue for thrill
    else
        speedBar:SetStatusBarColor(unpack(self.db.profile.speedBarColor)) -- Default orange
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
        -- Immediately update speed bar color when ascent starts (for instant "boosting" color)
        if active and speedBar then
            self:UpdateSpeedBarColors()
        end
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
    
    -- Show/hide speed frame based on skyriding state
    if not isGliding and not isFlying then
        if speedBar then
            speedBar:Hide()
        end
        return
    else
        if speedBar then
            speedBar:Show()
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
    
    -- Update color based on state using dedicated function
    self:UpdateSpeedBarColors()
    
    -- Also update vigor/charge bars periodically (for 11.2.7 charge system)
    self:UpdateChargeBars()
end



function zSkyridingBar:UpdateChargeBars()
    if not chargeFrame or not chargeFrame.bars then
        return
    end
    
    local surgeForwardID = 372608 -- Surge Forward spell
    local spellChargeInfo = C_Spell.GetSpellCharges(surgeForwardID)
    
    -- Debug output (can be removed later)
    -- print(string.format("zSkyridingBar: Charges: %s/%s", 
    --     spellChargeInfo and spellChargeInfo.currentCharges or "?",
    --     spellChargeInfo and spellChargeInfo.maxCharges or "?"))
    
    if spellChargeInfo and spellChargeInfo.currentCharges and spellChargeInfo.maxCharges then
        local charges = spellChargeInfo.currentCharges
        local maxCharges = spellChargeInfo.maxCharges
        local start = spellChargeInfo.cooldownStartTime
        local duration = spellChargeInfo.cooldownDuration
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
                elseif i == charges + 1 and start and duration and duration > 0 then
                    -- Currently recharging (next charge) - smooth animation
                    local elapsed = GetTime() - start
                    local progress = math.min(100, (elapsed / duration) * 100)
                    updateChargeBarColor(bar, false, true)
                    smoothSetValue(bar, progress)
                else
                    -- Empty charge - set instantly
                    updateChargeBarColor(bar, false, false)
                    bar:SetValue(0)
                    bar.currentValue = 0
                    bar.targetValue = 0
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
        -- print("zSkyridingBar: Spell charges not available, showing test bars")
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
    
    if chargeFrame then
        self:CreateChargeBars()
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
