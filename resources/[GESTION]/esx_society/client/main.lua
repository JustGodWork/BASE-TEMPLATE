local employees = {}
local onlinePlayers = {}
local society = {}
local money = 0

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx:setOrga')
AddEventHandler('esx:setOrga', function(orga)
	ESX.PlayerData.orga = orga
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	ESX.PlayerData = xPlayer
	ESX.PlayerLoaded = true
end)

MFAClient.CreateMenu('Menu Principal', 'GESTION ENTREPRISE', 'INTERACTION')
MFAClient.CreateSubMenu('employesManagement', 'Menu Principal','GESTION DES EMPLOYES', 'INTERACTION')
MFAClient.CreateSubMenu('employesSalary', 'Menu Principal','GESTION DES SALAIRES', 'INTERACTION')
MFAClient.CreateSubMenu('employesRecruit', 'Menu Principal','RECRUTER', 'INTERACTION')

menuPrincipal = function(societyName)
	MFAClient.IsVisible('Menu Principal', true, true, function()
		RageUI.SeparatorMini()
		RageUI.Separator("Argent de l'entreprise: "..money.."~g~$")
		RageUI.SeparatorMini()
		MFAClient.ButtonWithStyle('Déposer de l\'argent', 'Déposer de l\'argent dans votre entreprise', {}, true, function(_, _, s)
			if s then
				local amount = MFAClient.KeyboardInput('', 'Combien voulez-vous déposer ?', '', 8)
				if not amount or amount == "" or tonumber(amount) <= 0 then
					ESX.ShowNotification("~r~Montant invalide")
					return
				elseif tonumber(amount) > 0 then
					ESX.TriggerServerCallback("esx_society:deposit", function(valid)
						if valid then
							money = money + tonumber(amount)
						end
					end, societyName, tonumber(amount))
				end
			end
		end)
		MFAClient.ButtonWithStyle('Retirer de l\'argent', 'Retirer de l\'argent de votre entreprise', {}, true, function(_, _, s)
			if s then
				local amount = MFAClient.KeyboardInput('', 'Combien voulez-vous retirer ?', '', 8)
				if not amount or amount == "" or tonumber(amount) <= 0 then
					ESX.ShowNotification("~r~Montant invalide")
					return
				elseif tonumber(amount) > 0 then
					ESX.TriggerServerCallback("esx_society:withdraw", function(valid)
						if valid then
							money = money - tonumber(amount)
						end
					end, societyName, tonumber(amount))
				end
			end
		end)
		MFAClient.ButtonWithStyle('Gestion des employés', 'Voir la liste des employés', {}, true, function(_, _, s)
			if s then
				employees = {}
				ESX.TriggerServerCallback('esx_society:getEmployees', function(employes)
					employees = employes
				end, societyName)
			end
		end, 'employesManagement')
		MFAClient.ButtonWithStyle('Recruter du personnel', nil, {}, true, function(_, _, s)
			if s then
				onlinePlayers = {}
				ESX.TriggerServerCallback('esx_society:getOnlinePlayers', function(players)
					onlinePlayers = players
				end)
			end
		end, 'employesRecruit')
		MFAClient.ButtonWithStyle('Gestion des salaires', 'Gérer les salaires de vos employés', {}, true, function(_, _, s)
			if s then
				society = {}
				if ESX.PlayerData.job.name == societyName then
					ESX.TriggerServerCallback('esx_society:getJob', function(job)
						society = job
					end, societyName)
					Wait(200)
				elseif ESX.PlayerData.orga.name == societyName then
					ESX.TriggerServerCallback('esx_society:getOrga', function(orga)
						society = orga
					end, societyName)
					Wait(200)
				end
			end
		end, 'employesSalary')
	end)
	menuManageEmployee(societyName)
	menuRecruit(societyName)
	menuSalary(societyName)
end

menuManageEmployee = function(societyName)
	MFAClient.IsVisible('employesManagement', true, true, function()
		if #employees > 0 then
			for _, v in pairs(employees) do
				MFAClient.RList(("%s [%s - %s]"):format(v.name, v.job.label, v.job.grade_label), { "Promouvoir", "Rétrograder", "Virer" }, 1, nil, {}, true, {
					onSelected = function(Index, items)
						onChangeIndex(Index, societyName, v)
					end
				})
			end
		else
			RageUI.Line()
			RageUI.Separator("Aucun employés")
			RageUI.Line()
		end
	end)
end

