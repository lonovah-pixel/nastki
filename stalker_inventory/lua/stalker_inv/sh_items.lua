local S = STALKER_INV
-- Общий реестр; исполняемые OnUse задаются только на сервере.
function S.RegisterItem(id, data)
    assert(type(id)=="string" and #id<=48 and id:match("^[%w_]+$"), "Некорректный ID предмета")
    assert(type(data)=="table" and type(data.weight)=="number" and data.weight>=0 and data.weight<10000, "Некорректный вес")
    data.name = data.name or id
    data.description = data.description or "Описание отсутствует."
    data.model = data.model or "models/props_junk/cardboard_box004a.mdl"
    data.icon = data.icon or ""
    data.category = data.category or "misc"
    data.stats = data.stats or {}
    data.max_stack = data.stackable and math.Clamp(math.floor(data.max_stack or 1),1,999) or 1
    data.durability = math.floor(math.Clamp(data.durability or 100,0,100))
    S.Items[id] = data
end
local function add(id, d) S.RegisterItem(id,d) end
add("medkit",{name="Аптечка",description="Индивидуальный набор первой помощи. Восстанавливает 35 здоровья.",model="models/items/healthkit.mdl",weight=.3,stackable=true,max_stack=10,category="medicine",stats={health=35}})
add("bandage",{name="Бинт",description="Стерильная повязка. Восстанавливает 10 здоровья.",model="models/props_lab/box01a.mdl",weight=.05,stackable=true,max_stack=20,category="medicine",stats={health=10}})
add("water",{name="Вода",description="Чистая питьевая вода. Утоляет жажду.",model="models/props_junk/garbage_plasticbottle003a.mdl",weight=.5,stackable=true,max_stack=10,category="food",stats={thirst=35}})
add("food",{name="Консервы",description="Походный рацион. Утоляет голод.",model="models/props_junk/garbage_metalcan001a.mdl",weight=.35,stackable=true,max_stack=10,category="food",stats={hunger=30}})
add("ammo_pistol",{name="Пистолетные патроны",description="Одна единица даёт 12 патронов стандартного типа Pistol.",model="models/items/boxsrounds.mdl",weight=.12,stackable=true,max_stack=60,category="ammo",ammo="Pistol",ammoCount=12,stats={rounds=12}})
add("pistol",{name="Пистолет",description="Стандартный SWEP weapon_pistol. Перенесите в слот пистолета.",model="models/weapons/w_pistol.mdl",weight=.9,category="pistol",weapon="weapon_pistol",clip1=12,stats={damage=12},salvage={scrap=3}})
add("rifle",{name="Автомат",description="Стандартный SWEP weapon_smg1. Основное оружие.",model="models/weapons/w_smg1.mdl",weight=3.2,category="primary",weapon="weapon_smg1",clip1=30,stats={damage=10},salvage={scrap=6}})
add("jacket",{name="Куртка сталкера",description="Укреплённая куртка. Запас брони сохраняется при снятии и надевании.",model="models/props_c17/SuitCase_Passenger_Physics.mdl",weight=4.5,category="armor",stats={armor=40},salvage={scrap=4}})
add("helmet",{name="Шлем",description="Защитный шлем; характеристики доступны интеграциям через хук экипировки.",weight=1.2,category="helmet",stats={protection=10},salvage={scrap=2}})
add("boots",{name="Ботинки",description="Походные ботинки. Дополнительный слот снаряжения.",weight=1.5,category="boots",stats={condition=100},salvage={scrap=2}})
add("artifact",{name="Каменный цветок",description="Артефакт. Добавляет 0.12 к радиационному индикатору, пока экипирован.",model="models/props_junk/rock001a.mdl",weight=.5,category="artifact",stats={radiation=.12},salvage={scrap=5}})
add("scrap",{name="Детали",description="Материалы, полученные при разборе снаряжения.",model="models/gibs/metal_gib4.mdl",weight=.15,stackable=true,max_stack=100,category="material"})
S.StatNames = {health="Здоровье",thirst="Вода",hunger="Сытость",rounds="Патроны",damage="Урон",armor="Броня",radiation="Радиация",protection="Защита",condition="Состояние"}

for _,id in ipairs({"medkit","bandage","water","food","ammo_pistol","pistol","rifle","jacket","helmet","boots","artifact","scrap"}) do
 if S.Items[id] and S.Items[id].icon=="" then S.Items[id].icon="stalker_inv/items/"..id..".png" end
end

S.CategoryNames={medicine="Медицина",food="Провизия",ammo="Боеприпасы",pistol="Пистолет",primary="Основное оружие",secondary="Второе оружие",armor="Костюм",helmet="Шлем",boots="Обувь",artifact="Артефакт",material="Материалы",misc="Снаряжение"}

add("antirad",{name="Антирад",description="Снижает накопленную дозу радиации на 40.",model="models/healthvial.mdl",weight=.1,stackable=true,max_stack=10,category="medicine"})
add("hazmat",{name="Защитный костюм",description="Снижает поступающую радиацию на 70%.",model="models/props_c17/SuitCase_Passenger_Physics.mdl",weight=6,category="armor",stats={armor=25,radiationProtection=.7}})
S.StatNames.radiationProtection="Защита от радиации"
-- Отдельных иконок нет: используем ближайшие по смыслу вместо «?».
S.Items.antirad.icon="stalker_inv/items/medkit.png"
S.Items.hazmat.icon="stalker_inv/items/jacket.png"
