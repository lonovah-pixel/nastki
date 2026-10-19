--[[-----------------------------------------------------------------------
Categories
---------------------------------------------------------------------------
The categories of the default F4 menu.

Please read this page for more information:
https://darkrp.miraheze.org/wiki/DarkRP:Categories

STALKER RP: меню F4 DarkRP отключено (F4 — КПК), категории группируют
профессии в таблице игроков. Оружие, патроны и снаряжение продают торговцы
Зоны через STALKER Inventory.
---------------------------------------------------------------------------]]

DarkRP.createCategory{
    name = "Вольные сталкеры",
    categorises = "jobs",
    startExpanded = true,
    color = Color(181, 159, 94, 255),
    canSee = function(ply) return true end,
    sortOrder = 10,
}

DarkRP.createCategory{
    name = "Группировки",
    categorises = "jobs",
    startExpanded = true,
    color = Color(180, 65, 48, 255),
    canSee = function(ply) return true end,
    sortOrder = 20,
}

DarkRP.createCategory{
    name = "Наука и экология",
    categorises = "jobs",
    startExpanded = true,
    color = Color(204, 161, 72, 255),
    canSee = function(ply) return true end,
    sortOrder = 30,
}

DarkRP.createCategory{
    name = "Служебное",
    categorises = "jobs",
    startExpanded = false,
    color = Color(110, 114, 96, 255),
    canSee = function(ply) return ply:IsAdmin() end,
    sortOrder = 100,
}
