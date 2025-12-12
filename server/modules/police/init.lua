-- #JericoFX
local _POLICE_DB = lib.load("server.modules.police.db")

---@alias PoliceCaseStatus "open"|"investigating"|"closed"|"archived"
---@alias PoliceCasePersonRole "suspect"|"victim"|"witness"|"officer"
---@alias EvidenceType "photo"|"video"|"note"|"file"

---@class PoliceCasePerson
---@field citizenid string
---@field role PoliceCasePersonRole
---@field note? string

---@class PoliceCaseEvidenceQueueItem
---@field type EvidenceType
---@field description? string
---@field file_path? string

---@class PoliceCaseEvidenceRow
---@field id number
---@field type EvidenceType
---@field descryption? string
---@field file_path? string
---@field created_at string
---@field added_by_cid string

---@class PoliceCaseRow
---@field id number
---@field type string
---@field title string
---@field description? string
---@field status PoliceCaseStatus
---@field created_at string
---@field updated_at? string
---@field created_by_cid string
---@field last_editor_cid? string

---@class PoliceCase
---@field id? number
---@field type string
---@field title string
---@field description? string
---@field status PoliceCaseStatus
---@field created_by_cid string
---@field last_editor_cid string
---@field created_at? string
---@field updated_at? string
---@field people PoliceCasePerson[]
---@field evidences (PoliceCaseEvidenceRow[]|PoliceCaseEvidenceQueueItem[])
local PoliceCase = lib.class('PoliceCase')

---@type table<PoliceCaseStatus, boolean>
local VALID_STATUSES = {
  open = true,
  investigating = true,
  closed = true,
  archived = true,
}

---@private
---@param cond boolean
---@param msg string
local function assertOrError(cond, msg)
  if not cond then
    lib.print.error(msg)
  end
end

---@private
---@param s any
---@return boolean
local function isNonEmptyString(s)
  return type(s) == 'string' and #s > 0
end

---Create a new PoliceCase instance.
---If `id` is nil, it represents a new case not yet inserted in DB.
---@param id? number
---@param typeOfCase string
---@param title string
---@param description? string
---@param createdByCid string
---@param status? PoliceCaseStatus
---@param createdAt? string
---@param updatedAt? string
---@param lastEditorCid? string
function PoliceCase:constructor(id, typeOfCase, title, description, createdByCid, status, createdAt, updatedAt, lastEditorCid)
  assertOrError(isNonEmptyString(typeOfCase), 'PoliceCase: "typeOfCase" is required (non-empty string)')
  assertOrError(isNonEmptyString(title), 'PoliceCase: "title" is required (non-empty string)')
  assertOrError(isNonEmptyString(createdByCid), 'PoliceCase: "createdByCid" is required (non-empty string)')

  status = status or 'open'
  assertOrError(VALID_STATUSES[status] == true, ('PoliceCase: invalid "status": %s'):format(tostring(status)))

  self.id = id and tonumber(id) or nil
  self.type = typeOfCase
  self.title = title
  self.description = description or nil
  self.status = status

  self.created_by_cid = createdByCid
  self.last_editor_cid = lastEditorCid or createdByCid

  -- These usually come from DB on Load()
  self.created_at = createdAt
  self.updated_at = updatedAt

  self.people = {}
  self.evidences = {} 
end

