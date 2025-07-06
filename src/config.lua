local settings = require('settings')
local profiles = require('src/profiles')

local config = {}

local default = T {
    profiles = {},
    lastProfileLoaded = nil
}

config.load = function ()
    return settings.load(default)
end

config.init = function (cfg)
    tme.config = cfg
    tme.selectedProfile = tme.config.lastProfileLoaded or nil
    profiles.loadTrusts(tme.selectedProfile)
end

return config
