local imgui = require('imgui')
local chat = require('chat')
local settings = require('settings')
local commands = require('src.commands')
local search = require('src.search')
local task = require('src.task')
local profiles = require('src.profiles')
local utils = require('src.utils')
local searchStatus = require('data.searchStatus')
local profileActions = require('data.profileActions')
local trustCategories = require('data.trustCategories')
local categoryNames = require('data.categoryNames')
local skillchainNames = require('data.skillchainNames')
local trustUtils = require('src.trustUtils')
local ffi = require('ffi')
local json = require('json')

local ui = {}
local categoryIcons = {}
local skillchainIcons = {}

-- Category color tints
local categoryColors = {
    ['Tank'] = { 0.078, 0.341, 0.961, 1.0 },             -- rgb(20, 87, 245)
    ['Melee Fighter'] = { 0.878, 0.173, 0.063, 1.0 },    -- rgb(224, 44, 16)
    ['Ranged Fighter'] = { 1.0, 0.518, 0.620, 1.0 },     -- rgb(255, 132, 158)
    ['Offensive Caster'] = { 0.694, 0.302, 0.922, 1.0 }, -- rgb(177, 77, 235)
    ['Healer'] = { 0.192, 0.902, 0.494, 1.0 },           -- rgb(49, 230, 126)
    ['Support'] = { 0.961, 0.741, 0.078, 1.0 },          -- rgb(245, 189, 20)
    ['Special'] = { 0.867, 0.925, 0.988, 1.0 },          -- rgb(221, 236, 252)
    ['Unity Concord'] = { 1.0, 0.0, 0.149, 1.0 }         -- rgb(255, 0, 38)
}

-- Ordered category list for dropdown
local categoryOrder = {
    'Tank',
    'Melee Fighter',
    'Ranged Fighter',
    'Offensive Caster',
    'Healer',
    'Support',
    'Special',
    'Unity Concord'
}

-- Name mapping: in-game name -> wiki name (for info/category lookup)
local nameMapping = {
    ['AAEV'] = 'Ark Angel EV',
    ['AAGK'] = 'Ark Angel GK',
    ['AAHM'] = 'Ark Angel HM',
    ['AAMR'] = 'Ark Angel MR',
    ['AATT'] = 'Ark Angel TT',
    ['D. Shantotto'] = 'Domina Shantotto'
}

-- Load trust information data
local trustInformation = {}
do
    local jsonPath = string.format('%s\\addons\\%s\\data\\trustInformation.json', AshitaCore:GetInstallPath(), addon.name)
    local file = io.open(jsonPath, 'r')
    if file then
        local content = file:read('*all')
        file:close()
        local data = json.decode(content)
        if data and data.trusts then
            trustInformation = data.trusts
        end
    end
end

local function loadCategoryIcons()
    for category, fileName in pairs(categoryNames) do
        local iconPath = string.format('%s\\addons\\%s\\resources\\icons\\%s.png',
            AshitaCore:GetInstallPath(), addon.name, fileName)

        if categoryIcons[category] == nil then
            categoryIcons[category] = {}

            local textureData = utils.createTextureFromFile(iconPath)
            if textureData and textureData.Texture then
                categoryIcons[category].Texture = textureData.Texture
                categoryIcons[category].Pointer = tonumber(ffi.cast('uint32_t', textureData.Texture))
                categoryIcons[category].Width = textureData.Width
                categoryIcons[category].Height = textureData.Height
            end
        end
    end
end

-- Load skillchain icons
local function loadSkillchainIcons()
    for _, scName in ipairs(skillchainNames) do
        -- Try with _SC_Icon suffix first, then without
        local iconPath = string.format('%s\\addons\\%s\\resources\\icons\\%s_SC_Icon.png',
            AshitaCore:GetInstallPath(), addon.name, scName)

        -- For Status_Ability, use the direct filename
        if scName == 'Status_Ability' then
            iconPath = string.format('%s\\addons\\%s\\resources\\icons\\%s.png',
                AshitaCore:GetInstallPath(), addon.name, scName)
        end

        if skillchainIcons[scName] == nil then
            skillchainIcons[scName] = {}

            local textureData = utils.createTextureFromFile(iconPath)
            if textureData and textureData.Texture then
                skillchainIcons[scName].Texture = textureData.Texture
                skillchainIcons[scName].Pointer = tonumber(ffi.cast('uint32_t', textureData.Texture))
                skillchainIcons[scName].Width = textureData.Width
                skillchainIcons[scName].Height = textureData.Height
            end
        end
    end
