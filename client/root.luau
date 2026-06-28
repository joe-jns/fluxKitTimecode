--[[


░█████╗░░█████╗░░█████╗░███████╗██╗░░░░░░██████╗██╗░░░██╗░██████╗████████╗███████╗███╗░░░███╗░██████╗
██╔══██╗██╔══██╗██╔══██╗██╔════╝██║░░░░░██╔════╝╚██╗░██╔╝██╔════╝╚══██╔══╝██╔════╝████╗░████║██╔════╝
███████║██║░░╚═╝██║░░╚═╝█████╗░░██║░░░░░╚█████╗░░╚████╔╝░╚█████╗░░░░██║░░░█████╗░░██╔████╔██║╚█████╗░
██╔══██║██║░░██╗██║░░██╗██╔══╝░░██║░░░░░░╚═══██╗░░╚██╔╝░░░╚═══██╗░░░██║░░░██╔══╝░░██║╚██╔╝██║░╚═══██╗
██║░░██║╚█████╔╝╚█████╔╝███████╗███████╗██████╔╝░░░██║░░░██████╔╝░░░██║░░░███████╗██║░╚═╝░██║██████╔╝
╚═╝░░╚═╝░╚════╝░░╚════╝░╚══════╝╚══════╝╚═════╝░░░░╚═╝░░░╚═════╝░░░░╚═╝░░░╚══════╝╚═╝░░░░░╚═╝╚═════╝░


Scripted by: AccelRanger

Core: Client GUI
Description: Client Panel handler

--]]

task.wait(1)
local shows = game.ReplicatedStorage.AccelSystemsFKTC.shows
local songs = game.ReplicatedStorage.AccelSystemsFKTC.songs
local localPlayer = game.Players.LocalPlayer
local show = 1
local logTable = {}

print("" .. "\n" .. "--------- AccelSystems FKTC ---------" .. "\n" .. "" .. "\n" .. "Running client/root" .. "\n" .. "Extracting GUI" .. "\n" .. "Processing whitelist" .. "\n" .. "UserID: "..game.Players.LocalPlayer.UserId .. "\n" .. "User: "..game.Players.LocalPlayer.Name .. "\n" .. "" .. "\n" .."--------- AccelSystems FKTC ---------")

local showRunning = false

local remoteFolder = game.ReplicatedStorage:FindFirstChild("AccelSystemsFKTC").session.folder.Value
local compressModule = require(game.ReplicatedStorage.AccelSystemsFKTC.lib.ColourModule)

local remotes = {
	effects = remoteFolder.direct.effects,
	faders = remoteFolder.direct.faders,
	pyrotechnics = remoteFolder.direct.pyrotechnics,
	status = remoteFolder.direct.status,
	functions = remoteFolder.call.functions
}

-- [FORK] état lecture / enregistrement + helpers de statut
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local STOP_KEY = Enum.KeyCode.Backspace -- touche pour stopper un show en cours

local isPlaying = false
local stopRequested = false
local recording = false
local activeEffects = {} -- effets allumés pendant la lecture (pour le blackout)
local startPlayback -- [FORK] déclaration anticipée (utilisée dans changeFrame avant sa définition)

local function setStatus(text)
	script.Parent.main.top.msg.Text = text
end
local function resetStatus()
	if not isPlaying and not recording then
		script.Parent.main.top.msg.Text = "Flux Kit Timecode System"
	end
end

local gui = script.Parent.main
local templates = script.templates
local showGUI = gui.core.shows
local songGUI = gui.core.songs
local outputGUI = gui.core.output

local clickSound = Instance.new("Sound")
clickSound.Parent = game:GetService("SoundService")
clickSound.SoundId = "rbxassetid://6976440355"
clickSound.Name = "FKTC_UI_SOUNDS_C"

local playSound = Instance.new("Sound")
playSound.Parent = game:GetService("SoundService")
playSound.SoundId = "rbxassetid://97367190838793"
playSound.Name = "FKTC_UI_SOUNDS_P"

local errorSound = Instance.new("Sound")
errorSound.Parent = game:GetService("SoundService")
errorSound.SoundId = "rbxassetid://3429876367"
errorSound.Name = "FKTC_UI_SOUNDS_E"

