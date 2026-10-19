-- STALKER Crafting: параметры баланса. Все числа меняются без правки Lua: «Комендант» → «Настройки» → «Крафт и готовка»
-- (или консоль stalker_setting craft.<параметр> <значение>).
local CR=STALKER_CRAFT
CR.Version="1.0.0"
CR.Config={
 TimeMult=1,          -- множитель времени крафта (базовое время рецептов — 2–6 с)
 CookMult=1,          -- множитель времени готовки
 RepairArmor=40,      -- ремкомплект брони: сколько процентов состояния возвращает костюму или шлему
 RepairWeapon=40,     -- оружейный набор: то же для экипированного оружия
 NeedToolkit=true,    -- простые рецепты вне верстака требуют набор инструментов в рюкзаке
 StationRange=140,    -- дистанция до верстака или костра, units (≈2.7 м)
 MoveTolerance=96,    -- насколько можно сместиться во время крафта «в поле», units
 MaxRepeat=10,        -- сколько изделий можно поставить в очередь за раз
 FireMinutes=10,      -- срок походного костра из предмета
 FireLimit=1,         -- одновременно горящих походных костров на игрока
 FireHeal=1,          -- лечение у костра: HP за интервал
 FireHealInterval=5,  -- интервал лечения, с
 FireHealRadius=160,  -- радиус тепла костра, units
 FoodMult=1,          -- множитель сытости и жажды приготовленных блюд
 ToxicDose=8,         -- доза радиации за «сомнительное мясо»
 Markers=true,        -- верстаки и постоянные костры — метки на карте КПК
 MaxBenches=32,MaxFires=32, -- лимиты мест администратора на карту
 -- Цвета огня в мире (не интерфейс): языки пламени, угли и дым.
 FX={fire={255,150,60},ember={255,96,40},smoke={92,90,86}},
}
local Cfg=CR.Config

-- Регистрация в общем реестре: значения realm="shared" нужны клиенту для подписей и длительностей в окне.
local SET=STALKER_SETTINGS
if SET and SET.Bind then
 local cat="Крафт и готовка"
 local function refreshItems() if CR.ApplyItemStats then CR.ApplyItemStats() end end
 local function bind(id,key,def) def.category=cat;SET.Bind("craft."..id,Cfg,key,def) end
 bind("time_mult","TimeMult",{label="Множитель времени крафта",type="number",min=.1,max=5,step=.05,decimals=2,realm="shared",order=1,
  description="Базовое время рецептов — 2–6 секунд. 0.5 — вдвое быстрее, 2 — вдвое дольше."})
 bind("cook_mult","CookMult",{label="Множитель времени готовки",type="number",min=.1,max=5,step=.05,decimals=2,realm="shared",order=2})
 bind("repair_armor","RepairArmor",{label="Ремкомплект брони: восстановление, %",type="number",min=5,max=100,step=1,realm="shared",order=3,onChange=refreshItems})
 bind("repair_weapon","RepairWeapon",{label="Оружейный набор: восстановление, %",type="number",min=5,max=100,step=1,realm="shared",order=4,onChange=refreshItems})
 bind("need_toolkit","NeedToolkit",{label="Простые рецепты требуют набор инструментов",type="bool",realm="shared",order=5,
  description="Выключено — простые рецепты доступны где угодно. Сложные рецепты всегда требуют верстак."})
 bind("station_range","StationRange",{label="Дистанция до верстака и костра, units",type="number",min=60,max=400,step=10,realm="shared",order=6})
 bind("move_tolerance","MoveTolerance",{label="Допустимое смещение при крафте в поле, units",type="number",min=16,max=400,step=8,realm="server",order=7})
 bind("max_repeat","MaxRepeat",{label="Изделий в очереди за раз",type="number",min=1,max=50,step=1,realm="shared",order=8})
 bind("fire_minutes","FireMinutes",{label="Срок походного костра, мин",type="number",min=1,max=120,step=1,realm="shared",order=9,
  description="Постоянные костры администратора горят всегда."})
 bind("fire_limit","FireLimit",{label="Походных костров на игрока",type="number",min=1,max=5,step=1,realm="server",order=10})
 bind("fire_heal","FireHeal",{label="Лечение у костра, HP за интервал",type="number",min=0,max=20,step=1,realm="shared",order=11,description="0 — костёр не лечит."})
 bind("fire_heal_interval","FireHealInterval",{label="Интервал лечения у костра, с",type="number",min=1,max=60,step=1,realm="shared",order=12})
 bind("fire_heal_radius","FireHealRadius",{label="Радиус тепла костра, units",type="number",min=40,max=600,step=10,realm="shared",order=13})
 bind("food_mult","FoodMult",{label="Множитель сытости и жажды блюд",type="number",min=.25,max=3,step=.05,decimals=2,realm="shared",order=14,onChange=refreshItems})
 bind("toxic_dose","ToxicDose",{label="Доза радиации за сомнительное мясо",type="number",min=0,max=50,step=1,realm="shared",order=15,onChange=refreshItems})
 bind("markers","Markers",{label="Верстаки и постоянные костры на карте КПК",type="bool",realm="server",order=16,
  onChange=function() if SERVER and CR.RefreshMarkers then CR.RefreshMarkers() end end})
end

-- Общие помощники.
function CR.FormatTime(sec)
 sec=math.max(0,math.floor(tonumber(sec) or 0))
 if sec>=3600 then return string.format("%d ч %02d мин",math.floor(sec/3600),math.floor(sec%3600/60)) end
 return string.format("%02d:%02d",math.floor(sec/60),sec%60)
end
function CR.Seconds(v) v=tonumber(v) or 0;return (v%1==0 and string.format("%d",v) or string.format("%.1f",v)).." с" end
