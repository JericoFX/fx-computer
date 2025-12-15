local M = {}

local function safeCallback(cb, payload)
    if type(cb) == 'function' then
        cb(payload)
    end
end

function M.registerNui()
    RegisterNUICallback('fxcomputer:police:saveCase', function(data, cb)
        local id = lib.callback.await('fxcomputer:server:police:saveCase', false, data)
        safeCallback(cb, { id = id })
    end)

    RegisterNUICallback('fxcomputer:police:getCase', function(data, cb)
        local caseData = nil
        if data and data.id then
            caseData = lib.callback.await('fxcomputer:server:police:getCase', false, data.id)
        end
        safeCallback(cb, caseData)
    end)
end

return M
