addon.name = 'trustme'
addon.version = "0.9"
addon.author = 'looney'
addon.desc = 'Simple addon to search through your trusts'
addon.link = 'https://github.com/loonsies/trustme'

require 'common'
local settings = require('settings')
local config = require('src.config')
local ui = require('src.ui')
local commands = require('src.commands')
local task = require('src.task')
local searchStatus = require('data.searchStatus')
local http = require('libs.nonBlockingRequests')

tme = {
    visible = { false },
    config = {},
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
    minSize = { 575, 200 },
    minModalSize = { 450, 0 },
    selectedProfile = nil,
    workerResult = nil,
    zoning = false
}

ashita.events.register('load', 'load_cb', function ()
    config.init(config.load())
    ui.init()

    settings.register('settings', 'settings_update_cb', function (newConfig)
        config.init(newConfig)
    end)
end)

ashita.events.register('command', 'command_cb', function (cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        commands.handleCommand(args)
    end
end)

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if e.id == 0x000A then
        if tme.zoning then
            tme.visible[1] = true
            tme.zoning = false
        end
    elseif e.id == 0x000B then
        if tme.visible[1] then
            tme.visible[1] = false
            tme.zoning = true
        end
    end
end)

ashita.events.register('packet_out', 'packet_out_cb', function (e)
    task.handleQueue()
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    ui.updateETA()
    ui.updateUI()
    http.processAll()
end)
