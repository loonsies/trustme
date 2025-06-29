addon.name = 'trustme'
addon.version = '0.1'
addon.author = 'looney'
addon.desc = 'Simple addon to search through your trusts'
addon.link = 'https://github.com/loonsies/trustme'

-- Ashita dependencies
require 'common'
chat = require('chat')
imgui = require('imgui')

-- Local dependencies
task = require('task')

local searchStatus = {
    noResults = 0,
    found = 1,
    [0] = 'No results found',
    [1] = 'Found'
 }

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

local function GetJobPointCount(job, category)
    local jobTable = playerData.JobPoints[job];
    if not jobTable then
        return 0;
    end

    local categories = jobTable.Categories;
    if not categories then
        return 0;
    end

    local count = categories[category + 1];
    if not count then
        return 0;
    else
        return count;
    end
end

local function getTrusts()
    local trusts = {}
    local resMgr = AshitaCore:GetResourceManager();
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local mainJob = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob()
    local mainJobLevel = AshitaCore:GetMemoryManager():GetPlayer():GetMainJobLevel();
    local subJob = AshitaCore:GetMemoryManager():GetPlayer():GetSubJob();
    local subJobLevel = AshitaCore:GetMemoryManager():GetPlayer():GetSubJobLevel();

    for i = 1, 0x400 do
        local res = resMgr:GetSpellById(i)
        if (res) and (player:HasSpell(i)) then
            local levelRequired = res.LevelRequired;

            -- Maybe not best workaround, but trust are all usable at WAR1.
            if (levelRequired[2] == 1) then
                local hasSpell = false;
                local jpMask = res.JobPointMask;
                if (bit.band(bit.rshift(jpMask, mainJob), 1) == 1) then
                    if (mainJobLevel == 99) and (player:GetJobPointTotal(mainJob) >= levelRequired[mainJob + 1]) then
                        hasSpell = true;
                    end
                elseif (levelRequired[mainJob + 1] ~= -1) and (mainJobLevel >= levelRequired[mainJob + 1]) then
                    hasSpell = true;
                end

                if (bit.band(bit.rshift(jpMask, subJob), 1) == 0) then
                    if (levelRequired[subJob + 1] ~= -1) and (subJobLevel >= levelRequired[subJob + 1]) then
                        hasSpell = true;
                    end
                end

                if (hasSpell) then
                    table.insert(trusts, res)
                end
            end
        end
    end

    table.sort(trusts, function(a, b)
        return a.Name[1] < b.Name[1]
    end)

    return trusts
end

local function search()
    tme.search.results = {}
    local trusts = getTrusts()
    local input = table.concat(tme.search.input)

    for id, trust in pairs(trusts) do
        if #input == 0 or trust.Name[1] and (string.find(trust.Name[1]:lower(), input:lower(), 1, true)) then
            table.insert(tme.search.results, trust.Name[1])
        end
    end

    if #tme.search.results == 0 then
        tme.search.status = searchStatus.noResults
    else
        tme.search.status = searchStatus.found
    end
end

local function drawUI()
    if imgui.Begin('trustme', tme.visible, ImGuiWindowFlags_AlwaysAutoResize) then
        if #tme.queue > 0 then
            local mins = math.floor(tme.eta / 60)
            local secs = math.floor(tme.eta % 60)
            imgui.Text(string.format('%d tasks queued - est. %d:%02d', #tme.queue, mins, secs))
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
                        local isSelected = table.contains(tme.search.selectedTrusts, trustName)

                        imgui.PushID(trustName)
                        imgui.TableNextRow()

                        imgui.TableSetColumnIndex(0)
                        if imgui.Selectable(trustName, isSelected) then
                            pos = table.find(tme.search.selectedTrusts, trustName)
                            if pos ~= nil then
                                table.delete(tme.search.selectedTrusts, trustName)
                            else
                                table.insert(tme.search.selectedTrusts, trustName)
                            end
                        end

                        imgui.TableSetColumnIndex(1)
                        if imgui.Button('Summon') then
                            local entry = {
                                type = taskTypes.summon,
                                trustName = trustName,
                                interval = 8
                             }
                            task.enqueue(entry)
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

        if imgui.Button(string.format('Summon selected (%i)', #tme.search.selectedTrusts)) then
            if #tme.search.selectedTrusts ~= 0 then
                for i = 1, #tme.search.selectedTrusts do
                    local entry = {
                        type = taskTypes.summon,
                        trustName = tme.search.selectedTrusts[i],
                        interval = 8
                     }
                    task.enqueue(entry)
                end
                tme.eta = (tme.eta or 0) + (#tme.search.selectedTrusts * 8)
            end
        end
        imgui.SameLine()

        if imgui.Button('Stop') then
            task.clear()
        end
        imgui.SameLine()

        if imgui.Button('Clear selection') then
            tme.search.selectedTrusts = {}
        end
    end
end

local function updateETA()
    local now = os.clock()
    local deltaTime = now - tme.lastUpdateTime
    tme.lastUpdateTime = now

    if tme.eta > 0 then
        tme.eta = math.max(0, tme.eta - deltaTime)
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
    updateETA()
    updateUI()
end)
