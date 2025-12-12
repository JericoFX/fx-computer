-- #JERICOFX
---@alias MedicalStatus "open"|"treated"|"transferred"|"closed"

---@class LabQueueItem
---@field test_type string
---@field result_value? string
---@field notes? string
---@field created_by_cid string

---@class LabResultRow
---@field id number
---@field incident_id number
---@field test_type string
---@field result_value? string
---@field notes? string
---@field created_at string
---@field created_by_cid string

---@class MedicalIncidentRow
---@field id number
---@field patient_cid string
---@field doctor_cid string
---@field created_at string
---@field diagnosis? string
---@field treatment? string
---@field status MedicalStatus

---@class MedicalIncident
---@field id? number
---@field patient_cid string
---@field doctor_cid string
---@field created_at? string
---@field diagnosis? string
---@field treatment? string
---@field status MedicalStatus
---@field lab_queue LabQueueItem[]
---@field lab_results LabResultRow[]   -- loaded (optional)
local MedicalIncident = lib.class('MedicalIncident')

---@type table<MedicalStatus, boolean>
local VALID_MED_STATUS = {
  open = true,
  treated = true,
  transferred = true,
  closed = true,
}

---@private
---@param cond boolean
---@param msg string
local function assertOrError(cond, msg)
  if not cond then error(msg, 3) end
end

---@private
---@param s any
---@return boolean
local function isNonEmptyString(s)
  return type(s) == 'string' and #s > 0
end

---Create a new MedicalIncident instance.
---Constructor args map 1:1 to DB columns in ems_incidents.
---@param id? number
---@param patientCid string
---@param doctorCid string
---@param diagnosis? string
---@param treatment? string
---@param status? MedicalStatus
---@param createdAt? string
function MedicalIncident:constructor(id, patientCid, doctorCid, diagnosis, treatment, status, createdAt)
  assertOrError(isNonEmptyString(patientCid), 'MedicalIncident: "patientCid" is required')
  assertOrError(isNonEmptyString(doctorCid), 'MedicalIncident: "doctorCid" is required')

  status = status or 'open'
  assertOrError(VALID_MED_STATUS[status] == true, ('MedicalIncident: invalid "status": %s'):format(tostring(status)))

  self.id = id and tonumber(id) or nil
  self.patient_cid = patientCid
  self.doctor_cid = doctorCid
  self.diagnosis = diagnosis
  self.treatment = treatment
  self.status = status
  self.created_at = createdAt

  self.lab_queue = {}
  self.lab_results = {}
end

---Set diagnosis and treatment fields.
---@param diagnosis? string
---@param treatment? string
---@return MedicalIncident
function MedicalIncident:SetClinical(diagnosis, treatment)
  self.diagnosis = diagnosis
  self.treatment = treatment
  return self
end

---Update status.
---@param status MedicalStatus
---@return MedicalIncident
function MedicalIncident:SetStatus(status)
  assertOrError(VALID_MED_STATUS[status] == true, ('SetStatus: invalid status: %s'):format(tostring(status)))
  self.status = status
  return self
end

---Queue a lab result to be inserted on Save().
---@param testType string
---@param createdByCid string
---@param resultValue? string
---@param notes? string
---@return MedicalIncident
function MedicalIncident:AddLabResult(testType, createdByCid, resultValue, notes)
  assertOrError(isNonEmptyString(testType), 'AddLabResult: "testType" is required')
  assertOrError(isNonEmptyString(createdByCid), 'AddLabResult: "createdByCid" is required')

  ---@type LabQueueItem
  local item = {
    test_type = testType,
    result_value = resultValue,
    notes = notes,
    created_by_cid = createdByCid,
  }

  local n = #self.lab_queue
  self.lab_queue[n + 1] = item
  return self
end

---Insert or update incident; persist queued lab results.
---@return number incidentId
function MedicalIncident:Save()
  if not self.id then
    local insertId = MySQL.insert.await([[
      INSERT INTO ems_incidents (patient_cid, doctor_cid, diagnosis, treatment, status)
      VALUES (?, ?, ?, ?, ?)
    ]], {
      self.patient_cid,
      self.doctor_cid,
      self.diagnosis,
      self.treatment,
      self.status,
    })

    self.id = insertId
  else
    MySQL.update.await([[
      UPDATE ems_incidents
      SET patient_cid = ?, doctor_cid = ?, diagnosis = ?, treatment = ?, status = ?
      WHERE id = ?
    ]], {
      self.patient_cid,
      self.doctor_cid,
      self.diagnosis,
      self.treatment,
      self.status,
      self.id,
    })
  end

  -- Persist lab queue (always INSERT)
  if self.lab_queue and #self.lab_queue > 0 then
    for i = 1, #self.lab_queue do
      local l = self.lab_queue[i]
      if l then
        MySQL.insert.await([[
          INSERT INTO ems_lab_results (incident_id, test_type, result_value, notes, created_by_cid)
          VALUES (?, ?, ?, ?, ?)
        ]], {
          self.id,
          l.test_type,
          l.result_value,
          l.notes,
          l.created_by_cid,
        })
      end
    end

    ---@type LabQueueItem[]
    self.lab_queue = {}
  end

  return self.id
end

---Load incident by id; optionally include lab results.
---@param incidentId number
---@param includeLabs? boolean
---@return MedicalIncident? incident
function MedicalIncident.Load(incidentId, includeLabs)
  local id = tonumber(incidentId)
  if not id then return nil end

  ---@type MedicalIncidentRow[]|nil
  local rows = MySQL.query.await('SELECT * FROM ems_incidents WHERE id = ? LIMIT 1', { id })
  if not rows or not rows[1] then return nil end

  local r = rows[1]

  ---@type MedicalIncident
  local obj = MedicalIncident:new(
    r.id,
    r.patient_cid,
    r.doctor_cid,
    r.diagnosis,
    r.treatment,
    r.status,
    r.created_at
  )

  if includeLabs == true then
    ---@type LabResultRow[]|nil
    local labs = MySQL.query.await([[
      SELECT id, incident_id, test_type, result_value, notes, created_at, created_by_cid
      FROM ems_lab_results
      WHERE incident_id = ?
      ORDER BY id DESC
    ]], { id })

    obj.lab_results = labs or {}
  end

  return obj
end

return MedicalIncident
