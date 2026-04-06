--[[
    ╔══════════════════════════════════════════════════════╗
    ║         ADM DEV 1.0 — LORD SANTOS                    ║
    ║  Sistema Completo de Teste Anticheat para FPS        ║
    ║  Tudo em UM ÚNICO ModuleScript                       ║
    ╚══════════════════════════════════════════════════════╝
    
    Como usar:
    1. Crie um ModuleScript em ReplicatedStorage chamado "ADMDev"
    2. Cole todo este código dentro dele
    3. Crie um LocalScript em StarterPlayer > StarterPlayerScripts e use:
    
       local ADMDev = require(game.ReplicatedStorage.ADMDev)
       ADMDev.Init()
       
    4. Pressione **K** para abrir o menu
--]]

local ADMDev = {}

-- ====================== SERVIÇOS ======================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ====================== CONFIGURAÇÕES ======================
local CONFIG = {
    -- Aim
    PRECISAO_NORMAL     = 0.75,
    PRECISAO_SUSPEITA   = 0.98,
    NUM_DISPAROS        = 30,

    -- Visão
    NUM_ALVOS           = 8,
    LOS_THRESHOLD       = 0.6,

    -- Velocidade
    VEL_NORMAL_MAX      = 16,
    VEL_SUSPEITA        = 32,
    DURACAO_MOVE        = 6,
}

local THRESH = {
    ACERTO_SUSPEITO      = 0.90,
    ACERTO_CRITICO       = 0.97,
    REACAO_MIN_SUSPEITA  = 0.060,
    REACAO_MIN_CRITICA   = 0.030,
    LOS_PORCENTAGEM      = 0.50,
    LOS_CRITICA          = 0.75,
    VEL_SUSPEITA         = 20,
    VEL_CRITICA          = 30,
    FLAGS_ALERTA         = 5,
    FLAGS_BAN_SUGERIDO   = 10,
}

-- ====================== ESTADO ======================
local simAtiva = false
local conexoes = {}
local dadosSessao = {
    totalDisparos = 0, acertos = 0, temposReacao = {},
    velocidades = {}, rastreioForaLOS = 0, totalRastreios = 0,
}

local estadoJogadores = {}
local logBuffer = {}
local flagBuffer = {}

local screenGui, frameMenu, frameSettings = nil, nil, nil
local menuAberto = false
local callbacks = {}

local CATEGORIAS = {
    AIM        = "🎯 AIM",
    VISAO      = "👁 VISÃO",
    VELOCIDADE = "⚡ VELOCIDADE",
    SISTEMA    = "⚙ SISTEMA",
    UI         = "🖥 UI",
}

-- ====================== CORES (Tema Amarelo) ======================
local COR = {
    AMARELO        = Color3.fromRGB(255, 210, 0),
    AMARELO_ESCURO = Color3.fromRGB(200, 160, 0),
    AMARELO_HOVER  = Color3.fromRGB(255, 230, 80),
    FUNDO          = Color3.fromRGB(12, 12, 14),
    FUNDO_PAINEL   = Color3.fromRGB(18, 18, 22),
    FUNDO_CARD     = Color3.fromRGB(24, 24, 30),
    TEXTO          = Color3.fromRGB(255, 255, 255),
    TEXTO_CINZA    = Color3.fromRGB(160, 160, 180),
    BORDA          = Color3.fromRGB(40, 40, 50),
}

-- ====================== HELPERS ======================
local function timestamp()
    local t = math.floor(workspace:GetServerTimeNow and workspace:GetServerTimeNow() or os.clock())
    return string.format("[%02d:%02d]", math.floor(t/60)%60, t%60)
end

local function Log(categoria, msg, nivel)
    nivel = nivel or "info"
    local ts = "[" .. timestamp() .. "]"
    local txt = string.format("[ADM DEV] %s [%s] %s", ts, categoria, msg)

    if nivel == "warn" then
        warn(txt)
    else
        print(txt)
    end

    table.insert(logBuffer, {categoria = categoria, msg = msg})
    if #logBuffer > 200 then table.remove(logBuffer, 1) end
end

local function Flag(jogador, categoria, descricao, valor)
    local entrada = {jogador = jogador, categoria = categoria, descricao = descricao, valor = valor, timestamp = os.clock()}
    table.insert(flagBuffer, entrada)

    warn(string.format("[ADM DEV] %s 🚩 FLAG >> %s | %s | %s", timestamp(), jogador, categoria, descricao))
end

local function garantirEstado(nome)
    if not estadoJogadores[nome] then
        estadoJogadores[nome] = {
            totalDisparos = 0, acertos = 0, reacoes = {}, velocidades = {},
            totalRastreios = 0, rastreioForaLOS = 0, totalFlags = 0,
        }
    end
    return estadoJogadores[nome]
