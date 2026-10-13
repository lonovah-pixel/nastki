--[[---------------------------------------------------------------------------
STALKER RP HUD replacement
---------------------------------------------------------------------------
Стандартная панель DarkRP (здоровье/профессия/кошелёк) заменена плашкой КПК.
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

local colors = {
    text = Color(217, 207, 176), muted = Color(138, 143, 115), accent = Color(200, 169, 81),
    green = Color(112, 158, 91), red = Color(179, 68, 48), back = Color(25, 27, 22, 235), line = Color(91, 91, 71),
}
local scale = 1
local function px(n) return math.Round(n * scale) end
local function fonts()
    scale = math.Clamp(ScrH() / 900, .85, 1.8)
    surface.CreateFont("STALKER.RPHud", {font = "Tahoma", size = px(14), weight = 600, extended = true})
    surface.CreateFont("STALKER.RPHudSmall", {font = "Consolas", size = px(11), weight = 500, extended = true})
end
fonts()
hook.Add("OnScreenSizeChanged", "STALKER.RPHudFonts", fonts)

local function panel(x, y, w, h)
    if STALKER_STYLE and STALKER_STYLE.Panel then
        STALKER_STYLE.Panel("stalker_inv", x, y, w, h, false)
    else
        surface.SetDrawColor(colors.back); surface.DrawRect(x, y, w, h)
        surface.SetDrawColor(colors.line); surface.DrawOutlinedRect(x, y, w, h, 1)
    end
end

local function bar(x, y, w, h, ratio, col)
    if STALKER_STYLE and STALKER_STYLE.Bar then return STALKER_STYLE.Bar(x, y, w, h, ratio, col) end
    surface.SetDrawColor(9, 12, 8, 240); surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(col); surface.DrawRect(x + 1, y + 1, (w - 2) * math.Clamp(ratio, 0, 1), h - 2)
end

local function factionHUDActive()
    local cvar = GetConVar("stfw_hud")
    return STFW and STFW.State and cvar and cvar:GetBool()
end

local function menuOpen()
    return (STALKER_INV and IsValid(STALKER_INV.Frame)) or (STALKER_NPC and IsValid(STALKER_NPC.Window))
end

hook.Add("HUDPaint", "STALKER.RPHud", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or menuOpen() then return end
    if hook.Run("HUDShouldDraw", "STALKER_RPHud") == false then return end

    local vitals = not factionHUDActive()
    local w, h = px(232), vitals and px(84) or px(52)
    local x, y = px(24), ScrH() - px(28) - h
    panel(x, y, w, h)

    local job = ply:getDarkRPVar("job") or team.GetName(ply:Team())
    local money = ply:getDarkRPVar("money") or 0
    local salary = ply:getDarkRPVar("salary") or 0
    draw.SimpleText(job, "STALKER.RPHud", x + px(10), y + px(7), team.GetColor(ply:Team()))
    draw.SimpleText(DarkRP.formatMoney(money), "STALKER.RPHud", x + w - px(10), y + px(7), colors.accent, TEXT_ALIGN_RIGHT)
    draw.SimpleText("КПК / СЧЁТ", "STALKER.RPHudSmall", x + px(10), y + px(30), colors.muted)
    draw.SimpleText(salary > 0 and ("+" .. DarkRP.formatMoney(salary) .. " / выплата") or "без жалования", "STALKER.RPHudSmall", x + w - px(10), y + px(30), colors.muted, TEXT_ALIGN_RIGHT)

    if vitals then
        local hp, maxHp = math.max(0, ply:Health()), math.max(1, ply:GetMaxHealth())
        draw.SimpleText("HP " .. hp, "STALKER.RPHudSmall", x + px(10), y + px(50), colors.text)
        bar(x + px(70), y + px(53), w - px(80), px(6), hp / maxHp, hp / maxHp < .3 and colors.red or colors.green)
        draw.SimpleText("БРОНЯ " .. ply:Armor(), "STALKER.RPHudSmall", x + px(10), y + px(66), colors.text)
        bar(x + px(70), y + px(69), w - px(80), px(6), ply:Armor() / 100, colors.accent)
    end
end)
