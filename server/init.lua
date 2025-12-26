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

    local jobData = player.PlayerData.job
    if not jobData then return false end

    if Config.RequireOnDuty and jobData.onduty == false then return false end

    local jobName = jobData.name
    if not jobName or jobName == '' then return false end

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

local VALID_POLICE_STATUS = {
    open = true,
    investigating = true,
    closed = true,
    archived = true,
}

local VALID_POLICE_ROLES = {
    suspect = true,
    victim = true,
    witness = true,
    officer = true,
}

local VALID_EVIDENCE_TYPES = {
    photo = true,
    video = true,
    note = true,
    file = true,
}

local VALID_MED_STATUS = {
    open = true,
    treated = true,
    transferred = true,
    closed = true,
}

local VALID_NEWS_STATUS = {
    draft = true,
    scheduled = true,
    published = true,
    archived = true,
}

local function getValidationMax(key, fallback)
    if Config and Config.Validation and Config.Validation[key] then
        return Config.Validation[key]
    end
    return fallback
end

local function isStringWithin(value, maxLen)
    if value == nil then return true end
    if type(value) ~= 'string' then return false end
    return #value <= maxLen
end

local function isNonEmptyStringWithin(value, maxLen)
    if not isNonEmptyString(value) then return false end
    return #value <= maxLen
end

local function sanitizeHtmlBasic(value)
    if type(value) ~= 'string' then return value end
    local s = value
    s = s:gsub('<[sS][cC][rR][iI][pP][tT][^>]*>.-</[sS][cC][rR][iI][pP][tT]>', '')
    s = s:gsub('on%w+%s*=%s*"(.-)"', '')
    s = s:gsub("on%w+%s*=%s*'(.-)'", '')
    s = s:gsub("on%w+%s*=%s*[^%s>]+", '')
    s = s:gsub('javascript:', '')
    return s
end

local rateLimits = {}

local function isRateLimited(src, key, cooldownMs)
    if not src or not key then return false end
    local now = GetGameTimer()
    local player = rateLimits[src]
    if not player then
        player = {}
        rateLimits[src] = player
    end
    local last = player[key] or 0
    if now - last < cooldownMs then
        return true
    end
    player[key] = now
    return false
end

local function canEditNonOwner(module)
    if Config and Config.AllowNonOwnerEdits and Config.AllowNonOwnerEdits[module] == true then
        return true
    end
    return false
end

local function validateRelatedCase(id)
    if id == nil then return true end
    local num = safeNumber(id)
    if not num then return false end
    local caseObj = Police.Load(num)
    return caseObj ~= nil
end

local function validateRelatedIncident(id)
    if id == nil then return true end
    local num = safeNumber(id)
    if not num then return false end
    local incident = Medical.Load(num, false)
    return incident ~= nil
end

