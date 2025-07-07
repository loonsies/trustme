local chat = require('chat')
local task = require('src/task')
local trustUtils = require('src/trustUtils')
local profiles = require('src/profiles')
local utils = require('src/utils')
local taskTypes = require('data/taskTypes')

local commands = {}

function commands.summon(trusts)
    if trusts and #trusts > 0 then
        print(chat.header(addon.name):append(chat.success(string.format('Summoning %s', table.concat(trusts, ', ')))))
        for i = 1, #trusts do
            local entry = {
                type = taskTypes.summon,
                trustName = trusts[i],
                interval = 8
            }
            task.enqueue(entry)
        end
        tme.eta = (tme.eta or 0) + (#trusts * 8)
    end
end

function commands.handleCommand(args)
    local command = string.lower(args[1])
    local arg = #args > 1 and string.lower(args[2]) or ''
    local arg2 = #args > 2 and string.lower(args[3]) or ''

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
            local trusts = utils.filterEmpty(string.split(arg2, ',') or {})
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
            local started = trustUtils.fetchLoginCampaignCiphers()

            local ciphers = tme.workerResult or {}

            tme.workerResult = nil

            if #ciphers > 0 then
                local ownedTrusts = trustUtils.getTrustNames(trustUtils.getTrusts())
                local missingCiphers = trustUtils.findMissingCiphers(ciphers, ownedTrusts)
                if #missingCiphers > 0 then
                    local formattedList = {}
                    for _, entry in ipairs(missingCiphers) do
                        table.insert(formattedList, string.format('%s (%s)', entry.cipher, entry.name))
                    end
                    local output = table.concat(formattedList, ', ')

                    print(chat.header(addon.name):append(chat.message(string.format('Current login campaign ciphers you are missing: %s', output))))
                else
                    print(chat.header(addon.name):append(chat.success('You already own every cipher sold in the current login campaign')))
                end
            else
                print(chat.header(addon.name):append(chat.success('Failed to fetch current login campaign')))
            end
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
