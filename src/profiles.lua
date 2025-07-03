profiles = {}

local function findProfileIndex(profiles, name)
    for i, profile in ipairs(profiles) do
        if profile.name == name then
            return i
        end
    end
    return nil
end

function profiles.getProfiles()
    return tme.config.profiles or {}
end

function profiles.getProfile(name)
    local profiles = profiles.getProfiles()
    for _, profile in ipairs(profiles) do
        if profile.name == name then
            return profile
        end
    end
    return nil
end

function profiles.getProfileIndex(name)
    return findProfileIndex(tme.config.profiles or {}, name)
end

function profiles.saveProfile(name, trusts)
    tme.config.profiles = tme.config.profiles or {}

    local idx = findProfileIndex(tme.config.profiles, name)
    if idx then
        -- Update existing
        tme.config.profiles[idx].trusts = table.copy(trusts)
    else
        -- Create new
        table.insert(tme.config.profiles, {
            name = name,
            trusts = table.copy(trusts)
        })
    end

    settings.save()
end

function profiles.deleteProfile(name)
    if not tme.config.profiles then return end

    local idx = findProfileIndex(tme.config.profiles, name)
    if idx then
        table.remove(tme.config.profiles, idx)
        settings.save()
    end
end

function profiles.loadTrusts(index)
    local profile = tme.config.profiles[index]
    tme.search.selectedTrusts = {}
    if profile.trusts then
        for _, trust in ipairs(profile.trusts) do
            table.insert(tme.search.selectedTrusts, trust)
        end
    end
end

return profiles
