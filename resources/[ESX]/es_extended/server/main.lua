SetMapName('San Andreas')
SetGameType('MFA Concept Template')
	
local newPlayer = 'INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `group` = ?'
local loadPlayer = 'SELECT `accounts`, `job`, `job_grade`, `orga`, `orga_grade`, `group`, `position`, `inventory`, `skin`, `loadout`'

if Config.Multichar then
	newPlayer = newPlayer..', `firstname` = ?, `lastname` = ?, `dateofbirth` = ?, `sex` = ?, `height` = ?'
end

if Config.Multichar or Config.Identity then
	loadPlayer = loadPlayer..', `firstname`, `lastname`, `dateofbirth`, `sex`, `height`'
end

loadPlayer = loadPlayer..' FROM `users` WHERE identifier = ?'

if Config.Multichar then
	AddEventHandler('esx:onPlayerJoined', function(src, char, data)
		while not next(ESX.Jobs) and not next(ESX.Orga) do Wait(50) end

		if not ESX.Players[src] then
			local identifier = char..':'..ESX.GetIdentifier(src)
			if data then
				createESXPlayer(identifier, src, data)
			else
				loadESXPlayer(identifier, src, false)
			end
		end
	end)
else
	RegisterNetEvent('esx:onPlayerJoined')
	AddEventHandler('esx:onPlayerJoined', function()
		while not next(ESX.Jobs) and not next(ESX.Orga) do Wait(50) end

		if not ESX.Players[source] then
			onPlayerJoined(source)
		end
	end)
end

function onPlayerJoined(playerId)
	local identifier = ESX.GetIdentifier(playerId)
	if identifier then
		if ESX.GetPlayerFromIdentifier(identifier) then
			DropPlayer(playerId, ('Une erreur est survenue pendant le chargement de votre personnage!\nCode erreur: identifier-active-ingame\n\nCette erreur est causé par un joueur actif sur le serveur avec le même steam ID que vous.\n\nVotre steam ID: %s'):format(identifier))
		else
			local result = MySQL.scalar.await('SELECT 1 FROM users WHERE identifier = ?', { identifier })
			if result then
				loadESXPlayer(identifier, playerId, false)
			else
				createESXPlayer(identifier, playerId)
			end
		end
	else
		DropPlayer(playerId, 'Une erreur est survenue pendant le chargement de votre personnage!\nCode erreur: identifier-missing-ingame\n\nVeuillez démarrer votre steam avant de lancer le jeu.')
	end
end

function createESXPlayer(identifier, playerId, data)
	local accounts = {}

	for account,money in pairs(Config.StartingAccountMoney) do
		accounts[account] = money
	end

	if Core.IsPlayerAdmin(playerId) then
		print(('^2[INFO] ^0 Le joueur ^5%s ^0a reçu les permissions Administrateur via ^5[server.cfg].^7'):format(playerId))
		defaultGroup = "admin"
	else
		defaultGroup = "user"
	end

	if not Config.Multichar then
		MySQL.prepare(newPlayer, { json.encode(accounts), identifier, defaultGroup }, function()
			loadESXPlayer(identifier, playerId, true)
		end)
	else
		MySQL.prepare(newPlayer, {
			json.encode(accounts),
			identifier,
			defaultGroup,
			data.firstname,
			data.lastname,
			data.dateofbirth,
			data.sex,
			data.height
		}, function()
			loadESXPlayer(identifier, playerId, true)
		end)
	end
end

if not Config.Multichar then
	AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
		deferrals.defer()
		local playerId = source
		local identifier = ESX.GetIdentifier(playerId)

		if identifier then
			if ESX.GetPlayerFromIdentifier(identifier) then
				deferrals.done(('Une erreur est survenue pendant le chargement de votre personnage!\nCode erreur: identifier-active-ingame\n\nCette erreur est causé par un joueur actif sur le serveur avec le même steam ID que vous.\n\nVotre steam ID: %s'):format(identifier))
			else
				deferrals.done()
			end
		else
			deferrals.done('Une erreur est survenue pendant le chargement de votre personnage!\nCode erreur: identifier-missing-ingame\n\nVeuillez démarrer votre steam avant de lancer le jeu.')
		end
	end)
end