end

-- Get categories for a trust
local function getTrustCategories(trustName)
    -- Map in-game name to wiki name for lookup
    local lookupName = nameMapping[trustName] or trustName

    local categories = {}
    for category, trusts in pairs(trustCategories) do
        for _, name in ipairs(trusts) do
            if name == lookupName then
                table.insert(categories, category)
            end
        end
    end
    return categories
end

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

local infoWindow = {
    visible = { false },
    trustName = nil,
    scrollY = { 0 }
}

local missingWindow = {
    visible = { false },
    currentTab = 1,
    hideUC = { false },
    missingTrusts = {},
    loginCampaignResults = {},
    searchMissing = { '' },
    searchLogin = { '' }
}

local categoryFilter = {
    selected = 'All'
}

-- Track last clicked URL to prevent duplicate clicks
local lastUrlClick = {
    url = nil,
    time = 0
}

function ui.drawSearch()
    imgui.Text('Search (' .. #tme.search.results .. ')')
    imgui.SetNextItemWidth(-1)
    imgui.InputText('##SearchInput', tme.search.input, 48)

    -- Category filter dropdown
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo('##CategoryFilter', categoryFilter.selected) then
        if imgui.Selectable('All', categoryFilter.selected == 'All') then
            categoryFilter.selected = 'All'
        end
        imgui.Separator()
        for _, category in ipairs(categoryOrder) do
            if trustCategories[category] then
                if imgui.Selectable(category, categoryFilter.selected == category) then
                    categoryFilter.selected = category
                end
            end
        end
        imgui.EndCombo()
    end

    local availX, availY = imgui.GetContentRegionAvail()

    -- Filter results by category
    local filteredResults = {}
    if categoryFilter.selected == 'All' then
        filteredResults = tme.search.results
    else
        for _, trustName in ipairs(tme.search.results) do
            local categories = getTrustCategories(trustName)
            for _, cat in ipairs(categories) do
                if cat == categoryFilter.selected then
                    table.insert(filteredResults, trustName)
                    break
                end
            end
        end
    end

    if imgui.BeginTable('##SearchResultsTableChild', 3, bit.bor(ImGuiTableFlags_ScrollY), { availX, availY }) then
        imgui.TableSetupColumn('##TrustColumn', ImGuiTableColumnFlags_WidthStretch)
        imgui.TableSetupColumn('##InfoAction', ImGuiTableColumnFlags_WidthFixed)
        imgui.TableSetupColumn('##SummonAction', ImGuiTableColumnFlags_WidthFixed)

        if tme.search.status == searchStatus.found then
            local clipper = ImGuiListClipper.new()
            clipper:Begin(#filteredResults, -1)

            while clipper:Step() do
                for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                    local trustName = filteredResults[i + 1]
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

                    -- Draw category icons after the trust name
                    local categories = getTrustCategories(trustName)
                    for _, category in ipairs(categories) do
                        if categoryIcons[category] and categoryIcons[category].Pointer then
                            imgui.SameLine()
                            local tintColor = categoryColors[category] or { 1.0, 1.0, 1.0, 1.0 }
                            imgui.ImageWithBg(categoryIcons[category].Pointer, { 16, 16 }, { 0, 0 }, { 1, 1 }, { 0, 0, 0, 0 }, tintColor)
                            if imgui.IsItemHovered() then
                                imgui.SetTooltip(category)
                            end
                        end
                    end

                    imgui.TableSetColumnIndex(1)
                    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 4, 0 })
                    if imgui.Button('Info##' .. trustName, { 0, 0 }) then
                        infoWindow.visible[1] = true
                        -- Map in-game name to wiki name for info lookup
                        infoWindow.trustName = nameMapping[trustName] or trustName
                        infoWindow.scrollY[1] = 0
                    end
                    imgui.PopStyleVar()

                    imgui.TableSetColumnIndex(2)
                    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 4, 0 })
                    if imgui.Button('Summon##' .. trustName, { 0, 0 }) then
                        commands.summon({ trustName })
                    end
                    imgui.PopStyleVar()

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
end

