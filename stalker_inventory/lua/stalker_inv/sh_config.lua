local S = STALKER_INV
S.Config = {
    Width = 960, Height = 600, Columns = 8, Rows = 5, Slot = 64, QuickSlot = 48,
    DarkRP = {UseHunger=true, DisableStarter=true},
    MaxWeight = 50, OverweightSpeed = 0.55, Autosave = 30,
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
    Colors = {background=Color(28,26,20), panel=Color(42,38,32), brass=Color(107,93,63),
        accent=Color(200,169,81), text=Color(217,207,176), muted=Color(138,127,99),
        danger=Color(162,43,31), ok=Color(74,122,58)},
    Starter = {{"medkit",3},{"bandage",5},{"water",2},{"food",2},{"ammo_pistol",15},
        {"pistol",1},{"jacket",1},{"artifact",1},{"scrap",4}},
    MapMaterials = {} -- ["gm_construct"] = "stalker_inv/maps/gm_construct.png"
}
S.Items = S.Items or {}
S.ITEMS = S.Items
S.EquipmentByID = {}
for _, e in ipairs(S.Config.Equipment) do S.EquipmentByID[e.id] = e end
if SERVER then
    S.CVBackend = CreateConVar("stalker_inv_storage", "sqlite", FCVAR_ARCHIVE, "sqlite или json")
    S.CVStarter = CreateConVar("stalker_inv_starter", "1", FCVAR_ARCHIVE, "Выдавать стартовый набор новым игрокам")
else
    S.CVKey = CreateClientConVar("stalker_inv_key", tostring(KEY_TAB), true, false, "Код клавиши открытия")
    S.CVScale = CreateClientConVar("stalker_inv_scale", "1", true, false, "Масштаб интерфейса", 0.65, 2)
    S.CVFont = CreateClientConVar("stalker_inv_font", "Consolas", true, false, "Моноширинный шрифт (или Courier New)")
    S.CVHeading = CreateClientConVar("stalker_inv_heading", "Trebuchet MS", true, false, "Заголовки (или Trebuchet MS)")
end
