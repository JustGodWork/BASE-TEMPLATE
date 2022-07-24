local Jobs = {}
local Orga = {}
local RegisteredSocieties = {}

function GetSociety(name)
	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			return RegisteredSocieties[i]
		end
	end
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		local result = MySQL.query.await('SELECT * FROM jobs')
		local result2 = MySQL.query.await('SELECT * FROM organisations')

		for i = 1, #result, 1 do
			Jobs[result[i].name] = result[i]
			Jobs[result[i].name].grades = {}
		end

		for i = 1, #result2, 1 do
			Orga[result2[i].name] = result2[i]
			Orga[result2[i].name].grades = {}
		end

		local resultJobGrade = MySQL.query.await('SELECT * FROM job_grades')
		local resultOrgaGrade = MySQL.query.await('SELECT * FROM orga_grades')

		for i = 1, #resultJobGrade, 1 do
			Jobs[resultJobGrade[i].job_name].grades[tostring(resultJobGrade[i].grade)] = resultJobGrade[i]
		end

		for i = 1, #resultOrgaGrade, 1 do
			Orga[resultOrgaGrade[i].orga_name].grades[tostring(resultOrgaGrade[i].grade)] = resultOrgaGrade[i]
		end
	end
end)

function isPlayerInSociety(source, jobName)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer.job.name == jobName or xPlayer.orga.name == jobName then
		return true
	end
	return false
end

function IsPlayerBoss(source, jobName)
	local xPlayer = ESX.GetPlayerFromId(source)
	if (xPlayer.job.name == jobName and xPlayer.job.grade_name == "boss") 
	or (xPlayer.orga.name == jobName and xPlayer.orga.grade_name == "boss") 
	then
		return true
	end
	return false
end

AddEventHandler('esx_society:registerSociety', function(name, label, account, datastore, inventory, data)
	local found = false

	local society = {
		name = name,
		label = label,
		account = account,
		datastore = datastore,
		inventory = inventory,
		data = data
	}

	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			found, RegisteredSocieties[i] = true, society
			break
		end
	end

	if not found then
		table.insert(RegisteredSocieties, society)
	end
end)

AddEventHandler('esx_society:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('esx_society:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

ESX.RegisterServerCallback('esx_society:withdraw', function(source, cb, societyName, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	amount = ESX.Math.Round(tonumber(amount))

	if isPlayerInSociety(xPlayer.source, society.name) then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			if amount > 0 and account.money >= amount then
				account.removeMoney(amount)
				xPlayer.addMoney(amount)
				xPlayer.showNotification(_U('have_withdrawn', ESX.Math.GroupDigits(amount)))
				cb(true)
			else
				xPlayer.showNotification(_U('invalid_amount'))
				cb(false)
			end
		end)
	else
		print(('esx_society: %s attempted to call withdrawMoney!'):format(xPlayer.identifier))
	end
end)

RegisterServerEvent('esx_society:withdrawMoney')
AddEventHandler('esx_society:withdrawMoney', function(societyName, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	amount = ESX.Math.Round(tonumber(amount))

	if isPlayerInSociety(xPlayer.source, society.name) then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			if amount > 0 and account.money >= amount then
				account.removeMoney(amount)
				xPlayer.addMoney(amount)
				xPlayer.showNotification(_U('have_withdrawn', ESX.Math.GroupDigits(amount)))
			else
				xPlayer.showNotification(_U('invalid_amount'))
			end
		end)
	else
		print(('esx_society: %s attempted to call withdrawMoney!'):format(xPlayer.identifier))
	end
end)

ESX.RegisterServerCallback('esx_society:deposit', function(src, cb, societyName, amount)
	local xPlayer = ESX.GetPlayerFromId(src)
	local society = GetSociety(societyName)
	amount = ESX.Math.Round(tonumber(amount))

	if isPlayerInSociety(xPlayer.source, society.name) then
		if amount > 0 and xPlayer.getMoney() >= amount then
			TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
				xPlayer.removeMoney(amount)
				xPlayer.showNotification(_U('have_deposited', ESX.Math.GroupDigits(amount)))
				account.addMoney(amount)
			end)
			cb(true)
		else
			xPlayer.showNotification(_U('invalid_amount'))
			cb(false)
		end
	else
		print(('esx_society: %s attempted to call depositMoney!'):format(xPlayer.identifier))
	end
end)

