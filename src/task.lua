local chat = require('chat')
local taskTypes = require('data/taskTypes')

local task = {}
local throttle_timer = 0

local function handleEntry(entry)
    if entry.type == taskTypes.summon then
        AshitaCore:GetChatManager():QueueCommand(-1, string.format('/ma "%s" <me>', entry.trustName))
        throttle_timer = os.clock() + entry.interval
    else
        print(chat.header(addon.name):append(chat.error(string.format('Unknown task type: %s', tostring(entry.type)))))
    end
end

function task.handleQueue()
    while #tme.queue > 0 and os.clock() > throttle_timer do
        handleEntry(tme.queue[1])
        table.remove(tme.queue, 1)
    end
end

function task.clear()
    if #tme.queue > 0 then
        print(chat.header(addon.name):append(chat.warning(string.format('Removed %i tasks from queue', #tme.queue))))
    end
    tme.queue = {}
    tme.eta = 0
end

function task.enqueue(entry)
    local queueCount = #tme.queue
    if queueCount == 0 and os.clock() > throttle_timer then
        handleEntry(entry)
    else
        tme.queue[queueCount + 1] = entry
    end
end

return task
