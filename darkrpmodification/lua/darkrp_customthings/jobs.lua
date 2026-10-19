--[[---------------------------------------------------------------------------
DarkRP custom jobs — STALKER RP
---------------------------------------------------------------------------
Стандартные профессии DarkRP отключены в darkrp_config/disabled_defaults.lua.

Членство в группировке выдаёт STALKER Factions (вербовщик или приглашение
лидера). Меню F4 DarkRP отключено (F4 — КПК), ручная смена профессии запрещена:
модуль darkrp_modules/stalker_jobs сам выдаёт профессию группировки при
вступлении и возвращает на «Сталкера» при выходе или исключении. Поле
stalkerFaction связывает профессию с ID фракции; customCheck не даёт её чужим
даже при принудительной смене.

Снаряжение не выдаётся профессией: оружие и броня экипируются из инвентаря
(TAB), иначе инвентарь откажется выдавать SWEP того же класса.

Документация по полям: https://darkrp.miraheze.org/wiki/DarkRP:CustomJobFields
---------------------------------------------------------------------------]]

-- Член группировки по сетевым переменным STALKER Factions (видны и в F4 на клиенте).
local function stalkerMember(faction)
    return function(ply)
        return ply:GetNW2Bool("stfw_joined", false) and ply:GetNW2String("stfw_faction", "") == faction
    end
end

local function factionJob(name, data)
    data.customCheck = stalkerMember(data.stalkerFaction)
    data.CustomCheckFailMsg = data.CustomCheckFailMsg or ("Профессия выдаётся членам группировки «" .. data.factionName .. "»: вступите у её вербовщика или по приглашению лидера.")
    data.factionName = nil
    data.weapons = data.weapons or {}
    data.max = data.max or 0
    data.admin = 0
    data.vote = false
    data.hasLicense = false
    data.candemote = true
    data.category = data.category or "Группировки"
    return DarkRP.createJob(name, data)
end

