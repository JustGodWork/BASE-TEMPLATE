ESX = {}
ESX.Players = {}
ESX.Jobs = {}
ESX.Orga = {}
ESX.Items = {}
Core = {}
Core.UsableItemsCallbacks = {}
Core.ServerCallbacks = {}
Core.TimeoutCount = -1
Core.CancelledTimeouts = {}
Core.RegisteredCommands = {}
Core.Pickups = {}
Core.PickupId = 0

AddEventHandler('esx:getSharedObject', function(cb)
	cb(ESX)
end)

exports('getSharedObject', function()
	return ESX
end)

if GetResourceState('ox_inventory') ~= 'missing' then
	Config.OxInventory = true
	SetConvarReplicated('inventory:framework', 'esx')
	SetConvarReplicated('inventory:weight', Config.MaxWeight * 1000)
end

local function StartDBSync()
	CreateThread(function()
		while true do
			Wait(10 * 60 * 1000)
			Core.SavePlayers()
		end
	end)
end

MySQL.ready(function()
	if not Config.OxInventory then
		local items = MySQL.query.await('SELECT * FROM items')
		for k, v in ipairs(items) do
			ESX.Items[v.name] = {
				label = v.label,
				weight = v.weight,
				rare = v.rare,
				canRemove = v.can_remove
			}
		end
	else
		TriggerEvent('__cfx_export_ox_inventory_Items', function(ref)
			if ref then
				ESX.Items = ref()
			end
		end)

		AddEventHandler('ox_inventory:itemList', function(items)
			ESX.Items = items
		end)

		while not next(ESX.Items) do Wait(0) end
	end

	local Jobs = {}
	local jobs = MySQL.query.await('SELECT * FROM jobs')

	for _, v in ipairs(jobs) do
		Jobs[v.name] = v
		Jobs[v.name].grades = {}
	end

	local jobGrades = MySQL.query.await('SELECT * FROM job_grades')

	for _, v in ipairs(jobGrades) do
		if Jobs[v.job_name] then
			Jobs[v.job_name].grades[tostring(v.grade)] = v
		end
	end

	for _, v in pairs(Jobs) do
		if ESX.Table.SizeOf(v.grades) == 0 then
			Jobs[v.name] = nil
		end
	end

	if not Jobs then
		-- Fallback data, if no jobs exist
		ESX.Jobs['nojob'] = {
			label = 'Sans-Emploi',
			grades = {
				['0'] = {
					grade = 0,
					label = '',
					salary = 200,
					skin_male = {},
					skin_female = {}
				}
			}
		}
	else
		ESX.Jobs = Jobs
	end

	local Orga = {}
	local orga = MySQL.query.await('SELECT * FROM organisations')

	for _, v in ipairs(orga) do
		Orga[v.name] = v
		Orga[v.name].grades = {}
	end

	local orgaGrades = MySQL.query.await('SELECT * FROM orga_grades')

	for _, v in ipairs(orgaGrades) do
		if Orga[v.orga_name] then
			Orga[v.orga_name].grades[tostring(v.grade)] = v
		end
	end

	for _, v in pairs(Orga) do
		if ESX.Table.SizeOf(v.grades) == 0 then
			Orga[v.name] = nil
		end
	end

	if not Orga then
		-- Fallback data, if no jobs exist
		ESX.Orga['noorga'] = {
			label = 'Aucune organisation',
			grades = {
				['0'] = {
					grade = 0,
					label = '',
					salary = 200,
					skin_male = {},
					skin_female = {}
				}
			}
		}
	else
		ESX.Orga = Orga
	end

	print('[^2INFO^7] [^1OVER - JUSTGOD#4717^7] ESX ^5Legacy^0 initialized')
	StartDBSync()
	StartPayCheck()
end)

RegisterServerEvent('esx:clientLog')
AddEventHandler('esx:clientLog', function(msg)
	if Config.EnableDebug then
		print(('[^2TRACE^7] %s^7'):format(msg))
	end
end)

RegisterServerEvent('esx:triggerServerCallback')
AddEventHandler('esx:triggerServerCallback', function(name, requestId, ...)
	local playerId = source

	ESX.TriggerServerCallback(name, requestId, playerId, function(...)
		TriggerClientEvent('esx:serverCallback', playerId, requestId, ...)
	end, ...)
end)

RegisterServerEvent('esx:savePlayer')
AddEventHandler('esx:savePlayer', function(xPlayerSource)
	local src = xPlayerSource
	local xPlayer = ESX.GetPlayerFromId(src)

	if xPlayer then
		Core.SavePlayer(xPlayer)
	end
end)
