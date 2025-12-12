-- Config only on server #JericoFX

local Config = {}
Config.DebugLog = true --set to true to fill the console with a bunch of logs

Config.ModuleJobs = {
  medical = { ambulance = true, doctor = true },
  news    = { reporter = true, news = true },
  police  = { police = true, sheriff = true }, -- if someone add more....
}

return Config