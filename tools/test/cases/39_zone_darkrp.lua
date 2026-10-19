-- Задание J: настройки Зоны в админ-системе, панель «Коменданта», износ защиты, сумка погибшего с наводкой,
-- доза через STALKER_RAD, метки карты КПК, отладка аномалий, stz_status, памятка и DarkRP без F4.
-- Область мира: x 5 500 000 … 5 900 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local Z,S,ST=STALKER_ZONE,STALKER_INV,STALKER_SETTINGS
local X=5500000
local function join(nick,x,y,opts)
 opts=opts or {};opts.nick=nick;opts.pos=Vector(X+(x or 0),y or 0,0)
 return TEST.join(opts)
end

section("Зона: настройки в админ-системе ("..M.Realm..")")
local allowed={["Аномалии"]=true,["Артефакты"]=true,["Мутанты"]=true,["Выживание"]=true,["Смерть и потери"]=true,["Торговля"]=true}
local n,badCat=0,nil
for id,def in pairs(ST.Defs) do
 if id:sub(1,5)=="zone." then n=n+1;if not allowed[def.category] or def.label==id then badCat=id end end
end
check(n>=60,"параметры Зоны зарегистрированы: "..n)
check(badCat==nil,"категории и подписи по-русски: "..tostring(badCat))
for _,id in ipairs({"zone.detector.det_echo.range","zone.detector.det_veles.range","zone.anomaly.electro.radius","zone.anomaly.vortex.pull",
 "zone.artifact_visible_range","zone.anomaly_damage_scale","zone.mutant.chimera.reward","zone.death_bag_range"}) do
 check(ST.Defs[id] and ST.Defs[id].realm=="shared","нужное клиенту — shared: "..id)
end
for _,id in ipairs({"zone.anomaly.burner.interval","zone.anomaly.electro.cooldown","zone.anomaly.electro.damage","zone.anomaly.springboard.force",
 "zone.mutant.zombie.health","zone.max_artifacts","zone.artifact_refresh","zone.survival_enabled","zone.survival_tick","zone.death_drop",
 "zone.death_bag_lifetime","zone.ammo_persistence","zone.restock_minutes","zone.restock_share","zone.resist_cap","zone.starter",
 "zone.max_mutants","zone.corpse_lifetime","zone.artifact_bonus.trader_scientists","zone.map_fields","zone.map_traders"}) do
 check(ST.Defs[id]~=nil,"настройка "..id)
end
check(not ST.Defs["zone.anomaly.burner.cooldown"],"у «Жарки» вместо перезарядки — период урона")
check(Z.Mutants.zombie.health==1 and Z.Mutants.chimera.health==1.5,"множитель здоровья есть у каждого мутанта")

