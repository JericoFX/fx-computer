local Config = lib.load("shared.init_client")
local PoliceClient = require "client.modules.police.init"
local MedicalClient = require "client.modules.medical.init"
local NewsClient = require "client.modules.news.init"

local playerCid = nil

local function setCid(cid)
    playerCid = cid
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('fxcomputer:server:refreshPlayerCid')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    setCid(nil)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    TriggerServerEvent('fxcomputer:server:refreshPlayerCid')
end)

RegisterNetEvent('fxcomputer:client:updateCid', function(cid)
    setCid(cid)
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
