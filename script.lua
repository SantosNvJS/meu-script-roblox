-- ================================================
-- CHEAT LUA - SCRIPT COMPLETO EM UM ÚNICO ARQUIVO
-- FPS Hacker para o seu jogo (feito por Grok)
-- Abra/fecha o menu com a tecla K
-- Tudo pronto pra você subir no GitHub
-- ================================================

local Cheat = {}

-- ====================== CONFIGURAÇÕES ======================
Cheat.Config = {
    enabled = true,

    aimbot = {
        enabled = true,
        fov = 120,
        smooth = 0.35,
        bone = "head",          -- "head", "chest", "spine"
        teamCheck = true,
        visibleCheck = true
    },

    esp = {
        enabled = true,
        boxes = true,
        names = true,
        health = true,
        distance = true,
        color_enemy = {1, 0, 0, 1},
        color_ally  = {0, 1, 0, 1}
    },

    triggerbot = { enabled = true, delay = 0 },
    norecoil   = { enabled = true, intensity = 0.7 },
    speedhack  = { enabled = false, multiplier = 1.8 },
    bhop       = { enabled = true }
}

-- ====================== UTILS (adapte pro seu motor) ======================
Cheat.Utils = {}

function Cheat.Utils.GetLocalPlayer()
    -- SUBSTITUA pela função do SEU jogo
    return game:GetService("Players").LocalPlayer  -- exemplo Roblox/Lua
end

function Cheat.Utils.GetPlayers()
    -- Retorna todos os jogadores (menos o local)
    local players = {}
    -- Exemplo: for _, plr in ipairs(game.Players:GetPlayers()) do
    return players
end

function Cheat.Utils.WorldToScreen(pos)
    -- Retorna {x = num, y = num, onScreen = bool} ou nil
    -- Implemente com a câmera do seu jogo
    return {x = 0, y = 0, onScreen = false}
end

function Cheat.Utils.IsVisible(ent)
    -- Raycast do local até o alvo
    return true  -- adapte
end

function Cheat.Utils.GetBonePosition(player, bone)
    -- Retorna posição do osso (vector)
    return player.Position or {x=0,y=0,z=0}
end

-- Funções de desenho (exemplo com Love2D - adapte pro seu framework)
function Cheat.Utils.DrawRect(x, y, w, h, color)
    love.graphics.setColor(color)
    love.graphics.rectangle("line", x, y, w, h)
end

function Cheat.Utils.DrawText(text, x, y, color)
    love.graphics.setColor(color or {1,1,1,1})
    love.graphics.print(text, x, y)
end

function Cheat.Utils.DrawLine(x1,y1,x2,y2,color)
    love.graphics.setColor(color)
    love.graphics.line(x1,y1,x2,y2)
end

-- ====================== MÓDULOS (tudo dentro do Cheat) ======================

-- AIMBOT
Cheat.Aimbot = {}
function Cheat.Aimbot.GetBestTarget()
    if not Cheat.Config.aimbot.enabled then return nil end
    local localPlayer = Cheat.Utils.GetLocalPlayer()
    local bestTarget = nil
    local bestFov = Cheat.Config.aimbot.fov

    for _, player in ipairs(Cheat.Utils.GetPlayers()) do
        if player ~= localPlayer and (not Cheat.Config.aimbot.teamCheck or player.team ~= localPlayer.team) then
            local headPos = Cheat.Utils.GetBonePosition(player, Cheat.Config.aimbot.bone)
            local screen = Cheat.Utils.WorldToScreen(headPos)

            if screen and screen.onScreen then
                local centerX, centerY = love.graphics.getWidth()/2, love.graphics.getHeight()/2
                local dist = math.sqrt((screen.x - centerX)^2 + (screen.y - centerY)^2)

                if dist < bestFov and (not Cheat.Config.aimbot.visibleCheck or Cheat.Utils.IsVisible(player)) then
                    bestFov = dist
                    bestTarget = player
                end
            end
        end
    end
    return bestTarget
end

function Cheat.Aimbot.Update()
    local target = Cheat.Aimbot.GetBestTarget()
    if not target then return end

    local targetPos = Cheat.Utils.GetBonePosition(target, Cheat.Config.aimbot.bone)
    local localAngles = Cheat.Utils.GetLocalPlayer().ViewAngles  -- adapte

    local newAngles = localAngles:LookAt(targetPos)  -- adapte
    newAngles = localAngles:Lerp(newAngles, Cheat.Config.aimbot.smooth)

    Cheat.Utils.GetLocalPlayer().ViewAngles = newAngles  -- adapte
end

-- ESP
Cheat.ESP = {}
function Cheat.ESP.Draw()
    if not Cheat.Config.esp.enabled then return end

    for _, player in ipairs(Cheat.Utils.GetPlayers()) do
        local pos = player.Position  -- adapte
        local screen = Cheat.Utils.WorldToScreen(pos)
        if not screen or not screen.onScreen then goto continue end

        local headScreen = Cheat.Utils.WorldToScreen(Cheat.Utils.GetBonePosition(player, "head"))
        local footScreen = Cheat.Utils.WorldToScreen(Cheat.Utils.GetBonePosition(player, "spine"))

        if not headScreen or not footScreen then goto continue end

        local height = headScreen.y - footScreen.y
        local width = height / 2.2
        local x = headScreen.x - width / 2
        local y = headScreen.y

        local color = (player.team == Cheat.Utils.GetLocalPlayer().team) and Cheat.Config.esp.color_ally or Cheat.Config.esp.color_enemy

        if Cheat.Config.esp.boxes then
            Cheat.Utils.DrawRect(x, y, width, height, color)
        end

        if Cheat.Config.esp.names then
            local dist = (pos - Cheat.Utils.GetLocalPlayer().Position).magnitude or 0
            Cheat.Utils.DrawText(player.name .. " [" .. math.floor(dist) .. "m]", x, y - 18, {1,1,1,1})
        end

        ::continue::
    end