---@param src number
---@return string|nil
lib.callback.register("fxcomputer:server:police:saveCase", function(source, payload)
    if not HasModuleAccess(source, "police") then return end
    if not isTable(payload) then return end
    if isRateLimited(source, 'police:save', Config.Cooldowns and Config.Cooldowns.saveMs or 1500) then return end

    local player = GetQBPlayer(source)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local caseId = safeNumber(payload.id)
    local existing = caseId and Police.Load(caseId) or nil

    if caseId and not existing then
        debugLog("Intento de editar caso inexistente")
        return
    end

    if existing and existing.created_by_cid ~= citizenid and not canEditNonOwner("police") then
        debugLog("Intento de editar caso sin permisos de propietario")
        return
    end

    local typeOfCase = payload.type or (existing and existing.type)
    local title = payload.title or (existing and existing.title)
    local description = payload.description or (existing and existing.description)
    local status = payload.status or (existing and existing.status)

    if not isNonEmptyStringWithin(typeOfCase, getValidationMax('maxTitle', 120)) then return end
    if not isNonEmptyStringWithin(title, getValidationMax('maxTitle', 120)) then return end
    if not isStringWithin(description, getValidationMax('maxDescription', 2000)) then return end
    if status and VALID_POLICE_STATUS[status] ~= true then return end

    local createdBy = (existing and existing.created_by_cid) or citizenid
    local case = Police:new(
        caseId,
        typeOfCase,
        title,
        description,
        createdBy,
        status,
        existing and existing.created_at or nil,
        existing and existing.updated_at or nil,
        citizenid
    )

    if isTable(payload.people) then
        if #payload.people > getValidationMax('maxPeople', 30) then return end
        for i = 1, #payload.people do
            local p = payload.people[i]
            if p
                and isNonEmptyStringWithin(p.citizenid, getValidationMax('maxTitle', 120))
                and isNonEmptyStringWithin(p.role, getValidationMax('maxPersonRole', 20))
                and VALID_POLICE_ROLES[p.role] == true
                and isStringWithin(p.note, getValidationMax('maxNote', 500))
            then
                case:AddPerson(p.citizenid, p.role, p.note)
            end
        end
    end

    if isTable(payload.evidences) then
        if #payload.evidences > getValidationMax('maxEvidences', 40) then return end
        for i = 1, #payload.evidences do
            local e = payload.evidences[i]
            if e
                and isNonEmptyStringWithin(e.type, getValidationMax('maxEvidenceType', 20))
                and VALID_EVIDENCE_TYPES[e.type] == true
                and isStringWithin(e.description, getValidationMax('maxDescription', 2000))
                and isStringWithin(e.file_path, getValidationMax('maxUrl', 300))
            then
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
    if isRateLimited(source, 'police:get', Config.Cooldowns and Config.Cooldowns.getMs or 800) then return end
    local id = safeNumber(caseId)
    if not id then return end
    return Police.Load(id)
end)

lib.callback.register("fxcomputer:server:medical:saveIncident", function(source, payload)
    if not HasModuleAccess(source, "medical") then return end
    if not isTable(payload) then return end
    if isRateLimited(source, 'medical:save', Config.Cooldowns and Config.Cooldowns.saveMs or 1500) then return end

    local player = GetQBPlayer(source)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local incidentId = safeNumber(payload.id)
    local existing = incidentId and Medical.Load(incidentId, true) or nil

    if incidentId and not existing then
        debugLog("Intento de editar incidente inexistente")
        return
    end

    if existing and existing.doctor_cid ~= citizenid and not canEditNonOwner("medical") then
        debugLog("Intento de editar incidente sin permisos de propietario")
        return
    end

    local patientCid = payload.patientCid or (existing and existing.patient_cid) or citizenid
    local diagnosis = payload.diagnosis or (existing and existing.diagnosis)
    local treatment = payload.treatment or (existing and existing.treatment)
    local status = payload.status or (existing and existing.status)

    if not isNonEmptyStringWithin(patientCid, getValidationMax('maxTitle', 120)) then return end
    if not isStringWithin(diagnosis, getValidationMax('maxDiagnosis', 2000)) then return end
    if not isStringWithin(treatment, getValidationMax('maxTreatment', 2000)) then return end
    if status and VALID_MED_STATUS[status] ~= true then return end

    local doctorCid = (existing and existing.doctor_cid) or citizenid
    local incident = Medical:new(
        incidentId,
        patientCid,
        doctorCid,
        diagnosis,
        treatment,
        status,
        existing and existing.created_at or nil
    )

    if isTable(payload.labs) then
        if #payload.labs > getValidationMax('maxLabs', 40) then return end
        for i = 1, #payload.labs do
            local l = payload.labs[i]
            if l
                and isNonEmptyStringWithin(l.test_type, getValidationMax('maxLabTestType', 80))
                and isStringWithin(l.result_value, getValidationMax('maxResultValue', 500))
                and isStringWithin(l.notes, getValidationMax('maxNote', 500))
            then
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
    if isRateLimited(source, 'medical:get', Config.Cooldowns and Config.Cooldowns.getMs or 800) then return end
    local id = safeNumber(incidentId)
    if not id then return end
    return Medical.Load(id, true)
end)

