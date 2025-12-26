-- Config only on server #JericoFX

local Config = {}
Config.DebugLog = true --set to true to fill the console with a bunch of logs
Config.RequireOnDuty = true

Config.ModuleJobs = {
  medical = { ambulance = true, doctor = true },
  news    = { reporter = true, news = true },
  police  = { police = true, sheriff = true }, -- if someone add more....
}

Config.AllowNonOwnerEdits = {
  police = false,
  medical = false,
  news = false,
}

Config.Cooldowns = {
  saveMs = 1500,
  getMs = 800,
  accessCheckMs = 1000,
}

Config.Validation = {
  maxTitle = 120,
  maxSubtitle = 160,
  maxCategory = 80,
  maxSlug = 120,
  maxDescription = 2000,
  maxDiagnosis = 2000,
  maxTreatment = 2000,
  maxContentHtml = 20000,
  maxContentJson = 30000,
  maxUrl = 300,
  maxNote = 500,
  maxPersonRole = 20,
  maxEvidenceType = 20,
  maxLabTestType = 80,
  maxResultValue = 500,
  maxMediaLinks = 30,
  maxPeople = 30,
  maxEvidences = 40,
  maxLabs = 40,
}

return Config
