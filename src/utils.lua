utils = {}

function utils.getTrusts()
    local trusts = {}
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
                    table.insert(trusts, res)
                end
            end
        end
    end

    table.sort(trusts, function (a, b)
        return a.Name[1] < b.Name[1]
    end)

    return trusts
end

function utils.getTrustNames(trusts)
    local names = {}
    for _, trust in ipairs(trusts) do
        if trust.Name and trust.Name[1] then
            table.insert(names, trust.Name[1])
        end
    end
    return names
end

function utils.filterEmpty(list)
    local result = {}
    for _, v in ipairs(list) do
        local trimmed = v:match('^%s*(.-)%s*$') -- trim spaces
        if trimmed ~= '' then
            table.insert(result, trimmed)
        end
    end
    return result
end

local function getBaseUrl(url)
    return url:match('^(https?://[^/]+)')
end

local function fetchUrl(url)
    local maxRedirects = 5
    local redirects = 0

    while redirects < maxRedirects do
        local response_body = {}
        local _, statusCode, headers = http.request {
            url = url,
            sink = ltn12.sink.table(response_body)
        }

        local body = table.concat(response_body)

        if not body then
            print('HTTP request failed')
            return nil
        end

        if statusCode >= 300 and statusCode < 400 then
            local location = headers.location
            if not location then
                print('Redirect status but no Location header')
                return nil
            end

            if not location:match('^https?://') then
                local base = getBaseUrl(url)
                location = base .. location
            end

            url = location
            redirects = redirects + 1
        else
            return body
        end
    end

    print('Too many redirections')
    return nil
end

function utils.fetchLoginCampaignCiphers()
    local url = 'https://www.bg-wiki.com/ffxi/Repeat_Login_Campaign#Current_Login_Campaign'
    local html = fetchUrl(url)
    if not html then
        return nil
    end

    local ciphers = {}

    for cipher in html:gmatch('title="Cipher: ([^"]+)"') do
        local cipherUrl = 'https://www.bg-wiki.com/ffxi/Cipher:_' .. cipher
        local cipherHtml = fetchUrl(cipherUrl)

        local trustName1, trustName2

        if cipherHtml then
            trustName1 = cipherHtml:match('<table[^>]-class="wikitable"[^>]->.-<big>(.-)</big>')
            trustName2 = cipherHtml:match('Cipher of ([^<]+)\'s alter ego')
        end

        table.insert(ciphers, {
            cipher = cipher,
            trustName1 = trustName1,
            trustName2 = trustName2
        })
    end

    return ciphers
end

function utils.findMissingCiphers(ciphers, ownedTrusts)
    local missing = {}

    for _, cipher in ipairs(ciphers) do
        local found = false

        for _, owned in ipairs(ownedTrusts) do
            if (cipher.trustName1 and owned:lower() == cipher.trustName1:lower())
            or (cipher.trustName2 and owned:lower() == cipher.trustName2:lower()) then
                found = true
                break
            end
        end

        if not found then
            table.insert(missing, cipher.cipher)
        end
    end

    return missing
end

return utils
