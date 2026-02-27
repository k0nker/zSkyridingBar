-- Options.lua - Configuration panel for zSkyridingBar

local zSkyridingBar = LibStub("AceAddon-3.0"):GetAddon("zSkyridingBar")

-- Get localization from AceLocale
local L = LibStub("AceLocale-3.0"):GetLocale("zSkyridingBar")

-- Order counter for dynamic ordering
local orderCounter = 0
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

local function resetOrder()
    orderCounter = 0
end

-- True when the active profile is one of the locked built-in presets.
local function isBuiltinProfile()
    local cur = zSkyridingBar.db:GetCurrentProfile()
    return cur == "Classic" or cur == "Thick"
end


-- Options table
local options = {
    type = "group",
    name = "zSkyridingBar",
    handler = zSkyridingBar,
    get = function(info)
        return zSkyridingBar.db.profile[info[#info]]
    end,
    set = function(info, value)
        zSkyridingBar.db.profile[info[#info]] = value
        zSkyridingBar:RefreshConfig()
    end,
    args = {
        header = {
            order = nextOrder(),
            type = "header",
            name = L["zSkyridingBar Options"],
        },

        enabled = {
            order = nextOrder(),
            type = "toggle",
            name = L["Enable"],
            desc = L["Enable/disable the addon"],
            get = function(info)
                return zSkyridingBar.db.profile.enabled
            end,
            set = function(info, value)
                zSkyridingBar.db.profile.enabled = value
                if value then
                    zSkyridingBar:Enable()
                else
                    zSkyridingBar:Disable()
                end
            end,
            width = 0.8,
        },

        resetAll = {
            order = nextOrder(),
            type = "execute",
            name = L["Reset All"],
            desc = L["Reset all settings to default values"],
            func = function()
                zSkyridingBar:ResetCurrentProfile()
            end,
            width = 0.8,
        },


        generalGroup = {
            order = nextOrder(),
            type = "group",
            name = L["General"],
            inline = true,
            args = {
                profilesHeader = {
                    order = nextOrder(),
                    type = "header",
                    name = L["Profile"],
                },
                activeProfile = {
                    order = nextOrder(),
                    type = "select",
                    name = L["Active Profile"],
                    desc = L["Switch between saved setting profiles"],
                    values = function()
                        -- Always show Classic and Thick even before they are seeded
                        local profiles = { Classic = "Classic", Thick = "Thick" }
                        for name, _ in pairs(zSkyridingBar.db.profiles) do
                            profiles[name] = name
                        end
                        return profiles
                    end,
                    get = function()
                        return zSkyridingBar.db:GetCurrentProfile()
                    end,
                    set = function(_, value)
                        zSkyridingBar.db:SetProfile(value)
                        zSkyridingBar:RefreshConfig()
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("zSkyridingBar")
                    end,
                    width = "double",
                },
                newProfile = {
                    order = nextOrder(),
                    type = "input",
                    name = L["New Profile"],
                    desc = L["Type a name and press Enter to create a new profile"],
                    get = function() return "" end,
                    set = function(_, value)
                        if not value or value == "" then return end
                        zSkyridingBar:CreateNewProfile(value)
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("zSkyridingBar")
                    end,
                },
                deleteProfile = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Delete Profile"],
                    desc = L["Delete the current profile (cannot delete Classic or Thick)"],
                    disabled = function()
                        local cur = zSkyridingBar.db:GetCurrentProfile()
                        return cur == "Classic" or cur == "Thick"
                    end,
                    confirm = function()
                        return L["Are you sure you want to delete the profile: "] ..
                            "'" .. zSkyridingBar.db:GetCurrentProfile() .. "'?"
                    end,
                    func = function()
                        zSkyridingBar:DeleteCurrentProfile()
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("zSkyridingBar")
                    end,
                },
                profileSpacer = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                generalHeader = {
                    order = nextOrder(),
                    type = "header",
                    name = L["General Settings"],
                },
                chargeRefreshSound = {
                    order = nextOrder(),
                    type = "select",
                    name = L["Charge Refresh Sound"],
                    desc = L["Sound to play when a skyriding charge refreshes"],
                    values = {
                        [0] = L["Disabled"],
                        [39516] = L["Store Purchase"],
                        [90104] = L["Ting!"],
                        [171373] = L["Contribute"],
                        [200835] = L["Azerite Hammer"],
                        [213208] = L["Renown Whoosh"],
                        [231912] = L["Stereo Toast Low"],
                        [233378] = L["Digsite Toast"],
                        [233592] = L["Ping Assist"],
                        [237328] = L["Lightwell"],
                        [241984] = L["Holy Impact"],
                        [254762] = L["Stereo Toast High"],
                        [278769] = L["Chime"],
                        [303828] = L["Store Toast"],

                    },
                    get = function(info)
                        -- Return 0 if sound is disabled, otherwise return the sound ID
                        if zSkyridingBar.db.profile.chargeRefreshSound then
                            return zSkyridingBar.db.profile.chargeRefreshSoundId
                        else
                            return 0
                        end
                    end,
                    set = function(info, value)
                        if value == 0 then
                            zSkyridingBar.db.profile.chargeRefreshSound = false
                        else
                            zSkyridingBar.db.profile.chargeRefreshSound = true
                            zSkyridingBar.db.profile.chargeRefreshSoundId = value
                            -- Preview the selected sound
                            zSkyridingBar:PreviewChargeSound()
                        end
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacerTheme = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },

                showRechargeIndicator = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Recharge Indicator"],
                    desc = L["Show indicator line at 60% on speed bar"],
                    get = function(info)
                        return zSkyridingBar.db.profile.showSpeedIndicator
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.showSpeedIndicator = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacer1 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },

                showSpeed = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Show Speed"],
                    desc = L["Display speed value on the speed bar"],
                    get = function(info)
                        return zSkyridingBar.db.profile.speedShow
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.speedShow = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                speedUnits = {
                    order = nextOrder(),
                    type = "select",
                    name = L["Speed Units"],
                    desc = L["Format to display speed value in"],
                    values = {
                        [1] = L["yd/s"],
                        [2] = L["move%"],
                    },
                    get = function(info)
                        return zSkyridingBar.db.profile.speedUnits
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.speedUnits = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                fontSpacer1 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                fontSize = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Font Size"],
                    desc = L["Set the font size"],
                    min = 8,
                    max = 32,
                    step = 1,
                    get = function(info)
                        return zSkyridingBar.db.profile.fontSize or 12
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.fontSize = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                fontColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Font Color"],
                    desc = L["Set the font color"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.fontColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.fontColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.fontColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                fontSpacer2 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                fontFace = {
                    order = nextOrder(),
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = L["Font Face"],
                    desc = L["Set the font face"],
                    values = LibStub("LibSharedMedia-3.0"):HashTable("font"),
                    get = function(info)
                        return zSkyridingBar.db.profile.fontFace or "Homespun"
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.fontFace = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                fontFlag = {
                    order = nextOrder(),
                    type = "select",
                    name = L["Font Flags"],
                    desc = L["Set the font flags"],
                    values = {
                        [""] = L["None"],
                        ["OUTLINE"] = L["Outline"],
                        ["THICKOUTLINE"] = L["Thick Outline"],
                        ["MONOCHROME"] = L["Monochrome"],
                    },
                    get = function(info)
                        return zSkyridingBar.db.profile.fontFlag
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.fontFlag = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
            },
        },

        positionSizeGroup = {
            order = nextOrder(),
            type = "group",
            name = L["Position and Size"],
            inline = true,
            args = {
                frameHeader = {
                    order = nextOrder(),
                    type = "header",
                    name = L["Frame Settings"],
                },
                framespacer01 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                frameStrata = {
                    order = nextOrder(),
                    type = "select",
                    name = L["Frame Strata"],
                    desc = L["Set the frame strata (layer) of the addon"],
                    values = {
                        ["BACKGROUND"] = L["Background"],
                        ["LOW"] = L["Low"],
                        ["MEDIUM"] = L["Medium"],
                        ["HIGH"] = L["High"],
                        ["DIALOG"] = L["Dialog"],
                        ["TOOLTIP"] = L["Tooltip"],
                    },
                },

                singleFrameMode = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Single Frame Mode"],
                    desc = "Group all frames under one master frame in EditMode. Disable for independent per-frame positioning.",
                    get = function(info)
                        return zSkyridingBar.db.profile.singleFrameMode
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.singleFrameMode = value
                        zSkyridingBar:CreateAllFrames()
                    end,
                },
                framespacer02 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                moveFrame = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Move Frame"],
                    desc = L["Open EditMode to reposition the addon"],
                    func = function()
                        zSkyridingBar:OpenEditMode()
                    end,
                },
                sizeSpacer01 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                barHeader = {
                    order = nextOrder(),
                    type = "header",
                    name = L["Bar Settings"],
                },
                speedBarWidth = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Speed Bar Width"],
                    desc = L["Set the width of the speed bar"],
                    min = 10,
                    max = 800,
                    step = 1,
                    disabled = isBuiltinProfile,
                    get = function(info)
                        return zSkyridingBar.db.profile.speedBarWidth
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.speedBarWidth = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                speedBarHeight = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Speed Bar Height"],
                    desc = L["Set the height of the speed bar"],
                    min = 10,
                    max = 800,
                    step = 1,
                    disabled = isBuiltinProfile,
                    get = function(info)
                        return zSkyridingBar.db.profile.speedBarHeight
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.speedBarHeight = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                sizeSpacer02 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                resetSpeedBarSize = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Reset Speed Bar Size"],
                    desc = L["Reset speed bar size to default"],
                    disabled = isBuiltinProfile,
                    func = function()
                        zSkyridingBar.db.profile.speedBarWidth = zSkyridingBar.db.defaults.profile.speedBarWidth
                        zSkyridingBar.db.profile.speedBarHeight = zSkyridingBar.db.defaults.profile.speedBarHeight
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                hideSpeedBar = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Hide Speed Bar"],
                    desc = L["Hide the speed bar"],
                    get = function(info)
                        return zSkyridingBar.db.profile.hideSpeedBar
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.hideSpeedBar = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                sizeSpacer03 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                chargeBarWidth = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Charge Bar Width"],
                    desc = L["Set the width of the charge bars"],
                    min = 10,
                    max = 800,
                    step = 1,
                    disabled = isBuiltinProfile,
                    get = function(info)
                        return zSkyridingBar.db.profile.chargeBarWidth
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.chargeBarWidth = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                chargeBarHeight = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Charge Bar Height"],
                    desc = L["Set the height of the charge bars"],
                    min = 10,
                    max = 800,
                    step = 1,
                    disabled = isBuiltinProfile,
                    get = function(info)
                        return zSkyridingBar.db.profile.chargeBarHeight
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.chargeBarHeight = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                sizeSpacer04 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                chargeBarSpacing = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Charge Bar Spacing"],
                    desc = L["Set the spacing between charge bars"],
                    min = 0,
                    max = 200,
                    step = 1,
                    disabled = isBuiltinProfile,
                    get = function(info)
                        return zSkyridingBar.db.profile.chargeBarSpacing
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.chargeBarSpacing = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                sizeSpacer05 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                resetChargeBarSize = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Reset Charge Bar Size"],
                    desc = L["Reset charge bar size to default"],
                    disabled = isBuiltinProfile,
                    func = function()
                        zSkyridingBar.db.profile.chargeBarWidth = zSkyridingBar.db.defaults.profile.chargeBarWidth
                        zSkyridingBar.db.profile.chargeBarHeight = zSkyridingBar.db.defaults.profile.chargeBarHeight
                        zSkyridingBar.db.profile.chargeBarSpacing = zSkyridingBar.db.defaults.profile.chargeBarSpacing
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                hideChargeBar = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Hide Charge Bars"],
                    desc = L["Hide the charge bars"],
                    get = function(info)
                        return zSkyridingBar.db.profile.hideChargeBar
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.hideChargeBar = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                sizeSpacer06 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                secondWindBarWidth = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Second Wind Bar Width"],
                    desc = L["Set the width of the second wind bar"],
                    min = 10,
                    max = 800,
                    step = 1,
                    disabled = isBuiltinProfile,
                    get = function(info)
                        return zSkyridingBar.db.profile.secondWindBarWidth
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.secondWindBarWidth = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                secondWindBarHeight = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Second Wind Bar Height"],
                    desc = L["Set the height of the second wind bar"],
                    min = 10,
                    max = 800,
                    step = 1,
                    disabled = isBuiltinProfile,
                    get = function(info)
                        return zSkyridingBar.db.profile.secondWindBarHeight
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.secondWindBarHeight = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                sizeSpacer07 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                resetSecondWindBarSize = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Reset Second Wind Bar Size"],
                    desc = L["Reset second wind bar size to default"],
                    disabled = isBuiltinProfile,
                    func = function()
                        zSkyridingBar.db.profile.secondWindBarWidth = zSkyridingBar.db.defaults.profile.secondWindBarWidth
                        zSkyridingBar.db.profile.secondWindBarHeight = zSkyridingBar.db.defaults.profile.secondWindBarHeight
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                hideSecondWindBar = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Hide Second Wind Bar"],
                    desc = L["Hide the second wind bar"],
                    get = function(info)
                        return zSkyridingBar.db.profile.hideSecondWindBar
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.hideSecondWindBar = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                sizeSpacer08 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },
                hideSpeedAbility = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Hide Speed Ability"],
                    desc = L["Hide the speed ability"],
                    get = function(info)
                        return zSkyridingBar.db.profile.hideSpeedAbility
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.hideSpeedAbility = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },
            },
        },

        colorsGroup = {
            order = nextOrder(),
            type = "group",
            name = L["Colors"],
            inline = true,
            args = {
                themeHeader = {
                    order = nextOrder(),
                    type = "header",
                    name = L["Color and Texture Settings"],
                },
                speedBarTexture = {
                    order = nextOrder(),
                    type = "select",
                    dialogControl = "LSM30_Statusbar",
                    name = L["Speed Bar Texture"],
                    desc = L["Texture for the speed bar"],
                    values = LibStub("LibSharedMedia-3.0"):HashTable("statusbar"),
                    get = function(info)
                        return zSkyridingBar.db.profile.speedBarTexture
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.speedBarTexture = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                chargeBarTexture = {
                    order = nextOrder(),
                    type = "select",
                    dialogControl = "LSM30_Statusbar",
                    name = L["Charge Bar Texture"],
                    desc = L["Texture for the charge bars"],
                    values = LibStub("LibSharedMedia-3.0"):HashTable("statusbar"),
                    get = function(info)
                        return zSkyridingBar.db.profile.chargeBarTexture
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.chargeBarTexture = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacer_textures = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },

                speedBarBackgroundColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Speed Bar Background Color"],
                    desc = L["Background color for the speed bar"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.speedBarBackgroundColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.speedBarBackgroundColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.speedBarBackgroundColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                defaultSpeedColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Default Speed Color"],
                    desc = L["Color for normal speed"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.speedBarNormalColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.speedBarNormalColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.speedBarNormalColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                spacer1 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },

                optimalSpeedColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Optimal Speed Color"],
                    desc = L["Color for optimal speed/thrill"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.speedBarThrillColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.speedBarThrillColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.speedBarThrillColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                fastSpeedColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Fast Speed Color"],
                    desc = L["Color for fast speed/boosting"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.speedBarBoostColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.speedBarBoostColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.speedBarBoostColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacer2 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },

                rechargeIndicatorColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Recharge Indicator Color"],
                    desc = L["Color for recharge indicator"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.speedIndicatorColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.speedIndicatorColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.speedIndicatorColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                spacer3 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },
                chargeBarBackgroundColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Charge Bar Background Color"],
                    desc = L["Background color for the charge bars"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.chargeBarBackgroundColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.chargeBarBackgroundColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.chargeBarBackgroundColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                slowRechargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Normal Recharge"],
                    desc = L["Color for normal recharge speed"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.chargeBarNormalRechargeColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.chargeBarNormalRechargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.chargeBarNormalRechargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacer4 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },

                fastRechargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Fast Recharge"],
                    desc = L["Color when recharge is at highest speed"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.chargeBarFastRechargeColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.chargeBarFastRechargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.chargeBarFastRechargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                fullChargeChargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Full Recharge"],
                    desc = L["Color when recharge is full"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.chargeBarFullColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.chargeBarFullColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.chargeBarFullColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                spacer5 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },
                noSecondWindChargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["No Wind"],
                    desc = L["Color when there are no second wind charges"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.secondWindNoChargeColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.secondWindNoChargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.secondWindNoChargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                oneSecondWindChargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["One Wind"],
                    desc = L["Color when there is 1 second wind charge"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.secondWindOneChargeColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.secondWindOneChargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.secondWindOneChargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                spacer6 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },
                twoSecondWindChargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Two Winds"],
                    desc = L["Color when there are 2 second wind charges"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.secondWindTwoChargeColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.secondWindTwoChargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.secondWindTwoChargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                threeSecondWindChargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Three Wind"],
                    desc = L["Color when there are 3 second wind charges"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.secondWindThreeChargeColor
                        if not color then
                            local defaults = zSkyridingBar.db.defaults.profile.secondWindThreeChargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.secondWindThreeChargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                spacer7 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },
                resetColors = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Reset Colors"],
                    desc = L["Reset all color settings and textures to defaults"],
                    func = function()
                        local defaults = zSkyridingBar.db.defaults.profile
                        zSkyridingBar.db.profile.speedBarNormalColor = defaults.speedBarNormalColor
                        zSkyridingBar.db.profile.speedBarBoostColor = defaults.speedBarBoostColor
                        zSkyridingBar.db.profile.speedBarThrillColor = defaults.speedBarThrillColor
                        zSkyridingBar.db.profile.chargeBarColor = defaults.chargeBarColor
                        zSkyridingBar.db.profile.chargeBarFastRechargeColor = defaults.chargeBarFastRechargeColor
                        zSkyridingBar.db.profile.speedIndicatorColor = defaults.speedIndicatorColor
                        zSkyridingBar.db.profile.chargeBarFullColor = defaults.chargeBarFullColor
                        zSkyridingBar.db.profile.chargeBarNormalRechargeColor = defaults.chargeBarNormalRechargeColor
                        zSkyridingBar.db.profile.speedBarTexture = defaults.speedBarTexture
                        zSkyridingBar.db.profile.chargeBarTexture = defaults.chargeBarTexture
                        zSkyridingBar.db.profile.speedBarBackgroundColor = defaults.speedBarBackgroundColor
                        zSkyridingBar.db.profile.chargeBarBackgroundColor = defaults.chargeBarBackgroundColor
                        zSkyridingBar.db.profile.secondWindNoChargeColor = defaults.secondWindNoChargeColor
                        zSkyridingBar.db.profile.secondWindOneChargeColor = defaults.secondWindOneChargeColor
                        zSkyridingBar.db.profile.secondWindTwoChargeColor = defaults.secondWindTwoChargeColor
                        zSkyridingBar.db.profile.secondWindThreeChargeColor = defaults.secondWindThreeChargeColor
                        zSkyridingBar:RefreshConfig()
                        zSkyridingBar:UpdateFonts()
                        zSkyridingBar.print(L["Reset colors and textures to defaults."])
                    end,
                },
            },
        },
    },
}

-- GetOptionsTable function to be called from main addon
function zSkyridingBar:GetOptionsTable()
    resetOrder()
    return options
end
