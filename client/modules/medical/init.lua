local M = {}

local function safeCallback(cb, payload)
    if type(cb) ~= 'function' then return end
    cb(payload or {})
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

function M.sendNUI(name, data)
    if name == nil then return end
    local action = (type(name) == "string") and name or tostring(name)
    SendNUIMessage({
        action = action,
        data = data or {}
    })
end

return M