menuRecruit = function(societyName)
	MFAClient.IsVisible('employesRecruit', true, true, function()
		if #onlinePlayers > 0 then
			for _, v in pairs(onlinePlayers) do
				MFAClient.ButtonWithStyle('Recruter '..v.name.." ?", nil, {}, true, function(_, _, s)
					if s then
						if ESX.PlayerData.job.name == societyName then
							ESX.TriggerServerCallback('esx_society:setJob', function()
								ESX.ShowNotification("~g~Recrutement effectué")
							end, v.identifier, societyName, 0, 'hire')
							RageUI.GoBack()
						elseif ESX.PlayerData.orga.name == societyName then
							ESX.TriggerServerCallback('esx_society:setOrga', function()
								ESX.ShowNotification("~g~Recrutement effectué")
							end, v.identifier, societyName, 0, 'hire')
							RageUI.GoBack()
						end
					end
				end)
			end
		else
			RageUI.Line()
			RageUI.Separator("Aucun habitant en ville")
			RageUI.Line()
		end
	end)
end

menuSalary = function(societyName)
	MFAClient.IsVisible('employesSalary', true, true, function()
		for _, v in pairs(society.grades) do
			MFAClient.ButtonWithStyle(v.label.." "..v.salary.."~g~$", 'Modifier le salaire du grade '.. v.label.." ?", {RightBadge = RageUI.BadgeStyle.Keyboard}, true, function(_, _, s)
				if s then
					local amount = MFAClient.KeyboardInput('Combien voulez-vous mettre ?', '', '', 8)
					amount = tonumber(amount)
					if amount <= 0 then
						ESX.ShowNotification("~r~Montant invalide")
					elseif amount > Config.MaxSalary then
						ESX.ShowNotification("~r~Montant trop élevé")
					else
						if ESX.PlayerData.job.name == societyName then
							ESX.TriggerServerCallback('esx_society:setJobSalary', function()
								ESX.ShowNotification("~g~Modification effectuée")
							end, v.job_name, v.grade, amount)
							RageUI.GoBack()
						elseif ESX.PlayerData.orga.name == societyName then
							ESX.TriggerServerCallback('esx_society:setOrgaSalary', function()
								ESX.ShowNotification("~g~Modification effectuée")
							end, v.orga_name, v.grade, amount)
							RageUI.GoBack()
						end
					end
				end
			end)
		end
	end)
end

onChangeIndex = function(Index, societyName, value)
	if Index == 1 then
		if ESX.PlayerData.job.name == societyName then
			ESX.TriggerServerCallback('esx_society:setJob', function()
				ESX.ShowNotification("Vous avez promu " .. value.name .. ".")
			end, value.identifier, value.job.name, value.job.grade + 1, 'promote')
		elseif ESX.PlayerData.orga.name == societyName then
			ESX.TriggerServerCallback('esx_society:setOrga', function()
				ESX.ShowNotification("Vous avez promu " .. value.name .. ".")
			end, value.identifier, value.job.name, value.job.grade + 1, 'promote')
		end
	elseif Index == 2 then
		if ESX.PlayerData.job.name == societyName then
			ESX.TriggerServerCallback('esx_society:setJob', function()
				ESX.ShowNotification("Vous avez rétrograder " .. value.name .. ".")
			end, value.identifier, value.job.name, value.job.grade - 1, 'retro')
		elseif ESX.PlayerData.orga.name == societyName then
			ESX.TriggerServerCallback('esx_society:setOrga', function()
				ESX.ShowNotification("Vous avez rétrograder " .. value.name .. ".")
			end, value.identifier, value.job.name, value.job.grade - 1, 'retro')
		end
	elseif Index == 3 then
		if ESX.PlayerData.job.name == societyName then
			ESX.TriggerServerCallback('esx_society:setJob', function()
				ESX.ShowNotification("Vous avez viré " .. value.name .. ".")
			end, value.identifier, "nojob", 0, 'fire')
		elseif ESX.PlayerData.orga.name == societyName then
			ESX.TriggerServerCallback('esx_society:setOrga', function()
				ESX.ShowNotification("Vous avez viré " .. value.name .. ".")
			end, value.identifier, "noorga", 0, 'fire')
		end
	end
end

AddEventHandler('esx_society:openBossMenu', function(society)
	ESX.TriggerServerCallback('esx_society:getSocietyMoney', function(societyMoney)
		money = societyMoney
	end, society)

	MFAClient.OpenMenu('Menu Principal', function()
		menuPrincipal(society)
	end, 0)
end)