function loadESXPlayer(identifier, playerId, isNew)
	local userData = {
		accounts = {},
		inventory = {},
		job = {},
		orga = {},
		loadout = {},
		playerName = GetPlayerName(playerId),
		weight = 0
	}

	local result = MySQL.prepare.await(loadPlayer, { identifier })
	local job, jobGrade, jobObject, jobGradeObject = result.job, tostring(result.job_grade)
	local orga, orgaGrade, orgaObject, orgaGradeObject = result.orga, tostring(result.orga_grade)
	local foundAccounts, foundItems = {}, {}

	-- Accounts
	if result.accounts and result.accounts ~= '' then
		local accounts = json.decode(result.accounts)

		for account,money in pairs(accounts) do
			foundAccounts[account] = money
		end
	end

	for account,label in pairs(Config.Accounts) do
		table.insert(userData.accounts, {
			name = account,
			money = foundAccounts[account] or Config.StartingAccountMoney[account] or 0,
			label = label
		})
	end

	-- Job
	if ESX.DoesJobExist(job, jobGrade) then
		jobObject, jobGradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[jobGrade]
	else
		print(('[^3WARNING^7] Job invalide pour %s [job: %s, grade: %s]'):format(identifier, job, jobGrade))
		job, jobGrade = 'nojob', '0'
		jobObject, jobGradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[jobGrade]
	end

	if ESX.DoesOrgaExist(orga, orgaGrade) then
		orgaObject, orgaGradeObject = ESX.Orga[orga], ESX.Orga[orga].grades[orgaGrade]
	else
		print(('[^3WARNING^7] Orga invalide pour %s [orga: %s, grade: %s]'):format(identifier, orga, orgaGrade))
		orga, orgaGrade = 'noorga', '0'
		orgaObject, orgaGradeObject = ESX.Orga[orga], ESX.Orga[orga].grades[orgaGrade]
	end

	userData.job.id = jobObject.id
	userData.orga.id = orgaObject.id
	userData.job.name = jobObject.name
	userData.orga.name = orgaObject.name
	userData.job.label = jobObject.label
	userData.orga.label = orgaObject.label

	userData.job.grade = tonumber(jobGrade)
	userData.orga.grade = tonumber(orgaGrade)
	userData.job.grade_name = jobGradeObject.name
	userData.orga.grade_name = orgaGradeObject.name
	userData.job.grade_label = jobGradeObject.label
	userData.orga.grade_label = orgaGradeObject.label
	userData.job.grade_salary = jobGradeObject.salary
	userData.orga.grade_salary = orgaGradeObject.salary

	userData.job.skin_male = {}
	userData.orga.skin_male = {}
	userData.job.skin_female = {}
	userData.orga.skin_female = {}

	if jobGradeObject.skin_male then userData.job.skin_male = json.decode(jobGradeObject.skin_male) end
	if orgaGradeObject.skin_male then userData.orga.skin_male = json.decode(orgaGradeObject.skin_male) end
	if jobGradeObject.skin_female then userData.job.skin_female = json.decode(jobGradeObject.skin_female) end
	if orgaGradeObject.skin_female then userData.orga.skin_female = json.decode(orgaGradeObject.skin_female) end

	-- Inventory
	if not Config.OxInventory then
		if result.inventory and result.inventory ~= '' then
			local inventory = json.decode(result.inventory)

			for name,count in pairs(inventory) do
				local item = ESX.Items[name]

				if item then
					foundItems[name] = count
				else
					print(('[^3WARNING^7] Item invalide: "%s" pour "%s"'):format(name, identifier))
				end
			end
		end

		for name,item in pairs(ESX.Items) do
			local count = foundItems[name] or 0
			if count > 0 then userData.weight = userData.weight + (item.weight * count) end

			table.insert(userData.inventory, {
				name = name,
				count = count,
				label = item.label,
				weight = item.weight,
				usable = Core.UsableItemsCallbacks[name] ~= nil,
				rare = item.rare,
				canRemove = item.canRemove
			})
		end

		table.sort(userData.inventory, function(a, b)
			return a.label < b.label
		end)
	else
		if result.inventory and result.inventory ~= '' then
			userData.inventory = json.decode(result.inventory)
		else
			userData.inventory = {}
		end
	end

	-- Group
	if result.group then
		if result.group == "superadmin" then
			userData.group = "admin"
		else
			userData.group = result.group
		end
	else
		userData.group = 'user'
	end

	-- Loadout
	if not Config.OxInventory then
		if result.loadout and result.loadout ~= '' then
			local loadout = json.decode(result.loadout)

			for name,weapon in pairs(loadout) do
				local label = ESX.GetWeaponLabel(name)

				if label then
					if not weapon.components then weapon.components = {} end
					if not weapon.tintIndex then weapon.tintIndex = 0 end

					table.insert(userData.loadout, {
						name = name,
						ammo = weapon.ammo,
						label = label,
						components = weapon.components,
						tintIndex = weapon.tintIndex
					})
				end
			end
		end
	end

	-- Position
	if result.position and result.position ~= '' then
		userData.coords = json.decode(result.position)
	else
		print('[^3WARNING^7] La ligne ^5"position"^0 dans la table ^5"users"^0 est manquante. Les données par défault sont utilisé, Vérifier votre base de données.')
		userData.coords = {x = -269.4, y = -955.3, z = 31.2, heading = 205.8}
	end

	-- Skin
	if result.skin and result.skin ~= '' then
		userData.skin = json.decode(result.skin)
	else
		if userData.sex == 'f' then userData.skin = {sex=1} else userData.skin = {sex=0} end
	end

	-- Identity
	if result.firstname and result.firstname ~= '' then
		userData.firstname = result.firstname
		userData.lastname = result.lastname
		userData.playerName = userData.firstname..' '..userData.lastname
		if result.dateofbirth then userData.dateofbirth = result.dateofbirth end
		if result.sex then userData.sex = result.sex end
		if result.height then userData.height = result.height end
	end

	local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.group, userData.accounts, userData.inventory, userData.weight, userData.job, userData.orga, userData.loadout, userData.playerName, userData.coords)
	ESX.Players[playerId] = xPlayer

	if userData.firstname then 
		xPlayer.set('firstName', userData.firstname)
		xPlayer.set('lastName', userData.lastname)
		if userData.dateofbirth then xPlayer.set('dateofbirth', userData.dateofbirth) end
		if userData.sex then xPlayer.set('sex', userData.sex) end
		if userData.height then xPlayer.set('height', userData.height) end
	end

	TriggerEvent('esx:playerLoaded', playerId, xPlayer, isNew)

	xPlayer.triggerEvent('esx:playerLoaded', {
		accounts = xPlayer.getAccounts(),
		coords = xPlayer.getCoords(),
		identifier = xPlayer.getIdentifier(),
		inventory = xPlayer.getInventory(),
		job = xPlayer.getJob(),
		orga = xPlayer.getOrga(),
		loadout = xPlayer.getLoadout(),
		maxWeight = xPlayer.getMaxWeight(),
		money = xPlayer.getMoney(),
		dead = false
	}, isNew, userData.skin)

	if not Config.OxInventory then
		xPlayer.triggerEvent('esx:createMissingPickups', Core.Pickups)
	else
		exports.ox_inventory:setPlayerInventory(xPlayer, userData.inventory)
	end

	xPlayer.triggerEvent('esx:registerSuggestions', Core.RegisteredCommands)
	print(('[^2INFO^0] Le joueur ^5"%s" ^0se connecte au serveur. ID: ^5%s^7'):format(xPlayer.getName(), playerId))
