addon.name = 'trustme'
addon.version = "0.4"
addon.author = 'looney'
addon.desc = 'Simple addon to search through your trusts'
addon.link = 'https://github.com/loonsies/trustme'

-- Ashita dependencies
require 'common'
chat = require('chat')
settings = require('settings')
imgui = require('imgui')
http = require('socket.http')
ltn12 = require('socket.ltn12')

-- Local dependencies
ui = require('src/ui')
commands = require('src/commands')
config = require('src/config')
task = require('src/task')
search = require('src/search')
utils = require('src/utils')
profiles = require('src/profiles')

searchStatus = require('data/searchStatus')
profileActions = require('data/profileActions')

tme = {
    visible = { false },
    config = config.load(),
    search = {
        results = {},
        input = { '' },
        previousInput = { '' },
        status = searchStatus.noResults,
        selectedTrusts = {},
        previousSelectedTrusts = nil,
        startup = true
    },
    eta = 0,
    lastUpdateTime = os.clock(),
    queue = {},
    minSize = { 700, 200 },
    minModalSize = { 450, 0 },
    selectedProfile = nil
}

tme.selectedProfile = tme.config.lastProfileLoaded or nil

ashita.events.register('command', 'command_cb', function (cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        commands.handleCommand(args)
    end
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    ui.updateETA()
    ui.updateUI()
end)
