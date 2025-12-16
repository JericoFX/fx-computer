local M = {}

local function safeCallback(cb, payload)
    if type(cb) ~= 'function' then return end
    cb(payload or {})
end

function M.registerNui()
    RegisterNUICallback('fxcomputer:news:saveArticle', function(data, cb)
        local id = lib.callback.await('fxcomputer:server:news:saveArticle', false, data)
        safeCallback(cb, { id = id })
    end)

    RegisterNUICallback('fxcomputer:news:getArticle', function(data, cb)
        local article = nil
        if data and data.id then
            article = lib.callback.await('fxcomputer:server:news:getArticle', false, data.id)
        end
        safeCallback(cb, article)
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
