task = {}
local throttle_timer = 0

taskTypes = {
    summon = 1
 }

local function handleEntry(entry)
    if entry.type == taskTypes.summon then
        AshitaCore:GetChatManager():QueueCommand(-1, string.format('/ma %s <me>', entry.trustName))
        throttle_timer = os.clock() + entry.interval
    else
        print('Unknown task type: ' .. tostring(entry.type))
    end
end

local function handleQueue()
    while #tme.queue > 0 and os.clock() > throttle_timer do
        handleEntry(tme.queue[1])
        table.remove(tme.queue, 1)
    end
end

function task.clear()
    tme.queue = {}
end

function task.enqueue(entry)
    local queueCount = #tme.queue
    if queueCount == 0 and os.clock() > throttle_timer then
        handleEntry(entry)
    else
        tme.queue[queueCount + 1] = entry
    end
end

ashita.events.register('packet_out', 'packet_out_cb', function(e)
    handleQueue()
end)

return task
