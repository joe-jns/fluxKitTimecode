--[[


░█████╗░░█████╗░░█████╗░███████╗██╗░░░░░░██████╗██╗░░░██╗░██████╗████████╗███████╗███╗░░░███╗░██████╗
██╔══██╗██╔══██╗██╔══██╗██╔════╝██║░░░░░██╔════╝╚██╗░██╔╝██╔════╝╚══██╔══╝██╔════╝████╗░████║██╔════╝
███████║██║░░╚═╝██║░░╚═╝█████╗░░██║░░░░░╚█████╗░░╚████╔╝░╚█████╗░░░░██║░░░█████╗░░██╔████╔██║╚█████╗░
██╔══██║██║░░██╗██║░░██╗██╔══╝░░██║░░░░░░╚═══██╗░░╚██╔╝░░░╚═══██╗░░░██║░░░██╔══╝░░██║╚██╔╝██║░╚═══██╗
██║░░██║╚█████╔╝╚█████╔╝███████╗███████╗██████╔╝░░░██║░░░██████╔╝░░░██║░░░███████╗██║░╚═╝░██║██████╔╝
╚═╝░░╚═╝░╚════╝░░╚════╝░╚══════╝╚══════╝╚═════╝░░░░╚═╝░░░╚═════╝░░░░╚═╝░░░╚══════╝╚═╝░░░░░╚═╝╚═════╝░


Scripted by: AccelRanger

Core: Server Core
Description: Main

--]]

local config = script.Parent.Configuration
local sessiondata = script.Parent.sessionData

script.Parent.GUI.loader.Parent = game.StarterGui
config.whitelist:Clone().Parent = game.ReplicatedStorage.AccelSystemsFKTC

local config = script.Parent.Configuration
local logTable = {}
local whitelist = require(config.whitelist)
local compressModule = require(game.ReplicatedStorage.AccelSystemsFKTC.lib.ColourModule)
local warnModule = require(game.ReplicatedStorage.AccelSystemsFKTC.lib.WarningModule)
local lastEventTime = os.clock()
local sound = Instance.new("Sound", game.SoundService)
sound.Name = "AccelSystemsFKTC"

-- [FORK] Persistance des shows via DataStore : sauvegarde auto + rechargement
-- auto au démarrage. Plus besoin de copier le JSON à la main.
-- (Nécessite "Enable Studio Access to API Services" dans Game Settings > Security
--  pour tester en Studio. Dégrade proprement si indisponible : aucune erreur.)
local DataStoreService = game:GetService("DataStoreService")
local SHOW_STORE
local SHOW_INDEX_KEY = "__index__"
local DELETED_KEY = "__deleted__" -- noms supprimés (ré-effacés à chaque démarrage, même les "baked")
pcall(function() SHOW_STORE = DataStoreService:GetDataStore("FKTC_Shows_v1") end)

local function showsFolder()
	return game.ReplicatedStorage.AccelSystemsFKTC.shows
end