--functions
local function processShowfile(showfile)
	local n = #showfile
	local startClock = os.clock()
	local target = 0 -- temps cumulé cible (timing absolu = pas de dérive)
	table.clear(activeEffects)

	for i, event in ipairs(showfile) do -- [FORK] ipairs = ordre garanti
		local eventType = event.eventType
		local arg1 = event.Function
		local arg2 = event.Arguments
		local arg3 = event.ExternalArgument
		local arg4 = event.FunctionsExpand
		local arg5 = event.ColorCompressed

		-- [FORK] timing sans dérive : on attend l'INSTANT cible, pas un delay relatif
		target += event.Delay
		while not stopRequested do
			local remaining = target - (os.clock() - startClock)
			if remaining <= 0 then break end
			task.wait(math.min(remaining, 0.05)) -- réactif à l'arrêt
		end
		if stopRequested then break end -- [FORK] arrêt demandé

		if remotes[eventType] then
			if eventType == "functions" or eventType == "pyrotechnics" then
				if arg4 == nil then
					if arg3 == "sound" then
						game.Workspace.AccelSystemsFKTC.remotes.soundRemote:FireServer(arg1, arg2)
					else
						remotes[eventType]:FireServer(arg1, arg2, arg3)
					end
				else
					local compressedColor = compressModule.decompressColor3String(arg5)
					remotes[eventType]:FireServer(arg1, arg2, arg3, arg4, compressedColor)
				end
			else
				-- [FORK] suivi des effets actifs (pour le blackout à l'arrêt)
				if eventType == "effects" then
					local key = HttpService:JSONEncode(arg1)
					if arg2 == "on" then
						activeEffects[key] = arg1
					elseif arg2 == "off" then
						activeEffects[key] = nil
					end
				end
				remotes[eventType]:FireServer(arg1, arg2)
			end
		else
			warn("No remote found for event type: "..tostring(eventType))
		end

		-- [FORK] indicateur de progression
		setStatus(string.format("Lecture %d/%d  -  %.1fs", i, n, os.clock() - startClock))
	end
end

--[[

Arg1> sound name
Arg2> sound id
Arg3> type

--]]

local function tableToString(tbl)
	return game:GetService("HttpService"):JSONEncode(tbl)
end

local function stringToTable(tbl)
	return game:GetService("HttpService"):JSONDecode(tbl)
end

local function logAction(action)
	game.Workspace.AccelSystemsFKTC.remotes.logAction:FireServer(action)
end

local function createShow(name, data)
	game.Workspace.AccelSystemsFKTC.remotes.createShow:FireServer(name, data)
end

local function selectSong(name, id)
	game.Workspace.AccelSystemsFKTC.remotes.selectSong:FireServer(name, id)
	gui.core.songSelected.Text = "Song Selected: "..name
end

local function userWarning(header,text)
	--warn(header, text)
	script.Parent.main.top.msg.Text = header..": "..text
	task.wait(3)
	script.Parent.main.top.msg.Text = "Flux Kit Timecode System"
end

local function changeFrame(frame)
	clickSound:Play()
	for _,v in pairs(gui.core:GetChildren()) do
		if v:IsA("Frame") then
			if v.Name == frame then
				v.Visible = true
			else
				v.Visible = false
			end
		end
	end

	if frame == "output" then
		for _,v in pairs(outputGUI.frame:GetChildren()) do
			if v:IsA("Frame") and v.Name ~= "spacer" then
				v:Destroy()
			end
		end

		for _,v in pairs(game.Workspace.AccelSystemsFKTC.remotes.clientData:InvokeServer("outputlog")) do
			local clone = templates.logTemplate:Clone()
			clone.log.Text = v
			clone.Parent = outputGUI.frame
		end
	elseif frame == "shows" then
		for _,v in pairs(showGUI.frame:GetChildren()) do
			if v:IsA("Frame") and v.Name ~= "spacer" then
				v:Destroy()
			end
		end

		for _,v in pairs(shows:GetChildren()) do
			local clone = templates.showTemplate:Clone()
			clone.Name = v.Name
			clone.showName.Text = v.Name
			clone.Parent = showGUI.frame
		end

		for _,v in pairs(showGUI.frame:GetChildren()) do
			if v:IsA("Frame") then
				if v.Name ~= "spacer" then
					v.playShow.MouseButton1Up:Connect(function()
						clickSound:Play()
						for _,value in pairs(shows:GetChildren()) do
							if v.Name == value.Name then
								startPlayback(value) -- [FORK] lecture sécurisée
							end
						end
					end)
				end
			end
		end
	end

	gui.core.selected.Text = "Selected: "..frame
end

-- [FORK] extinction propre : coupe les effets restés allumés (haze, breath, etc.)
local function blackout()
	for _, fn in pairs(activeEffects) do
		pcall(function() remotes.effects:FireServer(fn, "off") end)
	end
	table.clear(activeEffects)
end

-- [FORK] arrêt d'un show en cours
local function stopPlayback()
	if isPlaying then
		stopRequested = true
	end
end

-- [FORK] bouton STOP intégré au menu : on CLONE "Stop Recording" pour garder le
-- style exact du panneau, on le place juste en dessous, et on le câble sur l'arrêt.
local ok = pcall(function()
	if gui.core:FindFirstChild("stopShow") then return end -- déjà créé
	local src = gui.core:FindFirstChild("stopRecording")
	if not src then return end

	local btn = src:Clone()
	btn.Name = "stopShow"
	-- met à jour le texte (bouton texte OU label enfant)
	if btn:IsA("TextButton") then btn.Text = "STOP SHOW" end
	for _, lbl in ipairs(btn:GetDescendants()) do
		if lbl:IsA("TextLabel") then lbl.Text = "STOP SHOW" end
	end
	-- placé juste sous "Stop Recording" (ignoré si le menu a une mise en page auto)
	btn.Position = src.Position + UDim2.new(0, 0, src.Size.Y.Scale, src.Size.Y.Offset + 6)
	btn.Parent = gui.core

	btn.MouseButton1Up:Connect(function()
		clickSound:Play()
		stopPlayback()
	end)
end)
if not ok then
	warn("[FORK] bouton stopShow non créé (la touche "..STOP_KEY.Name.." reste disponible).")
end

-- [FORK] lancement sécurisé d'un show (anti-double, JSON protégé, progression, blackout)
function startPlayback(showValue) -- assigne le local déclaré plus haut
	if isPlaying then
		setStatus("Déjà en lecture — ["..STOP_KEY.Name.."] pour stopper")
		return
	end

	local ok, decoded = pcall(stringToTable, showValue.Value)
	if not ok or type(decoded) ~= "table" then
		errorSound:Play()
		setStatus("Erreur : show illisible (JSON invalide)")
		task.delay(3, resetStatus)
		return
	end

	isPlaying = true
	stopRequested = false
	playSound:Play()
	logAction("play")

	processShowfile(decoded)

	blackout() -- [FORK] coupe les effets bloqués
	local stopped = stopRequested
	if stopped then
		-- [FORK] coupe aussi la musique (jouée côté serveur)
		pcall(function() game.Workspace.AccelSystemsFKTC.remotes.soundRemote:FireServer("__STOP__") end)
	end
	isPlaying = false
	stopRequested = false
	setStatus(stopped and "Show stoppé (blackout)" or "Show terminé")
	task.delay(3, resetStatus)
end

-- [FORK] touche d'arrêt
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == STOP_KEY then
		stopPlayback()
	end
end)

