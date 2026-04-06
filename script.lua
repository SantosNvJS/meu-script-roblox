-- =====================================================
-- ADMIN TEST SYSTEM - TUDO EM UM ÚNICO MODULESCRIPT
-- ADM DEV 1.0 Lord Santos
-- Tema amarelo moderno | Menu com K | Simulações de Anticheat
-- =====================================================

local AdminTestSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- ==================== LOGGER ====================
local function Log(message, level)
	level = level or "INFO"
	local timestamp = os.date("%X")
	print(string.format("[%s] [%s] %s", timestamp, level, message))
end

-- ==================== DETECTION (Flags + Stats) ====================
local playerData = {}

local function RegisterPlayer(player)
	if playerData[player] then return end
	playerData[player] = {
		flags = { AIM = 0, VISÃO = 0, VELOCIDADE = 0 },
		accuracy = 0,
		reactionTime = 0,
		speed = 16,
		noLosTracks = 0
	}
	Log("Detection: Jogador registrado - " .. player.Name)
end

local function UpdatePlayerStats(player, accuracy, reactionTime, speed, noLosTracks)
	local data = playerData[player]
	if not data then return end
	
	if accuracy then data.accuracy = accuracy end
	if reactionTime then data.reactionTime = reactionTime end
	if speed then data.speed = speed end
	if noLosTracks then data.noLosTracks = noLosTracks end
	
	Log(string.format(
		"Stats → %s | Accuracy=%.1f%% | Reaction=%.2fs | Speed=%.1f | NoLOS=%d",
		player.Name, data.accuracy, data.reactionTime, data.speed, data.noLosTracks
	))
	
	-- Verifica flags suspeitas
	if data.accuracy > 85 then
		data.flags.AIM = data.flags.AIM + 1
		Log("FLAG [AIM] - Alta precisão! Total: " .. data.flags.AIM, "WARN")
	end
	
	if data.speed > 40 then
		data.flags.VELOCIDADE = data.flags.VELOCIDADE + 1
		Log("FLAG [VELOCIDADE] - Velocidade anormal! Total: " .. data.flags.VELOCIDADE, "WARN")
	end
	
	if data.noLosTracks > 0 then
		data.flags.VISÃO = data.flags.VISÃO + 1
		Log("FLAG [VISÃO] - Rastreamento sem LOS! Total: " .. data.flags.VISÃO, "WARN")
	end
end

-- ==================== PLAYER SIMULATION ====================
local aimConnection = nil
local moveConnection = nil

local function SpawnTestDummies(count)
	count = count or 5
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		Log("Erro: Character não encontrado!", "ERROR")
		return
	end
	
	local rootPos = character.HumanoidRootPart.Position
	for i = 1, count do
		local dummy = Instance.new("Model")
		dummy.Name = "TestDummy" .. i
		
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = dummy
		
		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = Vector3.new(2, 2, 1)
		rootPart.Position = rootPos + Vector3.new(math.random(-30, 30), 5, math.random(-30, 30))
		rootPart.Anchored = false
		rootPart.CanCollide = true
		rootPart.Parent = dummy
		
		dummy.PrimaryPart = rootPart
		dummy.Parent = workspace
		
		Log("Dummy de teste #" .. i .. " criado")
	end
end

function AdminTestSystem.StartAimSimulation()
	if aimConnection then return end
	
	RegisterPlayer(localPlayer)
	SpawnTestDummies()
	
	aimConnection = RunService.Heartbeat:Connect(function()
		local character = localPlayer.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end
		
		local root = character.HumanoidRootPart
		local target = nil
		local closest = math.huge
		
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj.Name:find("TestDummy") and obj:FindFirstChild("HumanoidRootPart") then
				local dist = (root.Position - obj.HumanoidRootPart.Position).Magnitude
				if dist < closest then
					closest = dist
					target = obj.HumanoidRootPart
				end
			end
		end
		
		if target then
			root.CFrame = CFrame.lookAt(root.Position, target.Position)
			UpdatePlayerStats(localPlayer, 98, 0.08, nil, nil)
			Log("Simulação de mira de alta precisão ativa (testando AIM)")
		end
	end)
	
	Log("✅ SIMULAÇÃO DE MIRA ALTA PRECISÃO INICIADA")
