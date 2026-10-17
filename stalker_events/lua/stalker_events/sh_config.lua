-- STALKER Events: настройки баланса. Все числа меняются без правки Lua: «Комендант» → «Настройки» → «События»
-- (или консоль stalker_setting events.<параметр> <значение>).
local E=STALKER_EVENTS
E.Version="1.0.0"
E.Config={
 -- Планировщик: случайный интервал (минуты) отсчитывается от конца предыдущего события.
 Scheduler=true,IntervalMin=25,IntervalMax=50,
 MinPlayers=2,          -- минимум игроков в сети для автоматического события (у события может быть свой минимум выше)
 MaxNPC=24,             -- сколько NPC событий может жить одновременно
 RandomMin=900,RandomMax=2600, -- случайная точка без размеченных мест: расстояние от игрока, units
 -- Сбитый груз: ящик живёт CargoMinutes, вскрытие — удержание E CargoHold секунд.
 CargoMinutes=10,CargoHold=6,CargoGuardsMin=2,CargoGuardsMax=4,CargoArtifactChance=35,
 -- Гон мутантов: волны у логова, награда DarkRP за мутантов умножается на время события.
 HuntMinutes=8,HuntWaveSize=4,HuntWaveInterval=90,HuntRewardMult=2,
 -- Артефактный шторм: лимит артефактов (общий и каждого поля) умножается, досыпка раз в StormTick секунд.
 StormMinutes=10,StormMult=2,StormTick=60,
 -- Военный рейд: отряд npc_combine_s, награда DarkRP за каждого бойца.
 RaidMinutes=12,RaidSquad=5,RaidReward=150,
 -- Охота за головой: награда убийце цели или цели, если она продержалась до конца.
 BountyMinutes=10,BountyReward=5000,BountySurvive=3000,BountyUpdate=5,
 -- Вес события в случайном выборе планировщика (0 — только ручной запуск).
 Weights={cargo=30,hunt=25,storm=20,raid=15,bounty=10},
 -- Маячки игроков.
 BeaconLimit=3,BeaconMinutes=30,BeaconRange=220,
 -- Точки администратора на карте.
 MaxSpots=64,MaxPOI=128,
 -- Цвета эффектов в мире (не интерфейс): дым и огонь сбитого груза.
 FX={smoke={90,88,82},fire={255,150,60}},
}
local Cfg=E.Config

-- Каталог событий: подписи общие для сервера и клиента.
E.Info={
 cargo={name="Сбитый груз",desc="Вертолёт снабжения потерял груз. Ящик дымится на месте падения, рядом бродят мутанты. Вскрытие — удерживать E."},
 hunt={name="Гон мутантов",desc="Мутанты волнами выходят из логова. Пока идёт гон, награда за каждого мутанта увеличена."},
 storm={name="Артефактный шторм",desc="Аномальные поля выбрасывают больше артефактов, чем обычно. Когда шторм утихнет, лишние рассеются."},
 raid={name="Военный рейд",desc="Армейский отряд высадился в Зоне. За каждого бойца платят награду."},
 bounty={name="Охота за головой",desc="За голову опытного сталкера назначена награда. Продержится до конца — награду получит он сам."},
}
E.EventOrder={"cargo","hunt","storm","raid","bounty"}

-- Типы точек интереса (подпись метки: «тип · название»).
E.POITypes={{"camp","Лагерь"},{"shelter","Укрытие"},{"danger","Опасность"},{"loot","Хабар"},{"water","Вода"},{"trader","Торговец"},{"base","База"},{"note","Отметка"}}
E.POITypeName={}
for _,t in ipairs(E.POITypes) do E.POITypeName[t[1]]=t[2] end

-- Лут сбитого груза: группы с шансом и числом бросков; строки {предмет, мин, макс, вес}.
-- Предметы, которых нет в инвентаре сервера, пропускаются.
E.CargoLoot={
 {name="Патроны",chance=1,rolls={2,3},items={{"ammo_smg",2,5,30},{"ammo_pistol",2,6,25},{"ammo_buckshot",1,4,20},{"ammo_357",1,3,12},{"ammo_ar2",1,2,8}}},
 {name="Медицина",chance=1,rolls={1,2},items={{"medkit",1,3,30},{"bandage",2,5,25},{"medkit_army",1,2,15},{"medkit_sci",1,1,8},{"antirad",1,3,20}}},
 {name="Броня",chance=.7,rolls={1,1},items={{"jacket",1,1,30},{"helmet",1,1,25},{"zarya",1,1,15},{"tactical_helmet",1,1,15},{"berill",1,1,5}}},
 {name="Снаряжение",chance=.4,rolls={1,1},items={{"beacon",1,2,1}}},
}

