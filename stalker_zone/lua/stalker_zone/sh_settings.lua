-- Настройки Зоны в общей админ-панели («Комендант» → «Настройки», консоль stalker_setting zone.<id>).
-- Регистрация в обоих realm: клиенту нужны радиусы аномалий, дальности детекторов, видимость артефактов,
-- а энциклопедия КПК, памятка и справочник показывают урон, награды, сроки — такие значения помечены realm="shared".
local Z=STALKER_ZONE
local S=STALKER_SETTINGS
if not S or not S.Bind then return end
local cfg=Z.Config
local order=0
local function bind(id,tbl,key,def)
 order=order+1;def.order=def.order or order;def.type=def.type or "number"
 return S.Bind("zone."..id,tbl,key,def)
end
local function itemName(id) local I=STALKER_INV and STALKER_INV.Items;return I and I[id] and I[id].name or id end
-- Таймеры с интервалом из настроек подстраиваются сразу, без перезапуска карты.
local function retime(name) return function(v) if timer.Exists(name) then timer.Adjust(name,v) end end end

--[[ Аномалии ]]
local A="Аномалии"
bind("anomaly_damage_scale",cfg,"AnomalyDamageScale",{category=A,label="Множитель урона всех аномалий",min=0,max=5,step=.05,decimals=2,realm="shared",
 description="1 — урон по таблице аномалий, 0 — аномалии не ранят. Защиты костюмов и артефактов применяются после множителя."})
bind("anomaly_min_gap",cfg,"AnomalyMinGap",{category=A,label="Минимальное расстояние между аномалиями поля, units",min=40,max=1000,
 description="Действует при следующей перестройке полей."})
bind("max_fields",cfg,"MaxFields",{category=A,label="Лимит полей аномалий на карте",min=1,max=256})
bind("map_fields",cfg,"MarkFields",{category=A,label="Поля аномалий и логова на карте КПК",type="bool",
 description="Только карта КПК: на экране и в мире эти метки не рисуются."})
for _,kind in ipairs(Z.AnomalyOrder) do
 local a=Z.Anomalies[kind];local name="«"..a.name.."»: "
 bind("anomaly."..kind..".radius",a,"radius",{category=A,label=name.."радиус срабатывания, units",min=20,max=600,realm="shared"})
 bind("anomaly."..kind..".damage",a,"damage",{category=A,label=name..(a.interval and "урон за такт" or "урон за срабатывание"),min=0,max=500,step=.5,decimals=1,realm="shared"})
 if a.interval then
  bind("anomaly."..kind..".interval",a,"interval",{category=A,label=name.."период урона, с",min=.1,max=10,step=.05,decimals=2,realm="shared"})
 else
  bind("anomaly."..kind..".cooldown",a,"cooldown",{category=A,label=name.."перезарядка, с",min=0,max=60,step=.1,decimals=1,realm="shared"})
 end
 if a.force then bind("anomaly."..kind..".force",a,"force",{category=A,label=name.."сила отброса",min=0,max=2000,realm="shared"}) end
 if a.pull then
  bind("anomaly."..kind..".pull",a,"pull",{category=A,label=name.."радиус затягивания, units",min=40,max=1200,realm="shared",
   description="Должен быть больше радиуса срабатывания, иначе воронка не затягивает."})
  bind("anomaly."..kind..".pull_force",a,"pullForce",{category=A,label=name.."сила затягивания",min=0,max=400})
 end
end

--[[ Артефакты ]]
local R="Артефакты"
bind("max_artifacts",cfg,"MaxArtifacts",{category=R,label="Лимит артефактов на карте",min=0,max=500})
bind("artifact_refresh",cfg,"ArtifactRefreshMinutes",{category=R,label="Досыпать артефакты без выброса, мин",min=0,max=1440,realm="shared",
 description="0 — артефакты появляются только после выброса."})
bind("artifact_pickup_range",cfg,"ArtifactPickupRange",{category=R,label="Дальность подбора артефакта, units",min=40,max=400})
bind("artifact_visible_range",cfg,"ArtifactVisibleRange",{category=R,label="С детектором артефакт проявляется ближе, units",min=50,max=3000,realm="shared"})
bind("announce_regen",cfg,"AnnounceRegen",{category=R,label="Сообщать о новых артефактах после выброса",type="bool"})
for _,id in ipairs({"det_echo","det_bear","det_veles"}) do
 local d=Z.Detectors[id]
 if d then bind("detector."..id..".range",d,"range",{category=R,label="Детектор «"..(itemName(id):match("«(.-)»") or id).."»: дальность сигнала, units",min=100,max=6000,realm="shared"}) end