lib.callback.register("fxcomputer:server:news:saveArticle", function(source, payload)
    if not HasModuleAccess(source, "news") then return end
    if not isTable(payload) then return end
    if isRateLimited(source, 'news:save', Config.Cooldowns and Config.Cooldowns.saveMs or 1500) then return end

    local player = GetQBPlayer(source)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local articleId = safeNumber(payload.id)
    local existing = articleId and News.Load(articleId, true) or nil

    if articleId and not existing then
        debugLog("Intento de editar artículo inexistente")
        return
    end

    if existing and existing.author_cid ~= citizenid and not canEditNonOwner("news") then
        debugLog("Intento de editar artículo sin permisos de propietario")
        return
    end

    local title = payload.title or (existing and existing.title)
    local subtitle = payload.subtitle or (existing and existing.subtitle)
    local category = payload.category or (existing and existing.category)
    local status = payload.status or (existing and existing.status)
    local coverImageUrl = payload.cover_image_url or (existing and existing.cover_image_url)
    local coverVideoUrl = payload.cover_video_url or (existing and existing.cover_video_url)
    local contentHtml = payload.content_html or (existing and existing.content_html)
    local contentJson = payload.content_json or (existing and existing.content_json)
    local relatedCaseId = payload.related_case_id or (existing and existing.related_case_id)
    local relatedIncidentId = payload.related_incident_id or (existing and existing.related_incident_id)
    local slug = payload.slug or (existing and existing.slug)

    if not isNonEmptyStringWithin(title, getValidationMax('maxTitle', 120)) then return end
    if not isStringWithin(subtitle, getValidationMax('maxSubtitle', 160)) then return end
    if not isStringWithin(category, getValidationMax('maxCategory', 80)) then return end
    if status and VALID_NEWS_STATUS[status] ~= true then return end
    if not isStringWithin(coverImageUrl, getValidationMax('maxUrl', 300)) then return end
    if not isStringWithin(coverVideoUrl, getValidationMax('maxUrl', 300)) then return end
    if not isStringWithin(contentHtml, getValidationMax('maxContentHtml', 20000)) then return end
    if not isStringWithin(contentJson, getValidationMax('maxContentJson', 30000)) then return end
    if not isStringWithin(slug, getValidationMax('maxSlug', 120)) then return end
    if not validateRelatedCase(relatedCaseId) then return end
    if not validateRelatedIncident(relatedIncidentId) then return end

    contentHtml = sanitizeHtmlBasic(contentHtml)

    local authorCid = (existing and existing.author_cid) or citizenid
    local article = News:new(
        articleId,
        title,
        subtitle,
        category,
        status,
        coverImageUrl,
        coverVideoUrl,
        contentHtml,
        contentJson,
        authorCid,
        relatedCaseId,
        relatedIncidentId,
        slug,
        existing and existing.created_at or nil,
        existing and existing.published_at or nil
    )

    if isTable(payload.media_links) then
        if #payload.media_links > getValidationMax('maxMediaLinks', 30) then return end
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
    if isRateLimited(source, 'news:get', Config.Cooldowns and Config.Cooldowns.getMs or 800) then return end
    local id = safeNumber(articleId)
    if not id then return end
    return News.Load(id, true)
end)

RegisterNetEvent('fxcomputer:server:requestAccessCheck', function(module)
    local src = source
    if isRateLimited(src, 'access:check', Config.Cooldowns and Config.Cooldowns.accessCheckMs or 1000) then return end
    local allowed = HasModuleAccess(src, module)
    TriggerClientEvent('fxcomputer:client:accessResult', src, module, allowed)
end)

RegisterNetEvent('fxcomputer:server:refreshPlayerCid', function() end)
