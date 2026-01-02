local chat  = require('chat')
local http  = require('socket.http')
local ltn12 = require('socket.ltn12')
local ffi   = require('ffi')
local d3d8  = require('d3d8');

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

function utils.createTextureFromFile(path)
    if (path ~= nil) then
        local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]')
        local d3d8_device = d3d8.get_device()
        if (ffi.C.D3DXCreateTextureFromFileA(d3d8_device, path, dx_texture_ptr) == ffi.C.S_OK) then
            local texture = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]))
            local result, desc = texture:GetLevelDesc(0)
            if result == 0 then
                tx         = {}
                tx.Texture = texture
                tx.Width   = desc.Width
                tx.Height  = desc.Height
                return tx
            end
            return
        end
    end
end

return utils