end

-- ====================== DETECÇÃO ======================
local function nivelSeveridade(valor, normal, grave)
    if valor >= grave then return "🔴 GRAVE" end
    if valor >= normal then return "🟡 SUSPEITO" end
    return nil
end

local function nivelSeveridadeInv(valor, normal, grave)
    if valor <= grave then return "🔴 GRAVE" end
    if valor <= normal then return "🟡 SUSPEITO" end
    return nil
end

local function RegistrarDisparo(jogador, acertou, tempoReacao)
    local estado = garantirEstado(jogador)
    estado.totalDisparos += 1
    if acertou then estado.acertos += 1 end
    table.insert(estado.reacoes, tempoReacao)

    local nivel = nivelSeveridadeInv(tempoReacao, THRESH.REACAO_MIN_SUSPEITA, THRESH.REACAO_MIN_CRITICA)
    if nivel then
        estado.totalFlags += 1
        Flag(jogador, CATEGORIAS.AIM, string.format("%s | Reação muito rápida: %.0fms", nivel, tempoReacao*1000), tempoReacao)
    end
end

local function AnalisarAim(jogador, taxaAcerto, reacaoMedia)
    local estado = garantirEstado(jogador)
    Log("DETECTION", string.format("[%s] AIM → Acerto: %.1f%% | Reação: %.0fms", jogador, taxaAcerto*100, reacaoMedia*1000))

    local nivelA = nivelSeveridade(taxaAcerto, THRESH.ACERTO_SUSPEITO, THRESH.ACERTO_CRITICO)
    if nivelA then
        estado.totalFlags += 1
        Flag(jogador, CATEGORIAS.AIM, string.format("%s | Taxa de acerto anormal: %.1f%%", nivelA, taxaAcerto*100), taxaAcerto)
    end

    local nivelR = nivelSeveridadeInv(reacaoMedia, THRESH.REACAO_MIN_SUSPEITA, THRESH.REACAO_MIN_CRITICA)
    if nivelR then
        estado.totalFlags += 1
        Flag(jogador, CATEGORIAS.AIM, string.format("%s | Reação média anormal: %.0fms", nivelR, reacaoMedia*1000), reacaoMedia)
    end

    AnalisarFlags()
end

local function AnalisarVisao(jogador, pctForaLOS)
    local estado = garantirEstado(jogador)
    local nivel = nivelSeveridade(pctForaLOS, THRESH.LOS_PORCENTAGEM, THRESH.LOS_CRITICA)
    if nivel then
        estado.totalFlags += 1
        Flag(jogador, CATEGORIAS.VISAO, string.format("%s | Rastreando fora de LOS: %.1f%%", nivel, pctForaLOS*100), pctForaLOS)
    end
    AnalisarFlags()
end

local function RegistrarVelocidade(jogador, velocidade)
    local estado = garantirEstado(jogador)
    local nivel = nivelSeveridade(velocidade, THRESH.VEL_SUSPEITA, THRESH.VEL_CRITICA)
    if nivel then
        estado.totalFlags += 1
        Flag(jogador, CATEGORIAS.VELOCIDADE, string.format("%s | Velocidade suspeita: %.0f u/s", nivel, velocidade), velocidade)
    end
end

function AnalisarFlags()
    for nome, estado in pairs(estadoJogadores) do
        local total = estado.totalFlags
        if total >= THRESH.FLAGS_BAN_SUGERIDO then
            Log("DETECTION", string.format("🚨 BAN SUGERIDO → %s (%d flags)", nome, total), "warn")
        elseif total >= THRESH.FLAGS_ALERTA then
            Log("DETECTION", string.format("⚠️ ALERTA → %s (%d flags)", nome, total), "warn")
        end
    end
end

-- ====================== SIMULAÇÕES ======================
local function posAleatoriaAoRedor(centro, raio)
    local ang = math.random() * 2 * math.pi
    local dist = math.random(raio//2, raio)
    return Vector3.new(centro.X + math.cos(ang)*dist, centro.Y, centro.Z + math.sin(ang)*dist)
end

local function estaEmLOS(posicao)
    local origem = Camera.CFrame.Position
    local direcao = (posicao - origem).Unit
    local dist = (posicao - origem).Magnitude
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character or {}}
    local result = workspace:Raycast(origem, direcao * dist, params)
    return result == nil or result.Distance >= dist - 2
end

