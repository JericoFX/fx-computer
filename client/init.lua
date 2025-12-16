local Config = lib.load("shared.init_client")
local QBCore = exports['qb-core']:GetCoreObject()
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

CreateThread(function()
    refreshCid()
end)

RegisterNetEvent('fxcomputer:client:accessResult', function(module, allowed)
    if not allowed then
        lib.notify({
            title = 'FX Computer',
            description = ('No tienes permisos para %s'):format(module or 'modulo'),
            type = 'error'
        })
    end
end)

PoliceClient.registerNui(playerCid)
MedicalClient.registerNui(playerCid)
NewsClient.registerNui(playerCid)
