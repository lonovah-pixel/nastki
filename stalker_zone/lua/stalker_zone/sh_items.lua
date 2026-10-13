-- Каталог предметов Зоны поверх STALKER Inventory. Реестр общий: файл выполняется в обоих realm.
-- price.buy — цена у торговца, price.sell — сколько торговец платит игроку (до поправок фракций и износа).
local Z=STALKER_ZONE
Z.ItemPrices={
 -- Базовые предметы инвентаря, у которых не было цены у торговцев.
 helmet={buy=1800,sell=700},boots={buy=900,sell=350},artifact={buy=5500,sell=2200},
}
Z.Artifacts={}

local function icon(id) return "stalker_zone/items/"..id..".png" end

function Z.RegisterItems()
 local S=STALKER_INV;if not S or not S.RegisterItem then return false end
 local function add(id,data,price)
  data.icon=data.icon or icon(id)
  S.RegisterItem(id,data)
  if price then Z.ItemPrices[id]=price end
 end
 for key,name in pairs(Z.StatNames) do S.StatNames[key]=name end
 S.CategoryNames.detector="Детектор";S.CategoryNames.explosive="Взрывчатка"

 -- Оружие: базовые SWEP Half-Life 2, доступные на любом сервере GMod.
 add("crowbar",{name="Монтировка",description="Тяжёлая монтировка. Слот «Второе». Подходит для разделки туш мутантов.",model="models/weapons/w_crowbar.mdl",weight=1.2,category="secondary",weapon="weapon_crowbar",clip1=-1,stats={damage=25},salvage={scrap=2}},{buy=300,sell=100})
 add("revolver",{name="Револьвер .357",description="Шестизарядный револьвер с мощным патроном. Слот «Пистолет».",model="models/weapons/w_357.mdl",weight=1.4,category="pistol",weapon="weapon_357",clip1=6,stats={damage=40},salvage={scrap=4}},{buy=2500,sell=1000})
 add("shotgun",{name="Дробовик СПАС-12",description="Помповый дробовик. Незаменим против мутантов на короткой дистанции.",model="models/weapons/w_shotgun.mdl",weight=3.6,category="primary",weapon="weapon_shotgun",clip1=6,stats={damage=56},salvage={scrap=6}},{buy=4500,sell=1800})
 add("ar2",{name="Экспериментальная винтовка",description="Трофейная импульсная винтовка неизвестного производства. Магазин 30.",model="models/weapons/w_irifle.mdl",weight=4.2,category="primary",weapon="weapon_ar2",clip1=30,stats={damage=11},salvage={scrap=10}},{buy=12000,sell=5000})
 add("crossbow",{name="Арбалет",description="Бесшумный арбалет с оптикой. Болт поражает цель на большой дистанции.",model="models/weapons/w_crossbow.mdl",weight=3.8,category="primary",weapon="weapon_crossbow",clip1=1,stats={damage=100},salvage={scrap=8}},{buy=9000,sell=3500})
 add("grenade",{name="Граната РГД-5",description="Ручная осколочная граната. «Использовать» — взять гранату в руки.",model="models/weapons/w_grenade.mdl",weight=.3,stackable=true,max_stack=5,category="explosive",stats={damage=125}},{buy=600,sell=250})

 -- Боеприпасы: одна единица — пачка патронов указанного типа.
 add("ammo_smg",{name="Автоматные патроны",description="Пачка на 30 патронов типа SMG1 для автомата.",model="models/items/boxmrounds.mdl",weight=.3,stackable=true,max_stack=40,category="ammo",ammo="SMG1",ammoCount=30,stats={rounds=30}},{buy=120,sell=45})
 add("ammo_buckshot",{name="Дробь 12×70",description="8 патронов с картечью для дробовика.",model="models/items/boxbuckshot.mdl",weight=.25,stackable=true,max_stack=40,category="ammo",ammo="Buckshot",ammoCount=8,stats={rounds=8}},{buy=110,sell=40})
 add("ammo_357",{name="Патроны .357",description="6 патронов для револьвера.",model="models/items/357ammo.mdl",weight=.15,stackable=true,max_stack=40,category="ammo",ammo="357",ammoCount=6,stats={rounds=6}},{buy=150,sell=60})
 add("ammo_ar2",{name="Магазин к винтовке",description="30 зарядов для экспериментальной винтовки.",model="models/items/combine_rifle_cartridge01.mdl",weight=.35,stackable=true,max_stack=20,category="ammo",ammo="AR2",ammoCount=30,stats={rounds=30}},{buy=400,sell=150})
 add("ammo_bolt",{name="Арбалетные болты",description="4 стальных болта для арбалета.",model="models/items/crossbowrounds.mdl",weight=.3,stackable=true,max_stack=20,category="ammo",ammo="XBowBolt",ammoCount=4,stats={rounds=4}},{buy=300,sell=110})

 -- Костюмы. armor — очки брони, radiationProtection — доля (0–1), *Resist — проценты.
 local suit="models/props_c17/SuitCase_Passenger_Physics.mdl"
 add("bandit_jacket",{name="Кожаная куртка",description="Поношенная кожанка. Немного защищает от ударов и осколков.",model=suit,weight=3,category="armor",stats={armor=30,bulletResist=3,strikeResist=10},salvage={scrap=2}},{buy=1200,sell=450})
 add("zarya",{name="Комбинезон «Заря»",description="Лёгкий армированный комбинезон с базовой защитой от аномалий.",model=suit,weight=5,category="armor",stats={armor=60,radiationProtection=.25,bulletResist=10,burnResist=10,shockResist=10,chemResist=10},salvage={scrap=6}},{buy=6000,sell=2400})
 add("duty_suit",{name="ПСЗ-9д «Броня Долга»",description="Тяжёлый общевойсковой комбинезон «Долга». Держит пулю.",model=suit,weight=8,category="armor",stats={armor=85,radiationProtection=.3,bulletResist=20,blastResist=10},salvage={scrap=10}},{buy=14000,sell=5500})
 add("freedom_suit",{name="«Ветер свободы»",description="Облегчённый бронекомбинезон «Свободы». Не стесняет движений.",model=suit,weight=6,category="armor",stats={armor=70,radiationProtection=.35,bulletResist=15,speed=5},salvage={scrap=8}},{buy=12000,sell=4800})
 add("merc_suit",{name="Комбинезон наёмника",description="Надёжный городской комбинезон с бронепластинами.",model=suit,weight=7,category="armor",stats={armor=75,radiationProtection=.25,bulletResist=15,strikeResist=10},salvage={scrap=8}},{buy=12500,sell=5000})
 add("monolith_suit",{name="Комбинезон «Монолит»",description="Серый комбинезон фанатиков Монолита с усиленной радиозащитой.",model=suit,weight=7,category="armor",stats={armor=80,radiationProtection=.45,bulletResist=18},salvage={scrap=9}},{buy=15000,sell=6000})
 add("berill",{name="Бронекостюм «Берилл-5М»",description="Армейский бронекостюм спецподразделений. Тяжёлый, но очень прочный.",model=suit,weight=9,category="armor",stats={armor=90,radiationProtection=.2,bulletResist=25,blastResist=15,speed=-5},salvage={scrap=11}},{buy=16000,sell=6500})
 add("seva",{name="Комбинезон «СЕВА»",description="Научный комбинезон с замкнутым дыханием. Лучшая защита от аномалий.",model=suit,weight=7,category="armor",stats={armor=65,radiationProtection=.6,bulletResist=10,burnResist=30,shockResist=30,chemResist=40},salvage={scrap=10}},{buy=22000,sell=9000})
 add("exo",{name="Экзоскелет",description="Силовой каркас с бронепластинами. Почти неуязвим, но медленный.",model=suit,weight=14,category="armor",stats={armor=150,radiationProtection=.35,bulletResist=35,blastResist=25,strikeResist=30,speed=-20},salvage={scrap=20}},{buy=45000,sell=18000})

 -- Шлемы и обувь.
 add("gasmask",{name="Противогаз ГП-5",description="Фильтрует радиоактивную пыль и ядовитые испарения.",weight=.9,category="helmet",stats={radiationProtection=.15,chemResist=25},salvage={scrap=1}},{buy=1500,sell=600})
 add("tactical_helmet",{name="Тактический шлем",description="Армейский шлем с забралом. Спасает от попаданий в голову.",weight=1.6,category="helmet",stats={headshot=35,radiationProtection=.05},salvage={scrap=3}},{buy=4000,sell=1600})
 add("sphere",{name="Шлем «Сфера-08»",description="Титановый шлем спецназа с противогазом.",weight=2.2,category="helmet",stats={headshot=45,radiationProtection=.15,chemResist=15},salvage={scrap=5}},{buy=6500,sell=2600})
 add("army_boots",{name="Армейские берцы",description="Крепкие ботинки с высоким берцем. Смягчают падения.",weight=1.8,category="boots",stats={fallResist=35,speed=3},salvage={scrap=2}},{buy=2200,sell=900})

 -- Детекторы. Работают, пока лежат в рюкзаке.
 add("det_echo",{name="Детектор «Отклик»",description="Простой детектор: пищит чаще рядом с артефактом. Делает артефакт видимым вблизи. Держите в рюкзаке.",model="models/props_lab/reciever01b.mdl",weight=.4,category="detector",stats={range=12}},{buy=2000,sell=800})
 add("det_bear",{name="Детектор «Медведь»",description="Показывает направление на ближайший артефакт. Держите в рюкзаке.",model="models/props_lab/reciever01b.mdl",weight=.5,category="detector",stats={range=20}},{buy=6000,sell=2400})
 add("det_veles",{name="Детектор «Велес»",description="Сканер с экраном: отмечает все артефакты в радиусе. Держите в рюкзаке.",model="models/props_lab/reciever01b.mdl",weight=.6,category="detector",stats={range=30}},{buy=15000,sell=6000})

 -- Медицина и провизия.
 add("medkit_army",{name="Армейская аптечка",description="Восстанавливает 60 здоровья.",model="models/items/healthkit.mdl",weight=.35,stackable=true,max_stack=10,category="medicine",stats={health=60}},{buy=900,sell=350})
 add("medkit_sci",{name="Научная аптечка",description="Восстанавливает 45 здоровья и снижает дозу радиации на 25.",model="models/healthvial.mdl",weight=.3,stackable=true,max_stack=10,category="medicine",stats={health=45,dose=25}},{buy=1400,sell=550})
 add("vodka",{name="Водка «Казаки»",description="Народное средство: снижает дозу радиации на 15.",model="models/props_junk/GlassBottle01a.mdl",weight=.5,stackable=true,max_stack=10,category="medicine",stats={dose=15}},{buy=300,sell=100})
 add("energy",{name="Энергетик «Non-Stop»",description="Газированный напиток. Утоляет жажду.",model="models/props_junk/PopCan01a.mdl",weight=.33,stackable=true,max_stack=10,category="food",stats={thirst=25}},{buy=250,sell=90})
 add("bread",{name="Хлеб",description="Буханка серого хлеба. Утоляет голод.",model="models/props_junk/garbage_bag001a.mdl",weight=.3,stackable=true,max_stack=10,category="food",stats={hunger=20}},{buy=90,sell=35})
 add("sausage",{name="Колбаса «Диетическая»",description="Колбаса сомнительного происхождения. Хорошо утоляет голод.",model="models/props_junk/garbage_metalcan002a.mdl",weight=.4,stackable=true,max_stack=10,category="food",stats={hunger=28}},{buy=140,sell=55})

 -- Артефакты. radiation — прибавка к фону (доза/с) пока экипирован, отрицательная выводит радиацию.
 -- tier: 1 — частый, 4 — легендарный. anomalies — в каких аномалиях рождается.
 local function artifact(id,data,price,spawn)
  data.category="artifact";data.weight=data.weight or .5;data.durability=100
  add(id,data,price)
  spawn.id=id;Z.Artifacts[id]=spawn
 end
 artifact("medusa",{name="Медуза",description="Студенистый артефакт гравитационных аномалий. Немного гасит пули.",stats={radiation=.08,bulletResist=6}},
  {buy=3500,sell=1400},{tier=1,weight=30,anomalies={springboard=true,vortex=true},color=Color(150,200,120),model="models/maxofs2d/hover_rings.mdl"})
 artifact("night_star",{name="Ночная звезда",description="Светится в темноте. Смягчает падения и придаёт лёгкость шагу.",stats={radiation=.15,fallResist=30,speed=4}},
  {buy=7500,sell=3000},{tier=2,weight=12,anomalies={springboard=true,vortex=true},color=Color(140,220,255),model="models/maxofs2d/hover_basic.mdl"})
 artifact("bubble",{name="Пузырь",description="Пористый пузырь, вытягивающий радиацию из организма.",stats={radiation=-.2}},
  {buy=9000,sell=3600},{tier=2,weight=10,anomalies={acid=true},color=Color(200,180,120),model="models/dav0r/hoverball.mdl"})
 artifact("battery",{name="Батарейка",description="Заряжает мышцы электричеством: бегаешь быстрее.",stats={radiation=.1,speed=8}},
  {buy=6000,sell=2400},{tier=2,weight=14,anomalies={electro=true},color=Color(110,160,255),model="models/items/battery.mdl"})
 artifact("flash",{name="Вспышка",description="Рождается в «Электре». Отводит электрические разряды.",stats={radiation=.1,shockResist=30}},
  {buy=6500,sell=2600},{tier=1,weight=22,anomalies={electro=true},color=Color(160,200,255),model="models/items/combine_rifle_ammo01.mdl"})
 artifact("crystal",{name="Кристалл",description="Горячий на ощупь кристалл из «Жарки». Защищает от огня.",stats={radiation=.12,burnResist=30}},
  {buy=6500,sell=2600},{tier=1,weight=22,anomalies={burner=true},color=Color(255,150,70),model="models/maxofs2d/hover_classic.mdl"})
 artifact("slime",{name="Слизь",description="Липкая масса из «Киселя». Нейтрализует яды и кислоты.",stats={radiation=.1,chemResist=30}},
  {buy=5000,sell=2000},{tier=1,weight=24,anomalies={acid=true},color=Color(140,230,90),model="models/Gibs/Antlion_gib_small_2.mdl"})
 artifact("soul",{name="Душа",description="Причудливое образование, ускоряющее заживление ран.",stats={radiation=.2,regen=.5}},
  {buy=14000,sell=5600},{tier=3,weight=5,anomalies={acid=true,burner=true},color=Color(255,120,150),model="models/props_c17/doll01.mdl"})
 artifact("goldfish",{name="Золотая рыбка",description="Редчайший гравитационный артефакт: защищает и придаёт сил.",stats={radiation=.25,bulletResist=15,speed=6}},
  {buy=25000,sell=10000},{tier=3,weight=3,anomalies={vortex=true},color=Color(255,210,80),model="models/items/combine_rifle_ammo01.mdl"})
 artifact("compass",{name="Компас",description="Легенда Зоны. Говорят, указывает проход через любые аномалии.",stats={radiation=.3,speed=10,fallResist=50,regen=.3}},
  {buy=50000,sell=20000},{tier=4,weight=1,anomalies={vortex=true,electro=true},color=Color(255,170,60),model="models/props_combine/breenglobe.mdl"})

 -- Существующий «Каменный цветок» становится артефактом гравитационных аномалий.
 if S.Items.artifact then
  S.Items.artifact.stats.bulletResist=8
  S.Items.artifact.description="Каменный нарост из гравитационных аномалий. Слегка гасит пули, но фонит."
  Z.Artifacts.artifact={id="artifact",tier=1,weight=26,anomalies={springboard=true,vortex=true},color=Color(190,190,150),model="models/props_junk/rock001a.mdl"}
 end
 -- Смысл для шлема, ботинок и куртки из базового набора.
 if S.Items.helmet then S.Items.helmet.stats.headshot=20 end
 if S.Items.boots then S.Items.boots.stats.fallResist=20;S.Items.boots.stats.condition=nil end
 if S.Items.jacket then S.Items.jacket.stats.bulletResist=5;S.Items.jacket.stats.strikeResist=10 end
 if S.Items.hazmat then S.Items.hazmat.stats.chemResist=40;S.Items.hazmat.stats.burnResist=15;S.Items.hazmat.icon=icon("hazmat") end
 -- Свои иконки вместо временных заглушек базового инвентаря.
 if S.Items.antirad then S.Items.antirad.icon=icon("antirad") end

 -- Стартовый набор: инвентарь выдаёт его только новому (пустому) сохранению.
 S.Config.Starter=table.Copy(Z.Config.Starter)
 S.Config.DarkRP.DisableStarter=false
 Z.ItemsReady=true
 return true
end

Z.RegisterItems()
hook.Add("STALKER_INV_Ready","STALKER_ZONE.Items",Z.RegisterItems)

-- Лучший детектор в рюкзаке (сервер — состояние игрока, клиент — локальная копия).
function Z.BestDetector(inv)
 if not inv or type(inv.grid)~="table" then return end
 local best,bestID
 for _,item in pairs(inv.grid) do
  local d=Z.Detectors[item.id]
  if d and (not best or d.tier>best.tier) then best,bestID=d,item.id end
 end
 return best,bestID
end