local function simularAim(precisao)
    local nome = LocalPlayer.Name
    Log("SIM-AIM", string.format("Iniciando simulação de mira (%.0f%% precisão)", precisao*100))

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    local alvos = {}
    for i = 1, 5 do
        local p = Instance.new("Part")
        p.Size = Vector3.new(2,2,2)
        p.Position = posAleatoriaAoRedor(hrp.Position, 40)
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 0.7
        p.BrickColor = BrickColor.new("Bright yellow")
        p.Parent = workspace
        p.Name = "ADMAlvo_"..i
        table.insert(alvos, p)
    end

    task.spawn(function()
        for i = 1, CONFIG.NUM_DISPAROS do
            if not simAtiva then break end
            local alvo = alvos[math.random(1,#alvos)]
            if not alvo then continue end

            local tReacao = (precisao >= CONFIG.PRECISAO_SUSPEITA) and (math.random(20,60)/1000) or (math.random(120,380)/1000)
            task.wait(tReacao)

            local acertou = math.random() <= precisao
            dadosSessao.totalDisparos += 1
            if acertou then dadosSessao.acertos += 1 end
            table.insert(dadosSessao.temposReacao, tReacao)

            RegistrarDisparo(nome, acertou, tReacao)

            task.wait(math.random(10,30)/100)
        end

        -- Limpeza
        for _, a in ipairs(alvos) do if a and a.Parent then a:Destroy() end end

        local taxa = dadosSessao.totalDisparos > 0 and (dadosSessao.acertos / dadosSessao.totalDisparos) or 0
        local reacaoMedia = 0
        if #dadosSessao.temposReacao > 0 then
            local soma = 0
            for _, t in ipairs(dadosSessao.temposReacao) do soma += t end
            reacaoMedia = soma / #dadosSessao.temposReacao
        end

        Log("SIM-AIM", string.format("Fim da simulação | Acerto: %.1f%% | Reação média: %.0fms", taxa*100, reacaoMedia*1000))
        AnalisarAim(nome, taxa, reacaoMedia)
        simAtiva = false
    end)
end

local function simularVisao()
    local nome = LocalPlayer.Name
    Log("SIM-LOS", "Iniciando simulação de rastreamento LOS")

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local alvos = {}
    for i = 1, CONFIG.NUM_ALVOS do
        local p = Instance.new("Part")
        p.Size = Vector3.new(1.5,1.5,1.5)
        p.Position = posAleatoriaAoRedor(char.HumanoidRootPart.Position, 60)
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 0.8
        p.BrickColor = BrickColor.new("Cyan")
        p.Parent = workspace
        p.Name = "ADMLOSAlvo_"..i
        table.insert(alvos, p)
    end

    local iter = 0
    local conn = RunService.Heartbeat:Connect(function()
        iter += 1
        if iter > 60 then
            conn:Disconnect()
            for _, a in ipairs(alvos) do if a and a.Parent then a:Destroy() end end

            local pct = dadosSessao.totalRastreios > 0 and (dadosSessao.rastreioForaLOS / dadosSessao.totalRastreios) or 0
            Log("SIM-LOS", string.format("LOS finalizado | Fora de visão: %.1f%%", pct*100))
            AnalisarVisao(nome, pct)
            return
        end

        for _, alvo in ipairs(alvos) do
            if alvo and alvo.Parent then
                local emLOS = estaEmLOS(alvo.Position)
                dadosSessao.totalRastreios += 1
                if not emLOS then
                    dadosSessao.rastreioForaLOS += 1
                    alvo.BrickColor = BrickColor.new("Bright red")
                else
                    alvo.BrickColor = BrickColor.new("Bright green")
                end
            end
        end
    end)
    table.insert(conexoes, conn)
end

local function simularVelocidade()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local velOriginal = hum.WalkSpeed
    local nome = LocalPlayer.Name

    Log("SIM-VEL", "Iniciando simulação de velocidade")

    task.spawn(function()
        local fases = {
            {vel=16,  dur=1.5, label="Normal"},
            {vel=24,  dur=1.5, label="Leve"},
            {vel=32,  dur=1.5, label="SUSPEITO"},
            {vel=50,  dur=1.0, label="CRÍTICO"},
            {vel=16,  dur=1.0, label="Restaurando"},
        }
        for _, f in ipairs(fases) do
            hum.WalkSpeed = f.vel
            table.insert(dadosSessao.velocidades, f.vel)
            RegistrarVelocidade(nome, f.vel)
            Log("SIM-VEL", string.format("WalkSpeed = %d → %s", f.vel, f.label))
            task.wait(f.dur)
        end
        hum.WalkSpeed = velOriginal
        Log("SIM-VEL", "Velocidade restaurada")
    end)
end

-- ====================== INTERFACE ======================
local function criarBotao(parent, texto, posY, callback, corFundo)
    corFundo = corFundo or COR.AMARELO
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 44)
    btn.Position = UDim2.new(0, 0, 0, posY)
    btn.BackgroundColor3 = corFundo
    btn.Text = texto
    btn.TextColor3 = COR.FUNDO
    btn.TextSize = 15
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.ZIndex = 10
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = COR.AMARELO_HOVER}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = corFundo}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    return btn
end

