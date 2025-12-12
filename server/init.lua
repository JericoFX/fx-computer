-- #JericoFX
--[[
TODO
* Get,Delete,Update,Ctrate different reports and stuff

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


local Reports = {
    police = {},
    medical = {},
    news = {}
}

--@param src number
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

lib.callback.register("fx-computer::server::generateNewPoliceReport",function(source,id, typeOfCase, title, description, createdByCid, status, createdAt, updatedAt, lastEditorCid) 
    if not HasModuleAccess(source,"police") then return end
    
end)