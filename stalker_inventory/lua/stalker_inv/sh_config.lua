local S = STALKER_INV
S.Config = {
    Width = 960, Height = 600, Columns = 8, Rows = 5, Slot = 64, QuickSlot = 48,
    DarkRP = {UseHunger=true, DisableStarter=true},
    MaxWeight = 50, OverweightSpeed = 0.55, Autosave = 30,
    -- Личные тайники: сущность в мире видна и доступна только владельцу.
    -- StashSlots — вместимость НОВЫХ тайников (хранится в самом тайнике: stash.slots);
    -- старые тайники без поля сохраняют прежние LegacyStashSlots ячеек, чтобы ничего не потерять.
    MaxStashes = 3, StashSlots = 12, LegacyStashSlots = 20, StashRange = 150, StashUseRange = 120,
    -- Компактная модель: небольшой свёрток не бросается в глаза; запасная — портфель.
    StashModel = "models/props_junk/garbage_bag001a.mdl", StashModelFallback = "models/props_c17/BriefCase001a.mdl",
    -- Наводки на чужие тайники: шанс (%) получить координаты случайного тайника убитого игрока,
    -- срок наводки (часы), сколько наводок можно держать одновременно, время обыска (удержание E, с).
    StashIntelChance = 35, StashIntelHours = 6, StashIntelMax = 8, StashIntelHold = 3,
    -- Износ брони от урона: процентов состояния за 1 единицу полученного урона.
    -- Износ копится и применяется одним сохранением раз в ArmorWearInterval секунд.
    ArmorWearPerDamage = 0.08, ArmorWearInterval = 2,
    -- Типы урона, изнашивающие костюм и шлем: пули, дробь, взрыв, удары, разрывы, огонь, электричество, кислота.
    ArmorWearTypes = {DMG_BULLET, DMG_BUCKSHOT, DMG_BLAST, DMG_CLUB, DMG_SLASH, DMG_BURN, DMG_SLOWBURN, DMG_SHOCK, DMG_ENERGYBEAM, DMG_ACID},
    -- Боеприпасы SWEP остаются нативными; хотбар не подменяет выбор оружия.
    QuickModifier = KEY_LALT, AllowDisassemble = true,
    Equipment = {
        {id="helmet", title="Шлем", category="helmet"},
        {id="armor", title="Броня", category="armor"},
        {id="primary", title="Основное", category="primary"},
        {id="secondary", title="Второе", category="secondary"},
        {id="pistol", title="Пистолет", category="pistol"},
        {id="throwable", title="Гранаты", category="throwable"},
        {id="artifact1", title="Артеф. I", category="artifact"},
        {id="artifact2", title="Артеф. II", category="artifact"},
        {id="boots", title="Ботинки", category="boots"}
    },
    -- Запасная палитра на случай, если ядро (STALKER_THEME) не загружено. При наличии темы цвета
    -- берутся из её токенов при отрисовке (см. cl_theme.lua).
    Colors = {background=Color(28,26,20), panel=Color(42,38,32), panel2=Color(35,39,30), brass=Color(107,93,63), lineHi=Color(191,174,116),
        accent=Color(200,169,81), accent2=Color(222,196,120), text=Color(217,207,176), muted=Color(138,127,99),
        danger=Color(162,43,31), ok=Color(74,122,58), warn=Color(214,170,64), info=Color(100,138,145),
        track=Color(9,12,8,240), shadow=Color(8,10,8,220), highlight=Color(144,139,107,75)},
    Starter = {{"medkit",3},{"bandage",5},{"water",2},{"food",2},{"ammo_pistol",15},
        {"pistol",1},{"jacket",1},{"artifact",1},{"scrap",4}},
    MapMaterials = {} -- ["gm_construct"] = "stalker_inv/maps/gm_construct.png"
}
S.Items = S.Items or {}
S.ITEMS = S.Items
S.EquipmentByID = {}
for _, e in ipairs(S.Config.Equipment) do S.EquipmentByID[e.id] = e end
-- Предметы этих категорий изнашиваются и теряют защиту с износом (S.ConditionFactor).
S.WearCategories = {armor=true, helmet=true, boots=true}
if SERVER then
    S.CVBackend = CreateConVar("stalker_inv_storage", "sqlite", FCVAR_ARCHIVE, "sqlite или json")
    S.CVStarter = CreateConVar("stalker_inv_starter", "1", FCVAR_ARCHIVE, "Выдавать стартовый набор новым игрокам")
else
    S.CVKey = CreateClientConVar("stalker_inv_key", tostring(KEY_TAB), true, false, "Код клавиши открытия")
    S.CVScale = CreateClientConVar("stalker_inv_scale", "1", true, false, "Масштаб интерфейса", 0.65, 2)
    S.CVFont = CreateClientConVar("stalker_inv_font", "Consolas", true, false, "Моноширинный шрифт (или Courier New)")
    S.CVHeading = CreateClientConVar("stalker_inv_heading", "Trebuchet MS", true, false, "Заголовки (или Trebuchet MS)")
end

-- Параметры в админ-панели («Комендант» → Настройки → «Инвентарь»). Значения, нужные клиенту
-- (вес, скорость, лимиты тайников), отправляются игрокам (realm="shared").
local SET = STALKER_SETTINGS
if SET and SET.Bind then
    local cat = "Инвентарь"
    SET.Bind("inv.max_weight", S.Config, "MaxWeight", {category=cat, label="Допустимый вес без перегруза, кг", type="number",
        min=5, max=500, step=1, realm="shared", order=1, description="Сверх этого веса скорость снижается."})
    SET.Bind("inv.overweight_speed", S.Config, "OverweightSpeed", {category=cat, label="Скорость при перегрузе (доля от обычной)", type="number",
        min=0.1, max=1, step=0.05, decimals=2, realm="shared", order=2})
    SET.Bind("inv.max_stashes", S.Config, "MaxStashes", {category=cat, label="Личных тайников на игрока", type="number",
        min=0, max=10, step=1, realm="shared", order=3, description="Уже созданные тайники сверх лимита сохраняются."})
    SET.Bind("inv.stash_slots", S.Config, "StashSlots", {category=cat, label="Ячеек в новом тайнике", type="number",
        min=4, max=20, step=1, realm="shared", order=4, description="Вместимость хранится в самом тайнике: старые тайники не меняются."})
    SET.Bind("inv.stash_intel_chance", S.Config, "StashIntelChance", {category=cat, label="Шанс наводки на тайник с убитого, %", type="number",
        min=0, max=100, step=1, realm="server", order=5, description="Убийца получает координаты сразу, иначе наводка остаётся в рюкзаке погибшего."})
    SET.Bind("inv.stash_intel_hours", S.Config, "StashIntelHours", {category=cat, label="Срок действия наводки, ч", type="number",
        min=0.5, max=72, step=0.5, decimals=1, realm="server", order=6})
    SET.Bind("inv.armor_wear", S.Config, "ArmorWearPerDamage", {category=cat, label="Износ брони за 1 ед. урона, %", type="number",
        min=0, max=2, step=0.01, decimals=2, realm="server", order=7, description="0 — костюмы и шлемы не изнашиваются от урона."})
    SET.Bind("inv.autosave", S.Config, "Autosave", {category=cat, label="Автосохранение инвентарей, с", type="number",
        min=10, max=600, step=5, realm="server", order=8,
        onChange=function() if SERVER and S.StartAutosave then S.StartAutosave() end end})
end
