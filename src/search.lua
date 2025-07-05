local trustUtils = require('src/trustUtils')
local searchStatus = require('data/searchStatus')

local search = {}

function search.updateSearch()
    tme.search.results = {}
    local trusts = trustUtils.getTrusts()
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

return search