-- Общие помощники.
function E.FormatTime(sec)
 sec=math.max(0,math.floor(tonumber(sec) or 0))
 if sec>=3600 then return string.format("%d ч %02d мин",math.floor(sec/3600),math.floor(sec%3600/60)) end
 return string.format("%02d:%02d",math.floor(sec/60),sec%60)
end
function E.Money(n)
 if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(n) end
 return tostring(n).." ₽"
end

--[[ Настройки (категория «События») ]]
local S=STALKER_SETTINGS
local function bind(id,tbl,key,def)
 def.category="События";def.type=def.type or "number"
 S.Bind("events."..id,tbl,key,def)
end
-- Изменение интервала или включение планировщика сразу пересчитывает время следующего события.
local function reschedule() if SERVER and E.ClampSchedule then E.ClampSchedule() end end
bind("scheduler",Cfg,"Scheduler",{label="Автоматические события",type="bool",order=1,onChange=reschedule,
 description="Планировщик запускает случайное событие через случайный интервал после окончания предыдущего."})
bind("interval_min",Cfg,"IntervalMin",{label="Интервал между событиями: от, мин",min=5,max=600,order=2,onChange=reschedule})
bind("interval_max",Cfg,"IntervalMax",{label="Интервал между событиями: до, мин",min=5,max=600,order=3,onChange=reschedule})
bind("min_players",Cfg,"MinPlayers",{label="Минимум игроков для автоматического события",min=0,max=64,order=4})
bind("max_npc",Cfg,"MaxNPC",{label="Максимум NPC событий одновременно",min=4,max=80,order=5})
bind("cargo_minutes",Cfg,"CargoMinutes",{label="Сбитый груз: ящик живёт, мин",min=2,max=60,order=10})
bind("cargo_hold",Cfg,"CargoHold",{label="Сбитый груз: вскрытие (удержание E), с",min=1,max=30,order=11})
bind("cargo_guards_min",Cfg,"CargoGuardsMin",{label="Сбитый груз: мутантов охраны от",min=0,max=8,order=12})
bind("cargo_guards_max",Cfg,"CargoGuardsMax",{label="Сбитый груз: мутантов охраны до",min=0,max=8,order=13})
bind("cargo_artifact",Cfg,"CargoArtifactChance",{label="Сбитый груз: шанс артефакта, %",min=0,max=100,order=14})
bind("hunt_minutes",Cfg,"HuntMinutes",{label="Гон мутантов: длительность, мин",min=2,max=60,order=20})
bind("hunt_wave_size",Cfg,"HuntWaveSize",{label="Гон мутантов: мутантов в волне",min=1,max=12,order=21})
bind("hunt_wave_interval",Cfg,"HuntWaveInterval",{label="Гон мутантов: интервал волн, с",min=20,max=600,order=22})
bind("hunt_reward_mult",Cfg,"HuntRewardMult",{label="Гон мутантов: множитель награды за мутанта",min=1,max=5,step=.5,decimals=1,order=23})
bind("storm_minutes",Cfg,"StormMinutes",{label="Артефактный шторм: длительность, мин",min=2,max=60,order=30})
bind("storm_mult",Cfg,"StormMult",{label="Артефактный шторм: множитель лимита артефактов",min=1,max=5,step=.5,decimals=1,order=31})
bind("storm_tick",Cfg,"StormTick",{label="Артефактный шторм: досыпка артефактов, с",min=20,max=600,order=32})
bind("raid_minutes",Cfg,"RaidMinutes",{label="Военный рейд: длительность, мин",min=2,max=60,order=40})
bind("raid_squad",Cfg,"RaidSquad",{label="Военный рейд: бойцов в отряде",min=2,max=12,order=41})
bind("raid_reward",Cfg,"RaidReward",{label="Военный рейд: награда за бойца, ₽",min=0,max=10000,step=10,order=42})
bind("bounty_minutes",Cfg,"BountyMinutes",{label="Охота за головой: длительность, мин",min=2,max=60,order=50})
bind("bounty_reward",Cfg,"BountyReward",{label="Охота за головой: награда убийце, ₽",min=0,max=1000000,step=100,order=51})
bind("bounty_survive",Cfg,"BountySurvive",{label="Охота за головой: награда выжившей цели, ₽",min=0,max=1000000,step=100,order=52})
for i,id in ipairs(E.EventOrder) do
 bind("weight_"..id,Cfg.Weights,id,{label="Вес события «"..E.Info[id].name.."» (0 — только вручную)",min=0,max=100,order=60+i})
end
bind("beacon_limit",Cfg,"BeaconLimit",{label="Маячки: не больше на игрока",min=1,max=10,order=70,realm="shared"})
bind("beacon_minutes",Cfg,"BeaconMinutes",{label="Маячки: срок работы, мин",min=1,max=240,order=71,realm="shared"})
