-- #JericoFX
--[[
Ensambla los callbacks seguros para los distintos módulos del MDT/Computadora.
]]

if not lib then
    print("[fx-computer] ox_lib is needed, download it from communityox github")
    return
end

local Config = lib.load("shared.init_server")
local QBCore = exports['qb-core']:GetCoreObject()
local Police = require "server.modules.police.init"
local Medical = require "server.modules.medical.init"
local News = require "server.modules.news.init"

local function debugLog(msg)
    if Config and Config.DebugLog then
        lib.print.debug(('[fx-computer] %s'):format(msg))
    end
end

---@param src number
---@return any|nil player
local function GetQBPlayer(src)
    if not src then return end
    return QBCore.Functions.GetPlayer(src)
end

---@param src number
---@param module string
---@return boolean
local function HasModuleAccess(src, module)
    local player = GetQBPlayer(src)
    if not player then return false end

    local jobName = player.PlayerData.job and player.PlayerData.job.name
    if not jobName then return false end

    local allowed = Config.ModuleJobs[module]
    return allowed and allowed[jobName] == true or false
end

---@param value any
---@return boolean
local function isNonEmptyString(value)
    return type(value) == 'string' and #value > 0
end

---@param tbl any
---@return boolean
local function isTable(tbl)
    return type(tbl) == 'table'
end

local function safeNumber(n)
    if n == nil then return nil end
    local v = tonumber(n)
    return v
end

---@param src number
---@return string|nil
local function getCitizenId(src)
    local player = GetQBPlayer(src)
    if not player then return nil end
    return player.PlayerData.citizenid
end

lib.callback.register("fxcomputer:server:police:saveCase", function(source, payload)
    if not HasModuleAccess(source, "police") then return end
    if not isTable(payload) then return end

    local player = GetQBPlayer(source)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local caseId = safeNumber(payload.id)
    local existing = caseId and Police.Load(caseId) or nil

    if caseId and not existing then
        debugLog("Intento de editar caso inexistente")
        return
    end

    local createdBy = (existing and existing.created_by_cid) or citizenid
    local case = Police:new(
        caseId,
        payload.type,
        payload.title,
        payload.description,
        createdBy,
        payload.status,
        payload.created_at,
        payload.updated_at,
        citizenid
    )

    if isTable(payload.people) then
        for i = 1, #payload.people do
            local p = payload.people[i]
            if p and isNonEmptyString(p.citizenid) and isNonEmptyString(p.role) then
                case:AddPerson(p.citizenid, p.role, p.note)
            end
        end
    end

    if isTable(payload.evidences) then
        for i = 1, #payload.evidences do
            local e = payload.evidences[i]
            if e and isNonEmptyString(e.type) then
                case:AddEvidence(e.type, e.description, e.file_path)
            end
        end
    end

    local id = case:Save(citizenid)
    debugLog(("Caso policial guardado ID %s por %s"):format(tostring(id), tostring(citizenid)))
    return id
end)

lib.callback.register("fxcomputer:server:police:getCase", function(source, caseId)
    if not HasModuleAccess(source, "police") then return end
    local id = safeNumber(caseId)
    if not id then return end
    return Police.Load(id)
end)

lib.callback.register("fxcomputer:server:medical:saveIncident", function(source, payload)
    if not HasModuleAccess(source, "medical") then return end
    if not isTable(payload) then return end

    local player = GetQBPlayer(source)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local incidentId = safeNumber(payload.id)
    local existing = incidentId and Medical.Load(incidentId, true) or nil

    if incidentId and not existing then
        debugLog("Intento de editar incidente inexistente")
        return
    end

    local doctorCid = (existing and existing.doctor_cid) or citizenid
    local incident = Medical:new(
        incidentId,
        payload.patientCid or (existing and existing.patient_cid) or citizenid,
        doctorCid,
        payload.diagnosis or (existing and existing.diagnosis),
        payload.treatment or (existing and existing.treatment),
        payload.status or (existing and existing.status),
        payload.created_at or (existing and existing.created_at)
    )

    if isTable(payload.labs) then
        for i = 1, #payload.labs do
            local l = payload.labs[i]
            if l and isNonEmptyString(l.test_type) then
                incident:AddLabResult(l.test_type, citizenid, l.result_value, l.notes)
            end
        end
    end

    local id = incident:Save()
    debugLog(("Incidente médico guardado ID %s por %s"):format(tostring(id), tostring(citizenid)))
    return id
end)

lib.callback.register("fxcomputer:server:medical:getIncident", function(source, incidentId)
    if not HasModuleAccess(source, "medical") then return end
    local id = safeNumber(incidentId)
    if not id then return end
    return Medical.Load(id, true)
end)

lib.callback.register("fxcomputer:server:news:saveArticle", function(source, payload)
    if not HasModuleAccess(source, "news") then return end
    if not isTable(payload) then return end

    local player = GetQBPlayer(source)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local articleId = safeNumber(payload.id)
    local existing = articleId and News.Load(articleId, true) or nil

    if articleId and not existing then
        debugLog("Intento de editar artículo inexistente")
        return
    end

    local authorCid = (existing and existing.author_cid) or citizenid
    local article = News:new(
        articleId,
        payload.title or (existing and existing.title),
        payload.subtitle or (existing and existing.subtitle),
        payload.category or (existing and existing.category),
        payload.status or (existing and existing.status),
        payload.cover_image_url or (existing and existing.cover_image_url),
        payload.cover_video_url or (existing and existing.cover_video_url),
        payload.content_html or (existing and existing.content_html),
        payload.content_json or (existing and existing.content_json),
        authorCid,
        payload.related_case_id or (existing and existing.related_case_id),
        payload.related_incident_id or (existing and existing.related_incident_id),
        payload.slug or (existing and existing.slug),
        payload.created_at or (existing and existing.created_at),
        payload.published_at or (existing and existing.published_at)
    )

    if isTable(payload.media_links) then
        for i = 1, #payload.media_links do
            local m = payload.media_links[i]
            local mediaId = m and safeNumber(m.media_id)
            if mediaId then
                article:LinkMedia(mediaId, m.is_main == true)
            end
        end
    end

    local id = article:Save()
    debugLog(("Artículo guardado ID %s por %s"):format(tostring(id), tostring(citizenid)))
    return id
end)

lib.callback.register("fxcomputer:server:news:getArticle", function(source, articleId)
    if not HasModuleAccess(source, "news") then return end
    local id = safeNumber(articleId)
    if not id then return end
    return News.Load(id, true)
end)

RegisterNetEvent('fxcomputer:server:requestAccessCheck', function(module)
    local src = source
    local allowed = HasModuleAccess(src, module)
    TriggerClientEvent('fxcomputer:client:accessResult', src, module, allowed)
end)

RegisterNetEvent('fxcomputer:server:refreshPlayerCid', function()
    local src = source
    local cid = getCitizenId(src)
    if not cid then return end
    TriggerClientEvent('fxcomputer:client:updateCid', src, cid)
end)