function ui.drawSelected()
    if imgui.BeginChild('##SelectedChild', { 0, 126 }, ImGuiChildFlags_Borders) then
        if #tme.search.selectedTrusts > 0 then
            if imgui.BeginTable('##SelectedTable', 2, 0, { 0, 0 }) then
                imgui.TableSetupColumn('##NameColumn', ImGuiTableColumnFlags_WidthStretch)
                imgui.TableSetupColumn('##SummonColumn', ImGuiTableColumnFlags_WidthFixed)

                for i, trustName in ipairs(tme.search.selectedTrusts) do
                    local popupId = trustName .. '_selected_menu'
                    imgui.PushID(trustName .. '_selected')

                    -- Find if this trust is in the queue
                    local queuePosition = nil
                    for qIdx, entry in ipairs(tme.queue) do
                        if entry.trustName == trustName then
                            queuePosition = qIdx
                            break
                        end
                    end

                    imgui.TableNextRow()
                    imgui.TableSetColumnIndex(0)

                    -- Draw trust name with selectable
                    local clicked = imgui.Selectable(trustName, false, ImGuiSelectableFlags_AllowDoubleClick, { 0, 0 })

                    if clicked then
                        imgui.OpenPopup(popupId)
                    end

                    if imgui.IsItemClicked(1) then -- right click
                        imgui.OpenPopup(popupId)
                    end

                    -- Draw category icons right next to name
                    local categories = getTrustCategories(trustName)
                    for _, category in ipairs(categories) do
                        if categoryIcons[category] and categoryIcons[category].Pointer then
                            imgui.SameLine()
                            local tintColor = categoryColors[category] or { 1.0, 1.0, 1.0, 1.0 }
                            imgui.ImageWithBg(categoryIcons[category].Pointer, { 16, 16 }, { 0, 0 }, { 1, 1 }, { 0, 0, 0, 0 }, tintColor)
                            if imgui.IsItemHovered() then
                                imgui.SetTooltip(category)
                            end
                        end
                    end

                    -- Draw status text
                    if queuePosition then
                        local statusText = string.format('Summoning... %d/%d', queuePosition, #tme.queue)
                        local textWidth = imgui.CalcTextSize(statusText)
                        local availWidth = imgui.GetContentRegionAvail()
                        imgui.SameLine(imgui.GetCursorPosX() + availWidth - textWidth)
                        imgui.TextDisabled(statusText)
                    end

                    -- Summon/Cancel button column
                    imgui.TableSetColumnIndex(1)
                    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 4, 0 })
                    if queuePosition then
                        -- Show Cancel button if trust is in queue
                        if imgui.Button('Cancel##btn_' .. trustName, { 0, 0 }) then
                            table.remove(tme.queue, queuePosition)
                        end
                    else
                        -- Show Summon button if trust is not in queue
                        if imgui.Button('Summon##btn_' .. trustName, { 0, 0 }) then
                            commands.summon({ trustName })
                        end
                    end
                    imgui.PopStyleVar()

                    if imgui.BeginPopup(popupId) then
                        if imgui.MenuItem('Summon') then
                            commands.summon({ trustName })
                        end

                        if imgui.MenuItem('Remove') then
                            table.delete(tme.search.selectedTrusts, trustName)
                        end

                        if i == 1 then
                            imgui.TextDisabled('Move up')
                        else
                            if imgui.MenuItem('Move up') then
                                table.remove(tme.search.selectedTrusts, i)
                                table.insert(tme.search.selectedTrusts, i - 1, trustName)
                            end
                        end

                        if i == #tme.search.selectedTrusts then
                            imgui.TextDisabled('Move down')
                        else
                            if imgui.MenuItem('Move down') then
                                table.remove(tme.search.selectedTrusts, i)
                                table.insert(tme.search.selectedTrusts, i + 1, trustName)
                            end
                        end

                        imgui.EndPopup()
                    end

                    imgui.PopID()
                end
                imgui.EndTable()
            end
        else
            imgui.TextWrapped('Selected: None')
        end
        imgui.EndChild()
    end
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
    imgui.SameLine()

    if imgui.Button('Missing') then
        missingWindow.visible[1] = true
    end
end

