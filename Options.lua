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

-- Custom print function for addon messages
function zSkyridingBar:Print(message)
    print("zSkyridingBar: " .. message)
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
                zSkyridingBar.db:ResetProfile()
                zSkyridingBar:RefreshConfig()
                zSkyridingBar:Print(L["Reset all settings to default."])
            end,
            width = 0.8,
        },


        generalGroup = {
            order = nextOrder(),
            type = "group",
            name = L["General"],
            inline = true,
            args = {
                theme = {
                    order = nextOrder(),
                    type = "select",
                    name = L["Theme"],
                    desc = L["Choose UI theme (Classic or Thick)"],
                    values = {
                        classic = L["Classic"],
                        thick = L["Thick"],
                    },
                    get = function(info)
                        return zSkyridingBar.db.profile.theme or "classic"
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.theme = value
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
            },
        },

        positionSizeGroup = {
            order = nextOrder(),
            type = "group",
            name = L["Position and Size"],
            inline = true,
            args = {
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

                moveFrame = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Move Frame"],
                    desc = L["Toggle move mode to reposition the addon"],
                    func = function()
                        zSkyridingBar:ToggleMoveMode()
                    end,
                },

                spacer2 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },

                scale = {
                    order = nextOrder(),
                    type = "range",
                    name = L["Scale"],
                    desc = L["Set the scale of the addon"],
                    min = 0.5,
                    max = 3.0,
                    step = 0.1,
                    get = function(info)
                        return zSkyridingBar.db.profile.frameScale or 1
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.frameScale = value
                        zSkyridingBar:UpdateFramePositions()
                        zSkyridingBar:RefreshConfig()
                    end,
                    isPercent = true,
                },

                resetPosition = {
                    order = nextOrder(),
                    type = "execute",
                    name = L["Reset Position"],
                    desc = L["Reset position and size settings to defaults"],
                    func = function()
                        local defaults = zSkyridingBar.db.defaults.profile
                        zSkyridingBar.db.profile.speedBarX = defaults.speedBarX
                        zSkyridingBar.db.profile.speedBarY = defaults.speedBarY
                        zSkyridingBar.db.profile.chargesBarX = defaults.chargesBarX
                        zSkyridingBar.db.profile.chargesBarY = defaults.chargesBarY
                        zSkyridingBar.db.profile.speedAbilityX = defaults.speedAbilityX
                        zSkyridingBar.db.profile.speedAbilityY = defaults.speedAbilityY
                        zSkyridingBar.db.profile.secondWindX = defaults.secondWindX
                        zSkyridingBar.db.profile.secondWindY = defaults.secondWindY
                        zSkyridingBar.db.profile.frameScale = defaults.frameScale
                        zSkyridingBar.db.profile.frameStrata = defaults.frameStrata
                        zSkyridingBar.db.profile.speedBarWidth = defaults.speedBarWidth
                        zSkyridingBar.db.profile.speedBarHeight = defaults.speedBarHeight
                        zSkyridingBar.db.profile.chargeBarWidth = defaults.chargeBarWidth
                        zSkyridingBar.db.profile.chargeBarHeight = defaults.chargeBarHeight
                        zSkyridingBar:UpdateFramePositions()
                        zSkyridingBar:RefreshConfig()
                        zSkyridingBar:Print(L["Reset position and size to defaults."])
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
                        zSkyridingBar.db.profile.speedBarBackgroundColor = {r, g, b, a}
                        zSkyridingBar:RefreshConfig()
                    end,
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
                        zSkyridingBar.db.profile.chargeBarBackgroundColor = {r, g, b, a}
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacer_background = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                    width = "full",
                },

                defaultSpeedColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Default Speed Color"],
                    desc = L["Color for normal speed"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.speedBarColor
                        if not color then 
                            local defaults = zSkyridingBar.db.defaults.profile.speedBarColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.speedBarColor = { r, g, b, a }
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
                baseChargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Base Charge Color"],
                    desc = L["Color for base charge"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.chargeBarSlowRechargeColor
                        if not color then 
                            local defaults = zSkyridingBar.db.defaults.profile.chargeBarSlowRechargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.chargeBarSlowRechargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacer4 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },

                chargingChargeColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Optimal Charge Color"],
                    desc = L["Color when charge is charging at highest speed"],
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
                    name = L["Full Charge Charge Color"],
                    desc = L["Color when charge is at full charge"],
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
                        zSkyridingBar.db.profile.speedBarColor = defaults.speedBarColor
                        zSkyridingBar.db.profile.speedBarBoostColor = defaults.speedBarBoostColor
                        zSkyridingBar.db.profile.speedBarThrillColor = defaults.speedBarThrillColor
                        zSkyridingBar.db.profile.chargeBarColor = defaults.chargeBarColor
                        zSkyridingBar.db.profile.chargeBarFastRechargeColor = defaults.chargeBarFastRechargeColor
                        zSkyridingBar.db.profile.speedIndicatorColor = defaults.speedIndicatorColor
                        zSkyridingBar.db.profile.chargeBarFullColor = defaults.chargeBarFullColor
                        zSkyridingBar.db.profile.chargeBarSlowRechargeColor = defaults.chargeBarSlowRechargeColor
                        zSkyridingBar.db.profile.chargeBarEmptyColor = defaults.chargeBarEmptyColor
                        zSkyridingBar.db.profile.speedBarTexture = defaults.speedBarTexture
                        zSkyridingBar.db.profile.chargeBarTexture = defaults.chargeBarTexture
                        zSkyridingBar.db.profile.speedBarBackgroundColor = defaults.speedBarBackgroundColor
                        zSkyridingBar.db.profile.chargeBarBackgroundColor = defaults.chargeBarBackgroundColor
                        zSkyridingBar.db.profile.secondWindNoChargeColor = defaults.secondWindNoChargeColor
                        zSkyridingBar.db.profile.secondWindOneChargeColor = defaults.secondWindOneChargeColor
                        zSkyridingBar.db.profile.secondWindTwoChargeColor = defaults.secondWindTwoChargeColor
                        zSkyridingBar.db.profile.secondWindThreeChargeColor = defaults.secondWindThreeChargeColor
                        zSkyridingBar:RefreshConfig()
                        zSkyridingBar:Print(L["Reset colors and textures to defaults."])
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