end

-- TRIGGERBOT
Cheat.Triggerbot = {}
function Cheat.Triggerbot.Update()
    if not Cheat.Config.triggerbot.enabled then return end
    -- Aqui você coloca o raycast do crosshair e atira automaticamente
    -- Exemplo: if IsEnemyUnderCrosshair() then Shoot() end
end

-- NORECOIL
Cheat.NoRecoil = {}
function Cheat.NoRecoil.Apply(recoilVector)
    if not Cheat.Config.norecoil.enabled then return recoilVector end
    return recoilVector * (1 - Cheat.Config.norecoil.intensity)
end

-- SPEEDHACK (chame no update do movimento do player)
Cheat.Speedhack = {}
function Cheat.Speedhack.Apply(speed)
    if not Cheat.Config.speedhack.enabled then return speed end
    return speed * Cheat.Config.speedhack.multiplier
end

-- BHOP
Cheat.Bhop = {}
function Cheat.Bhop.Update()
    if not Cheat.Config.bhop.enabled then return end
    -- Se estiver no chão e apertar espaço → pula novamente
end

-- ====================== MENU (abre/fecha com K) ======================
Cheat.Menu = {
    open = false,
    selected = 1,
    options = {
        {name = "Aimbot",          key = "aimbot"},
        {name = "ESP",             key = "esp"},
        {name = "Triggerbot",      key = "triggerbot"},
        {name = "No Recoil",       key = "norecoil"},
        {name = "Speedhack",       key = "speedhack"},
        {name = "Bunny Hop",       key = "bhop"},
        {name = "Ativar/Desativar Tudo", key = "global"}
    }
}

function Cheat.Menu.Toggle()
    Cheat.Menu.open = not Cheat.Menu.open
end

function Cheat.Menu.Draw()
    if not Cheat.Menu.open then return end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", w/2 - 200, 100, 400, 400)

    love.graphics.setColor(0, 1, 1, 1)
    love.graphics.print("=== MENU HACKER FPS ===", w/2 - 120, 120)
    love.graphics.print("Pressione K para fechar", w/2 - 130, 145)

    for i, opt in ipairs(Cheat.Menu.options) do
        local y = 180 + (i-1)*35
        local active = Cheat.Config[opt.key] and Cheat.Config[opt.key].enabled or (opt.key == "global" and Cheat.Config.enabled)

        love.graphics.setColor(1,1,1,1)
        if i == Cheat.Menu.selected then
            love.graphics.print("→", w/2 - 180, y)
        end

        love.graphics.print(opt.name, w/2 - 150, y)
        love.graphics.print(active and "[ON]" or "[OFF]", w/2 + 100, y)
    end

    love.graphics.setColor(1,1,1,0.6)
    love.graphics.print("Setas ↑↓ = selecionar | ENTER = toggle", w/2 - 170, 460)
end

function Cheat.Menu.KeyPressed(key)
    if not Cheat.Menu.open then return end

    if key == "up" then
        Cheat.Menu.selected = math.max(1, Cheat.Menu.selected - 1)
    elseif key == "down" then
        Cheat.Menu.selected = math.min(#Cheat.Menu.options, Cheat.Menu.selected + 1)
    elseif key == "return" then
        local opt = Cheat.Menu.options[Cheat.Menu.selected]
        if opt.key == "global" then
            Cheat.Config.enabled = not Cheat.Config.enabled
        else
            if Cheat.Config[opt.key] then
                Cheat.Config[opt.key].enabled = not Cheat.Config[opt.key].enabled
            end
        end
    end
end

-- ====================== FUNÇÕES PRINCIPAIS (chame no seu jogo) ======================

-- Chame isso no love.keypressed(key) ou no seu input handler
function Cheat:KeyPressed(key)
    if key == "k" then
        Cheat.Menu.Toggle()
        return
    end

    Cheat.Menu.KeyPressed(key)
end

-- Chame isso todo frame no Update(dt) do seu jogo
function Cheat:Update(dt)
    if not Cheat.Config.enabled then return end

    Cheat.Aimbot.Update()
    Cheat.Triggerbot.Update()
    Cheat.Bhop.Update()
    -- Speedhack e NoRecoil são aplicados onde você movimenta o player
end

-- Chame isso no Draw() do seu jogo (depois do resto do jogo)
function Cheat:Draw()
    Cheat.ESP.Draw()
    Cheat.Menu.Draw()
end

-- ====================== INICIALIZAÇÃO ======================
print("✅ Cheat Lua carregado com sucesso!")
print("   Pressione K para abrir o menu")

-- Para usar no seu jogo:
-- 1. Coloque esse arquivo como "cheat.lua"
-- 2. No seu main.lua faça:
--    local Cheat = require("cheat")
--    function love.keypressed(key) Cheat:KeyPressed(key) end
--    function love.update(dt) Cheat:Update(dt) end
--    function love.draw() Cheat:Draw() end

return Cheat
