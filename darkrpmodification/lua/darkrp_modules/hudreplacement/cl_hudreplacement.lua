--[[---------------------------------------------------------------------------
STALKER RP HUD replacement
---------------------------------------------------------------------------
Стандартная панель DarkRP (здоровье/профессия/кошелёк) заменена плашкой КПК
в общей теме сборки (STALKER_THEME / STALKER_STYLE).
Здоровье, броню, радиацию и потребности рисует HUD группировок (stfw_hud 1).
Если он выключен, эта плашка показывает здоровье и броню сама.
Агенда, голосовой чат, надписи над игроками и уведомления DarkRP остаются.
---------------------------------------------------------------------------]]

local hideHUDElements = {
    ["DarkRP_HUD"] = false,
    ["DarkRP_EntityDisplay"] = false,
    ["DarkRP_LocalPlayerHUD"] = true,
    ["DarkRP_Hungermod"] = true,
    ["DarkRP_Agenda"] = false,
    ["DarkRP_LockdownHUD"] = false,
    ["DarkRP_ArrestedHUD"] = false,
    ["DarkRP_ChatReceivers"] = false,
}

hook.Add("HUDShouldDraw", "HideDefaultDarkRPHud", function(name)
    if hideHUDElements[name] then return false end
end)

-- Цвета и масштаб — из темы ядра; без ядра плашка не рисуется (STALKER Core обязателен для сборки).
local function px(n) return STALKER_THEME.Px(n) end
local function col(token) return STALKER_THEME.C[token] end
local function themeReady()
    return STALKER_THEME and STALKER_THEME.C and STALKER_THEME.Px and STALKER_STYLE and STALKER_STYLE.Panel and STALKER_STYLE.Text
end

local function factionHUDActive()
    local cvar = GetConVar("stfw_hud")
    return STFW and STFW.State and cvar and cvar:GetBool()
end

local function menuOpen()
    return (STALKER_INV and IsValid(STALKER_INV.Frame)) or (STALKER_NPC and IsValid(STALKER_NPC.Window))
        or (STALKER_PDA and STALKER_PDA.IsOpen and STALKER_PDA.IsOpen())
end

hook.Add("HUDPaint", "STALKER.RPHud", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or menuOpen() or not themeReady() then return end
    if hook.Run("HUDShouldDraw", "STALKER_RPHud") == false then return end
    local U = STALKER_STYLE

    local vitals = not factionHUDActive()
    local w, h = px(240), vitals and px(86) or px(54)
    local x, y = px(24), ScrH() - px(28) - h
    U.Panel("", x, y, w, h, false)

    local job = ply:getDarkRPVar("job") or team.GetName(ply:Team())
    local money = ply:getDarkRPVar("money") or 0
    local salary = ply:getDarkRPVar("salary") or 0
    -- Цвет профессии — цвет группировки из jobs.lua (конфиг), остальное — токены темы.
    U.Text(U.Fit(job, "STALKER.Body", w * .55), "STALKER.Body", x + px(10), y + px(7), team.GetColor(ply:Team()))
    U.Text(DarkRP.formatMoney(money), "STALKER.Body", x + w - px(10), y + px(7), "accent", TEXT_ALIGN_RIGHT)
    U.Text("КПК / СЧЁТ", "STALKER.Mono", x + px(10), y + px(31), "muted")
    U.Text(salary > 0 and ("+" .. DarkRP.formatMoney(salary) .. " / выплата") or "без жалования", "STALKER.Mono", x + w - px(10), y + px(31), "muted", TEXT_ALIGN_RIGHT)

    if vitals then
        local hp, maxHp = math.max(0, ply:Health()), math.max(1, ply:GetMaxHealth())
        U.Text("HP " .. hp, "STALKER.Mono", x + px(10), y + px(51), "text")
        U.Bar(x + px(74), y + px(54), w - px(84), px(6), hp / maxHp, col(hp / maxHp < .3 and "danger" or "ok"))
        U.Text("БРОНЯ " .. ply:Armor(), "STALKER.Mono", x + px(10), y + px(67), "text")
        U.Bar(x + px(74), y + px(70), w - px(84), px(6), ply:Armor() / 100, col("accent"))
    end
end)
