-- Энциклопедия Зоны: аномалии, артефакты и детекторы, мутанты, группировки, выбросы, радиация.
-- Цифры берутся из конфигов STALKER_ZONE / STFW / ST_EMISSION / STALKER_RAD / STALKER_INV в момент открытия вкладки,
-- поэтому совпадают с настройками сервера. Раздел пропускается, если его аддона нет.
local P=STALKER_PDA
local C=STALKER_CORE
local function m(units) return string.format("%.1f м",C.Meters(tonumber(units) or 0)) end
local function num(v,d) v=tonumber(v) or 0;if v%1==0 then return tostring(v) end;return string.format("%."..(d or 1).."f",v) end
local function signed(v) v=tonumber(v) or 0;return (v>0 and "+" or "")..num(v,2) end

-- Тексты статей (что делать игроку). Цифры добавляются из конфигов.
P.Lore={
 anomalies={
  electro="Сгусток статического электричества. Бьёт разрядом всё живое в радиусе, затем перезаряжается — проходите сразу после разряда. Выдаёт себя треском и голубыми искрами.",
  burner="Термическая аномалия: столб пламени бьёт из-под земли, пока цель внутри. Урон идёт непрерывно. Видна по дрожанию воздуха и редким искрам.",
  springboard="Гравитационная аномалия: подбрасывает и швыряет о землю. Опасна ударом и падением — помогает защита от падения.",
  vortex="Гравитационная воронка: затягивает к центру и разрывает. Почувствовав притяжение, сразу уходите в противоположную сторону.",
  acid="Химическая аномалия: облако ядовитого зелёного пара. Разъедает кожу, пока вы внутри. Спасают химзащита и «Слизь».",
 },
 mutants={
  zombie="Сталкеры, потерявшие разум под пси-излучением. Медлительны, но выносливы и опасны вблизи.",
  snork="Быстрый прыгучий мутант: нападает рывками и сразу уходит из-под огня. Держите дистанцию.",
  izlom="Тяжёлый ядовитый мутант. Бросает в добычу тушканов — сначала отстреливайте мелочь.",
  tushkan="Мелкий прыгучий грызун. Один не страшен, но тушканы держатся стаями.",
  tushkan_fast="Ловкий тушкан, в которого трудно попасть. Стреляйте на упреждение.",
  tushkan_toxic="Ядовитый тушкан: укус сбивает здоровье почти до нуля. Держите при себе аптечку.",
  blinddog="Слепые псы охотятся стаей, окружают и чуют добычу издалека. Отходите к стене.",
  chimera="Сильнейший хищник Зоны: огромный, бронированный и очень живучий. В одиночку не связывайтесь.",
 },
}
P.ArtifactTiers={"распространённый","редкий","очень редкий","легендарный"}
P.DetectorModes={signal="сила сигнала",arrow="направление на артефакт",exact="точные метки артефактов"}
local dmgNames={{"DMG_SHOCK","электричество"},{"DMG_BURN","огонь"},{"DMG_CRUSH","удар"},{"DMG_BLAST","разрыв"},{"DMG_ACID","кислота"},
 {"DMG_POISON","яд"},{"DMG_RADIATION","радиация"},{"DMG_SLASH","порезы"},{"DMG_BULLET","пули"}}
local function damageType(v)
 v=tonumber(v);if not v then return "—" end
 for _,d in ipairs(dmgNames) do local bitv=rawget(_G,d[1]);if bitv and bitv~=0 and bit.band(v,bitv)~=0 then return d[2] end end
 return "физический"
end
local function itemName(id) local S=STALKER_INV;local it=S and S.Items and S.Items[id];return it and it.name or id end
local function statName(key)
 local S,Z=STALKER_INV,STALKER_ZONE
 return (Z and Z.StatNames and Z.StatNames[key]) or (S and S.StatNames and S.StatNames[key]) or key
end

