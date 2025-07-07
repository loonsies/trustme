local chat = require('chat')
local thread = require('src/thread')
local utils = require('src/utils')
local cipherData = require('data/cipherData')

local trustUtils = {}

function trustUtils.fetchLoginCampaignCiphers()
    local url = 'https://www.bg-wiki.com/ffxi/Repeat_Login_Campaign#Current_Login_Campaign'

    --if tme.worker ~= nil then
    --    print(chat.header(addon.name):append(chat.warning('Still fetching login campaign ciphers, please wait...')))
    --    return false
    --end

    --tme.worker = thread.start(function ()
    local response = utils.fetchUrl(url)
    if not response then
        return nil
    end
    local ciphers = {}

    if response then
        for cipher in response:gmatch('title="(Cipher: [^"]+)"') do
            table.insert(ciphers, cipher)
        end
    end

    tme.workerResult = ciphers
    --end)

    return true
end

--function trustUtils.pollWorker()
--    if tme.worker ~= nil then
--        local result = tme.worker:wait(0)
--        if result == 0 then
--            local ciphers = tme.workerResult or {}
--
--            tme.worker:close()
--            tme.worker = nil
--            tme.workerResult = nil
--
--            if #ciphers > 0 then
--                local ownedTrusts = trustUtils.getTrustNames(trustUtils.getTrusts())
--                local missingCiphers = trustUtils.findMissingCiphers(ciphers, ownedTrusts)
--                if #missingCiphers > 0 then
--                    local formattedList = {}
--                    for _, entry in ipairs(missingCiphers) do
--                        table.insert(formattedList, string.format('%s (%s)', entry.cipher, entry.name))
--                    end
--                    local output = table.concat(formattedList, ', ')
--
--                    print(chat.header(addon.name):append(chat.message(string.format('Current login campaign ciphers you are missing: %s', output))))
--                else
--                    print(chat.header(addon.name):append(chat.success('You already own every cipher sold in the current login campaign')))
--                end
--            else
--                print(chat.header(addon.name):append(chat.error('Failed to fetch current login campaign ciphers')))
--            end
--        end
--    end
--end

-- Credits to Thorny, from ttimers
function trustUtils.getTrusts()
    local ownedTrusts = {}
    local resMgr = AshitaCore:GetResourceManager();
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local mainJob = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob()
    local mainJobLevel = AshitaCore:GetMemoryManager():GetPlayer():GetMainJobLevel();
    local subJob = AshitaCore:GetMemoryManager():GetPlayer():GetSubJob();
    local subJobLevel = AshitaCore:GetMemoryManager():GetPlayer():GetSubJobLevel();
    local jpTotal = AshitaCore:GetMemoryManager():GetPlayer():GetJobPoints(mainJob);

    for i = 1, 0x400 do
        local res = resMgr:GetSpellById(i)
        if (res) and (player:HasSpell(i)) then
            local levelRequired = res.LevelRequired;

            -- Maybe not best workaround, but trust are all usable at WAR1.
            if (levelRequired[2] == 1) then
                local hasSpell = false;
                local jpMask = res.JobPointMask;
                if (bit.band(bit.rshift(jpMask, mainJob), 1) == 1) then
                    if (mainJobLevel == 99) and (jpTotal >= levelRequired[mainJob + 1]) then
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
                    table.insert(ownedTrusts, res)
                end
            end
        end
    end

    table.sort(ownedTrusts, function (a, b)
        return a.Name[1] < b.Name[1]
    end)

    return ownedTrusts
end

function trustUtils.getTrustNames(t)
    local names = {}
    for _, trust in ipairs(t) do
        if trust.Name and trust.Name[1] then
            table.insert(names, trust.Name[1])
        end
    end
    return names
end

function trustUtils.findMissingCiphers(ciphers, ownedTrusts)
    local missing = {}

    for _, cipherName in ipairs(ciphers) do
        local trustName = nil

        for _, entry in pairs(cipherData) do
            if entry.en and entry.en:lower() == cipherName:lower() then
                trustName = entry.trust_en
                break
            end
        end

        if trustName then
            local owned = false

            for _, ownedName in ipairs(ownedTrusts) do
                if ownedName:lower() == trustName:lower() then
                    owned = true
                    break
                end
            end

            if not owned then
                table.insert(missing, { cipher = cipherName, name = trustName })
            end
        else
            print(chat.header(addon.name):append(chat.error(string.format('Could not find corresponding trust name for %s', cipherName))))
        end
    end

    return missing
end

function trustUtils.findMissingTrusts(ownedTrusts, hideUC)
    local missing = {}
    local trustData = require('data/trustData')

    for _, entry in pairs(trustData) do
        local trustName = nil
        if entry.en then
            trustName = entry.en
        end

        if trustName then
            local owned = false

            for _, ownedName in ipairs(ownedTrusts) do
                if ownedName:lower() == trustName:lower() then
                    owned = true
                    break
                end
            end

            if not owned and (not hideUC or (hideUC and not string.find(trustName, '%(UC%)'))) then
                table.insert(missing, trustName)
            end
        end
    end

    return missing
end

return trustUtils