function ui.drawMissingWindow()
    if not missingWindow.visible[1] then
        return
    end

    -- Auto-fetch missing trusts if not loaded
    if not missingWindow.missingTrusts or #missingWindow.missingTrusts == 0 then
        local ownedTrusts = trustUtils.getTrustNames(trustUtils.getTrusts())
        missingWindow.missingTrusts = trustUtils.findMissingTrusts(ownedTrusts, missingWindow.hideUC[1])
    end

    imgui.SetNextWindowSize({ 450, 400 }, ImGuiCond_Always)
    imgui.SetNextWindowPos({ imgui.GetIO().DisplaySize.x * 0.5, imgui.GetIO().DisplaySize.y * 0.5 }, ImGuiCond_Appearing, { 0.5, 0.5 })

    if imgui.Begin('Missing trusts', missingWindow.visible, ImGuiWindowFlags_None) then
        -- Tab bar
        if imgui.BeginTabBar('##MissingTabBar', ImGuiTabBarFlags_None) then
            -- Missing trusts tab
            if imgui.BeginTabItem('Missing trusts') then
                missingWindow.currentTab = 1

                -- Hide UC checkbox
                if imgui.Checkbox('Hide Unity Concord', missingWindow.hideUC) then
                    -- Refresh the list when checkbox changes
                    local ownedTrusts = trustUtils.getTrustNames(trustUtils.getTrusts())
                    missingWindow.missingTrusts = trustUtils.findMissingTrusts(ownedTrusts, missingWindow.hideUC[1])
                end

                imgui.Separator()

                -- Search filter
                imgui.PushItemWidth(-1)
                imgui.InputText('##SearchMissing', missingWindow.searchMissing, 256)
                imgui.PopItemWidth()

                -- Total count (filtered)
                local filteredMissing = {}
                if missingWindow.missingTrusts and #missingWindow.missingTrusts > 0 then
                    local searchLower = missingWindow.searchMissing[1]:lower()
                    if searchLower == '' then
                        filteredMissing = missingWindow.missingTrusts
                    else
                        for _, trustName in ipairs(missingWindow.missingTrusts) do
                            if trustName:lower():find(searchLower, 1, true) then
                                table.insert(filteredMissing, trustName)
                            end
                        end
                    end
                end
                local totalMissing = #filteredMissing
                imgui.Text(string.format('Total: %d', totalMissing))

                -- List of missing trusts (filtered)
                if imgui.BeginChild('##MissingList', { 0, -30 }, ImGuiChildFlags_Borders) then
                    if #filteredMissing > 0 then
                        for _, trustName in ipairs(filteredMissing) do
                            imgui.Text(trustName)
                        end
                    else
                        if missingWindow.missingTrusts and #missingWindow.missingTrusts > 0 then
                            imgui.TextDisabled('No matches found')
                        else
                            imgui.TextDisabled('No missing trusts or click Refresh to load')
                        end
                    end
                    imgui.EndChild()
                end

                -- Refresh button
                if imgui.Button('Refresh##MissingRefresh', { -1, 0 }) then
                    local ownedTrusts = trustUtils.getTrustNames(trustUtils.getTrusts())
                    missingWindow.missingTrusts = trustUtils.findMissingTrusts(ownedTrusts, missingWindow.hideUC[1])
                end

                imgui.EndTabItem()
            end

            -- Login campaign tab
            if imgui.BeginTabItem('Login campaign') then
                missingWindow.currentTab = 2

                -- Search filter
                imgui.PushItemWidth(-1)
                imgui.InputText('##SearchLogin', missingWindow.searchLogin, 256)
                imgui.PopItemWidth()

                -- Calculate filtered results
                local filteredCiphers = {}
                if tme.workerResult and #tme.workerResult > 0 then
                    local ownedTrusts = trustUtils.getTrustNames(trustUtils.getTrusts())
                    local missingCiphers = trustUtils.findMissingCiphers(tme.workerResult, ownedTrusts)

                    local searchLower = missingWindow.searchLogin[1]:lower()
                    if searchLower == '' then
                        filteredCiphers = missingCiphers
                    else
                        for _, entry in ipairs(missingCiphers) do
                            local searchText = string.format('%s %s', entry.cipher, entry.name):lower()
                            if searchText:find(searchLower, 1, true) then
                                table.insert(filteredCiphers, entry)
                            end
                        end
                    end
                end

                -- Total count (filtered)
                local totalCiphers = #filteredCiphers
                imgui.Text(string.format('Total: %d', totalCiphers))

                -- List of login campaign results (filtered)
                if imgui.BeginChild('##LoginCampaignList', { 0, -30 }, ImGuiChildFlags_Borders) then
                    if #filteredCiphers > 0 then
                        for _, entry in ipairs(filteredCiphers) do
                            imgui.Text(string.format('%s (%s)', entry.cipher, entry.name))
                        end
                    else
                        if tme.workerResult and #tme.workerResult > 0 then
                            local ownedTrusts = trustUtils.getTrustNames(trustUtils.getTrusts())
                            local missingCiphers = trustUtils.findMissingCiphers(tme.workerResult, ownedTrusts)
                            if #missingCiphers > 0 then
                                imgui.TextDisabled('No matches found')
                            else
                                imgui.TextDisabled('You own all ciphers from current login campaign')
                            end
                        else
                            imgui.TextDisabled('No data loaded or click Refresh to fetch')
                        end
                    end
                    imgui.EndChild()
                end

                -- Refresh button
                if imgui.Button('Refresh##LoginCampaignRefresh', { -1, 0 }) then
                    print(chat.header(addon.name):append(chat.message('Fetching trust ciphers from login campaign...')))
                    trustUtils.fetchLoginCampaignCiphers()
                end

                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
    end
    imgui.End()
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

