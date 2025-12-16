local QBCore = exports['qb-core']:GetCoreObject()
local Config = lib.load("shared.init_client")
local PoliceClient = require "client.modules.police.init"
local MedicalClient = require "client.modules.medical.init"
local NewsClient = require "client.modules.news.init"

local playerCid = nil

local function refreshCid()
    local playerData = QBCore.Functions.GetPlayerData()
    playerCid = playerData and playerData.citizenid or nil
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshCid()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerCid = nil
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    refreshCid()
end)

if Config.DebugData then
    CreateThread(function() 
        refreshCid()
    end)
end

RegisterNetEvent('fxcomputer:client:accessResult', function(module, allowed)
    if not allowed then
        lib.notify({
            title = 'FX Computer',
            description = ('No tienes permisos para %s'):format(module or 'modulo'),
            type = 'error'
        })
    end
end)

PoliceClient.registerNui()
MedicalClient.registerNui()
NewsClient.registerNui()


