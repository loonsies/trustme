local chat = require('chat')
local task = require('src.task')
local trustUtils = require('src.trustUtils')
local profiles = require('src.profiles')
local utils = require('src.utils')
local taskTypes = require('data.taskTypes')

local commands = {}

function commands.summon(trusts)
    if trusts and #trusts > 0 then
        local toSummon = {}
        local duplicates = {}

        -- Check for duplicates in queue
        for i = 1, #trusts do
            local isDuplicate = false
            for _, entry in ipairs(tme.queue) do
                if entry.trustName == trusts[i] then
                    isDuplicate = true
                    table.insert(duplicates, trusts[i])
                    break
                end
            end
            if not isDuplicate then
                table.insert(toSummon, trusts[i])
            end
        end

        -- Log duplicates
        if #duplicates > 0 then
            print(chat.header(addon.name):append(chat.warning(string.format('Already in queue: %s', table.concat(duplicates, ', ')))))
        end

        -- Summon non-duplicates
        if #toSummon > 0 then
            print(chat.header(addon.name):append(chat.success(string.format('Summoning %s', table.concat(toSummon, ', ')))))
            for i = 1, #toSummon do
                local entry = {
                    type = taskTypes.summon,
                    trustName = toSummon[i],
                    interval = 8
                }
                task.enqueue(entry)
            end
            tme.eta = (tme.eta or 0) + (#toSummon * 8)
        end
    end
end

function commands.handleCommand(args)
    local command = string.lower(args[1])
    local arg = #args > 1 and string.lower(args[2]) or ''
    local arg2 = #args > 2 and string.lower(args[3]) or ''
    local arg2Raw = #args > 2 and args[3] or ''

    if command == '/tme' or command == '/trustme' or command == '/trusts' or command == '/trust' then
        if arg == '' then
            tme.visible[1] = not tme.visible[1]
        elseif arg == 'profile' or arg == 'p' then
            if arg2 == '' then
                print(chat.header(addon.name):append(chat.error('Please provide a profile name. Aborting')))
            else
                local profile = profiles.getProfile(arg2)
                if profile then
                    commands.summon(profile.trusts)
                else
                    print(chat.header(addon.name):append(chat.error('Unknown profile name. Aborting')))
                end
            end
        elseif arg == 'trust' or arg == 't' then
            local trusts = utils.filterEmpty(string.split(arg2Raw, ',') or {})
            if arg2 == '' or trusts == nil or #trusts == 0 then
                print(chat.header(addon.name):append(chat.error('Please provide a valid sequence of trusts. Aborting')))
            else
                commands.summon(trusts)
            end
        elseif arg == 'current' or arg == 'c' then
            if tme.selectedProfile ~= nil then
                local profile = tme.config.profiles[tme.selectedProfile]
                if profile then
                    commands.summon(profile.trusts)
                else
                    print(chat.header(addon.name):append(chat.error('Unknown profile name. Aborting')))
                end
            else
                print(chat.header(addon.name):append(chat.error('No profile loaded. Aborting')))
            end
        elseif arg == 'load' or arg == 'l' then
            if arg2 == '' then
                print(chat.header(addon.name):append(chat.error('Please provide a valid profile name. Aborting')))
            else
                local profileIndex = profiles.getProfileIndex(arg2)
                if profileIndex then
                    tme.selectedProfile = profileIndex
                    print(chat.header(addon.name):append(chat.success(string.format('Loaded profile "%s"', arg2))))
                else
                    print(chat.header(addon.name):append(chat.error('Unknown profile name. Aborting')))
                end
            end
        elseif arg == 'logincampaign' or arg == 'lc' then
            print(chat.header(addon.name):append(chat.message('Fetching trust ciphers from login campaign...')))
            trustUtils.fetchLoginCampaignCiphers()
        elseif arg == 'missing' or arg == 'm' then
            local hideUC = false
            if arg2 ~= '' and arg2 == 'hideuc' then
                hideUC = true
            end
            local missing = trustUtils.findMissingTrusts(trustUtils.getTrustNames(trustUtils.getTrusts()), hideUC)

            if missing and #missing > 0 then
                local output = table.concat(missing, ', ')
                print(chat.header(addon.name):append(chat.message(string.format('Trusts you are missing (%i): %s', #missing, output))))
            elseif missing and #missing == 0 then
                print(chat.header(addon.name):append(chat.success('You already own every trust')))
            else
                print(chat.header(addon.name):append(chat.error('Failed to get missing trusts')))
            end
        elseif arg == 'test' then

        end
    end
end

return commands