local function construirMenu()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ADMDevGUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = PlayerGui

    -- Menu Principal
    frameMenu = Instance.new("Frame")
    frameMenu.Size = UDim2.new(0, 300, 0, 380)
    frameMenu.Position = UDim2.new(0.5, -150, 0.5, -190)
    frameMenu.BackgroundColor3 = COR.FUNDO_PAINEL
    frameMenu.BorderSizePixel = 0
    frameMenu.Visible = false
    frameMenu.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frameMenu

    -- Top Bar Amarela
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1,0,0,4)
    top.BackgroundColor3 = COR.AMARELO
    top.BorderSizePixel = 0
    top.Parent = frameMenu
    Instance.new("UICorner", top).CornerRadius = UDim.new(0,4)

    -- Título
    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1,-20,0,28)
    titulo.Position = UDim2.new(0,10,0,82)
    titulo.BackgroundTransparency = 1
    titulo.Text = "ADM DEV 1.0"
    titulo.TextColor3 = COR.AMARELO
    titulo.TextSize = 22
    titulo.Font = Enum.Font.GothamBold
    titulo.Parent = frameMenu

    local subt = Instance.new("TextLabel")
    subt.Size = UDim2.new(1,-20,0,20)
    subt.Position = UDim2.new(0,10,0,110)
    subt.BackgroundTransparency = 1
    subt.Text = "Lord Santos • Teste Anticheat"
    subt.TextColor3 = COR.TEXTO_CINZA
    subt.TextSize = 12
    subt.Font = Enum.Font.Gotham
    subt.Parent = frameMenu

    -- Botões
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,-40,0,175)
    container.Position = UDim2.new(0,20,0,155)
    container.BackgroundTransparency = 1
    container.Parent = frameMenu

    criarBotao(container, "▶  JOGAR",           0,   callbacks.onPlay)
    criarBotao(container, "⚙  CONFIGURAÇÕES",   54,  callbacks.onSettings, COR.FUNDO_CARD)
    criarBotao(container, "🎯  TESTE DE MIRA",  108, callbacks.onAimTest,  COR.FUNDO_CARD)

    -- Botão Fechar
    local fechar = Instance.new("TextButton")
    fechar.Size = UDim2.new(0,28,0,28)
    fechar.Position = UDim2.new(1,-38,0,10)
    fechar.BackgroundColor3 = COR.FUNDO_CARD
    fechar.Text = "✕"
    fechar.TextColor3 = COR.TEXTO_CINZA
    fechar.TextSize = 14
    fechar.Font = Enum.Font.GothamBold
    fechar.Parent = frameMenu
    Instance.new("UICorner", fechar).CornerRadius = UDim.new(0,6)
    fechar.MouseButton1Click:Connect(function() ADMDev.FecharMenu() end)
end

-- ====================== API PÚBLICA ======================
function ADMDev.Init(cbs)
    callbacks = cbs or {
        onPlay = function() Log("UI", "JOGAR pressionado"); ADMDev.FecharMenu() end,
        onSettings = function() Log("UI", "CONFIGURAÇÕES"); end,
        onAimTest = function()
            Log("UI", "Iniciando TESTE COMPLETO")
            ADMDev.FecharMenu()
            ADMDev.IniciarTesteCompleto()
        end,
    }

    construirMenu()

    -- Tecla K
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.K then
            menuAberto = not menuAberto
            if menuAberto then
                frameMenu.Visible = true
                Log("UI", "Menu aberto")
            else
                frameMenu.Visible = false
                Log("UI", "Menu fechado")
            end
        end
    end)

    Log("SYSTEM", "ADM DEV 1.0 carregado com sucesso! Pressione K para abrir o menu.")
end

function ADMDev.IniciarTesteCompleto()
    if simAtiva then Log("SIM", "Simulação já em andamento!", "warn") return end
    simAtiva = true

    local precisao = CONFIG.PRECISAO_SUSPEITA
    simularAim(precisao)
    task.delay(1, simularVisao)
    task.delay(2, simularVelocidade)
end

function ADMDev.FecharMenu()
    if frameMenu then frameMenu.Visible = false end
    menuAberto = false
end

function ADMDev.AbrirMenu()
    if frameMenu then frameMenu.Visible = true end
    menuAberto = true
end

-- Retorna o módulo
return ADMDev
