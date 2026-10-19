-- STALKER Quests: настройки, квестодатели, шаблоны заданий и шаги обучения (общие для сервера и клиента).
-- Все числа меняются без правки Lua: «Комендант» → «Настройки» → «Задания» (или stalker_setting quests.<параметр>).
local Q=STALKER_QUESTS
Q.Version="1.0.0"
Q.Config={
 MaxActive=5,          -- активных заданий у игрока одновременно
 DailyLimit=15,        -- сколько заданий можно взять за сутки (0 — без ограничения)
 RewardMult=1,         -- множитель денежных наград (задания и шаги обучения)
 Tutorial=true,        -- «Путь новичка» для игроков без выполненных заданий
 Offers=3,             -- сколько заданий предлагает квестодатель за раз
 OfferMinutes=15,      -- через сколько минут квестодатель обновляет предложения
 Cooldown=20,          -- откат шаблона после сдачи, отказа или провала, мин
 TimeMult=1,           -- множитель сроков заданий
 TalkDistance=170,     -- дальность разговора с квестодателем, units
 VisitRadius=350,      -- радиус места для заданий «посетить», units
 MinVisitDistance=900, -- место «посетить» не ближе к квестодателю, units
 GuideLength=1000,     -- длина направляющей линии на земле, units
 History=25,           -- записей в истории заданий
 News=true,            -- новости КПК о выполнении трудных заданий
 MaxNPC=48,MaxPoints=96,
 PackageItem="quest_package",
}
local Cfg=Q.Config

--[[ Квестодатели. faction — чья репутация растёт за задания (STFW), model — модель HL2 (резерв — модель вербовщика). ]]
Q.FallbackModel="models/Humans/Group01/male_07.mdl"
Q.Profiles={
 barman={name="Бармен",title="Хозяин бара",model="models/odessa.mdl",faction="loner",order=1,
  about="Общие поручения: провизия, медикаменты, разведка, артефакты для клиентов.",
  greetings={"О, сталкер! Проходи, не стой в дверях. Работа есть — было бы кому делать.",
   "Живой? Уже хорошо. Садись, слушай, что у меня есть.","Заходи. Плачу честно, если сделано честно."}},
 professor={name="Профессор",title="Учёный",model="models/kleiner.mdl",faction="scientists",order=2,
  about="Артефакты, образцы тканей мутантов и замеры в аномальных полях.",
  greetings={"А, вы как раз вовремя! Науке нужны свежие образцы и смелые люди.",
   "Проходите, проходите. Только ничего не трогайте на столе — оно живое.","Для вас есть работа. Платит институт, а институт не скупится."}},
 hunter={name="Охотник",title="Охотник на мутантов",model="models/monk.mdl",faction="loner",order=3,
  about="Охота на мутантов и трофеи разделки.",
  greetings={"Тихо. Слышишь? Это тушканы в овраге. Хочешь заработать — бери ствол.",
   "Мутантов в округе развелось — на всех хватит. Мне нужен напарник.","Ружьё почищено? Тогда слушай, кого надо выследить."}},
 courier={name="Связной",title="Связной",model="models/Humans/Group03/male_06.mdl",faction="loner",order=4,
  about="Доставка посылок другим квестодателям и проверка мест.",
  greetings={"Есть груз и есть адресат. Не хватает только надёжных ног.","Тсс. Дело деликатное: посылку — из рук в руки.",
   "Курьер нужен. Платят хорошо, вопросов не задают."}},
}
Q.ProfileOrder={"barman","professor","hunter","courier"}

--[[ Типы заданий ]]
Q.Types={
 fetch={label="Принести",icon="▣"},kill={label="Охота",icon="✕"},artifact={label="Артефакты",icon="◆"},
 visit={label="Разведка",icon="◎"},deliver={label="Доставка",icon="✉"},emission={label="Выброс",icon="☢"},
}
-- Мутанты без STALKER Zone: ключи совпадают с каталогом Зоны (Z.Mutants).
Q.MutantFallback={
 zombie={class="npc_zombie",name="Зомбированный"},snork={class="npc_fastzombie",name="Снорк"},izlom={class="npc_poisonzombie",name="Излом"},
 tushkan={class="npc_headcrab",name="Тушкан"},tushkan_fast={class="npc_headcrab_fast",name="Быстрый тушкан"},
 tushkan_toxic={class="npc_headcrab_black",name="Ядовитый тушкан"},blinddog={class="npc_antlion",name="Слепой пёс"},
 chimera={class="npc_antlionguard",name="Химера"},
}

