addon.name = 'trustme'
addon.version = '0.4'
addon.author = 'looney'
addon.desc = 'Simple addon to search through your trusts'
addon.link = 'https://github.com/loonsies/trustme'

-- Ashita dependencies
require 'common'
chat = require('chat')
imgui = require('imgui')

-- Local dependencies
task = require('task')

tme = {
    visible = { false },
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
    queue = {}
 }

local searchStatus = {
    noResults = 0,
    found = 1,
    [0] = 'No results found',
    [1] = 'Found'
 }

local function getTrusts()
    local trusts = {}
    local resMgr = AshitaCore:GetResourceManager();

    for i = 1, 0x400 do
        local res = resMgr:GetSpellById(i);
        if (res) and (player:HasSpell(res)) then
            trusts:append(res);
        end
    end

    table.sort(trusts, function(a, b)
        return a.Name[1] < b.Name[1];
    end);

    return trusts
end

local function search()
    tme.search.results = {}
    local trusts = getTrusts()
    local input = table.concat(tme.search.input)

    for id, trust in pairs(trusts) do
        if #input == 0 or trust.Name[1] and (string.find(trust.Name[1]:lower(), input:lower())) then
            table.insert(tme.search.results, trust.Name[1])
        end
    end

    if #tme.search.results == 0 then
        tme.search.status = searchStatus.noResults
    else
        tme.search.status = searchStatus.found
    end
end

local function updateUI()
    if not tme.visible[1] then
        return
    end

    local currentInput = table.concat(tme.search.input)
    local previousInput = table.concat(tme.search.previousInput)

    if currentInput ~= previousInput or tme.search.startup then
        tme.search.results = {}
        search()
        tme.search.previousInput = { currentInput }
    end

    if tme.search.selectedTrusts ~= tme.search.previousSelectedTrusts then
        tme.search.previousSelectedTrusts = tme.search.selectedTrusts
    end

    drawUI()
end

local function drawUI()
    if imgui.Begin('trustme', tme.visible, ImGuiWindowFlags_AlwaysAutoResize) then
        if #queue > 0 then
            local mins = math.floor(eta / 60)
            local secs = math.floor(eta % 60)
            imgui.Text(string.format('%d tasks queued - est. %d:%02d', #queue, mins, secs))
        else
            imgui.Text('No tasks queued')
        end
        imgui.NewLine()

        imgui.Text('Search (' .. #tme.search.results .. ')')
        imgui.SetNextItemWidth(-1)
        imgui.InputText('##SearchInput', tme.search.input, 48)

        if imgui.BeginTable('##SearchResultsTableChild', 2, bit.bor(ImGuiTableFlags_ScrollY), { 0, 150 }) then
            imgui.TableSetupColumn('##TrustColumn', ImGuiTableColumnFlags_WidthStretch)
            if tme.search.status == searchStatus.found then
                local clipper = ImGuiListClipper.new()
                clipper:Begin(#tme.search.results, -1)

                while clipper:Step() do
                    for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                        local trustName = tme.search.results[i + 1]
                        local isSelected = table.haskey(tme.search.selectedTrusts, trustName)

                        imgui.PushID(trustName)
                        imgui.TableNextRow()

                        imgui.TableSetColumnIndex(0)
                        if imgui.Selectable(trustName) then
                            table.insert(tme.search.selectedTrusts, 1, trustName)
                        end

                        imgui.TableSetColumnIndex(1)
                        if imgui.Button('Summon') then
                            AshitaCore:GetChatManager():QueueCommand(-1, string.format('/ma %s <me>', trustName))
                        end

                        imgui.PopID()
                    end
                end

                clipper:End()
            else
                imgui.TableNextRow()
                imgui.TableSetColumnIndex(0)
                imgui.Text(searchStatus[tme.search.status])
            end
            imgui.EndTable()
        end

        if imgui.Button('Refresh') then
            search()
        end
        imgui.SameLine()

        if imgui.Button('Summon selected') then
            if #tme.search.selectedTrusts ~= 0 then
                for i = 1, #tme.search.selectedTrusts do
                    local entry = {
                        trustName = tme.search.selectedTrusts[i],
                        interval = 8
                     }
                    task.enqueue(entry)
                end
            end
        end
        imgui.SameLine()

        if imgui.Button('Clear selection') then
            task.clear()
        end
    end
end

local function handleCommand(args)
    local command = string.lower(args[1])
    if command == '/tme' or command == '/trustme' or command == '/trusts' or command == '/trust' then
        tme.visible[1] = not tme.visible[1]
    end
end

ashita.events.register('command', 'command_cb', function(cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        handleCommand(args)
    end
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function()
    updateUI()
end)
