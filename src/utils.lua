local chat = require('chat')
local http = require('socket.http')
local ltn12 = require('socket.ltn12')
local task = require('src/task')

local utils = {}

function utils.writeFile(path, data, mode, verbose)
    if not mode or (mode ~= 'w+' and mode ~= 'a+') then
        print(chat.header('filters'):append(chat.error(string.format('Unknown mode: %s', mode))))
        return
    end

    local filePath = string.format('%s\\%s', addon.path, path)

    local f = io.open(filePath, mode)
    if (f == nil) then
        print(chat.header('filters'):append(chat.error(string.format('Failed to open file: %s', filePath))))
        return false
    end

    f:write(tostring(data))
    f:close()

    if verbose then
        print(chat.header('filters'):append(chat.success(string.format('Successfully wrote file: %s', filePath))))
    end
    return true
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

function utils.fetchUrl(url)
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

return utils
