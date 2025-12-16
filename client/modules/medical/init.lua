local M = {}

local function safeCallback(cb, payload)
    if type(cb) == 'function' then
        cb(payload)
    end
end

function M.registerNui()
    RegisterNUICallback('fxcomputer:medical:saveIncident', function(data, cb)
        local id = lib.callback.await('fxcomputer:server:medical:saveIncident', false, data)
        safeCallback(cb, { id = id })
    end)

    RegisterNUICallback('fxcomputer:medical:getIncident', function(data, cb)
        local incident = nil
        if data and data.id then
            incident = lib.callback.await('fxcomputer:server:medical:getIncident', false, data.id)
        end
        safeCallback(cb, incident)
    end)
end

return M