RegisterServerEvent('esx_society:depositMoney')
AddEventHandler('esx_society:depositMoney', function(societyName, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	amount = ESX.Math.Round(tonumber(amount))

	if isPlayerInSociety(xPlayer.source, society.name) then
		if amount > 0 and xPlayer.getMoney() >= amount then
			TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
				xPlayer.removeMoney(amount)
				xPlayer.showNotification(_U('have_deposited', ESX.Math.GroupDigits(amount)))
				account.addMoney(amount)
			end)
		else
			xPlayer.showNotification(_U('invalid_amount'))
		end
	else
		print(('esx_society: %s attempted to call depositMoney!'):format(xPlayer.identifier))
	end
end)

RegisterServerEvent('esx_society:washMoney')
AddEventHandler('esx_society:washMoney', function(society, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local account = xPlayer.getAccount('black_money')
	amount = ESX.Math.Round(tonumber(amount))

	if isPlayerInSociety(xPlayer.source, society) then
		if amount and amount > 0 and account.money >= amount then
			xPlayer.removeAccountMoney('black_money', amount)

			MySQL.insert('INSERT INTO society_moneywash (identifier, society, amount) VALUES (?, ?, ?)', {xPlayer.identifier, society, amount},
			function(rowsChanged)
				xPlayer.showNotification(_U('you_have', ESX.Math.GroupDigits(amount)))
			end)
		else
			xPlayer.showNotification(_U('invalid_amount'))
		end
	else
		print(('esx_society: %s attempted to call washMoney!'):format(xPlayer.identifier))
	end
end)

RegisterServerEvent('esx_society:putVehicleInGarage')
AddEventHandler('esx_society:putVehicleInGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('esx_society:removeVehicleFromGarage')
AddEventHandler('esx_society:removeVehicleFromGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		for i=1, #garage, 1 do
			if garage[i].plate == vehicle.plate then
				table.remove(garage, i)
				break
			end
		end

		store.set('garage', garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:getSocietyMoney', function(src, cb, society)
    society = ("society_%s"):format(society)
    TriggerEvent('esx_addonaccount:getSharedAccount', society, function(account)
        local money = nil
        if account == nil then money = "ERROR"
        else money = account.money end
        cb(money)
    end)
end)

ESX.RegisterServerCallback('esx_society:getEmployees', function(source, cb, society)
	local employees = {}
	local boss = ESX.GetPlayerFromId(source)
	local xPlayers
	if boss.job.name == society then 
		xPlayers = ESX.GetExtendedPlayers('job', society)
		for _, xPlayer in pairs(xPlayers) do
			local name = xPlayer.name
			if Config.EnableESXIdentity and name == GetPlayerName(xPlayer.source) then
				name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
			end
			if xPlayer.getIdentifier() ~= boss.getIdentifier() then
				print(xPlayer.identifier)
				table.insert(employees, {
					name = name,
					identifier = xPlayer.identifier,
					job = {
						name = society,
						label = xPlayer.job.label,
						grade = xPlayer.job.grade,
						grade_name = xPlayer.job.grade_name,
						grade_label = xPlayer.job.grade_label
					}
				})
			end
		end
	elseif boss.orga.name == society then 
		xPlayers = ESX.GetExtendedPlayers('orga', society)
		for _, xPlayer in pairs(xPlayers) do

			local name = xPlayer.name
			if Config.EnableESXIdentity and name == GetPlayerName(xPlayer.source) then
				name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
			end
	
			if xPlayer.getIdentifier() ~= boss.getIdentifier() then
				table.insert(employees, {
					name = name,
					identifier = xPlayer.identifier,
					job = {
						name = society,
						label = xPlayer.orga.label,
						grade = xPlayer.orga.grade,
						grade_name = xPlayer.orga.grade_name,
						grade_label = xPlayer.orga.grade_label
					}
				})
			end
		end
	end
		
	local query
	if boss.job.name == society then 
		query = "SELECT identifier, job_grade FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"
	elseif boss.orga.name == society then
		query = "SELECT identifier, orga_grade FROM `users` WHERE `orga`= ? ORDER BY orga_grade DESC"
	end
	if Config.EnableESXIdentity then
		if boss.job.name == society then 
			query = "SELECT identifier, job_grade, firstname, lastname FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"
		elseif boss.orga.name == society then
			query = "SELECT identifier, orga_grade, firstname, lastname FROM `users` WHERE `orga`= ? ORDER BY orga_grade DESC"
		end
	end

	MySQL.query(query, {society},
	function(result)
		for k, row in pairs(result) do
			local alreadyInTable
			local identifier = row.identifier

			for k, v in pairs(employees) do
				if v.identifier == identifier then
					alreadyInTable = true
				end
			end

			if not alreadyInTable then
				local name = "Name not found." -- maybe this should be a locale instead ¯\_(ツ)_/¯

				if Config.EnableESXIdentity then
					name = row.firstname .. ' ' .. row.lastname 
				end
				
				if boss.job.name == society then 
					if row.identifier ~= boss.identifier then
						table.insert(employees, {
							name = name,
							identifier = identifier,
							job = {
								name = society,
								label = Jobs[society].label,
								grade = row.job_grade,
								grade_name = Jobs[society].grades[tostring(row.job_grade)].name,
								grade_label = Jobs[society].grades[tostring(row.job_grade)].label
							}
						})
					end
				elseif boss.orga.name == society then
					if row.identifier ~= boss.identifier then
						table.insert(employees, {
							name = name,
							identifier = identifier,
							job = {
								name = society,
								label = Orga[society].label,
								grade = row.orga_grade,
								grade_name = Orga[society].grades[tostring(row.orga_grade)].name,
								grade_label = Orga[society].grades[tostring(row.orga_grade)].label
							}
						})
					end
				end
			end
		end

		cb(employees)
	end)

end)

ESX.RegisterServerCallback('esx_society:getJob', function(source, cb, society)
	local job = json.decode(json.encode(Jobs[society]))
	local grades = {}

	for k,v in pairs(job.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	job.grades = grades

	cb(job)
end)

ESX.RegisterServerCallback('esx_society:getOrga', function(source, cb, society)
	local orga = json.decode(json.encode(Orga[society]))
	local grades = {}

	for k,v in pairs(orga.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	orga.grades = grades

	cb(orga)
end)

ESX.RegisterServerCallback('esx_society:setJob', function(source, cb, identifier, job, grade, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.job.grade_name == 'boss'

	if isBoss then
		local xTarget = ESX.GetPlayerFromIdentifier(identifier)

		if xTarget then
			if xTarget ~= xPlayer then
				xTarget.setJob(job, grade)

				if type == 'hire' then
					xTarget.showNotification(_U('you_have_been_hired', job))
				elseif type == 'promote' then
					xTarget.showNotification(_U('you_have_been_promoted'))
				elseif type == 'fire' then
					xTarget.showNotification(_U('you_have_been_fired', xTarget.getJob().label))
				elseif type == 'retro' then
					xTarget.showNotification("Vous avez était rétrograder", xTarget.getJob().label)
				end

				cb()
			else
				return
			end
		else
			MySQL.update('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {job, grade, identifier},
			function(rowsChanged)
				cb()
			end)
		end
	else
		print(('esx_society: %s attempted to setJob'):format(xPlayer.identifier))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_society:setOrga', function(source, cb, identifier, orga, grade, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.orga.grade_name == 'boss'

	if isBoss then
		local xTarget = ESX.GetPlayerFromIdentifier(identifier)

		if xTarget then
			if xTarget ~= xPlayer then
				xTarget.setOrga(orga, grade)

				if type == 'hire' then
					xTarget.showNotification(_U('you_have_been_hired', orga))
				elseif type == 'promote' then
					xTarget.showNotification(_U('you_have_been_promoted'))
				elseif type == 'fire' then
					xTarget.showNotification(_U('you_have_been_fired', xTarget.getOrga().label))
				end

				cb()
			else
				return
			end
		else
			MySQL.update('UPDATE users SET orga = ?, orga_grade = ? WHERE identifier = ?', {orga, grade, identifier},
			function(rowsChanged)
				cb()
			end)
		end
	else
		print(('esx_society: %s attempted to setOrga'):format(xPlayer.identifier))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_society:setJobSalary', function(source, cb, job, grade, salary)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == job and xPlayer.job.grade_name == 'boss' then
		if salary <= Config.MaxSalary then
			MySQL.update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', {salary, job, grade},
			function(rowsChanged)
				Jobs[job].grades[tostring(grade)].salary = salary

				local xPlayers = ESX.GetExtendedPlayers('job', job)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.job.grade == grade then
						xTarget.setJob(job, grade)
					end
				end

				cb()
			end)
		else
			print(('esx_society: %s attempted to setJobSalary over config limit!'):format(xPlayer.identifier))
			cb()
		end
	else
		print(('esx_society: %s attempted to setJobSalary'):format(xPlayer.identifier))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_society:setOrgaSalary', function(source, cb, orga, grade, salary)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.orga.name == orga and xPlayer.orga.grade_name == 'boss' then
		if salary <= Config.MaxSalary then
			MySQL.update('UPDATE orga_grades SET salary = ? WHERE orga_name = ? AND grade = ?', {salary, orga, grade},
			function(rowsChanged)
				Orga[orga].grades[tostring(grade)].salary = salary

				local xPlayers = ESX.GetExtendedPlayers('orga', orga)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.orga.grade == grade then
						xTarget.setOrga(orga, grade)
					end
				end

				cb()
			end)
		else
			print(('esx_society: %s attempted to setOrgaSalary over config limit!'):format(xPlayer.identifier))
			cb()
		end
	else
		print(('esx_society: %s attempted to setOrgaSalary'):format(xPlayer.identifier))
		cb()
	end
end)

local getOnlinePlayers, onlinePlayers = false, {}
ESX.RegisterServerCallback('esx_society:getOnlinePlayers', function(source, cb)
	local boss = ESX.GetPlayerFromId(source)
	if getOnlinePlayers == false and next(onlinePlayers) == nil then -- Prevent multiple xPlayer loops from running in quick succession
		getOnlinePlayers, onlinePlayers = true, {}
		
		local xPlayers = ESX.GetExtendedPlayers()
		for _, xPlayer in pairs(xPlayers) do
			if xPlayer.identifier ~= boss.identifier then
				table.insert(onlinePlayers, {
					source = xPlayer.source,
					identifier = xPlayer.identifier,
					name = xPlayer.name,
					job = xPlayer.job,
					orga = xPlayer.orga
				})
			end
		end
		cb(onlinePlayers)
		getOnlinePlayers = false
		Wait(1000) -- For the next second any extra requests will receive the cached list
		onlinePlayers = {}
		return
	end
	while getOnlinePlayers do Wait(0) end -- Wait for the xPlayer loop to finish
	cb(onlinePlayers)
end)

ESX.RegisterServerCallback('esx_society:getVehiclesInGarage', function(source, cb, societyName)
	local society = GetSociety(societyName)

	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		cb(garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:isBoss', function(source, cb, job)
	cb(isPlayerBoss(source, job))
end)

function WashMoneyCRON(d, h, m)
	MySQL.query('SELECT * FROM society_moneywash', function(result)
		for i=1, #result, 1 do
			local society = GetSociety(result[i].society)
			local xPlayer = ESX.GetPlayerFromIdentifier(result[i].identifier)

			-- add society money
			TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
				account.addMoney(result[i].amount)
			end)

			-- send notification if player is online
			if xPlayer then
				xPlayer.showNotification(_U('you_have_laundered', ESX.Math.GroupDigits(result[i].amount)))
			end

		end
		MySQL.update('DELETE FROM society_moneywash')
	end)
end

TriggerEvent('cron:runAt', 3, 0, WashMoneyCRON)
