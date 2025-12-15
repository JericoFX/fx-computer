local M = {}

local function safeCallback(cb, payload)
    if type(cb) == 'function' then
        cb(payload)
    end
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

return M