--setup
for _,v in pairs(shows:GetChildren()) do --shows
	local clone = templates.showTemplate:Clone()
	clone.Name = v.Name
	clone.showName.Text = v.Name
	clone.Parent = showGUI.frame
end

for _,v in pairs(songs:GetChildren()) do --songs
	local clone = templates.songTemplate:Clone()
	clone.Name = v.Name
	clone.songName.Text = v.Name
	clone.Parent = songGUI.frame
end

--logic

gui.core.outputBT.MouseButton1Up:Connect(function() changeFrame("output") end)
gui.core.showsBT.MouseButton1Up:Connect(function() changeFrame("shows") end)
gui.core.songsBT.MouseButton1Up:Connect(function() changeFrame("songs") end)

--shows
for _,v in pairs(showGUI.frame:GetChildren()) do
	if v:IsA("Frame") then
		if v.Name ~= "spacer" then
			v.playShow.MouseButton1Up:Connect(function()
				clickSound:Play()
				for _,value in pairs(shows:GetChildren()) do
					if v.Name == value.Name then
						startPlayback(value) -- [FORK] lecture sécurisée
					end
				end
			end)
		end
	end
end

--songs
for _,v in pairs(songGUI.frame:GetChildren()) do
	if v:IsA("Frame") then
		if v.Name ~= "spacer" then
			v.selectSong.MouseButton1Up:Connect(function()
				clickSound:Play()
				for _,value in pairs(songs:GetChildren()) do
					if v.Name == value.Name then
						if showRunning == false then
							selectSong(value.Name, value.Value)
						else
							userWarning("Sound System", "Showfile is running!")
						end
					end
				end
			end)
		end
	end
end

gui.core.compress.MouseButton1Up:Connect(function()
	clickSound:Play()
	local data = game.Workspace.AccelSystemsFKTC.remotes.clientData:InvokeServer("showfile")
	local func = tableToString(data)
	createShow("SHOW"..show.."COMPRESSED", func)
	logAction("compress")
	show += 1
end)

gui.core.startRecording.MouseButton1Up:Connect(function()
	clickSound:Play()
	game.Workspace.AccelSystemsFKTC.remotes.getDataClient:FireServer("startRecording")
	logAction("startRecording")

	-- [FORK] indicateur d'enregistrement (events + temps)
	recording = true
	local recStart = os.clock()
	task.spawn(function()
		while recording do
			local info = game.Workspace.AccelSystemsFKTC.remotes.clientData:InvokeServer("recordingCount")
			local count = (type(info) == "table" and info.count) or 0
			setStatus(string.format("\u{25CF} REC  -  %d events  -  %.1fs", count, os.clock() - recStart))
			task.wait(0.3)
		end
	end)
end)

gui.core.stopRecording.MouseButton1Up:Connect(function()
	clickSound:Play()
	game.Workspace.AccelSystemsFKTC.remotes.getDataClient:FireServer("stopRecording")
	logAction("stopRecording")

	-- [FORK] fin d'enregistrement
	recording = false
	local info = game.Workspace.AccelSystemsFKTC.remotes.clientData:InvokeServer("recordingCount")
	local count = (type(info) == "table" and info.count) or 0
	setStatus(string.format("Enregistrement arrêté  -  %d events", count))
	task.delay(3, resetStatus)
end)

gui.core.clear.MouseButton1Up:Connect(function()
	clickSound:Play()
	game.Workspace.AccelSystemsFKTC.remotes.getDataClient:FireServer("clear")
	logAction("clear")
end)