-- [FORK] garantit un nom unique (évite d'écraser un show existant)
local function uniqueName(base)
	local folder = showsFolder()
	if not folder:FindFirstChild(base) then return base end
	local i = 2
	while folder:FindFirstChild(base .. " (" .. i .. ")") do i += 1 end
	return base .. " (" .. i .. ")"
end

local function persistSaveShow(name, data)
	if not SHOW_STORE then return end
	pcall(function() SHOW_STORE:SetAsync("show_" .. name, data) end)
	pcall(function()
		SHOW_STORE:UpdateAsync(SHOW_INDEX_KEY, function(idx)
			idx = (type(idx) == "table") and idx or {}
			for _, n in ipairs(idx) do if n == name then return idx end end
			table.insert(idx, name)
			return idx
		end)
	end)
	-- si un nom supprimé est réutilisé, on le retire de la liste noire
	pcall(function()
		SHOW_STORE:UpdateAsync(DELETED_KEY, function(set)
			set = (type(set) == "table") and set or {}
			set[name] = nil
			return set
		end)
	end)
end

local function persistLoadShows()
	if not SHOW_STORE then return end
	local ok, idx = pcall(function() return SHOW_STORE:GetAsync(SHOW_INDEX_KEY) end)
	if not ok or type(idx) ~= "table" then return end
	for _, name in ipairs(idx) do
		if not showsFolder():FindFirstChild(name) then
			local ok2, data = pcall(function() return SHOW_STORE:GetAsync("show_" .. name) end)
			if ok2 and type(data) == "string" then
				local sv = Instance.new("StringValue")
				sv.Name = name
				sv.Value = data
				sv.Parent = showsFolder()
			end
		end
	end
end

local function persistDeleteShow(name)
	if not SHOW_STORE then return end
	pcall(function() SHOW_STORE:RemoveAsync("show_" .. name) end)
	pcall(function()
		SHOW_STORE:UpdateAsync(SHOW_INDEX_KEY, function(idx)
			idx = (type(idx) == "table") and idx or {}
			for i, n in ipairs(idx) do
				if n == name then table.remove(idx, i) break end
			end
			return idx
		end)
	end)
	-- ajoute à la liste noire -> sera ré-effacé à chaque démarrage (gère les shows "baked")
	pcall(function()
		SHOW_STORE:UpdateAsync(DELETED_KEY, function(set)
			set = (type(set) == "table") and set or {}
			set[name] = true
			return set
		end)
	end)
end

-- [FORK] supprime, au démarrage, tout show présent dans le dossier mais marqué supprimé
-- (utile pour les StringValue "baked" dans le place qu'un script runtime ne peut pas
--  retirer du fichier, mais qu'on peut masquer à chaque session)
local function purgeDeleted()
	if not SHOW_STORE then return end
	local ok, set = pcall(function() return SHOW_STORE:GetAsync(DELETED_KEY) end)
	if not ok or type(set) ~= "table" then return end
	for _, sv in ipairs(showsFolder():GetChildren()) do
		if sv:IsA("StringValue") and set[sv.Name] then
			sv:Destroy()
		end
	end
end

local gitVersion = require(84432237552644)()
local ver = "V1.5"

local selectedSong = nil

local showfile = {}

task.wait(2)
print("" .. "\n" .. "--------- AccelSystems FKTC ---------" .."" .. "\n" .. "\n" .. "Booting." .. "\n" .. "Getting Shows" .. "\n" .. "LOADED!" .. "\n" .. "" .. "\n" .. "--------- AccelSystems FKTC ---------")

if config.autoSearch.Value == true then
	for _,v in pairs(game.Workspace:GetDescendants()) do
		if v:IsA("Folder") and v.Name == "remotes" then
			if v.Parent.Name == "components" then
				config.folder.Value = v
				print("set")
			end
		end
	end
end

game.ReplicatedStorage.AccelSystemsFKTC.session.folder.Value = config.folder.Value

function init()
	if not config:FindFirstChild("folder") or config.folder.Value == nil then
		warnModule.Warn("exiting server code, returning nil", "ERROR 001","Configuration>folder >> Does not exist, or value is invalid.")
	elseif config:FindFirstChild("compilerDebug").Value == true then
		print("AccelSystems FKTC Compiler Debug State: true")--..config.compilerDebug.Value)
	elseif ver ~= gitVersion then
		warnModule.Warn("Current version","WARNING 001", "If the versions are not the same consider using the new one, Current version: "..ver.." Published version: "..gitVersion)
	end
end

-- [FORK FIX] Renvoie une copie du showfile avec le PREMIER delay forcé à 0.
-- Évite d'avoir à éditer le JSON dans Notepad à chaque export.
local function buildExport()
	local out = {}
	for i, e in ipairs(showfile) do
		out[i] = e
	end
	if out[1] then out[1].Delay = 0 end
	return out
end

local function logEvent(eventType, arg1, arg2, arg3, arg4, arg5)
	if script.Parent.sessionData.recording.Value == true then
		local currentTime = os.clock()
		local delay = currentTime - lastEventTime
		lastEventTime = currentTime

		table.insert(showfile, {
			eventType = eventType,
			Function = arg1,
			Arguments = arg2,
			ExternalArgument = arg3,
			FunctionsExpand = arg4,
			ColorCompressed = arg5,
			Delay = delay
		})
		
		if arg3 == nil then arg3 = "Returned nil" end;if arg4 == nil then arg4 = "Returned nil" end;if arg5 == nil then arg5 = "Returned nil" end
		
		if config.compilerDebug.Value == true then
			warn("--- "..eventType.." ---")
			print(arg1)
			print(arg2)
			print(arg3)
			print(arg4)
			print(arg5)
			print("Delay: " ..delay)
			warn("----------------------------")
		end
	end
end

-- events

game.Workspace.AccelSystemsFKTC.remotes.getData.OnServerInvoke = function(player)
	return buildExport() -- [FORK FIX] premier delay à 0
end

game.Workspace.AccelSystemsFKTC.remotes.clientData.OnServerInvoke = function(player, arg)
	if arg == "showfile" then
		return buildExport() -- [FORK FIX] premier delay à 0
	elseif arg == "recordingCount" then -- [FORK] pour l'indicateur d'enregistrement
		return { count = #showfile, recording = script.Parent.sessionData.recording.Value }
	elseif arg == "outputlog" then
		if game.ReplicatedStorage.AccelSystemsFKTC.debug.Value == true then print(logTable) end
		return logTable
	end
end

game.Workspace.AccelSystemsFKTC.remotes.getDataClient.OnServerEvent:Connect(function(player, arg)
	if whitelist(player) == true then
		if arg == "clear" then
			table.clear(showfile)
		elseif arg == "startRecording" then
			lastEventTime = os.clock() -- [FORK FIX] reset : le 1er delay part de l'instant du Start
			script.Parent.sessionData.recording.Value = true
		elseif arg == "stopRecording" then
			script.Parent.sessionData.recording.Value = false
		end
	end
end)

game.Workspace.AccelSystemsFKTC.remotes.getDataServer.Event:Connect(function(arg)
	if arg == "get" then
		game.Workspace.AccelSystemsFKTC.remotes.tableReturn:Fire(buildExport()) -- [FORK FIX] premier delay à 0
	elseif arg == "clear" then
		table.clear(showfile)
	elseif arg == "reset" then
		lastEventTime = os.clock()
	end
end)

game.Workspace.AccelSystemsFKTC.remotes.createShow.OnServerEvent:Connect(function(player,name, data)
	if whitelist(player) == true then
		local finalName = uniqueName(name) -- [FORK] noms uniques = plus d'écrasement
		local stringValue = Instance.new("StringValue", showsFolder())
		stringValue.Value = data
		stringValue.Name = finalName
		persistSaveShow(finalName, data) -- [FORK] sauvegarde persistante
	end
end)

-- [FORK] suppression / renommage de shows depuis l'UI (RemoteEvents créés si absents)
local remotesFolder = game.Workspace.AccelSystemsFKTC.remotes
local function ensureRemote(rname)
	local r = remotesFolder:FindFirstChild(rname)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = rname
		r.Parent = remotesFolder
	end
	return r
end

ensureRemote("deleteShow").OnServerEvent:Connect(function(player, name)
	if whitelist(player) ~= true then return end
	local sv = showsFolder():FindFirstChild(name)
	if sv then sv:Destroy() end
	persistDeleteShow(name)
end)

ensureRemote("renameShow").OnServerEvent:Connect(function(player, oldName, newName)
	if whitelist(player) ~= true then return end
	if type(newName) ~= "string" or newName == "" or newName == oldName then return end
	local sv = showsFolder():FindFirstChild(oldName)
	if not sv then return end
	local finalName = uniqueName(newName)
	local data = sv.Value
	sv.Name = finalName
	persistDeleteShow(oldName)
	persistSaveShow(finalName, data)
end)

game.Workspace.AccelSystemsFKTC.remotes.logAction.OnServerEvent:Connect(function(player,action)
	local msg 
	
	if action == "play" then
		msg = player.Name.." has started the playback.."
	elseif action == "startRecording" then
		msg = player.Name.." has started recording showfile."
	elseif action == "stopRecording" then
		msg = player.Name.." has stopped recording showfile."
	elseif action == "clear" then
		msg = player.Name.." has cleared the showfile."
	elseif action == "compress" then
		msg = player.Name.." has compressed the showfile."
	end
 	
	table.insert(logTable, msg)
end)

game.Workspace.AccelSystemsFKTC.remotes.selectSong.OnServerEvent:Connect(function(player, NAME, ID)
	selectedSong = {NAME, ID}
end)

game.Workspace.AccelSystemsFKTC.remotes.soundRemote.OnServerEvent:Connect(function(player, NAME, ID)
	if NAME == "__STOP__" then -- [FORK] arrêt de la musique quand on stoppe un show
		sound:Stop()
		return
	end
	sound.SoundId = "rbxassetid://"..ID
	sound:Play()
end)

game.ServerScriptService.AccelSystemsFKTC.sessionData.recording.Changed:Connect(function(VALUE)
	if VALUE == true and selectedSong ~= nil then
		sound.SoundId = "rbxassetid://"..selectedSong[2]
		sound:Play()
		
		logEvent("functions", selectedSong[1], selectedSong[2], "sound")
		
	elseif VALUE == false then
		sound:Stop()
	end
end)

-- logging

config.folder.Value.direct.effects.OnServerEvent:Connect(function(player, arg1, arg2)
	logEvent("effects", arg1, arg2) -- works
end)

config.folder.Value.direct.faders.OnServerEvent:Connect(function(player, arg1, arg2)
	logEvent("faders", arg1, arg2) -- works
end)

config.folder.Value.direct.pyrotechnics.OnServerEvent:Connect(function(player, arg1, arg2, arg3)
	logEvent("pyrotechnics", arg1, arg2, arg3) -- works
end)

config.folder.Value.direct.status.OnServerEvent:Connect(function(player, arg1, arg2)
	logEvent("status", arg1, arg2) -- works
end)

config.folder.Value.call.functions.OnServerEvent:Connect(function(player, arg1, arg2, arg3, arg4, arg5)
	if arg4 == nil then
		logEvent("functions", arg1, arg2, arg3) -- works
	else
		local compressedString = compressModule.compressColor3Table(arg5)
		logEvent("functions", arg1, arg2, arg3, arg4, compressedString) -- colors work
	end
end)

-- initiliaze

init()
task.spawn(function() -- [FORK] recharge les shows sauvegardés, puis purge les supprimés
	persistLoadShows()
	purgeDeleted()
end)
