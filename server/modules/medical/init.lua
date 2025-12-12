-- Init for Medical Module #JericoFX
local _DATABASE_MODULE = lib.load("server.modules.medical.db")
local Medical = lib.class("Medical")

--===============================--
--       MED RECORDS APP       --
--===============================--

function Medical:SetNewRecord(id,data)

end

function Medical:GetNewRecordById(id)

end

function Medical:ChangeRecordStatus(id,newStatus)

end

--===============================--
--       TRIAGE DESK APP       --
--===============================--

function Medical:SetNewTriageRecord()

end

function Medical:GetTriageById(id)

end

function Medical:ChangeTriageStatus(id,status)

end

--===============================--
--       LAB RESULTS APP       --
--===============================--

function Medical:SetNewLabRecord()

end

function Medical:GetLabByResultId(id)

end

function Medical:ChangeLabStatus(id,status)

end



return Medical