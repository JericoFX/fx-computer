
-- One class to handle everything #JericoFX
local BaseClass = lib.class("BaseClass")
local Data = {
    police = {},
    medical = {},
    news = {}
}

function BaseClass:ValidateJob(source,job)
    --check Job 
end

function BaseClass:Add(program,id,typeOfData,data)
    if not Data[program] or not Data[program][id] then return false end
    Data[program][id][typeOfData] = data
    return true
end

function BaseClass:Get(program,id)
    if not Data[program] or not Data[program][id] then return false end
    return Data[program][id]
end

function BaseClass:Delete(program,id)
    if not Data[program] or not Data[program][id] then return false end
    Data[program][id] = nil
    return true
end

function BaseClass:Update(program,id,typeOfData,data)
    local _update = self:Get(program,id)
    if not _update then return false end
    _update[typeOfData] = data
    return true
end

function BaseClass:Save()

end

return BaseClass