end

function AdminTestSystem.StartMovementSimulation()
	if moveConnection then return end
	
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("Humanoid") then return end
	local humanoid = character.Humanoid
	
	RegisterPlayer(localPlayer)
	
	moveConnection = RunService.Heartbeat:Connect(function()
		local speed = 16 + math.random(0, 84) -- até 100
		humanoid.WalkSpeed = speed
		UpdatePlayerStats(localPlayer, nil, nil, speed, nil)
	end)
	
	Log("✅ SIMULAÇÃO DE MOVIMENTAÇÃO RÁPIDA INICIADA")
end

function AdminTestSystem.SimulateVisionTracking()
	RegisterPlayer(localPlayer)
	UpdatePlayerStats(localPlayer, nil, nil, nil, 5)
	Log("✅ SIMULAÇÃO DE RASTREAMENTO SEM LINHA DE VISÃO (testando VISÃO)")
end

function AdminTestSystem.StopAllSimulations()
	if aimConnection then aimConnection:Disconnect() aimConnection = nil end
	if moveConnection then moveConnection:Disconnect() moveConnection = nil end
	
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
	if humanoid then humanoid.WalkSpeed = 16 end
	
	Log("⛔ Todas as simulações paradas")
end

-- ==================== UI (MENU COM TECLA K) ====================
local menuGui = nil
local menuOpen = false

local function CreateMenu()
	if menuGui then return menuGui end
	
	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "AdminDevMenu"
	menuGui.ResetOnSpawn = false
	menuGui.Parent = playerGui
	
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0.35, 0, 0.55, 0)
	mainFrame.Position = UDim2.new(0.325, 0, 0.225, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = menuGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = mainFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 3
	stroke.Parent = mainFrame
	
	-- Título
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.18, 0)
	title.BackgroundTransparency = 1
	title.Text = "adm dev 1.0 Lord Santos"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = mainFrame
	
	-- Botões
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Size = UDim2.new(1, 0, 0.82, 0)
	buttonsFrame.Position = UDim2.new(0, 0, 0.18, 0)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = mainFrame
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Parent = buttonsFrame
	
	local function createButton(text, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.85, 0, 0, 60)
		btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamSemibold
		btn.Parent = buttonsFrame
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 12)
		btnCorner.Parent = btn
		
		btn.MouseButton1Click:Connect(callback)
		return btn
	end
	
	createButton("Jogar", function()
		menuGui.Enabled = false
		menuOpen = false
		Log("UI: Modo Jogar ativado")
	end)
	
	createButton("Configurações", function()
		Log("UI: Configurações clicado (expanda conforme necessário)")
	end)
	
	createButton("Teste de Mira", function()
		AdminTestSystem.StartAimSimulation()
	end)
	
	menuGui.Enabled = false
	return menuGui
end

-- ==================== CONTROLE DE TECLA K ====================
function AdminTestSystem.ToggleMenu()
	menuOpen = not menuOpen
	if not menuGui then
		menuGui = CreateMenu()
	end
	menuGui.Enabled = menuOpen
	
	if menuOpen then
		Log("UI: Menu aberto (tecla K)")
	else
		Log("UI: Menu fechado (tecla K)")
	end
end

-- ==================== INICIALIZAÇÃO ====================
function AdminTestSystem.Init()
	Log("=== SISTEMA BASE DE TESTE ANTICHEAT - ADM DEV 1.0 Lord Santos INICIADO ===")
	
	-- Cria o menu na inicialização
	CreateMenu()
	
	-- Tecla K para abrir/fechar
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.K then
			AdminTestSystem.ToggleMenu()
		end
	end)
	
	Log("✅ Sistema carregado com sucesso!")
	Log("Pressione K para abrir o menu amarelo")
	Log("Comandos extras disponíveis:")
	Log("   AdminTestSystem.StartMovementSimulation()")
	Log("   AdminTestSystem.SimulateVisionTracking()")
	Log("   AdminTestSystem.StopAllSimulations()")
end

return AdminTestSystem