-- Helper function to render hyperlink text
local function renderHyperlink(text, url)
    -- Use a blue color for links (similar to header color)
    imgui.PushStyleColor(ImGuiCol_Text, { 0.26, 0.59, 0.98, 1.0 })
    imgui.Text(text)
    imgui.PopStyleColor()

    if imgui.IsItemHovered() then
        -- Extract domain from URL
        local domain = url:match('//([^/]+)') or url
        imgui.SetTooltip(string.format('Open link: %s', domain))
        imgui.SetMouseCursor(ImGuiMouseCursor_Hand)
    end

    if imgui.IsItemClicked(0) then
        local currentTime = os.clock()

        -- prevent clicking same URL within 1 second
        if lastUrlClick.url == url and (currentTime - lastUrlClick.time) < 1.0 then
            return
        end

        -- open URL with error handling - had a few game crashes when opening hyperlinks, not sure if that can help
        local success, err = pcall(function ()
            if url and url ~= '' then
                ashita.misc.open_url(url)
                lastUrlClick.url = url
                lastUrlClick.time = currentTime
            end
        end)

        if not success then
            print(chat.header(addon.name):append(chat.error(string.format('Failed to open URL: %s', tostring(err)))))
        end
    end
end

-- Helper function to render a single line of mixed content
local function renderLine(lineItems)
    -- Save current spacing and reduce it for wrapped lines
    local style = imgui.GetStyle()
    local originalSpacingY = style.ItemSpacing.y
    style.ItemSpacing.y = 0 -- Remove vertical spacing between wrapped lines

    -- Process items in order, preserving adjacency
    local availWidth = imgui.GetContentRegionAvail()
    local lineWidth = 0
    local firstInLine = true
    local needsSpace = false

    local function renderItem(item, addSpace)
        if item.type == 'text' then
            -- Check if this is punctuation that should stick to previous element
            local isPunctuation = item.value:match('^[,.;:!?]+$')

            if isPunctuation then
                -- Render punctuation without preceding space
                local label = item.value
                local labelWidth = imgui.CalcTextSize(label)

                if not firstInLine and (lineWidth + labelWidth > availWidth) then
                    firstInLine = true
                    lineWidth = 0
                    availWidth = imgui.GetContentRegionAvail()
                end

                if not firstInLine then
                    imgui.SameLine(0, 0)
                end
                imgui.Text(label)

                lineWidth = lineWidth + labelWidth
                firstInLine = false
                needsSpace = true -- Need space after punctuation
                return
            end

            -- Check if text is an operator with spaces (like " / ") - preserve as-is
            if item.value:match('^%s*/%s*$') or item.value:match('^%s*[%-%+%*]%s*$') then
                local label = item.value
                local labelWidth = imgui.CalcTextSize(label)

                if not firstInLine and (lineWidth + labelWidth > availWidth) then
                    firstInLine = true
                    lineWidth = 0
                    availWidth = imgui.GetContentRegionAvail()
                end

                if not firstInLine then
                    imgui.SameLine(0, 0)
                end
                imgui.Text(label)

                lineWidth = lineWidth + labelWidth
                firstInLine = false
                needsSpace = false -- Don't add space after operators
                return
            end

            -- Split text into words and render each
            local words = {}
            for word in item.value:gmatch('%S+') do
                table.insert(words, word)
            end

            for i, word in ipairs(words) do
                local label = (addSpace and ' ' or '') .. word
                local labelWidth = imgui.CalcTextSize(label)

                if not firstInLine and (lineWidth + labelWidth > availWidth) then
                    -- Wrap to next line
                    firstInLine = true
                    lineWidth = 0
                    availWidth = imgui.GetContentRegionAvail()
                    label = word
                    labelWidth = imgui.CalcTextSize(label)
                    addSpace = false
                end

                if not firstInLine then
                    imgui.SameLine(0, 0)
                end
                imgui.Text(label)

                lineWidth = lineWidth + labelWidth
                firstInLine = false
                addSpace = true
            end

            -- Check if the last word ends with characters that shouldn't have space after
            local lastWord = words[#words] or ''
            if lastWord:match('[/(]$') then
                needsSpace = false -- Don't add space after operators like / or (
            else
                needsSpace = true
            end
        elseif item.type == 'link' then
            local label = (addSpace and ' ' or '') .. item.text
            local labelWidth = imgui.CalcTextSize(label)

            if not firstInLine and (lineWidth + labelWidth > availWidth) then
                firstInLine = true
                lineWidth = 0
                availWidth = imgui.GetContentRegionAvail()
                label = item.text
                labelWidth = imgui.CalcTextSize(label)
            end

            if not firstInLine then
                imgui.SameLine(0, 0)
            end
            renderHyperlink(label, item.url)

            lineWidth = lineWidth + labelWidth
            firstInLine = false
            needsSpace = true
        elseif item.type == 'skillchain' then
            -- Skillchain icons need preceding space
            local scIcon = skillchainIcons[item.value]
            if scIcon and scIcon.Pointer then
                local iconSize = 16
                local spaceWidth = addSpace and imgui.CalcTextSize(' ') or 0

                if not firstInLine and (lineWidth + iconSize + spaceWidth > availWidth) then
                    firstInLine = true
                    lineWidth = 0
                    availWidth = imgui.GetContentRegionAvail()
                    addSpace = false
                    spaceWidth = 0
                end

                if not firstInLine then
                    imgui.SameLine(0, 0)
                end

                -- Add space before icon if needed
                if addSpace and not firstInLine then
                    imgui.Text(' ')
                    imgui.SameLine(0, 0)
                    lineWidth = lineWidth + spaceWidth
                end

                imgui.Image(scIcon.Pointer, { iconSize, iconSize })
                if imgui.IsItemHovered() then
                    imgui.SetTooltip(item.value)
                end

                lineWidth = lineWidth + iconSize
                firstInLine = false
            else
                -- Fallback to colored text
                local label = (addSpace and ' ' or '') .. '[' .. item.value .. ']'
                local labelWidth = imgui.CalcTextSize(label)

                if not firstInLine and (lineWidth + labelWidth > availWidth) then
                    firstInLine = true
                    lineWidth = 0
                    availWidth = imgui.GetContentRegionAvail()
                    label = '[' .. item.value .. ']'
                    labelWidth = imgui.CalcTextSize(label)
                end

                if not firstInLine then
                    imgui.SameLine(0, 0)
                end
                imgui.TextColored({ 0.8, 0.6, 1.0, 1.0 }, label)

                lineWidth = lineWidth + labelWidth
                firstInLine = false
            end
            needsSpace = false -- Don't add space after skillchain icon
        end
    end

    -- Render all items in order
    for i, item in ipairs(lineItems) do
        renderItem(item, needsSpace and not firstInLine)
    end

    -- Restore original spacing
    style.ItemSpacing.y = originalSpacingY

    -- Add small spacing after the complete logical line
    imgui.Dummy({ 0, 2 })
end

-- Helper function to render trust field data
local function renderFieldData(fieldData)
    if type(fieldData) ~= 'table' then
        imgui.TextDisabled('None')
        return
    end

    for lineIdx, line in ipairs(fieldData) do
        renderLine(line)
    end
end

-- Helper function to render multi-line section data (acquisition, special features)
local function renderSectionData(sectionData)
    if type(sectionData) ~= 'table' then
        imgui.TextDisabled('None')
        return
    end

    for lineIdx, line in ipairs(sectionData) do
        imgui.Bullet()
        imgui.BeginGroup()
        renderLine(line)
        imgui.EndGroup()
    end
end

function ui.drawInfoWindow()
    if not infoWindow.visible[1] then
        return
    end

    local trustData = trustInformation[infoWindow.trustName]
    if not trustData then
        infoWindow.visible[1] = false
        return
    end

    imgui.SetNextWindowSize({ 600, 500 }, ImGuiCond_Always)
    imgui.SetNextWindowPos({ imgui.GetIO().DisplaySize.x * 0.5, imgui.GetIO().DisplaySize.y * 0.5 }, ImGuiCond_Appearing, { 0.5, 0.5 })

    if imgui.Begin(string.format('Trust information: %s', infoWindow.trustName), infoWindow.visible, ImGuiWindowFlags_None) then
        imgui.Text(infoWindow.trustName)

        local categories = getTrustCategories(infoWindow.trustName)
        if #categories > 0 then
            imgui.SameLine()
            for _, category in ipairs(categories) do
                local icon = categoryIcons[category]
                if icon and icon.Pointer then
                    local tintColor = categoryColors[category] or { 1.0, 1.0, 1.0, 1.0 }
                    imgui.ImageWithBg(icon.Pointer, { 24, 24 }, { 0, 0 }, { 1, 1 }, { 0, 0, 0, 0 }, tintColor)
                    if imgui.IsItemHovered() then
                        imgui.SetTooltip(category)
                    end
                    imgui.SameLine()
                end
            end
            imgui.NewLine()
        end

        imgui.Separator()

        -- Job
        if trustData.job then
            imgui.TextColored({ 0.4, 0.8, 1.0, 1.0 }, 'Job:')
            imgui.SameLine()
            renderFieldData(trustData.job)
        end

        -- Spells
        if trustData.spells then
            imgui.TextColored({ 0.4, 0.8, 1.0, 1.0 }, 'Spells:')
            imgui.Indent(10)
            renderFieldData(trustData.spells)
            imgui.Unindent(10)
        end

        -- Abilities
        if trustData.abilities then
            imgui.TextColored({ 0.4, 0.8, 1.0, 1.0 }, 'Abilities:')
            imgui.Indent(10)
            renderFieldData(trustData.abilities)
            imgui.Unindent(10)
        end

        -- Weapon Skills
        if trustData.weapon_skills then
            imgui.TextColored({ 0.4, 0.8, 1.0, 1.0 }, 'Weapon Skills:')
            imgui.Indent(10)
            renderFieldData(trustData.weapon_skills)
            imgui.Unindent(10)
        end

        imgui.Separator()

        -- Acquisition
        if trustData.acquisition then
            if imgui.CollapsingHeader('Acquisition', ImGuiTreeNodeFlags_DefaultOpen) then
                imgui.Indent(10)
                renderSectionData(trustData.acquisition)
                imgui.Unindent(10)
            end
        end

        -- Special Features
        if trustData.special_features then
            if imgui.CollapsingHeader('Special Features', ImGuiTreeNodeFlags_DefaultOpen) then
                imgui.Indent(10)
                renderSectionData(trustData.special_features)
                imgui.Unindent(10)
            end
        end
        imgui.End()
    end
end

function ui.drawProfiles()
    if imgui.Button('New') then
        inputModal.visible = true
    end
    imgui.SameLine()

    if imgui.Button('Delete') then
        if tme.selectedProfile ~= nil then
            confirmationModal.action = profileActions.delete
            confirmationModal.args = {
                name = tme.config.profiles[tme.selectedProfile].name
            }
            confirmationModal.visible = true
        end
    end
    imgui.SameLine()

    if imgui.Button('Save') then
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

    imgui.SetNextItemWidth(-1)
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

        ui.drawProfiles()
        imgui.Separator()
        ui.drawSelected()
        imgui.Separator()
        ui.drawCommands()
        imgui.Dummy({ 0, 4 })
        ui.drawSearch()
        ui.drawConfirmationModal()
        ui.drawInputModal()
        ui.drawMissingWindow()
    end
    imgui.End()
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
    ui.drawInfoWindow()
end

function ui.init()
    loadCategoryIcons()
    loadSkillchainIcons()
end

return ui
