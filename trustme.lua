addon.name = 'trustme'
addon.version = '0.3'
addon.author = 'looney'
addon.desc = 'Simple addon to search through your trusts'
addon.link = 'https://github.com/loonsies/trustme'

require 'common'
local chat = require('chat')
local config = require('src/config')
local ui = require('src/ui')
local commands = require('src/commands')
local trustUtils = require('src/trustUtils')
local search = require('src/search')
local task = require('src/task')
local profiles = require('src/profiles')
local searchStatus = require('data/searchStatus')
local ffi = require('ffi')

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
    selectedProfile = nil,
    worker = nil,
    workerResult = nil
}

ashita.events.register('load', 'load_cb', function ()
    tme.selectedProfile = tme.config.lastProfileLoaded or nil
    profiles.loadTrusts(tme.selectedProfile)
end)

ashita.events.register('unload', 'unload_cb', function ()
    if tme.worker ~= nil then
        print(chat.header(addon.name):append(chat.error('Thread is still running, allowing up to 10 seconds for graceful shutdown...')))
        local waitResult = tme.worker:wait(10 * 1000)

        if waitResult == 0x102 then -- WAIT_TIMEOUT
            print(chat.header(addon.name):append(chat.error('Thread was forcibly terminated due to exceeding the timeout')))
        end

        tme.worker:close()
        tme.worker = nil
    end
end)

ashita.events.register('command', 'command_cb', function (cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        commands.handleCommand(args)
    end
end)

ashita.events.register('packet_out', 'packet_out_cb', function (e)
    task.handleQueue()
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    ui.updateETA()
    ui.updateUI()
    trustUtils.pollWorker()
end)