end

AddEventHandler('chatMessage', function(playerId, author, message)
	local xPlayer = ESX.GetPlayerFromId(playerId)
	if message:sub(1, 1) == '/' and playerId > 0 then
		CancelEvent()
		local commandName = message:sub(1):gmatch("%w+")()
		xPlayer.showNotification(_U('commanderror_invalidcommand', commandName))
	end
end)

AddEventHandler('playerDropped', function(reason)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer then
		TriggerEvent('esx:playerDropped', playerId, reason)

		Core.SavePlayer(xPlayer, function()
			ESX.Players[playerId] = nil
		end)
	end
end)

if Config.Multichar then
	AddEventHandler('esx:playerLogout', function(playerId)
		local xPlayer = ESX.GetPlayerFromId(playerId)
		if xPlayer then
			TriggerEvent('esx:playerDropped', playerId)

			Core.SavePlayer(xPlayer, function()
				ESX.Players[playerId] = nil
			end)
		end
		TriggerClientEvent("esx:onPlayerLogout", playerId)
	end)
end

RegisterNetEvent('esx:updateCoords')
AddEventHandler('esx:updateCoords', function(coords)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateCoords(coords)
	end
end)

if not Config.OxInventory then
	RegisterNetEvent('esx:updateWeaponAmmo')
	AddEventHandler('esx:updateWeaponAmmo', function(weaponName, ammoCount)
		local xPlayer = ESX.GetPlayerFromId(source)

		if xPlayer then
			xPlayer.updateWeaponAmmo(weaponName, ammoCount)
		end
	end)

	RegisterNetEvent('esx:giveInventoryItem')
	AddEventHandler('esx:giveInventoryItem', function(target, type, itemName, itemCount)
		local playerId = source
		local sourceXPlayer = ESX.GetPlayerFromId(playerId)
		local targetXPlayer = ESX.GetPlayerFromId(target)

		if type == 'item_standard' then
			local sourceItem = sourceXPlayer.getInventoryItem(itemName)

			if itemCount > 0 and sourceItem.count >= itemCount then
				if targetXPlayer.canCarryItem(itemName, itemCount) then
					sourceXPlayer.removeInventoryItem(itemName, itemCount)
					targetXPlayer.addInventoryItem   (itemName, itemCount)

					sourceXPlayer.showNotification(_U('gave_item', itemCount, sourceItem.label, targetXPlayer.name))
					targetXPlayer.showNotification(_U('received_item', itemCount, sourceItem.label, sourceXPlayer.name))
				else
					sourceXPlayer.showNotification(_U('ex_inv_lim', targetXPlayer.name))
				end
			else
				sourceXPlayer.showNotification(_U('imp_invalid_quantity'))
			end
		elseif type == 'item_account' then
			if itemCount > 0 and sourceXPlayer.getAccount(itemName).money >= itemCount then
				sourceXPlayer.removeAccountMoney(itemName, itemCount)
				targetXPlayer.addAccountMoney   (itemName, itemCount)

				sourceXPlayer.showNotification(_U('gave_account_money', ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName], targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_account_money', ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName], sourceXPlayer.name))
			else
				sourceXPlayer.showNotification(_U('imp_invalid_amount'))
			end
		elseif type == 'item_weapon' then
			if sourceXPlayer.hasWeapon(itemName) then
				local weaponLabel = ESX.GetWeaponLabel(itemName)

				if not targetXPlayer.hasWeapon(itemName) then
					local _, weapon = sourceXPlayer.getWeapon(itemName)
					local _, weaponObject = ESX.GetWeapon(itemName)
					itemCount = weapon.ammo

					sourceXPlayer.removeWeapon(itemName)
					targetXPlayer.addWeapon(itemName, itemCount)

					if weaponObject.ammo and itemCount > 0 then
						local ammoLabel = weaponObject.ammo.label
						sourceXPlayer.showNotification(_U('gave_weapon_withammo', weaponLabel, itemCount, ammoLabel, targetXPlayer.name))
						targetXPlayer.showNotification(_U('received_weapon_withammo', weaponLabel, itemCount, ammoLabel, sourceXPlayer.name))
					else
						sourceXPlayer.showNotification(_U('gave_weapon', weaponLabel, targetXPlayer.name))
						targetXPlayer.showNotification(_U('received_weapon', weaponLabel, sourceXPlayer.name))
					end
				else
					sourceXPlayer.showNotification(_U('gave_weapon_hasalready', targetXPlayer.name, weaponLabel))
					targetXPlayer.showNotification(_U('received_weapon_hasalready', sourceXPlayer.name, weaponLabel))
				end
			end
		elseif type == 'item_ammo' then
			if sourceXPlayer.hasWeapon(itemName) then
				local weaponNum, weapon = sourceXPlayer.getWeapon(itemName)

				if targetXPlayer.hasWeapon(itemName) then
					local _, weaponObject = ESX.GetWeapon(itemName)

					if weaponObject.ammo then
						local ammoLabel = weaponObject.ammo.label

						if weapon.ammo >= itemCount then
							sourceXPlayer.removeWeaponAmmo(itemName, itemCount)
							targetXPlayer.addWeaponAmmo(itemName, itemCount)

							sourceXPlayer.showNotification(_U('gave_weapon_ammo', itemCount, ammoLabel, weapon.label, targetXPlayer.name))
							targetXPlayer.showNotification(_U('received_weapon_ammo', itemCount, ammoLabel, weapon.label, sourceXPlayer.name))
						end
					end
				else
					sourceXPlayer.showNotification(_U('gave_weapon_noweapon', targetXPlayer.name))
					targetXPlayer.showNotification(_U('received_weapon_noweapon', sourceXPlayer.name, weapon.label))
				end
			end
		end
	end)

	RegisterNetEvent('esx:removeInventoryItem')
	AddEventHandler('esx:removeInventoryItem', function(type, itemName, itemCount)
		local playerId = source
		local xPlayer = ESX.GetPlayerFromId(source)

		if type == 'item_standard' then
			if itemCount == nil or itemCount < 1 then
				xPlayer.showNotification(_U('imp_invalid_quantity'))
			else
				local xItem = xPlayer.getInventoryItem(itemName)

				if (itemCount > xItem.count or xItem.count < 1) then
					xPlayer.showNotification(_U('imp_invalid_quantity'))
				else
					xPlayer.removeInventoryItem(itemName, itemCount)
					local pickupLabel = ('~y~%s~s~ [~b~%s~s~]'):format(xItem.label, itemCount)
					ESX.CreatePickup('item_standard', itemName, itemCount, pickupLabel, playerId)
					xPlayer.showNotification(_U('threw_standard', itemCount, xItem.label))
				end
			end
		elseif type == 'item_account' then
			if itemCount == nil or itemCount < 1 then
				xPlayer.showNotification(_U('imp_invalid_amount'))
			else
				local account = xPlayer.getAccount(itemName)

				if (itemCount > account.money or account.money < 1) then
					xPlayer.showNotification(_U('imp_invalid_amount'))
				else
					xPlayer.removeAccountMoney(itemName, itemCount)
					local pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(account.label, _U('locale_currency', ESX.Math.GroupDigits(itemCount)))
					ESX.CreatePickup('item_account', itemName, itemCount, pickupLabel, playerId)
					xPlayer.showNotification(_U('threw_account', ESX.Math.GroupDigits(itemCount), string.lower(account.label)))
				end
			end
		elseif type == 'item_weapon' then
			itemName = string.upper(itemName)

			if xPlayer.hasWeapon(itemName) then
				local _, weapon = xPlayer.getWeapon(itemName)
				local _, weaponObject = ESX.GetWeapon(itemName)
				local components, pickupLabel = ESX.Table.Clone(weapon.components)
				xPlayer.removeWeapon(itemName)

				if weaponObject.ammo and weapon.ammo > 0 then
					local ammoLabel = weaponObject.ammo.label
					pickupLabel = ('~y~%s~s~ [~g~%s~s~ %s]'):format(weapon.label, weapon.ammo, ammoLabel)
					xPlayer.showNotification(_U('threw_weapon_ammo', weapon.label, weapon.ammo, ammoLabel))
				else
					pickupLabel = ('~y~%s~s~'):format(weapon.label)
					xPlayer.showNotification(_U('threw_weapon', weapon.label))
				end

				ESX.CreatePickup('item_weapon', itemName, weapon.ammo, pickupLabel, playerId, components, weapon.tintIndex)
			end
		end
	end)


	RegisterNetEvent('esx:useItem')
	AddEventHandler('esx:useItem', function(itemName)
		local xPlayer = ESX.GetPlayerFromId(source)
		local count = xPlayer.getInventoryItem(itemName).count

		if count > 0 then
			ESX.UseItem(source, itemName)
		else
			xPlayer.showNotification(_U('act_imp'))
		end
	end)

	RegisterNetEvent('esx:onPickup')
	AddEventHandler('esx:onPickup', function(pickupId)
		local pickup, xPlayer, success = Core.Pickups[pickupId], ESX.GetPlayerFromId(source)

		if pickup then
			if pickup.type == 'item_standard' then
				if xPlayer.canCarryItem(pickup.name, pickup.count) then
					xPlayer.addInventoryItem(pickup.name, pickup.count)
					success = true
				else
					xPlayer.showNotification(_U('threw_cannot_pickup'))
				end
			elseif pickup.type == 'item_account' then
				success = true
				xPlayer.addAccountMoney(pickup.name, pickup.count)
			elseif pickup.type == 'item_weapon' then
				if xPlayer.hasWeapon(pickup.name) then
					xPlayer.showNotification(_U('threw_weapon_already'))
				else
					success = true
					xPlayer.addWeapon(pickup.name, pickup.count)
					xPlayer.setWeaponTint(pickup.name, pickup.tintIndex)

					for k,v in ipairs(pickup.components) do
						xPlayer.addWeaponComponent(pickup.name, v)
					end
				end
			end

			if success then
				Core.Pickups[pickupId] = nil
				TriggerClientEvent('esx:removePickup', -1, pickupId)
			end
		end
	end)
end

ESX.RegisterServerCallback('esx:getPlayerData', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		orga         = xPlayer.getOrga(),
		loadout      = xPlayer.getLoadout(),
		money        = xPlayer.getMoney()
	})
end)

ESX.RegisterServerCallback('esx:isUserAdmin', function(source, cb)
	cb(Core.IsPlayerAdmin(source))
end)

ESX.RegisterServerCallback('esx:getOtherPlayerData', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		orga          = xPlayer.getOrga(),
		loadout      = xPlayer.getLoadout(),
		money        = xPlayer.getMoney()
	})
end)

ESX.RegisterServerCallback('esx:getPlayerNames', function(source, cb, players)
	players[source] = nil

	for playerId,v in pairs(players) do
		local xPlayer = ESX.GetPlayerFromId(playerId)

		if xPlayer then
			players[playerId] = xPlayer.getName()
		else
			players[playerId] = nil
		end
	end

	cb(players)
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
	if eventData.secondsRemaining == 60 then
		CreateThread(function()
			Wait(50000)
			Core.SavePlayers()
		end)
	end
end)