---Add a person relation to this case.
---@param citizenid string
---@param role PoliceCasePersonRole
---@param note? string
---@return PoliceCase
function PoliceCase:AddPerson(citizenid, role, note)
  assertOrError(isNonEmptyString(citizenid), 'AddPerson: "citizenid" is required')
  assertOrError(isNonEmptyString(role), 'AddPerson: "role" is required')

  ---@type PoliceCasePerson
  local p = { citizenid = citizenid, role = role, note = note }

  self.people[#self.people+1] = p
  return self
end

---Queue an evidence item for insertion (will be inserted on Save()).
---@param evidenceType EvidenceType
---@param description? string
---@param filePath? string
---@return PoliceCase
function PoliceCase:AddEvidence(evidenceType, description, filePath)
  assertOrError(isNonEmptyString(evidenceType), 'AddEvidence: "evidenceType" is required')

  ---@type PoliceCaseEvidenceQueueItem
  local e = {
    type = evidenceType,
    description = description,
    file_path = filePath,
  }

  self.evidences[#self.evidences+1] =  e
  return self
end

---Insert or update the case in DB, and persist queued relations.
---`editorCid` should be the current officer saving the case.
---@param editorCid? string
---@return number caseId
function PoliceCase:Save(editorCid)
  if editorCid ~= nil then
    assertOrError(isNonEmptyString(editorCid), 'Save: "editorCid" must be a non-empty string when provided')
    self.last_editor_cid = editorCid
  end

  -- INSERT if new
  if not self.id then
    local insertId = MySQL.insert.await([[
      INSERT INTO mdt_cases (type, title, description, status, created_by_cid, last_editor_cid)
      VALUES (?, ?, ?, ?, ?, ?)
    ]], {
      self.type,
      self.title,
      self.description,
      self.status,
      self.created_by_cid,
      self.last_editor_cid,
    })

    self.id = insertId
  else
    -- UPDATE if existing
    MySQL.update.await([[
      UPDATE mdt_cases
      SET type = ?, title = ?, description = ?, status = ?, updated_at = NOW(), last_editor_cid = ?
      WHERE id = ?
    ]], {
      self.type,
      self.title,
      self.description,
      self.status,
      self.last_editor_cid,
      self.id,
    })
  end

  -- Persist people.
  if self.people and #self.people > 0 then
    for _, p in ipairs(self.people) do
      MySQL.insert.await([[
        INSERT INTO mdt_case_people (case_id, citizenid, role, note)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE note = VALUES(note)
      ]], { self.id, p.citizenid, p.role, p.note })
    end
  end

  -- Persist evidence queue (always INSERT)
  -- After inserting, we clear the queue to avoid duplicating on next Save().
  if self.evidences and #self.evidences > 0 then
    for _, e in ipairs(self.evidences) do
      -- Only queue items should be inserted here
      if e.type then
        MySQL.insert.await([[
          INSERT INTO mdt_evidences (case_id, type, description, file_path, added_by_cid)
          VALUES (?, ?, ?, ?, ?)
        ]], {
          self.id,
          e.type,
          e.description,
          e.file_path,
          self.last_editor_cid,
        })
      end
    end

    ---@type PoliceCaseEvidenceQueueItem[]
    self.evidences = {}
  end

  return self.id
end

---Load a case and its relations from DB.
---@param caseId number
---@return PoliceCase? caseObj
function PoliceCase.Load(caseId)
  local id = tonumber(caseId)
  if not id then return nil end

  ---@type PoliceCaseRow[]|nil
  local rows = MySQL.query.await('SELECT * FROM mdt_cases WHERE id = ? LIMIT 1', { id })
  if not rows or not rows[1] then return nil end

  local r = rows[1]

  ---@type PoliceCase
  local obj = PoliceCase:new(
    r.id,
    r.type,
    r.title,
    r.description,
    r.created_by_cid,
    r.status,
    r.created_at,
    r.updated_at,
    r.last_editor_cid
  )

  ---@type PoliceCasePerson[]|nil
  local people = MySQL.query.await('SELECT citizenid, role, note FROM mdt_case_people WHERE case_id = ?', { id })
  obj.people = people or {}

  ---@type PoliceCaseEvidenceRow[]|nil
  local evidences = MySQL.query.await([[
    SELECT id, type, description, file_path, created_at, added_by_cid
    FROM mdt_evidences
    WHERE case_id = ?
    ORDER BY id DESC
  ]], { id })
  obj.evidences = evidences or {}

  return obj
end

return PoliceCase
