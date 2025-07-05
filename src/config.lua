local settings = require('settings')

local config = {}

local default = T {
    profiles = {},
    lastProfileLoaded = nil
}

config.load = function ()
    return settings.load(default)
end

return config