end

--[[ Мутанты ]]
local U="Мутанты"
bind("max_mutants",cfg,"MaxMutants",{category=U,label="Лимит мутантов из логов на карте",min=0,max=500})
bind("max_lairs",cfg,"MaxMutantZones",{category=U,label="Лимит логов на карте",min=1,max=256})
bind("mutant_safe_radius",cfg,"MutantSafeRadius",{category=U,label="Не появляться ближе к игрокам, units",min=0,max=6000,realm="shared"})
bind("mutant_tick",cfg,"MutantTick",{category=U,label="Проверка логов, раз в N секунд",min=1,max=60,onChange=retime("STALKER_ZONE.Mutants")})
bind("corpse_lifetime",cfg,"CorpseLifetime",{category=U,label="Трупы мутантов исчезают через, с",min=30,max=3600,
 description="Разделка туши доступна 300 с — меньшее значение сокращает окно разделки."})
for _,key in ipairs(Z.MutantOrder) do
 local m=Z.Mutants[key]
 bind("mutant."..key..".reward",m,"reward",{category=U,label=m.name..": награда за убийство, ₽",min=0,max=100000,realm="shared"})
 bind("mutant."..key..".health",m,"health",{category=U,label=m.name..": множитель здоровья",min=.1,max=20,step=.1,decimals=1,realm="shared"})
end

--[[ Выживание ]]
local V="Выживание"
local sv=cfg.Survival
bind("survival_enabled",sv,"Enabled",{category=V,label="Голод и жажда на нуле отнимают здоровье",type="bool"})
bind("survival_tick",sv,"Tick",{category=V,label="Урон от голода и жажды раз в N секунд",min=1,max=300,onChange=retime("STALKER_ZONE.Survival")})
bind("survival_damage",sv,"Damage",{category=V,label="Урон от голода и жажды за раз",min=0,max=100})
bind("survival_respawn",sv,"RespawnMinimum",{category=V,label="Сытость и вода после возрождения не ниже, %",min=0,max=100,realm="shared"})
bind("survival_warn",sv,"WarnEvery",{category=V,label="Напоминать о голоде раз в N секунд",min=5,max=3600})
bind("resist_cap",cfg,"ResistCap",{category=V,label="Предел защиты от одного типа урона, %",min=0,max=100,
 description="Суммарная защита костюма, шлема и артефактов от пуль, огня, химии и т. д. не превышает это значение."})
bind("starter",cfg,"StarterEnabled",{category=V,label="Стартовый набор новичка",type="bool",
 description="Пистолет, патроны, бинты, вода, хлеб и монтировка — только новому сохранению инвентаря.",onChange=function() if Z.ApplyStarter then Z.ApplyStarter() end end})

--[[ Смерть и потери ]]
local D="Смерть и потери"
local dd=cfg.DeathDrop
bind("death_drop",dd,"Enabled",{category=D,label="Рюкзак погибшего остаётся на месте смерти",type="bool",
 description="Экипировка всегда остаётся при игроке; выпадает содержимое рюкзака."})
bind("death_bag_lifetime",dd,"Lifetime",{category=D,label="Сумка погибшего исчезает через, с",min=30,max=7200,realm="shared"})
bind("death_bag_range",dd,"UseRange",{category=D,label="Дальность обыска сумки, units",min=50,max=400,realm="shared"})
bind("ammo_persistence",cfg,"AmmoPersistence",{category=D,label="Сохранять запас патронов при выходе с сервера",type="bool",
 description="Смерть запас сбрасывает."})

--[[ Торговля ]]
local T="Торговля"
bind("restock_minutes",cfg,"RestockMinutes",{category=T,label="Восполнение складов торговцев, раз в N минут",min=0,max=1440,
 description="0 — склады не восполняются сами (кнопка «Пополнить склады» в «Коменданте» работает всегда)."})
bind("restock_share",cfg,"RestockShare",{category=T,label="Доля недостающего товара за одно восполнение",min=.05,max=1,step=.05,decimals=2})
bind("map_traders",cfg,"MarkTraders",{category=T,label="Торговцы и вербовщики на карте КПК",type="bool"})
for _,id in ipairs({"trader_scientists","trader_ecologists"}) do
 if Z.ArtifactBonus[id] then
  bind("artifact_bonus."..id,Z.ArtifactBonus,id,{category=T,label=(id=="trader_scientists" and "Учёные" or "Экологи")..": множитель цены скупки артефактов",
   min=.5,max=3,step=.05,decimals=2,onChange=function() if Z.ConfigureTraders then Z.ConfigureTraders() end end})
 end
end