local function anomalies()
 local Z=STALKER_ZONE;if type(Z)~="table" or type(Z.Anomalies)~="table" then return end
 local born={}
 for id,a in pairs(Z.Artifacts or {}) do for an in pairs(a.anomalies or {}) do born[an]=born[an] or {};table.insert(born[an],itemName(id)) end end
 local items={}
 local order=Z.AnomalyOrder or table.GetKeys(Z.Anomalies)
 for _,id in ipairs(order) do
  local a=Z.Anomalies[id]
  if type(a)=="table" then
   local blocks={P.Lore.anomalies[id] or "Аномальное образование. Обходите стороной и следите за детектором.",{head="Характеристики"},
    {"Радиус срабатывания",m(a.radius)},{"Урон",num(a.damage)..(a.interval and (" каждые "..num(a.interval,2).." с") or " за срабатывание"),"danger"},
    {"Тип урона",damageType(a.dmgType)}}
   if tonumber(a.cooldown) and a.cooldown>0 then blocks[#blocks+1]={"Перезарядка",num(a.cooldown).." с"} end
   if a.pull then blocks[#blocks+1]={"Зона притяжения",m(a.pull),"warn"} end
   if a.force then blocks[#blocks+1]={"Сила отброса",num(a.force)} end
   if born[id] then table.sort(born[id]);blocks[#blocks+1]={head="Рождает артефакты"};blocks[#blocks+1]=table.concat(born[id],", ").."." end
   if Z.Config and tonumber(Z.Config.AnomalyDamageScale) and Z.Config.AnomalyDamageScale~=1 then blocks[#blocks+1]={note="Множитель урона аномалий на сервере: ×"..num(Z.Config.AnomalyDamageScale,2)} end
   items[#items+1]={id="anomaly."..id,title=a.name or id,subtitle="Аномалия · радиус "..m(a.radius),color=a.color,blocks=blocks}
  end
 end
 return {title="Аномалии",items=items}
end

local function artifacts()
 local Z,S=STALKER_ZONE,STALKER_INV
 if type(Z)~="table" or type(Z.Artifacts)~="table" then return end
 local list={}
 for id,a in pairs(Z.Artifacts) do list[#list+1]={id=id,spawn=a,item=S and S.Items and S.Items[id] or {}} end
 table.sort(list,function(x,y) local tx,ty=x.spawn.tier or 1,y.spawn.tier or 1;if tx~=ty then return tx<ty end;return tostring(x.item.name or x.id)<tostring(y.item.name or y.id) end)
 local items={}
 for _,e in ipairs(list) do
  local it,sp=e.item,e.spawn
  local blocks={it.description or "Аномальное образование неизвестной природы.",{head="Свойства на поясе"}}
  local stats=type(it.stats)=="table" and it.stats or {}
  local keys=table.GetKeys(stats);table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do
   local v=tonumber(stats[k])
   if v and k=="radiation" then blocks[#blocks+1]={"Радиация",v>0 and (signed(v).." ед/с — фонит") or (signed(v).." ед/с — выводит"),v>0 and "danger" or "ok"}
   elseif v and k~="condition" then blocks[#blocks+1]={statName(k),signed(v),v>0 and "ok" or "danger"} end
  end
  blocks[#blocks+1]={head="Где искать"}
  local where={};for an in pairs(sp.anomalies or {}) do local a=Z.Anomalies and Z.Anomalies[an];where[#where+1]=a and a.name or an end
  table.sort(where)
  blocks[#blocks+1]=#where>0 and ("Рождается в аномалиях: "..table.concat(where,", ")..". Виден только с детектором в рюкзаке.") or "Место появления неизвестно."
  local price=Z.ItemPrices and Z.ItemPrices[e.id]
  if price then
   blocks[#blocks+1]={head="Цена"}
   if price.sell then blocks[#blocks+1]={"Торговцы платят до",P.Money(price.sell),"accent2"} end
   if price.buy then blocks[#blocks+1]={"Купить у торговца",P.Money(price.buy)} end
   blocks[#blocks+1]={note="Цена сделки зависит от состояния артефакта, репутации и отношений группировок."}
  end
  if it.weight then blocks[#blocks+1]={"Вес",num(it.weight,2).." кг"} end
  local tier=P.ArtifactTiers[tonumber(sp.tier) or 1] or "редкий"
  items[#items+1]={id="artifact."..e.id,title=it.name or e.id,subtitle="Артефакт · "..tier,color=sp.color,blocks=blocks}
 end
 -- Детекторы: без них артефакты не видны.
 local dets={}
 for id,d in pairs(Z.Detectors or {}) do dets[#dets+1]={id=id,d=d} end
 table.sort(dets,function(a,b) return (a.d.tier or 0)<(b.d.tier or 0) end)
 for _,e in ipairs(dets) do
  local price=Z.ItemPrices and Z.ItemPrices[e.id]
  local blocks={"Детектор работает, пока лежит в рюкзаке; из нескольких работает лучший. Чем ближе артефакт, тем чаще писк.",
   {"Уровень",num(e.d.tier)},{"Дальность",m(e.d.range)},{"Режим",P.DetectorModes[e.d.mode] or tostring(e.d.mode or "—")}}
  if price and price.buy then blocks[#blocks+1]={"Цена у торговца",P.Money(price.buy),"accent2"} end
  items[#items+1]={id="detector."..e.id,title=itemName(e.id),subtitle="Детектор · дальность "..m(e.d.range),blocks=blocks}
 end
 return {title="Артефакты и детекторы",items=items}
end

local function mutants()
 local Z=STALKER_ZONE;if type(Z)~="table" or type(Z.Mutants)~="table" then return end
 local B=STALKER_BUTCHERING;local butcher=B and B.Config and B.Config.Mutants
 local items={}
 for _,id in ipairs(Z.MutantOrder or table.GetKeys(Z.Mutants)) do
  local mu=Z.Mutants[id]
  if type(mu)=="table" then
   local blocks={P.Lore.mutants[id] or "Порождение Зоны. Будьте осторожны.",{head="Сведения"}}
   if mu.reward then blocks[#blocks+1]={"Награда за убийство",P.Money(mu.reward),"accent2"} end
   if tonumber(mu.health) and mu.health~=1 then blocks[#blocks+1]={"Живучесть","×"..num(mu.health,2),"warn"} end
   if mu.faction then blocks[#blocks+1]={"Стая",C.FactionName(mu.faction)} end
   local b=type(butcher)=="table" and butcher[mu.class]
   if type(b)=="table" then
    blocks[#blocks+1]={head="Разделка туши"}
    blocks[#blocks+1]={"Сложность","×"..num(b.difficulty,2)}
    blocks[#blocks+1]={"Токсичность",math.floor((tonumber(b.toxicity) or 0)*100).."%",(tonumber(b.toxicity) or 0)>.6 and "danger" or "warn"}
    blocks[#blocks+1]={"Выход трофеев","×"..num(b.yield,2)}
    blocks[#blocks+1]={note="Тушу разделывают монтировкой (E по туше) — мясо, шкуры и органы продаются торговцам."}
   end
   items[#items+1]={id="mutant."..id,title=mu.name or id,subtitle="Мутант"..(mu.reward and (" · награда "..P.Money(mu.reward)) or ""),blocks=blocks}
  end
 end
 return {title="Мутанты",items=items}
end

-- Отношения: текущие (снимок F6, если уже пришёл) или начальные из конфигурации.
local function relations(F,id)
 local out={}
 local rel=F.State and F.State.relations
 if type(rel)=="table" then
  for key,r in pairs(rel) do
   local a,b=tostring(key):match("^([%w_]+):([%w_]+)$")
   if a and (a==id or b==id) and type(r)=="table" then out[#out+1]={a==id and b or a,tonumber(r.points) or 0,r.war} end
  end
 else
  for _,r in ipairs(F.InitialRelations or {}) do
   if r[1]==id or r[2]==id then out[#out+1]={r[1]==id and r[2] or r[1],tonumber(r[3]) or 0} end
  end
 end
 table.sort(out,function(x,y) return x[2]<y[2] end)
 return out
end
local function factions()
 local F=STFW;if type(F)~="table" or type(F.Factions)~="table" then return end
 local text=F.Text or function(v) return type(v)=="table" and (v.ru or v.en) or tostring(v or "") end
 local list={}
 for id,f in pairs(F.Factions) do if f.playable then list[#list+1]=id end end
 table.sort(list,function(a,b) return C.FactionName(a)<C.FactionName(b) end)
 local items={}
 for _,id in ipairs(list) do
  local f=F.Factions[id]
  local blocks={text(f.description),{"Цель",text(f.ideology)},{"Позывной",tostring(f.tag or "—")}}
  local fee=F.Config and ((F.Config.JoinFees and F.Config.JoinFees[id]) or F.Config.JoinFee)
  if fee then blocks[#blocks+1]={"Вступительный взнос",tonumber(fee)==0 and "без взноса" or P.Money(fee),"accent2"} end
  local summary=F.State and F.State.summary
  if type(summary)=="table" and summary.members and summary.members[id] then
   local cap=summary.caps and summary.caps[id]
   blocks[#blocks+1]={"Состав",tostring(summary.members[id])..((tonumber(cap) or 0)>0 and (" / "..cap) or "")}
  end
  local rel=relations(F,id)
  if #rel>0 then
   blocks[#blocks+1]={head="Отношения"}
   for _,r in ipairs(rel) do
    local token=r[3] and "danger" or r[2]<=-30 and "danger" or r[2]>=30 and "ok" or "muted"
    blocks[#blocks+1]={C.FactionName(r[1]),(r[3] and "война, " or "")..string.format("%+d",r[2]),token}
   end
  end
  blocks[#blocks+1]={note="Вступление — у вербовщика группировки (E) или по приглашению лидера. Сеть группировок — F6."}
  local col=f.color and Color(f.color[1] or 200,f.color[2] or 200,f.color[3] or 200) or nil
  items[#items+1]={id="faction."..id,title=C.FactionName(id),subtitle="Группировка · "..tostring(f.tag or ""),color=col,blocks=blocks}
 end
 return {title="Группировки",items=items}
end

local function emissions()
 local E=ST_EMISSION;if type(E)~="table" or type(E.Config)~="table" then return end
 local cfgE=E.Config;local set=type(E.Settings)=="table" and E.Settings or nil
 local lo=set and tonumber(set.min) or (tonumber(cfgE.IntervalMin) or 0)/60
 local hi=set and tonumber(set.max) or (tonumber(cfgE.IntervalMax) or 0)/60
 local auto=set and set.auto or (set==nil and cfgE.AutoStart)
 local blocks={"Выброс — волна пси-энергии из центра Зоны. Убивает всех, кто остался под открытым небом. После выброса аномалии смещаются и рождаются новые артефакты.",
  {head="Как пережить"},"Услышав сирену, бегите под крышу: в здание, подвал, тоннель. Над головой должна быть крыша — открытые навесы не спасают.",
  "На пике выброса незащищённые сталкеры теряют сознание и получают тяжёлый урон.",
  {head="Расписание"},{"Выбросы по расписанию",auto and "включены" or "выключены",auto and "warn" or "muted"}}
 if auto and lo>0 then blocks[#blocks+1]={"Промежуток между выбросами",math.floor(lo).."–"..math.floor(hi).." мин"} end
 if tonumber(cfgE.KnockoutSeconds) then blocks[#blocks+1]={"Обморок на пике",num(cfgE.KnockoutSeconds).." с","danger"} end
 if type(cfgE.Phases)=="table" then
  blocks[#blocks+1]={head="Фазы"}
  local total=0
  for _,ph in ipairs(cfgE.Phases) do total=total+(tonumber(ph.duration) or 0) end
  for _,ph in ipairs(cfgE.Phases) do
   blocks[#blocks+1]={tostring(ph.name or ph.id),num(ph.duration).." с · урон "..num(ph.damage,1).."–"..num(ph.damageEnd,1).."/с",(tonumber(ph.damageEnd) or 0)>=4 and "danger" or "warn"}
  end
  blocks[#blocks+1]={note="Весь выброс длится около "..P.Duration(total)..". Урон указан для сталкеров вне укрытия."}
 end
 return {title="Выбросы",items={{id="emission.main",title="Выброс",subtitle="Главная угроза Зоны",blocks=blocks}}}
end

local function radiation()
 local R=STALKER_RAD;local S=STALKER_INV
 if type(R)~="table" and type(S)~="table" then return end
 local rc=type(R)=="table" and type(R.Config)=="table" and R.Config or {}
 local blocks={"Радиация копится как доза от 0 до 100. Источники — заражённые места, территории с фоном и фонящие артефакты на поясе. Вне заражения доза медленно спадает.",
  {head="Порог опасности"}}
 if rc.DamageThreshold then blocks[#blocks+1]={"Урон начинается с дозы",num(rc.DamageThreshold),"danger"} end
 if rc.MaxDamage then blocks[#blocks+1]={"Наибольший урон",num(rc.MaxDamage).." в секунду","danger"} end
 if rc.Decay then blocks[#blocks+1]={"Естественный спад дозы",num(rc.Decay,2).." в секунду","ok"} end
 local cure,protect={},{}
 for id,it in pairs(S and S.Items or {}) do
  local st=type(it)=="table" and type(it.stats)=="table" and it.stats or {}
  if tonumber(st.dose) and st.dose>0 then cure[#cure+1]={it.name or id,"−"..num(st.dose)}
  elseif id=="antirad" then cure[#cure+1]={it.name or id,"−"..num(rc.Antirad or 40)} end
  if tonumber(st.radiationProtection) and st.radiationProtection>0 then protect[#protect+1]={it.name or id,math.floor(st.radiationProtection*100).."%"} end
 end
 table.sort(cure,function(a,b) return a[1]<b[1] end);table.sort(protect,function(a,b) return a[1]<b[1] end)
 local items={{id="radiation.dose",title="Доза и фон",subtitle="Как работает радиация",blocks=blocks}}
 local help={"Дозу снижают препараты и спиртное, защиту дают костюмы и некоторые артефакты (отрицательная радиация в свойствах)."}
 if #cure>0 then help[#help+1]={head="Снижают дозу"};for _,c in ipairs(cure) do help[#help+1]={c[1],c[2],"ok"} end end
 if #protect>0 then help[#help+1]={head="Защита костюмов"};for _,c in ipairs(protect) do help[#help+1]={c[1],c[2],"info"} end end
 items[#items+1]={id="radiation.help",title="Защита и лечение",subtitle="Препараты и снаряжение",blocks=help}
 return {title="Радиация",items=items}
end

-- Все разделы энциклопедии (без панелей — проверяется тестами и без соседних аддонов).
P.EncyclopediaSections={anomalies,artifacts,mutants,factions,emissions,radiation}
function P.EncyclopediaData()
 local out={}
 for _,fn in ipairs(P.EncyclopediaSections) do
  local ok,g=pcall(fn)
  if ok and type(g)=="table" and g.items and #g.items>0 then out[#out+1]=g
  elseif not ok then ErrorNoHalt("[STALKER PDA] энциклопедия: "..tostring(g).."\n") end
 end
 return out
end

P.AddTab("encyclopedia",{title="Энциклопедия",order=50,build=function(parent)
 local data=P.EncyclopediaData()
 if #data==0 then P.UI.Text(parent,"Сведений о Зоне пока нет: аддоны Зоны не установлены.","muted");return end
 parent.Catalog=P.Catalog(parent,data,{placeholder="Поиск: аномалия, артефакт, мутант…",selected=P.EncyclopediaSelected})
 local select=parent.Catalog.select
 parent.Catalog.select=function(id) P.EncyclopediaSelected=id;select(id) end
end})