local citizens = {}
for i = 1, 9 do citizens[#citizens + 1] = "models/player/Group01/male_0" .. i .. ".mdl" end
for i = 1, 6 do citizens[#citizens + 1] = "models/player/Group01/female_0" .. i .. ".mdl" end
for i = 1, 4 do citizens[#citizens + 1] = "models/player/hostage/hostage_0" .. i .. ".mdl" end

local rebels = {}
for i = 1, 9 do rebels[#rebels + 1] = "models/player/Group03/male_0" .. i .. ".mdl" end
for i = 1, 6 do rebels[#rebels + 1] = "models/player/Group03/female_0" .. i .. ".mdl" end

local refugees = {
    "models/player/Group02/male_02.mdl", "models/player/Group02/male_04.mdl",
    "models/player/Group02/male_06.mdl", "models/player/Group02/male_08.mdl",
}

--[[---------------------------------------------------------------------------
Вольные сталкеры
---------------------------------------------------------------------------]]
TEAM_STALKER = DarkRP.createJob("Сталкер", {
    color = Color(181, 159, 94, 255),
    model = citizens,
    description = [[Вольный бродяга Зоны.
Ищет артефакты, разделывает мутантов, торгует с барыгами и выживает.
Вступить в группировку можно у её вербовщика (клавиша E)
или по приглашению лидера — профессия группировки выдаётся сама.]],
    weapons = {},
    command = "stalker",
    max = 0,
    salary = 15,
    admin = 0,
    vote = false,
    hasLicense = false,
    candemote = false,
    category = "Вольные сталкеры",
    sortOrder = 1,
})

--[[---------------------------------------------------------------------------
Группировки (только для действующих членов)
---------------------------------------------------------------------------]]
TEAM_DUTY = factionJob("Боец «Долга»", {
    stalkerFaction = "duty", factionName = "Долг",
    color = Color(180, 65, 48, 255),
    model = {"models/player/swat.mdl", "models/player/urban.mdl"},
    description = [[Дисциплинированная военизированная группировка.
Цель — защитить мир от угроз Зоны. Враждует со «Свободой».]],
    command = "duty", salary = 40, sortOrder = 10,
})

TEAM_FREEDOM = factionJob("Боец «Свободы»", {
    stalkerFaction = "freedom", factionName = "Свобода",
    color = Color(109, 151, 73, 255),
    model = rebels,
    description = [[Анархисты, считающие, что Зона должна быть открыта для всех.
Враждуют с «Долгом».]],
    command = "freedom", salary = 35, sortOrder = 11,
})

TEAM_BANDIT = factionJob("Бандит", {
    stalkerFaction = "bandits", factionName = "Бандиты",
    color = Color(140, 120, 101, 255),
    model = {"models/player/leet.mdl", "models/player/phoenix.mdl"},
    description = [[Вымогательство, контрабанда и «налоги» на тропах.
Не любят ни военных, ни одиночек.]],
    command = "bandit", salary = 25, sortOrder = 12,
})

TEAM_MERC = factionJob("Наёмник", {
    stalkerFaction = "mercs", factionName = "Наёмники",
    color = Color(84, 126, 167, 255),
    model = {"models/player/riot.mdl"},
    description = [[Профессиональные бойцы по контракту.
Работают на того, кто платит.]],
    command = "merc", salary = 45, sortOrder = 13,
})

TEAM_MONOLITH = factionJob("Монолитовец", {
    stalkerFaction = "monolith", factionName = "Монолит",
    color = Color(180, 190, 187, 255),
    model = {"models/player/combine_super_soldier.mdl", "models/player/combine_soldier.mdl"},
    description = [[Фанатичные защитники центра Зоны.
Служат Монолиту и не идут на переговоры с чужаками.]],
    command = "monolith", salary = 35, sortOrder = 14,
})

TEAM_MILITARY = factionJob("Военный", {
    stalkerFaction = "military", factionName = "Военные",
    color = Color(126, 142, 79, 255),
    model = {"models/player/gasmask.mdl", "models/player/soldier_stripped.mdl"},
    description = [[Подразделения, контролирующие периметр Зоны.
Приказ, порядок, контроль.]],
    command = "military", salary = 50, sortOrder = 15,
})

TEAM_CLEARSKY = factionJob("Боец «Чистого Неба»", {
    stalkerFaction = "clearsky", factionName = "Чистое Небо",
    color = Color(108, 184, 189, 255),
    model = {"models/player/guerilla.mdl", "models/player/odessa.mdl"},
    description = [[Исследователи-болотники, ищущие равновесие в Зоне.
Дружат с учёными.]],
    command = "clearsky", salary = 35, sortOrder = 16,
})

TEAM_RENEGADE = factionJob("Ренегат", {
    stalkerFaction = "renegades", factionName = "Ренегаты",
    color = Color(154, 115, 74, 255),
    model = refugees,
    description = [[Изгнанники и отколовшиеся сталкеры.
Выжить любой ценой.]],
    command = "renegade", salary = 20, sortOrder = 17,
})

TEAM_SCIENTIST = factionJob("Учёный", {
    stalkerFaction = "scientists", factionName = "Учёные",
    color = Color(204, 161, 72, 255),
    model = {"models/player/kleiner.mdl", "models/player/mossman.mdl", "models/player/magnusson.mdl", "models/player/eli.mdl"},
    description = [[Научные экспедиции и полевые лаборатории.
Скупают артефакты и образцы мутантов, нанимают охрану.]],
    command = "scientist", salary = 45, category = "Наука и экология", sortOrder = 20,
})

TEAM_ECOLOGIST = factionJob("Эколог", {
    stalkerFaction = "ecologists", factionName = "Экологи",
    color = Color(179, 176, 89, 255),
    model = {"models/player/arctic.mdl", "models/player/mossman_arctic.mdl"},
    description = [[Специалисты по аномальной среде в защитных костюмах.
Изучают последствия выбросов и радиационный фон.]],
    command = "ecologist", salary = 40, category = "Наука и экология", sortOrder = 21,
})

--[[---------------------------------------------------------------------------
Служебное
---------------------------------------------------------------------------]]
TEAM_ZONEADMIN = DarkRP.createJob("Администрация", {
    color = Color(110, 114, 96, 255),
    model = {"models/player/gman_high.mdl"},
    description = [[Служебная профессия для модерации.
Не участвует в отыгрыше и не вмешивается в конфликты игроков.]],
    weapons = {},
    command = "zoneadmin",
    max = 0,
    salary = 0,
    admin = 1,
    vote = false,
    hasLicense = false,
    candemote = false,
    category = "Служебное",
    sortOrder = 100,
})

--[[---------------------------------------------------------------------------
Define which team joining players spawn into and what team you change to if demoted
---------------------------------------------------------------------------]]
GAMEMODE.DefaultTeam = TEAM_STALKER

--[[---------------------------------------------------------------------------
Define which teams belong to civil protection
В Зоне нет полиции DarkRP: ордера, розыск и арест отключены.
---------------------------------------------------------------------------]]
GAMEMODE.CivilProtection = {}
