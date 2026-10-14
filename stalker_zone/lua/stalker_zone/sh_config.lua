-- STALKER Zone: аномалии, артефакты, детекторы, мутанты, снаряжение и торговля.
-- Все числа здесь — точки настройки баланса. Реестр предметов общий для сервера и клиента.
local Z=STALKER_ZONE
Z.Config={
 -- Доступ к редактору: суперадмин или право "zone" панели «Комендант».
 EditorPermission="zone",
 MaxFields=64,MaxMutantZones=64,
 -- Аномалии
 AnomalyMinGap=140,           -- минимальное расстояние между аномалиями поля
 AnomalyDamageScale=1,        -- множитель урона всех аномалий
 MaxArtifacts=60,             -- общий лимит артефактов на карте
 ArtifactRefreshMinutes=45,   -- досыпать артефакты без выброса (0 — только после выброса)
 ArtifactPickupRange=110,
 ArtifactVisibleRange=260,    -- с детектором артефакт проявляется ближе этой дистанции
 AnnounceRegen=true,
 -- Мутанты
 MaxMutants=60,MutantSafeRadius=700,MutantTick=5,
 CorpseLifetime=330,          -- трупы мутантов из логов (разделка доступна 300 с)
 -- Выживание
 Survival={Enabled=true,Tick=10,Damage=2,RespawnMinimum=30,WarnEvery=60},
 -- Рюкзак погибшего: содержимое рюкзака (не экипировка) остаётся на месте смерти.
 DeathDrop={Enabled=true,Lifetime=600,Model="models/props_c17/BriefCase001a.mdl",UseRange=110},
 -- Сохранение запаса патронов SWEP при выходе с сервера.
 AmmoPersistence=true,
 AmmoTypes={"Pistol","SMG1","Buckshot","357","AR2","XBowBolt","Grenade"},
 -- Восполнение складов торговцев (в минутах) и доля восполнения за раз.
 RestockMinutes=20,RestockShare=.5,
 -- Стартовый набор новичка (выдаётся один раз, только новому сохранению инвентаря).
 Starter={{"pistol",1},{"ammo_pistol",2},{"bandage",3},{"water",1},{"bread",1},{"crowbar",1}},
 -- Максимальная суммарная защита от одного типа урона, %.
 ResistCap=80,
}

-- Типы урона для защит снаряжения. Значения статов — проценты.
Z.Resists={
 bulletResist={DMG_BULLET,DMG_BUCKSHOT},
 burnResist={DMG_BURN,DMG_SLOWBURN,DMG_PLASMA},
 shockResist={DMG_SHOCK,DMG_ENERGYBEAM},
 chemResist={DMG_ACID,DMG_POISON,DMG_NERVEGAS,DMG_PARALYZE},
 blastResist={DMG_BLAST},
 fallResist={DMG_FALL},
 strikeResist={DMG_SLASH,DMG_CLUB},
}
Z.StatNames={bulletResist="Защита от пуль, %",burnResist="Термозащита, %",shockResist="Электрозащита, %",
 chemResist="Химзащита, %",blastResist="Защита от взрыва, %",fallResist="Защита от падения, %",strikeResist="Защита от ударов, %",
 headshot="Защита головы, %",regen="Регенерация, HP/с",speed="Скорость, %",heal="Лечение",dose="Снижение дозы",range="Дальность, м"}

-- Аномалии. radius — зона срабатывания, units (1 unit ≈ 1.9 см).
Z.Anomalies={
 electro={name="Электра",radius=110,damage=35,dmgType=DMG_SHOCK,cooldown=2.5,color=Color(120,170,255),
  sounds={"ambient/energy/zap1.wav","ambient/energy/zap2.wav","ambient/energy/zap3.wav","ambient/energy/zap5.wav","ambient/energy/zap7.wav","ambient/energy/zap9.wav"},
  idle="ambient/energy/electric_loop.wav"},
 burner={name="Жарка",radius=85,damage=5,dmgType=DMG_BURN,interval=.25,cooldown=0,color=Color(255,140,60),
  sounds={"ambient/fire/ignite.wav"},idle="ambient/fire/fire_small_loop1.wav"},
 springboard={name="Трамплин",radius=95,damage=18,dmgType=DMG_CRUSH,cooldown=3,force=520,color=Color(200,190,150),
  sounds={"physics/concrete/boulder_impact_hard1.wav","physics/concrete/boulder_impact_hard2.wav","physics/concrete/boulder_impact_hard3.wav","physics/concrete/boulder_impact_hard4.wav"}},
 vortex={name="Воронка",radius=70,pull=280,damage=60,dmgType=DMG_BLAST,cooldown=4,pullForce=55,color=Color(170,150,220),
  sounds={"ambient/levels/citadel/portal_beam_shoot5.wav","ambient/levels/citadel/portal_beam_shoot6.wav"},
  idle="ambient/energy/force_field_loop1.wav"},
 acid={name="Кисель",radius=105,damage=4,dmgType=DMG_ACID,interval=.5,cooldown=0,color=Color(130,220,90),
  sounds={"ambient/levels/canals/toxic_slime_gurgle2.wav","ambient/levels/canals/toxic_slime_gurgle4.wav"},
  idle="ambient/levels/canals/toxic_slime_loop1.wav"},
}
Z.AnomalyOrder={"electro","burner","springboard","vortex","acid"}

-- Детекторы работают, пока лежат в рюкзаке; берётся лучший.
-- mode: signal — только сила сигнала; arrow — направление; exact — метки артефактов.
Z.Detectors={
 det_echo={tier=1,range=650,mode="signal"},
 det_bear={tier=2,range=1050,mode="arrow"},
 det_veles={tier=3,range=1600,mode="exact"},
}

-- Мутанты: классы NPC из базового HL2. reward — оплата DarkRP за убийство.
Z.Mutants={
 zombie={class="npc_zombie",name="Зомбированный",reward=40,faction="zombies"},
 snork={class="npc_fastzombie",name="Снорк",reward=70,faction="zombies"},
 izlom={class="npc_poisonzombie",name="Излом",reward=90,faction="zombies"},
 tushkan={class="npc_headcrab",name="Тушкан",reward=15,faction="mutants"},
 tushkan_fast={class="npc_headcrab_fast",name="Быстрый тушкан",reward=20,faction="mutants"},
 tushkan_toxic={class="npc_headcrab_black",name="Ядовитый тушкан",reward=30,faction="mutants"},
 blinddog={class="npc_antlion",name="Слепой пёс",reward=45,faction="mutants"},
 chimera={class="npc_antlionguard",name="Химера",reward=600,faction="mutants",health=1.5},
}
Z.MutantOrder={"zombie","snork","izlom","tushkan","tushkan_fast","tushkan_toxic","blinddog","chimera"}
