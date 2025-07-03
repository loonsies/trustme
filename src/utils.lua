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

return utils
