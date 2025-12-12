-- #JericoFX
local _POLICE_DB = lib.load("server.modules.police.db")
local BaseClass = lib.load("server.modules.BaseClass")
local Police = lib.class("Police",BaseClass)
local Debug = lib.load("server.modules.debug")
--[[
    APP CASE DESK

Permite crear, editar y cerrar casos policiales.

Adjuntar evidencias, personas involucradas y notas.

Ver estado del caso (abierto, investigando, cerrado).

]]
function Police:constructor(id,typeOfData,data)
    self.program = "police"
    self.id = id
    self.typeOfData = typeOfData
    self.data = data
end

function Police:SetNew(...)
    self:super:Add(self.program,self.id,self.typeOfData,self.data)
    self:Save()
    lib.print.debug("SetNew %s ",id)
    return true
end

function Police:GetByID(id)
    lib.print.debug("GetByID %s ",id)
    return self:super:Get(self.program,self.id)
end

function Police:EditByID(id,typeOfData,data)
    local _temp = self:GetByID(id)
    if not _temp then 
        _temp = nil
        return false 
    end
    self:super:Update(self.program,sel.id,typeOfData,data)
    lib.print.debug("Update %s ",id)
end

function Police:SetUpdate(...)

end

function Police:DeleteCase(id)

end

function Police:Save()

end

return Police