--[[ Шаблоны заданий.
 type: fetch (принести goal предметов из items: ids / patterns с * / category), kill (mutants — ключи мутантов Зоны, nil — любые),
 artifact (подобрать goal артефактов), visit (sources: point — места администратора, poi — точки интереса событий,
 field — поля аномалий, lair — логова), deliver (посылка другому квестодателю), emission (пережить выброс).
 goal={мин,макс}, time — срок в минутах, reward={money, per (за единицу цели), rep, items={{id,n}}}, weight — вес выбора,
 news — новость КПК при выполнении. В текстах: {n} — количество, {what} — цель, {place} — место, {to} — получатель. ]]
Q.Templates={}
Q.TemplateOrder={}
local function T(def)
 def.weight=def.weight or 10;def.goal=def.goal or {1,1};def.time=def.time or 30;def.reward=def.reward or {}
 Q.Templates[def.id]=def;Q.TemplateOrder[#Q.TemplateOrder+1]=def.id
end
-- Бармен: общие поручения.
T{id="bar_food",profile="barman",type="fetch",title="Провизия для бара",what="еда (хлеб, колбаса, консервы)",items={ids={"bread","sausage","food"}},goal={3,5},time=45,
 desc="В подсобке шаром покати, а народ голодный. Принеси {n} ед. еды — хлеб, колбасу или консервы, — и я в долгу не останусь.",reward={money=150,per=90,rep=5}}
T{id="bar_meds",profile="barman",type="fetch",title="Аптечки для раненых",what="медикаменты (аптечки, бинты)",items={ids={"medkit","bandage","medkit_army"}},goal={2,4},time=45,
 desc="Вчера с болот притащили двоих, бинтовать нечем. Принеси {n} аптечек или бинтов.",reward={money=200,per=180,rep=6,items={{"vodka",1}}}}
T{id="bar_scout",profile="barman",type="visit",title="Разведка",sources={"point","poi","lair","field"},time=30,
 desc="Говорят, у места «{place}» неспокойно. Сходи, осмотрись и возвращайся с докладом.",reward={money=600,rep=6}}
T{id="bar_emission",profile="barman",type="emission",title="Пережить выброс",time=180,weight=6,
 desc="Скоро снова рванёт. Переживи ближайший выброс и возвращайся — расскажешь, где прятался. Укрытие ищи заранее.",reward={money=900,rep=8,items={{"antirad",1}}}}
T{id="bar_artifact",profile="barman",type="fetch",title="Артефакт для клиента",what="любой артефакт",items={category="artifact"},time=60,weight=8,
 desc="Один клиент с Большой земли интересуется артефактами. Любой подойдёт — принеси, и получишь сверх цены торговца.",reward={money=1800,rep=8}}
T{id="bar_clean",profile="barman",type="kill",title="Зачистка окрестностей",what="мутанты",goal={4,6},time=40,
 desc="Мутанты подходят к лагерю всё ближе. Убей {n} тварей — любых, — чтобы ребята спали спокойно.",reward={money=300,per=80,rep=5}}
-- Профессор: артефакты и образцы мутантов (трофеи разделки stb_*).
T{id="prof_measure",profile="professor",type="artifact",title="Полевые замеры",goal={1,2},time=45,
 desc="Мне нужны свежие показания с артефактов прямо в поле. Найдите и подберите {n} арт. — детектор держите в рюкзаке.",reward={money=700,per=600,rep=8}}
T{id="prof_common",profile="professor",type="fetch",title="Образец для лаборатории",what="обычный артефакт (Медуза, Вспышка, Кристалл, Слизь, Каменный цветок)",
 items={ids={"medusa","flash","crystal","slime","artifact"}},time=60,
 desc="Для серии опытов нужен образец. Подойдёт Медуза, Вспышка, Кристалл, Слизь или Каменный цветок.",reward={money=2200,rep=10}}
T{id="prof_rare",profile="professor",type="fetch",title="Редкий образец",what="редкий артефакт (Ночная звезда, Пузырь, Батарейка, Душа…)",
 items={ids={"night_star","bubble","battery","soul","goldfish","compass"}},time=90,weight=5,news=true,
 desc="Институт выделил грант на изучение редких образований. Ночная звезда, Пузырь, Батарейка, Душа — что угодно из этого списка.",reward={money=6000,rep=20}}
T{id="prof_tissue",profile="professor",type="fetch",title="Образцы тканей",what="органы мутантов (без токсинов)",items={patterns={"stb_organ_*_clean"}},goal={2,2},time=60,
 desc="Нужны органы мутантов для анализа — только чистые, без токсического заражения. Разделайте пару туш аккуратно.",reward={money=500,per=300,rep=8}}
T{id="prof_hide",profile="professor",type="fetch",title="Шкуры для анализа",what="шкуры мутантов",items={patterns={"stb_hide_*"}},goal={2,3},time=60,
 desc="Шкура мутанта — отличный материал для изучения мутаций. Принесите {n} шт., качество неважно.",reward={money=300,per=250,rep=6}}
T{id="prof_rare_part",profile="professor",type="fetch",title="Редкий компонент",what="редкий компонент разделки",items={patterns={"stb_rare_*"}},time=90,weight=6,
 desc="При разделке иногда попадаются редкие компоненты. Если повезёт — несите сразу мне.",reward={money=1500,rep=10}}
T{id="prof_field",profile="professor",type="visit",title="Замер фона",sources={"field"},time=30,
 desc="Отнесите датчик к полю аномалий «{place}» и постойте у центра. Аккуратнее с аномалиями!",reward={money=700,rep=6}}
-- Охотник: мутанты.
T{id="hunt_tushkan",profile="hunter",type="kill",title="Тушканы",what="тушканы",mutants={"tushkan","tushkan_fast","tushkan_toxic"},goal={5,8},time=40,
 desc="Тушканы опять полезли из оврагов. Убей {n} штук, пока они не съели нам все припасы.",reward={money=150,per=60,rep=4}}
T{id="hunt_dogs",profile="hunter",type="kill",title="Стая слепых псов",what="слепые псы",mutants={"blinddog"},goal={3,5},time=40,
 desc="Стая слепых псов повадилась к дороге. Убей {n} псов — вожака первым, если сможешь.",reward={money=200,per=120,rep=5}}
T{id="hunt_zombie",profile="hunter",type="kill",title="Зомбированные",what="зомбированные, снорки, изломы",mutants={"zombie","snork","izlom"},goal={4,6},time=40,
 desc="Зомбированные бродят у старых домов. Упокой {n} бедолаг — им уже не помочь.",reward={money=200,per=110,rep=5}}
T{id="hunt_chimera",profile="hunter",type="kill",title="Химера",what="химера",mutants={"chimera"},time=60,weight=4,news=true,
 desc="Видели химеру. Если завалишь её — заплачу как за десятерых. Одному не советую.",reward={money=4000,rep=20}}
T{id="hunt_meat",profile="hunter",type="fetch",title="Мясо на ужин",what="мясо мутантов",items={patterns={"stb_meat_*"}},goal={4,6},time=60,
 desc="Своё мясо закончилось. Разделай пару туш и принеси {n} кусков — на всех хватит.",reward={money=150,per=80,rep=4}}
T{id="hunt_season",profile="hunter",type="kill",title="Сезон охоты",what="любые мутанты",goal={8,12},time=60,
 desc="Хороший сезон! Убей {n} мутантов любой породы — плачу за каждого.",reward={money=300,per=70,rep=6}}
-- Связной: доставка посылок и проверка мест.
T{id="cour_parcel",profile="courier",type="deliver",title="Посылка",time=30,
 desc="Отнеси эту посылку: {to} ждёт. Не вскрывай — целее будешь.",reward={money=700,rep=5}}
T{id="cour_urgent",profile="courier",type="deliver",title="Срочная доставка",time=12,weight=7,
 desc="Срочно! Посылка для адресата «{to}», времени мало. Заплачу вдвое.",reward={money=1400,rep=7}}
T{id="cour_docs",profile="courier",type="deliver",title="Документы",time=25,
 desc="Папка с документами — лично в руки: {to}. Без лишних глаз.",reward={money=900,rep=6}}
T{id="cour_check",profile="courier",type="visit",title="Проверить место",sources={"point","poi"},time=30,
 desc="Мои люди не выходят на связь у места «{place}». Проверь, что там, и возвращайся.",reward={money=700,rep=5}}
T{id="cour_water",profile="courier",type="fetch",title="Вода для дозора",what="питьё (вода, энергетик)",items={ids={"water","energy"}},goal={3,4},time=40,
 desc="Дозорным на вышке нечего пить. Принеси {n} бутылок воды или энергетиков.",reward={money=100,per=70,rep=4}}

--[[ «Путь новичка»: шаги обучения. target — что отмечается меткой и ведёт направляющая линия. ]]
Q.TutorialSteps={
 {id="trader",title="Знакомство с торговцем",target="trader",reward={money=300},
  text="Найдите ближайшего торговца (метка на экране) и поговорите с ним: подойдите и нажмите E."},
 {id="detector",title="Детектор в рюкзаке",target="trader",reward={money=500},
  text="Без детектора артефакт не найти. Купите детектор у торговца (например, «Отклик») и держите его в рюкзаке."},
 {id="artifact",title="Первый артефакт",target="field",reward={money=500,items={{"bandage",2}}},
  text="Идите к полю аномалий (метка) и найдите артефакт — детектор подскажет, где он. Подберите его клавишей E. Обходите аномалии!"},
 {id="sell",title="Хабар",target="barman",reward={money=700},
  text="Сдайте артефакт Бармену (в разговоре — «Сдать артефакт») или продайте его торговцу."},
 {id="pda",title="КПК",reward={money=300},
  text="Откройте КПК клавишей F4 и загляните во вкладку «Задания»: здесь активные задания, история и обучение."},
 {id="recruiter",title="Группировки",target="recruiter",reward={money=1000},
  text="Подойдите к вербовщику (метка). У него можно вступить в группировку — или остаться вольным сталкером."},
}

--[[ Общие помощники ]]
function Q.Money(n)
 n=math.floor(tonumber(n) or 0)
 if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(n) end
 return tostring(n).." ₽"
end
function Q.FormatTime(sec)
 sec=math.max(0,math.floor(tonumber(sec) or 0))
 if sec>=3600 then return string.format("%d ч %02d мин",math.floor(sec/3600),math.floor(sec%3600/60)) end
 return string.format("%02d:%02d",math.floor(sec/60),sec%60)
end
-- Подстановка {n}, {what}, {place}, {to} в тексты шаблонов.
function Q.Fill(text,vars)
 return (tostring(text or ""):gsub("{(%w+)}",function(k) local v=vars and vars[k];if v~=nil then return tostring(v) end end))
end
function Q.ItemName(id)
 local d=STALKER_INV and STALKER_INV.Items and STALKER_INV.Items[id]
 return d and d.name or tostring(id)
end
-- Предметы шаблона fetch, которые есть в инвентаре сервера (ids, patterns с «*», category).
function Q.ResolveItems(match)
 local S=STALKER_INV;local out,seen={},{}
 if type(match)~="table" or not S or type(S.Items)~="table" then return out end
 local function add(id) if S.Items[id] and not seen[id] then seen[id]=true;out[#out+1]=id end end
 for _,id in ipairs(match.ids or {}) do add(id) end
 local pats={}
 for _,p in ipairs(match.patterns or {}) do pats[#pats+1]="^"..p:gsub("[%-%.%+%[%]%(%)%$%^%%%?]","%%%0"):gsub("%*",".*").."$" end
 if #pats>0 or match.category then
  local ids={};for id in pairs(S.Items) do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids) do
   if match.category and S.Items[id].category==match.category then add(id) end
   for _,p in ipairs(pats) do if id:match(p) then add(id) end end
  end
 end
 return out
end
-- Каталог мутантов: из STALKER Zone, без неё — встроенный список HL2.
function Q.Mutants()
 local Z=STALKER_ZONE
 if Z and type(Z.Mutants)=="table" and next(Z.Mutants) then return Z.Mutants end
 return Q.MutantFallback
end
-- Строка цели задания для КПК, трекера и диалога.
function Q.Objective(q)
 if type(q)~="table" then return "" end
 local t=q.type
 if t=="fetch" then return "Принесите: "..tostring(q.what or "предметы")
 elseif t=="kill" then return "Убейте: "..tostring(q.what or "мутанты")
 elseif t=="artifact" then return "Подберите артефакты в аномальных полях"
 elseif t=="visit" then return "Посетите место «"..tostring(q.place and q.place.name or "?").."»"
 elseif t=="deliver" then return "Доставьте посылку: "..tostring(q.toName or "получатель")
 elseif t=="emission" then return "Переживите выброс" end
 return ""
end
-- Награда одной строкой: «1 200 ₽ · Антирад ×1 · репутация «Учёные» +8».
function Q.RewardText(r)
 if type(r)~="table" then return "" end
 local parts={}
 if (tonumber(r.money) or 0)>0 then parts[#parts+1]=Q.Money(r.money) end
 for _,it in ipairs(r.items or {}) do if type(it)=="table" then parts[#parts+1]=Q.ItemName(it[1]).." ×"..tostring(it[2] or 1) end end
 if (tonumber(r.rep) or 0)~=0 and r.faction then
  local name=STALKER_CORE and STALKER_CORE.FactionName and STALKER_CORE.FactionName(r.faction) or r.faction
  parts[#parts+1]="репутация «"..tostring(name).."» "..((r.rep>0) and "+" or "")..tostring(r.rep)
 end
 return #parts>0 and table.concat(parts," · ") or "без награды"
end

--[[ Настройки (категория «Задания») ]]
local S=STALKER_SETTINGS
local function bind(id,key,def)
 def.category="Задания";def.type=def.type or "number"
 S.Bind("quests."..id,Cfg,key,def)
end
-- Изменение влияет на состояние игроков в сети: сервер пересылает его и пересчитывает обучение.
local function refresh() if SERVER and Q.RefreshAll then Q.RefreshAll() end end
bind("max_active","MaxActive",{label="Активных заданий у игрока, не больше",min=1,max=10,order=1,realm="shared",onChange=refresh})
bind("daily_limit","DailyLimit",{label="Заданий в сутки на игрока (0 — без ограничения)",min=0,max=200,order=2,realm="shared",onChange=refresh})
bind("reward_mult","RewardMult",{label="Множитель денежных наград",min=.1,max=10,step=.1,decimals=1,order=3,realm="shared",
 description="Действует на новые предложения квестодателей и на шаги обучения."})
bind("tutorial","Tutorial",{label="Обучение «Путь новичка»",type="bool",order=4,realm="shared",onChange=refresh,
 description="Цепочка из шести шагов с наградами для игроков без выполненных заданий."})
bind("offers","Offers",{label="Заданий в предложении квестодателя",min=1,max=6,order=5})
bind("offer_minutes","OfferMinutes",{label="Обновление предложений квестодателя, мин",min=1,max=240,order=6})
bind("cooldown","Cooldown",{label="Откат шаблона задания после сдачи или отказа, мин",min=0,max=1440,order=7})
bind("time_mult","TimeMult",{label="Множитель сроков заданий",min=.25,max=5,step=.25,decimals=2,order=8})
bind("talk_distance","TalkDistance",{label="Дальность разговора с квестодателем, units",min=80,max=400,order=9})
bind("visit_radius","VisitRadius",{label="Радиус места в заданиях «Разведка», units",min=100,max=2000,step=10,order=10,realm="shared"})
bind("min_visit_distance","MinVisitDistance",{label="Место разведки не ближе к квестодателю, units",min=0,max=20000,step=50,order=11})
bind("guide_length","GuideLength",{label="Длина направляющей линии к цели, units",min=300,max=3000,step=50,order=12,realm="shared"})
bind("history","History",{label="Записей в истории заданий",min=5,max=100,order=13})
bind("news","News",{label="Новости КПК о трудных заданиях",type="bool",order=14})
