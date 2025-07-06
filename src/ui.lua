local imgui = require('imgui')
local chat = require('chat')
local settings = require('settings')
local commands = require('src/commands')
local search = require('src/search')
local task = require('src/task')
local profiles = require('src/profiles')
local searchStatus = require('data/searchStatus')
local profileActions = require('data/profileActions')

local ui = {}

local confirmationModal = {
    visible = false,
    args = {
        name = '',
        trusts = {}
    },
    action = nil
}

local inputModal = {
    visible = false,
    alreadyExisting = false,
    input = {}
}

function ui.drawSearch()
    imgui.Text('Search (' .. #tme.search.results .. ')')
    imgui.SetNextItemWidth(-1)
    imgui.InputText('##SearchInput', tme.search.input, 48)

    local availX, availY = imgui.GetContentRegionAvail()
    local buttonsHeight = 75

    if imgui.BeginChild('##SearchChild', { availX, availY - buttonsHeight }) then
        if imgui.BeginTable('##SearchResultsTableChild', 2, bit.bor(ImGuiTableFlags_ScrollY)) then
            imgui.TableSetupColumn('##TrustColumn', ImGuiTableColumnFlags_WidthStretch)
            imgui.TableSetupColumn('##Action', ImGuiTableColumnFlags_WidthFixed)
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
                            commands.summon({ trustName })
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
        imgui.EndChild()
    end

    local selected = #tme.search.selectedTrusts > 0 and table.concat(tme.search.selectedTrusts, ', ') or 'None'
    imgui.TextWrapped(string.format('Selected: %s', selected))
end

function ui.drawCommands()
    if imgui.Button('Refresh') then
        search.updateSearch()
    end
    imgui.SameLine()

    if imgui.Button(string.format('Summon selected (%i)', #tme.search.selectedTrusts)) then
        if #tme.search.selectedTrusts ~= 0 then
            commands.summon(tme.search.selectedTrusts)
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

function ui.drawConfirmationModal(profile)
    if not confirmationModal.visible then
        return
    end

    imgui.SetNextWindowSize({ 0, 0 }, ImGuiCond_Always)
    imgui.SetNextWindowSizeConstraints(tme.minModalSize, { FLT_MAX, FLT_MAX })
    imgui.OpenPopup(string.format('Confirm %s profile', profileActions[confirmationModal.action]))

    if imgui.BeginPopupModal(string.format('Confirm %s profile', profileActions[confirmationModal.action]), nil, ImGuiWindowFlags_NoResize) then
        local name = confirmationModal.args.name
        local trusts = confirmationModal.args.trusts

        imgui.Text(string.format('Are you sure you want to %s "%s" profile?', profileActions[confirmationModal.action], name))
        imgui.Separator()
        if confirmationModal.action == profileActions.overwrite then
            imgui.Text(string.format('"%s" profile will be overwritten with the following data:', name))
            imgui.TextWrapped(table.concat(trusts, ', '))
        elseif confirmationModal.action == profileActions.delete then
            imgui.Text(string.format('"%s" profile will be deleted', name))
            imgui.Text(string.format('Once confirmed, this action cannot be undone'))
        end
        if imgui.Button('OK', { 120, 0 }) then
            if confirmationModal.action == profileActions.overwrite then
                profiles.saveProfile(name, trusts)
            elseif confirmationModal.action == profileActions.delete then
                profiles.deleteProfile(name)
            end
            confirmationModal.visible = false
            imgui.CloseCurrentPopup()
        end
        imgui.SameLine()
        if imgui.Button('Cancel', { 120, 0 }) then
            confirmationModal.visible = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

function ui.drawInputModal(profile)
    if not inputModal.visible then
        return
    end

    imgui.SetNextWindowSize({ 0, 0 }, ImGuiCond_Always)
    imgui.SetNextWindowSizeConstraints(tme.minModalSize, { FLT_MAX, FLT_MAX })
    imgui.OpenPopup('Create new profile')

    if imgui.BeginPopupModal('Create new profile', nil, ImGuiWindowFlags_NoResize) then
        imgui.Text('Enter a name for creating a new profile')
        imgui.Separator()

        if inputModal.alreadyExisting == true then
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.0, 0.0, 1.0 })
            imgui.Text('A profile with the entered name already exists')
            imgui.PopStyleColor()
        end

        imgui.SetNextItemWidth(-1)
        if imgui.InputText('##ModalInput', inputModal.input, 48) then
            if inputModal.input[1] == '' then
                inputModal.alreadyExisting = false
            end
        end

        if imgui.Button('OK', { 120, 0 }) then
            if #inputModal.input[1] > 0 then
                if profiles.getProfile(inputModal.input[1]) ~= nil then
                    inputModal.alreadyExisting = true
                else
                    profiles.saveProfile(inputModal.input[1], tme.search.selectedTrusts)
                    if tme.selectedProfile == nil then
                        tme.selectedProfile = #tme.config.profiles
                    end
                    inputModal.input = {}
                    inputModal.alreadyExisting = false
                    inputModal.visible = false
                    imgui.CloseCurrentPopup()
                end
            end
        end
        imgui.SameLine()
        if imgui.Button('Cancel', { 120, 0 }) then
            inputModal.input = {}
            inputModal.alreadyExisting = false
            inputModal.visible = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

function ui.drawProfiles()
    local comboWidth = 200

    local function getButtonWidth(label, maxWidth)
        local textSize = imgui.CalcTextSize(label)
        local padding = 20
        local minWidth = textSize + padding
        if minWidth > maxWidth then
            return maxWidth
        else
            return minWidth
        end
    end

    local availX, _ = imgui.GetContentRegionAvail()
    local maxButtonWidth = (availX - comboWidth - 20) / 3
    local newWidth = getButtonWidth('New', maxButtonWidth)
    local deleteWidth = getButtonWidth('Delete', maxButtonWidth)
    local saveWidth = getButtonWidth('Save', maxButtonWidth)
    local totalWidth = newWidth + deleteWidth + saveWidth + comboWidth + (imgui.GetStyle().ItemSpacing.x * 3)
    local posX = imgui.GetCursorPosX()

    imgui.SetCursorPosX(posX + availX - totalWidth)

    if imgui.Button('New', { newWidth, 0 }) then
        inputModal.visible = true
    end
    imgui.SameLine()

    if imgui.Button('Delete', { deleteWidth, 0 }) then
        if tme.selectedProfile ~= nil then
            confirmationModal.action = profileActions.delete
            confirmationModal.args = {
                name = tme.config.profiles[tme.selectedProfile].name
            }
            confirmationModal.visible = true
        end
    end
    imgui.SameLine()

    if imgui.Button('Save', { saveWidth, 0 }) then
        if tme.selectedProfile ~= nil then
            if #tme.config.profiles[tme.selectedProfile].trusts > 0 and (not table.equals(tme.config.profiles[tme.selectedProfile].trusts, tme.search.selectedTrusts)) then
                confirmationModal.action = profileActions.overwrite
                confirmationModal.args = {
                    name = tme.config.profiles[tme.selectedProfile].name,
                    trusts = tme.search.selectedTrusts
                }
                confirmationModal.visible = true
            else
                local name = tme.config.profiles[tme.selectedProfile].name
                local trusts = tme.search.selectedTrusts
                profiles.saveProfile(name, trusts)
            end
        end
    end
    imgui.SameLine()

    if tme.selectedProfile ~= nil then
        if tme.config.profiles == nil or tme.selectedProfile > #tme.config.profiles then
            tme.selectedProfile = nil
        end
    end

    local comboLabel = 'No profiles'
    if tme.config.profiles ~= nil and #tme.config.profiles > 0 then
        comboLabel = tme.config.profiles[tme.selectedProfile] and tme.config.profiles[tme.selectedProfile].name or 'Select a profile'
    end

    imgui.SetNextItemWidth(comboWidth)
    if imgui.BeginCombo('##ProfilesCombo', comboLabel) then
        if tme.config.profiles ~= nil and #tme.config.profiles > 0 then
            if imgui.Selectable('None', tme.selectedProfile == nil) then
                tme.selectedProfile = nil
                tme.search.selectedTrusts = {}
                tme.config.lastProfileLoaded = nil
                settings.save()
            end

            imgui.Separator()

            for i = 1, #tme.config.profiles do
                local isSelected = (tme.selectedProfile == i)
                if imgui.Selectable(tme.config.profiles[i].name, isSelected) then
                    tme.selectedProfile = i
                    profiles.loadTrusts(i)
                    tme.config.lastProfileLoaded = i
                    settings.save()
                end
            end
        else
            imgui.Text('No profiles available')
        end

        imgui.EndCombo()
    end
end

function ui.drawUI()
    imgui.SetNextWindowSizeConstraints(tme.minSize, { FLT_MAX, FLT_MAX })
    if imgui.Begin('trustme', tme.visible, bit.bor(ImGuiWindowFlags_HorizontalScrollbar)) then
        if #tme.queue > 0 then
            local mins = math.floor(tme.eta / 60)
            local secs = math.floor(tme.eta % 60)
            imgui.Text(string.format('%d tasks queued - est. %d:%02d', #tme.queue, mins, secs))
        else
            imgui.Text('No tasks queued')
        end
        imgui.SameLine()

        ui.drawProfiles()
        imgui.Separator()
        ui.drawSearch()
        ui.drawCommands()
        ui.drawConfirmationModal()
        ui.drawInputModal()
        imgui.End()
    end
end

function ui.updateETA()
    local now = os.clock()
    local deltaTime = now - tme.lastUpdateTime
    tme.lastUpdateTime = now

    if tme.eta > 0 then
        tme.eta = math.max(0, tme.eta - deltaTime)
    end
end

function ui.updateUI()
    if not tme.visible[1] then
        return
    end

    local currentInput = table.concat(tme.search.input)
    local previousInput = table.concat(tme.search.previousInput)

    if currentInput ~= previousInput or tme.search.startup then
        tme.search.results = {}
        tme.search.startup = false
        search.updateSearch()
        tme.search.previousInput = { currentInput }
    end

    if tme.search.selectedTrusts ~= tme.search.previousSelectedTrusts then
        tme.search.previousSelectedTrusts = tme.search.selectedTrusts
    end

    ui.drawUI()
end

return ui