if SERVER then
 section("Зона: настройки применяются")
 check(ST.Set("zone.anomaly.electro.radius",150),"радиус «Электры» меняется из панели")
 check(Z.Anomalies.electro.radius==150,"радиус применён к таблице аномалий")
 ST.Set("zone.anomaly.electro.radius",nil)
 check(Z.Anomalies.electro.radius==110,"сброс возвращает значение по умолчанию")
 check(ST.Set("zone.starter",false) and next(S.Config.Starter)==nil,"стартовый набор выключается")
 ST.Set("zone.starter",nil)
 check(#S.Config.Starter==#Z.Config.Starter,"стартовый набор снова включён")
 local N=STALKER_NPC
 local sci=N and N.Config.Traders.trader_scientists
 if check(sci and sci.prices.medusa,"учёные скупают артефакты") then
  ST.Set("zone.artifact_bonus.trader_scientists",2)
  check(sci.prices.medusa.sell==math.floor(Z.ItemPrices.medusa.sell*2),"множитель цены артефактов у учёных применён: "..sci.prices.medusa.sell)
  ST.Set("zone.artifact_bonus.trader_scientists",nil)
  check(sci.prices.medusa.sell==math.floor(Z.ItemPrices.medusa.sell*1.25),"множитель сброшен")
 end
 check(ST.Set("zone.survival_tick",15) and Z.Config.Survival.Tick==15,"интервал голода меняется на лету");ST.Set("zone.survival_tick",nil)
 check(ST.Set("zone.restock_minutes",0),"восполнение складов можно выключить")
 local stock=N.GetStock("trader_duty")
 for i,it in pairs(stock.grid) do if it.id=="bandage" then stock.grid[i]=nil end end
 -- Счётчик «просрочен»: при включённом восполнении склад пополнился бы на ближайшем такте.
 Z.RestockCounter=1000
 local before=util.TableToJSON(stock.grid);M.advance(61,1)
 check(util.TableToJSON(N.GetStock("trader_duty").grid)==before,"при 0 минут склады сами не восполняются")
 ST.Set("zone.restock_minutes",nil)

 section("Снаряжение: защита падает с износом")
 local gear=Z.GearProfile({equipment={armor={id="zarya",uid="t1",durability=50},helmet={id="sphere",uid="t2",durability=100},
  artifact1={id="battery",uid="t3",durability=50},boots={id="army_boots",uid="t4",durability=0}}})
 check(math.abs(gear.bulletResist-7.5)<1e-6,"костюм на 50% защищает на 75%: "..tostring(gear.bulletResist))
 check(math.abs(gear.headshot-45)<1e-6,"целый шлем — полная защита головы")
 check(gear.speed==8 and math.abs((gear.radiation or 0)-.1)<1e-6,"скорость и фон артефакта не зависят от износа")
 check(gear.fallResist==nil,"сломанные ботинки не защищают")
 local wearer=join("Носитель",0,0)
 check(S.GiveItem(wearer,"zarya",1),"костюм выдан")
 S.HandleAction(wearer,"move","grid",TEST.gridIndex(wearer,"zarya"),"equipment","armor")
 check(Z.Gear[wearer] and Z.Gear[wearer].bulletResist==10,"новый костюм — полная защита")
 local inv=table.Copy(wearer.StalkerInventory);inv.equipment.armor.durability=40;S.Commit(wearer,inv)
 check(math.abs(Z.Gear[wearer].bulletResist-7)<1e-6,"после износа защита пересчитана: "..Z.Gear[wearer].bulletResist)

 section("Доза — через STALKER_RAD")
 local R=STALKER_RAD
 if check(R and R.AddDose,"API радиации загружен") then
  R.SetDose(wearer,50)
  check(S.GiveItem(wearer,"vodka",1),"водка выдана")
  S.HandleAction(wearer,"use","grid",TEST.gridIndex(wearer,"vodka"))
  check(math.abs(R.GetDose(wearer)-35)<1e-6 and math.abs(wearer.StalkerInventory.dose-35)<1e-6,"водка снижает дозу на 15: "..R.GetDose(wearer))
  check(math.abs(wearer:GetNW2Float("stalker_dose",0)-35)<1e-6,"доза в NW2 совпадает")
  local orig,calls=R.AddDose,0
  R.AddDose=function(p,d) if p==wearer and d<0 then calls=calls+1 end;return orig(p,d) end
  check(S.GiveItem(wearer,"bubble",1),"«Пузырь» выдан")
  S.HandleAction(wearer,"move","grid",TEST.gridIndex(wearer,"bubble"),"equipment","artifact1")
  M.advance(3,.5)
  R.AddDose=orig
  check(calls>=1,"«Пузырь» выводит дозу через AddDose: "..calls)
 end

 section("Сумка погибшего и наводка на тайник")
 local given={};local giveOrig=S.GiveStashIntel
 S.GiveStashIntel=function(p,intel) given[#given+1]={p=p,intel=intel};return true end
 local plant
 hook.Add("DoPlayerDeath","zzz.test39.intel",function(victim) if plant then victim.StalkerIntelPending=plant end end)
 local function bagNear(pos) for _,b in ipairs(ents.FindByClass("stalker_deathbag")) do if b:GetPos():Distance(pos)<40 then return b end end end
 local looter=join("Обыскивающий",3000,0)
 -- Пустой рюкзак, но есть наводка: сумка всё равно выпадает.
 local v1=join("Пустой",1000,0)
 for i=1,40 do v1.StalkerInventory.grid[i]=nil end
 plant={owner="76561198000009999",ownerName="Хозяин",stash="s1"}
 M.kill(v1)
 local bag=bagNear(v1:GetPos()+Vector(0,0,16))
 check(IsValid(bag) and bag.StashIntel==plant and #bag.Items==0,"сумка с наводкой выпала при пустом рюкзаке")
 check(bag and bag:GetHasIntel()==true and bag:GetOwnerSID()==v1:SteamID64(),"сумка знает о записях КПК и владельце")
 if bag then
  looter._pos=bag:GetPos()-Vector(0,0,40)
  Z.LootBag(looter,bag)
  check(#given==1 and given[1].p==looter and given[1].intel==plant,"обыскавший получил наводку")
  check(not IsValid(bag),"пустая сумка после наводки убрана")
 end
 -- Рюкзак с вещами и наводкой.
 local v2=join("С вещами",1500,0)
 check(S.GiveItem(v2,"medkit_army",2),"вещи выданы")
 local items=table.Count(v2.StalkerInventory.grid)
 plant={owner="76561198000009998",ownerName="Другой",stash="s2"}
 M.kill(v2)
 bag=bagNear(v2:GetPos()+Vector(0,0,16))
 check(IsValid(bag) and #bag.Items==items and bag.StashIntel,"сумка с вещами и наводкой")
 if bag then
  looter._pos=bag:GetPos()-Vector(0,0,40)
  Z.LootBag(looter,bag)
  check(#given==2 and given[2].intel==plant,"наводка передана вместе с вещами")
  check(not IsValid(bag) and bag.StashIntel==nil,"сумка забрана целиком, наводка не повторяется")
 end
 -- Пустой рюкзак без наводки — сумки нет.
 plant=nil
 local v3=join("Нищий",2000,0)
 for i=1,40 do v3.StalkerInventory.grid[i]=nil end
 M.kill(v3)
 check(not bagNear(v3:GetPos()+Vector(0,0,16)),"без вещей и наводки сумка не выпадает")
 hook.Remove("DoPlayerDeath","zzz.test39.intel");S.GiveStashIntel=giveOrig
 for _,p in ipairs({v1,v2,v3}) do M.spawn(p) end

 section("Метки Зоны на карте КПК")
 local MK=STALKER_MARKERS
 local trader=ents.Create("stalker_npc_trader");trader:SetTraderID("sidor");trader:SetPos(Vector(X+5000,0,0))
 local recruiter=ents.Create("stalker_recruiter");recruiter:SetFactionID("duty");recruiter:SetPos(Vector(X+5200,0,0))
 Z.World.fields.mk39={id="mk39",name="Секретное поле",pos={x=X+6000,y=0,z=0},radius=700,count=3,artifacts=0,types={electro=true}}
 Z.World.zones.mk39={id="mk39",name="Секретное логово",pos={x=X+7000,y=0,z=0},radius=500,max=2,respawn=600,types={zombie=true}}
 Z.UpdateMarkers()
 local mt=MK.Get("stz.trader."..trader:EntIndex())
 check(mt and mt.kind=="trader" and mt.label=="Сидорович","торговец на карте: "..tostring(mt and mt.label))
 check(mt and mt.map==true and mt.range==0 and mt.world==false and mt.edge==false,"торговец только на карте (без HUD)")
 local mr=MK.Get("stz.recruiter."..recruiter:EntIndex())
 check(mr and mr.kind=="recruiter" and mr.label:find("Вербовщик",1,true) and mr.label:find("Долг",1,true),"вербовщик на карте: "..tostring(mr and mr.label))
 local mf=MK.Get("stz.field.mk39")
 check(mf and mf.label=="Аномальное поле" and mf.kind=="anomaly" and mf.radius==700 and mf.range==0,"поле аномалий: метка без названия поля и без HUD")
 local ml=MK.Get("stz.lair.mk39")
 check(ml and ml.label=="Логово мутантов" and ml.kind=="lair" and ml.range==0,"логово мутантов на карте")
 check(MK.Kinds.anomaly and MK.Kinds.lair and MK.Kinds.recruiter,"типы меток Зоны зарегистрированы для легенды карты")
 ST.Set("zone.map_traders",false)
 check(not MK.Get("stz.trader."..trader:EntIndex()) and MK.Get("stz.field.mk39"),"торговцы скрываются настройкой, поля остаются")
 ST.Set("zone.map_traders",nil)
 Z.World.fields.mk39=nil;Z.World.zones.mk39=nil;trader:Remove();recruiter:Remove()
 M.advance(31,1)
 check(not MK.Get("stz.field.mk39") and not MK.Get("stz.recruiter."..recruiter:EntIndex()),"метки обновляются раз в 30 с")

 section("Редактор Зоны: действия и права")
 local admin=join("Комендант Зоны",8000,0,{superadmin=true,aim=Vector(X+8200,0,0)})
 local plain=join("Посторонний",8100,0)
 check(Z.CanEdit(admin) and not Z.CanEdit(plain),"право zone проверяется через STALKER_CORE.CanAdmin")
 local ok,msg=Z.EditorAction(admin,{op="restock"})
 check(ok and tostring(msg):find("Пополнено складов",1,true),"пополнение складов: "..tostring(msg))
 ok,msg=Z.EditorAction(admin,{op="mutants_clear"})
 check(ok and tostring(msg):find("Убрано мутантов",1,true),"мутанты убираются: "..tostring(msg))
 check(not Z.EditorAction(plain,{op="restock"}) and not Z.EditorAction(plain,{op="mutants_clear"}),"без права zone быстрые действия недоступны")
 local raw=util.TableToJSON({op="artifacts",kind="field"})
 local chat=#plain._chat
 M.netReceive("stz.action",16+#raw*8,plain,{#raw,raw})
 check(#plain._chat==chat,"сеть: игрок без права не выполняет действие")
 M.netSent={}
 M.netReceive("stz.action",16+#raw*8,admin,{#raw,raw})
 check(admin._chat[#admin._chat]:find("Добавлено артефактов",1,true),"сеть: администратор досыпает артефакты")
 local state
 for _,s in ipairs(M.netSent) do if s.name=="stz.state" and s.to==admin then state=util.JSONToTable(util.Decompress(s.data[2])) end end
 check(state and state.stats and state.stats.mutants~=nil and state.stats.maxMutants and state.reply and state.reply.message,"снимок для панели: сводка мутантов и ответ")
 -- Телепорт к полю из списка панели.
 -- Телепорт к полю из списка панели (координаты области теста вне границ редактора — запись кладём напрямую).
 Z.World.fields.tp39={id="tp39",name="Поле J",pos={x=X+8200,y=0,z=0},radius=300,count=2,artifacts=0,types={acid=true}}
 admin._pos=Vector(X+9000,500,0)
 ok,msg=Z.EditorAction(admin,{op="goto",kind="field",id="tp39"})
 check(ok and admin:GetPos():Distance(Vector(X+8200,0,0))<200,"телепорт к полю: "..tostring(msg))
 check(not Z.EditorAction(plain,{op="goto",kind="field",id="tp39"}),"телепорт только с правом zone")
 Z.World.fields.tp39=nil

 section("stz_status и ошибки аномалий")
 local broken=ents.Create("stalker_anomaly");broken:SetKind("acid");broken:SetPos(Vector(X+12000,0,0));broken:Spawn()
 broken.Tick=function() error("тест J") end
 local warns=#M.warnings
 broken:Think()
 local last=Z.Errors[#Z.Errors]
 check(last and last.source:find("Кисель",1,true)==nil and last.source:find("acid",1,true) and last.text:find("тест J",1,true),"ошибка аномалии записана в журнал Зоны")
 if #M.warnings>warns then table.remove(M.warnings) end
 broken:Remove()
 M.printed={}
 M.command(nil,"stz_status")
 local text=table.concat(M.printed,"\n")
 check(text:find("[STALKER Zone] Карта",1,true) and text:find("Логова",1,true) and text:find("тест J",1,true),"stz_status: сводка и последние ошибки")
 M.command(plain,"stz_status")
 check(plain._chat[#plain._chat]:find("Нужно право",1,true),"stz_status недоступен без права")
 M.command(admin,"stz_status")
 check(admin._chat[#admin._chat]:find("выведена в консоль",1,true),"stz_status для администратора — в консоль")
 check(hook.Run("PlayerSay",plain,"!памятка")=="","!памятка открывает памятку")

 section("DarkRP: профессии без F4")
 local saved={teams=RPExtraTeams,default=GAMEMODE.DefaultTeam,num=team.NumPlayers,notify=DarkRP.notify}
 RPExtraTeams={[1]={name="Сталкер"},[2]={name="Боец «Долга»",stalkerFaction="duty",max=0},[3]={name="Учёный",stalkerFaction="scientists",max=1},[4]={name="Администрация"}}
 GAMEMODE.DefaultTeam=1
 local notes={}
 DarkRP.notify=function(p,kind,sec,text) notes[#notes+1]=text end
 team.NumPlayers=function(t) local c=0;for _,p in ipairs(player.GetAll()) do if p._team==t then c=c+1 end end;return c end
 M.loadFile(os.getenv("GMOD_ROOT").."/darkrpmodification/lua/darkrp_modules/stalker_jobs/sv_jobs.lua","stalker_jobs/sv_jobs.lua")
 local function rp(nick,x,admin2)
  local p=M.addPlayer({nick=nick,pos=Vector(X+x,9000,0),admin=admin2})
  p.changeTeam=function(self,t,force)
   local allow,reason=hook.Call("playerCanChangeTeam",nil,self,t,force)
   if allow==false then self._reason=reason;return false end
   self._team=t;return true
  end
  return p
 end
 local function member(p,f) p:SetNW2Bool("stfw_joined",f~=nil);p:SetNW2String("stfw_faction",f or "loner") end
 local H=hook.GetTable()
 local a=rp("Одиночка",100)
 check(not a:changeTeam(2,false) and tostring(a._reason):find("вербовщик",1,true),"ручная смена профессии запрещена: "..tostring(a._reason))
 check(a:changeTeam(2,true) and a:Team()==2,"принудительная смена разрешена");a._team=1
 local mod=rp("Модератор",200,true)
 check(mod:changeTeam(4,false) and mod:Team()==4,"администратор меняет профессию вручную")
 member(a,"duty");H.STFW_FactionChanged["STALKER.Jobs.AutoJoin"](a,"duty")
 check(a:Team()==2,"вступление выдаёт профессию группировки")
 member(a,nil);H.STFW_FactionLeft["STALKER.Jobs.Left"](a,"duty")
 check(a:Team()==1,"выход из группировки сразу снимает профессию")
 local first,second=rp("Учёный 1",300),rp("Учёный 2",400)
 member(first,"scientists");member(second,"scientists")
 H.STFW_FactionChanged["STALKER.Jobs.AutoJoin"](first,"scientists")
 H.STFW_FactionChanged["STALKER.Jobs.AutoJoin"](second,"scientists")
 check(first:Team()==3 and second:Team()==1 and second.StalkerJobPending==3,"нет мест — профессия ждёт")
 local f4=false;for _,t in ipairs(notes) do if t:find("F4",1,true) then f4=true end end
 check(not f4 and #notes>0,"сообщения не отправляют в F4")
 member(first,nil);M.advance(5.5,.5)
 check(first:Team()==1 and second:Team()==3,"место освободилось — профессия выдана сама")
 for _,p in ipairs({a,mod,first,second}) do M.removePlayer(p) end
 hook.Remove("playerCanChangeTeam","STALKER.Jobs.NoManual");hook.Remove("STFW_FactionChanged","STALKER.Jobs.AutoJoin")
 hook.Remove("STFW_FactionLeft","STALKER.Jobs.Left");timer.Remove("STALKER.Jobs.Membership")
 RPExtraTeams=saved.teams;GAMEMODE.DefaultTeam=saved.default;team.NumPlayers=saved.num;DarkRP.notify=saved.notify
 M.removePlayer(plain);M.removePlayer(looter)
end

if CLIENT then
 section("Клиент: настройки Зоны")
 check(ST.Apply("zone.artifact_visible_range",300) and Z.Config.ArtifactVisibleRange==300,"видимость артефактов приходит с сервера")
 ST.Apply("zone.artifact_visible_range",260)

 section("Клиент: редактор и панель «Коменданта»")
 local state={ready=true,stats={anomalies=4,artifacts=2,maxArtifacts=60,mutants=3,maxMutants=60,fields=1,zones=1,maxFields=64,maxZones=64,refresh=45,restock=20,traders=true,map="gm_test"},
  errors={{t=os.time(),source="Аномалия «acid»",text="тест"}},reply={ok=true,message="Добавлено артефактов: 2",op="artifacts"},
  fields={{id="f1",kind="field",name="Поле",pos={x=X,y=0,z=0},radius=500,count=5,artifacts=2,types={electro=true},liveAnomalies=5,liveArtifacts=1}},
  zones={{id="z1",kind="zone",name="Логово",pos={x=X+100,y=0,z=0},radius=400,max=3,respawn=60,types={zombie=true},liveMutants=2}}}
 local data=util.Compress(util.TableToJSON(state))
 M.netReceive("stz.state",16+#data*8,nil,{#data,data})
 check(Z.EditorState.stats.mutants==3 and Z.LastReply and Z.LastReply.ok,"снимок Зоны принят клиентом")
 M.command(nil,"stz_editor")
 local ed=Z.Editor
 if check(ed and ed.Rebuild and ed.BuildForm,"редактор открыт в окне STALKER_STYLE.Window") then
  M.protect("editor rebuild",ed.Rebuild,ed,"f1")
  ed.Kind="zone";ed.Selected="z1";M.protect("editor zone form",ed.BuildForm,ed)
  M.protect("editor paint",ed.Paint,ed,1000,680)
  check(ed.RadButton and ed.RadButton.Label=="Радиационные зоны","кнопка «Радиационные зоны» вместо команд радиации")
  M.consoleCommands={}
  M.protect("rad button",ed.RadButton.DoClick,ed.RadButton)
  check(M.consoleCommands[1] and M.consoleCommands[1][1]=="stalker_rad_menu","кнопка открывает stalker_rad_menu")
 end
 local src=io.open(os.getenv("GMOD_ROOT").."/stalker_zone/lua/stalker_zone/cl_editor.lua"):read("*a")
 check(not src:find("stalker_rad_add",1,true) and not src:find("stalker_rad_list",1,true),"в редакторе нет старых команд радиации")
 M.protect("editor preview",Z.DrawEditorPreview);M.protect("editor labels",Z.DrawEditorLabels)
 M.protect("entry row",Z.PaintEntryRow,"field",state.fields[1],400,46,true);M.protect("reply",Z.PaintReply,400,26)
 local root,v
 M.protect("admin panel",function() root,v=Z.BuildAdminPanel(M.stub("holder")) end)
 check(root and v and v.fields and v.zones and #v.buttons==5,"панель «Коменданта»: сводка, 5 действий, списки")
 if v then
  local labels={};for _,b in ipairs(v.buttons) do labels[#labels+1]=b.Label end
  local joined=table.concat(labels,"|")
  check(joined:find("Открыть редактор Зоны",1,true) and joined:find("Перестроить",1,true) and joined:find("Досыпать артефакты",1,true)
   and joined:find("Пополнить склады",1,true) and joined:find("Убрать мутантов",1,true),"кнопки панели: "..joined)
  M.protect("admin lists",Z.FillAdminLists,v)
  M.protect("admin summary",Z.PaintAdminSummary,800,100)
  M.netSent={}
  M.protect("restock click",v.buttons[4].DoClick,v.buttons[4])
  local sent=M.netSent[#M.netSent]
  check(sent and sent.name=="stz.action" and tostring(sent.data[2]):find('"restock"',1,true),"«Пополнить склады» отправляет запрос серверу")
  M.netSent={}
  M.protect("clear click",v.buttons[5].DoClick,v.buttons[5])
  check(#M.netSent==0 and v.buttons[5].ConfirmUntil,"«Убрать мутантов» требует подтверждения")
  M.protect("clear confirm",v.buttons[5].DoClick,v.buttons[5])
  check(#M.netSent==1,"повторное нажатие подтверждает")
 end
 Z.EditorState={fields={},zones={},stats={},ready=true}
 M.protect("admin summary empty",Z.PaintAdminSummary,800,100)

 section("Клиент: аномалии без ошибок и отладка радиусов")
 local warns=#M.warnings
 for _,kind in ipairs(Z.AnomalyOrder) do
  local a=ents.Create("stalker_anomaly");a:SetKind(kind);a:SetPos(Vector(X+200,0,0));a:SetTriggered(CurTime())
  M.protect("fx think "..kind,a.Think,a);M.protect("fx draw "..kind,a.DrawTranslucent,a)
  a:Spawn();M.protect("fx think2 "..kind,a.Think,a);M.protect("fx draw2 "..kind,a.DrawTranslucent,a)
 end
 local odd=ents.Create("stalker_anomaly");odd:SetKind("нет такой");M.protect("fx unknown",odd.Think,odd);M.protect("fx unknown draw",odd.DrawTranslucent,odd)
 check(#M.warnings==warns,"эффекты аномалий не дают ошибок (в т. ч. до Initialize и без типа)")
 local lp=LocalPlayer()
 check(not Z.AnomalyDebugAllowed(),"отладка аномалий выключена по умолчанию")
 GetConVar("stz_anomaly_debug"):SetString("1")
 check(not Z.AnomalyDebugAllowed(),"обычному игроку отладка недоступна")
 lp._admin=true
 check(Z.AnomalyDebugAllowed(),"администратор видит радиусы аномалий")
 M.protect("debug rings",Z.DrawAnomalyDebug);M.protect("debug labels",Z.DrawAnomalyDebugLabels)
 local line=Z.AnomalyDebugText(Z.Anomalies.electro)
 check(line:find("R 110",1,true) and line:find("перезарядка",1,true),"подпись отладки: "..line)
 GetConVar("stz_anomaly_debug"):SetString("0");lp._admin=nil

 section("Клиент: памятка, вкладка КПК, справочник")
 M.command(nil,"stz_help")
 check(Z.HelpFrame,"окно памятки открывается")
 local all={}
 for _,sec in ipairs(Z.Help) do
  all[#all+1]=sec[1]
  for _,l in ipairs(sec[2]) do
   if type(l)=="table" then all[#all+1]=l[1].." "..l[2] elseif type(l)=="function" then all[#all+1]=l() else all[#all+1]=l end
  end
 end
 local memo=table.concat(all,"\n")
 for _,word in ipairs({"F4","!кпк","G","H / !emote","флаг","Казна","Крафт","Готовка","Квестодатели","!quests","Путь новичка","stq_guideline 0",
  "События","Маячок","наводк","Нашивки","радиационных зонах","F6"}) do check(memo:find(word,1,true),"в памятке: "..word) end
 check(not memo:find("F4 — профессии",1,true) and not memo:find("в F4 открывается профессия",1,true),"устаревшие строки про F4 убраны")
 local tab=STALKER_CORE.PDATabs.memo
 check(tab and tab.title=="Памятка","вкладка КПК «Памятка»")
 if tab then M.protect("memo tab",tab.build,M.stub("pda")) end
 local P=STALKER_PDA
 check(P and P.Guide and P.Guide.zone,"раздел «Зона» в справочнике КПК")
 if P and P.Guide and P.Guide.zone then
  local blocks;M.protect("guide blocks",function() blocks=P.Guide.zone.blocks() end)
  check(type(blocks)=="table" and #blocks>5,"справочник «Зона» с числами из настроек")
 end
 M.protect("pda online",hook.Run,"STALKER_INV_DrawPDA",M.stub("pda"),512,388)
 local other=M.addPlayer({nick="Тайный Ник",pos=Vector(X+300,0,0)})
 local label=Z.OnlineLabel(other)
 local SO=STALKER_SOCIAL
 if SO and SO.Config and SO.Config.HideNames~=false then check(not label:find("Тайный Ник",1,true),"в сети КПК незнакомец без настоящего ника: "..label) end

 section("Клиент: сумка погибшего")
 local bag=ents.Create("stalker_deathbag");bag:SetPos(Vector(X+50,0,0));bag:Spawn()
 bag:SetOwnerName("Тайный Ник");bag:SetOwnerSID(other:SteamID64());bag:SetItemCount(2);bag:SetHasIntel(true)
 local owner=bag:OwnerLabel()
 if SO and SO.Config and SO.Config.HideNames~=false then check(not owner:find("Тайный Ник",1,true),"имя владельца сумки — глазами зрителя: "..owner) end
 lp._aimEntity=bag;lp._aim=Vector(X+50,0,0);lp._pos=Vector(X+40,0,0)
 M.protect("bag hint",hook.GetTable().HUDPaint["STALKER_ZONE.BagHint"])
 lp._aimEntity=nil;lp._pos=Vector(0,0,0);lp._aim=Vector(100,0,0)
 M.removePlayer(other)

 section("Клиент: DarkRP HUD на теме")
 local path=os.getenv("GMOD_ROOT").."/darkrpmodification/lua/darkrp_modules/hudreplacement/cl_hudreplacement.lua"
 check(M.loadFile(path,"cl_hudreplacement.lua"),"HUD DarkRP загружается")
 check(hook.Run("HUDShouldDraw","DarkRP_LocalPlayerHUD")==false,"стандартная плашка DarkRP скрыта")
 M.protect("rp hud",hook.GetTable().HUDPaint["STALKER.RPHud"])
 local hud=io.open(path):read("*a")
 check(not hud:find("%f[%w]Color%(") and hud:find("STALKER_THEME",1,true),"HUD DarkRP без жёстких цветов, на STALKER_THEME")
 hook.Remove("HUDPaint","STALKER.RPHud")
end
