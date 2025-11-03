-- Options.lua - Configuration panel for zSkyridingBar

local zSkyridingBar = LibStub("AceAddon-3.0"):GetAddon("zSkyridingBar")

-- Get localization (using simple strings for now, can be expanded)
local L = setmetatable({}, {
    __index = function(t, k)
        return k
    end
})

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
                hideDefaultVigorUI = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Hide Default Vigor UI"],
                    desc = L["Hide Blizzard's default vigor/power bar when skyriding"],
                    get = function(info)
                        return zSkyridingBar.db.profile.hideDefaultVigorUI
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.hideDefaultVigorUI = value
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                showRechargeIndicator = {
                    order = nextOrder(),
                    type = "toggle",
                    name = L["Show Recharge Indicator"],
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
                        zSkyridingBar.db.profile.frameX = defaults.frameX
                        zSkyridingBar.db.profile.frameY = defaults.frameY
                        zSkyridingBar.db.profile.frameScale = defaults.frameScale
                        zSkyridingBar.db.profile.frameStrata = defaults.frameStrata
                        zSkyridingBar.db.profile.speedBarWidth = defaults.speedBarWidth
                        zSkyridingBar.db.profile.speedBarHeight = defaults.speedBarHeight
                        zSkyridingBar.db.profile.vigorBarWidth = defaults.vigorBarWidth
                        zSkyridingBar.db.profile.vigorBarHeight = defaults.vigorBarHeight
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

                vigorBarTexture = {
                    order = nextOrder(),
                    type = "select",
                    dialogControl = "LSM30_Statusbar",
                    name = L["Vigor Bar Texture"],
                    desc = L["Texture for the vigor bars"],
                    values = LibStub("LibSharedMedia-3.0"):HashTable("statusbar"),
                    get = function(info)
                        return zSkyridingBar.db.profile.vigorBarTexture
                    end,
                    set = function(info, value)
                        zSkyridingBar.db.profile.vigorBarTexture = value
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

                vigorBarBackgroundColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Vigor Bar Background Color"],
                    desc = L["Background color for the vigor bars"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.vigorBarBackgroundColor
                        if not color then 
                            local defaults = zSkyridingBar.db.defaults.profile.vigorBarBackgroundColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.vigorBarBackgroundColor = {r, g, b, a}
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
                baseVigorColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Base Vigor Color"],
                    desc = L["Color for base vigor"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.vigorBarSlowRechargeColor
                        if not color then 
                            local defaults = zSkyridingBar.db.defaults.profile.vigorBarSlowRechargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.vigorBarSlowRechargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },

                spacer4 = {
                    order = nextOrder(),
                    type = "description",
                    name = "",
                },

                chargingVigorColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Charging Vigor Color"],
                    desc = L["Color when vigor is charging fast"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.vigorBarFastRechargeColor
                        if not color then 
                            local defaults = zSkyridingBar.db.defaults.profile.vigorBarFastRechargeColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.vigorBarFastRechargeColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                fullChargeVigorColor = {
                    order = nextOrder(),
                    type = "color",
                    name = L["Full Charge Vigor Color"],
                    desc = L["Color when vigor is at full charge"],
                    hasAlpha = true,
                    get = function(info)
                        local color = zSkyridingBar.db.profile.vigorBarFullColor
                        if not color then 
                            local defaults = zSkyridingBar.db.defaults.profile.vigorBarFullColor
                            return defaults[1], defaults[2], defaults[3], defaults[4]
                        end
                        return color[1], color[2], color[3], color[4]
                    end,
                    set = function(info, r, g, b, a)
                        zSkyridingBar.db.profile.vigorBarFullColor = { r, g, b, a }
                        zSkyridingBar:RefreshConfig()
                    end,
                },
                spacer5 = {
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
                        zSkyridingBar.db.profile.vigorBarColor = defaults.vigorBarColor
                        zSkyridingBar.db.profile.vigorBarFastRechargeColor = defaults.vigorBarFastRechargeColor
                        zSkyridingBar.db.profile.speedIndicatorColor = defaults.speedIndicatorColor
                        zSkyridingBar.db.profile.vigorBarFullColor = defaults.vigorBarFullColor
                        zSkyridingBar.db.profile.vigorBarSlowRechargeColor = defaults.vigorBarSlowRechargeColor
                        zSkyridingBar.db.profile.vigorBarEmptyColor = defaults.vigorBarEmptyColor
                        zSkyridingBar.db.profile.speedBarTexture = defaults.speedBarTexture
                        zSkyridingBar.db.profile.vigorBarTexture = defaults.vigorBarTexture
                        zSkyridingBar.db.profile.speedBarBackgroundColor = defaults.speedBarBackgroundColor
                        zSkyridingBar.db.profile.vigorBarBackgroundColor = defaults.vigorBarBackgroundColor
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
