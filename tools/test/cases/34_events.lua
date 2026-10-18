-- STALKER Events: каркас и планировщик, пять событий, места событий и точки интереса, маячки, админ-панель,
-- вкладка КПК и интеграция с «Комендантом». Область мира X: 3 000 000…3 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local E,C,MK,S,SI=STALKER_EVENTS,STALKER_CORE,STALKER_MARKERS,STALKER_SETTINGS,STALKER_INV
local X=3000000
section("События: загрузка ("..M.Realm..")")
check(E and E.Config and E.Info and E.Version,"STALKER_EVENTS загружен")
for _,id in ipairs({"events.scheduler","events.interval_min","events.interval_max","events.min_players","events.max_npc","events.cargo_minutes","events.cargo_hold",
 "events.cargo_guards_min","events.cargo_guards_max","events.cargo_artifact","events.hunt_minutes","events.hunt_reward_mult","events.storm_mult","events.raid_squad",
 "events.raid_reward","events.bounty_reward","events.bounty_survive","events.weight_cargo","events.weight_bounty","events.beacon_limit","events.beacon_minutes"}) do
 check(S.Defs[id] and S.Defs[id].category=="События","настройка в категории «События»: "..id)
end
check(S.Defs["events.beacon_limit"].realm=="shared" and S.Defs["events.scheduler"].type=="bool","realm и тип настроек маячков и планировщика")
check(SI.Items.beacon and SI.Items.beacon.name=="Маячок" and SI.Items.beacon.stackable,"предмет «Маячок» в инвентаре")
check(STALKER_ZONE.ItemPrices.beacon and STALKER_ZONE.ItemPrices.beacon.buy>0,"цена маячка у торговцев")
check(scripted_ents.Get("stalker_cargo") and scripted_ents.Get("stalker_beacon"),"сущности груза и маячка зарегистрированы")
check(E.FormatTime(75)=="01:15" and E.FormatTime(3700)=="1 ч 01 мин","формат времени")

local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end
local function newsHas(text) for i=1,math.min(15,#C.NewsFeed) do if C.NewsFeed[i].text:find(text,1,true) then return true end end;return false end

if SERVER then
 local players={}
 local function join(nick,x,y,extra)
  local o=extra or {};o.nick=nick;o.pos=Vector(X+x,y or 0,0);o.aim=o.aim or Vector(X+x+100,y or 0,0)
  local p=TEST.join(o);p.StfwProtected=0;players[#players+1]=p;return p
 end
 -- Прицел на точку земли: игрок подходит на 500 units (трассировка админ-панели — до 4000).
 local function aimAt(p,pos) p._aim=pos end
 local function standAt(p,pos) p:SetPos(pos-Vector(500,0,0));p._aim=pos end
 local admin=join("Админ событий",0,0,{superadmin=true})
 local plain=join("Без прав событий",0,500)

 section("События: каркас")
 local list=E.List()
 check(#list==5 and list[1].id=="cargo" and list[1].name=="Сбитый груз" and list[1].active==false,"STALKER_EVENTS.List(): {id,name,active}")
 local ok,err=E.Start("nope");check(not ok and type(err)=="string","неизвестное событие отклонено")
 ok,err=E.Stop("cargo");check(not ok and err=="Событие не идёт","остановка неидущего события — причина")
 check(not E.Register or pcall(E.Register,{id="bad id",start=function() end})==false,"некорректный id события отклонён")

 section("События: места событий (админ)")
 M.netSent={}
 standAt(admin,Vector(X+40000,0,0))
 local len,vals=packet({op="spot_add",name="Вертолётная площадка"})
 M.netReceive("stalker_events.admin",len,admin,vals)
 local reply=decode(lastSent("stalker_events.admin",admin))
 check(reply and reply.result and reply.result.ok and #reply.spots==1 and reply.spots[1].name=="Вертолётная площадка","место события добавлено под прицелом")
 local spotID=reply and reply.spots[1] and reply.spots[1].id
 check(file.Exists("stalker_events/gm_test.json","DATA") and file.Read("stalker_events/gm_test.json","DATA"):find("Вертолётная площадка",1,true),"места сохраняются в data/stalker_events/<карта>.json")
 local pos=E.PickPoint()
 check(pos and math.abs(pos.x-(X+40000))<1 and pos.z==0,"событие выбирает размеченное место")
 len,vals=packet({op="spot_add",name=""});M.netReceive("stalker_events.admin",len,admin,vals)
 reply=decode(lastSent("stalker_events.admin",admin))
 check(reply.result and not reply.result.ok and #reply.spots==1,"пустое название места отклонено")
 len,vals=packet({op="spot_show"});M.netReceive("stalker_events.admin",len,admin,vals)
 local shown=MK.Get("stev.spot."..admin:SteamID64().."."..tostring(spotID))
 check(shown and MK.VisibleTo(shown,admin) and not MK.VisibleTo(shown,plain),"места показаны только этому администратору")
 M.netSent={}
 len,vals=packet({op="spot_add",name="Чужое место"});M.netReceive("stalker_events.admin",len,plain,vals)
 reply=decode(lastSent("stalker_events.admin",plain))
 check(reply and reply.denied and table.Count(E.World.spots)==1,"игрок без права events не меняет места")
 len,vals=packet({op="start",id="cargo"});M.netReceive("stalker_events.admin",len,plain,vals)
 check(not E.Active.cargo,"игрок без права events не запускает события")

 section("События: сбитый груз")
 M.advance(3)
 standAt(admin,Vector(X+60000,0,0))
 M.netSent={}
 len,vals=packet({op="start",id="cargo",here=true});M.netReceive("stalker_events.admin",len,admin,vals)
 reply=decode(lastSent("stalker_events.admin",admin))
 local ev=E.Active.cargo
 check(ev and reply.result and reply.result.ok,"«Сбитый груз» запущен из админ-панели под прицелом")
 local crate=ev and ev.data.crate
 check(IsValid(crate) and crate:GetClass()=="stalker_cargo" and math.abs(crate:GetPos().x-(X+60000))<5,"ящик упал в точке")
 check(crate and #crate.Items>0 and crate:GetItemCount()>0,"лут ящика: "..tostring(crate and crate:GetItemCount()))
 local guards=0;for _,npc in ipairs(ev.npcs) do if IsValid(npc) and npc.StalkerEvent=="cargo" and npc.StalkerMutant then guards=guards+1 end end
 check(guards>=E.Config.CargoGuardsMin and guards<=E.Config.CargoGuardsMax,"охрана из мутантов Зоны: "..guards)
 local mk=MK.Get("stev.ev.cargo.crate")
 check(mk and mk.kind=="cargo" and MK.VisibleTo(mk,plain),"метка груза kind=cargo видна всем")
 check(newsHas("Сбитый груз"),"новость о грузе в ленте КПК")
 check(E.List()[1].active==true,"List() отмечает идущее событие")
 ok,err=E.Start("hunt");check(not ok and tostring(err):find("Уже идёт",1,true),"одновременно одно крупное событие")
 if STALKER_ADMIN and STALKER_ADMIN.EventList then
  local found=false;for _,row in ipairs(STALKER_ADMIN.EventList()) do if row.id=="cargo" and row.active then found=true end end
  check(found,"«Комендант» видит события и их состояние")
 end
 -- Детерминированное содержимое: первому сталкеру влезет только аптечка.
 crate.Items={{"medkit",3},{"ammo_smg",4},{"jacket",1}};crate:SetItemCount(E.CargoCount(crate))
 local opener=join("Вскрыватель",60060,0)
 for i=1,39 do opener.StalkerInventory.grid[i]=SI.NewItem("scrap",1) end;opener.StalkerInventory.grid[40]=nil
 aimAt(opener,crate:WorldSpaceCenter())
 opener:SetKey(IN_USE,true)
 crate:Use(opener)
 check(C.Hold.IsHolding(opener) and not crate:GetOpened(),"вскрытие — удержание E")
 M.advance(E.Config.CargoHold+.5,.1)
 opener:SetKey(IN_USE,false)
 check(crate:GetOpened(),"ящик вскрыт после удержания")
 check(TEST.gridCount(opener,"medkit")==3,"в рюкзак ушло то, что влезло")
 check(IsValid(crate) and crate:GetItemCount()==5 and E.Active.cargo,"остальное осталось в ящике: "..tostring(IsValid(crate) and crate:GetItemCount()))
 check((C.GetStats(opener).events or 0)==1,"участие в событии в статистике")
 local second=join("Подбирающий",60080,0);aimAt(second,crate:WorldSpaceCenter())
 local smgBefore=TEST.gridCount(second,"ammo_smg")
 crate:Use(second)
 check(TEST.gridCount(second,"ammo_smg")==smgBefore+4 and TEST.gridCount(second,"jacket")>=1,"вскрытый ящик отдаёт остаток без удержания")
 check(not IsValid(crate) and not E.Active.cargo,"пустой ящик убран, событие завершено")
 local alive=0;for _,npc in ipairs(ev.npcs) do if IsValid(npc) then alive=alive+1 end end
 check(alive==0 and not MK.Get("stev.ev.cargo.crate"),"охрана и метка убраны")
 -- Время вышло: ящик исчезает с новостью.
 check(E.Start("cargo",{pos=Vector(X+61000,0,0)}),"второй груз")
 local crate2=E.Active.cargo.data.crate
 E.Active.cargo.ends=CurTime()+.5;M.advance(1.5)
 check(not E.Active.cargo and not IsValid(crate2) and newsHas("никто и не вскрыл"),"невскрытый груз исчезает по времени")
 local loot=E.RollCargo();local okLoot=#loot>0
 for _,row in ipairs(loot) do if not SI.Items[row[1]] or row[2]<1 then okLoot=false end end
 check(okLoot,"таблица лута даёт только существующие предметы")

 section("События: гон мутантов")
 local hunter=join("Охотник",80000,0)
 check(E.Start("hunt",{pos=Vector(X+80500,0,0)}),"«Гон мутантов» запущен")
 ev=E.Active.hunt
 local wave1=#E.AliveNPC(ev)
 check(wave1>0 and E.RewardMult==E.Config.HuntRewardMult,"первая волна ("..wave1..") и множитель награды")
 local npc=E.AliveNPC(ev)[1]
 check(hook.Run("calculateNPCKillPay",hunter,npc)==math.floor(npc.KillValue*E.Config.HuntRewardMult),"награда DarkRP за мутанта гона умножена")
 local zoneNPC=ents.Create("npc_zombie");zoneNPC:SetPos(Vector(X+90000,0,0));zoneNPC:Spawn();zoneNPC.StalkerMutant="zombie";zoneNPC.KillValue=40
 check(hook.Run("calculateNPCKillPay",hunter,zoneNPC)==80,"во время гона дороже и мутанты логов")
 local combine=ents.Create("npc_combine_s");combine:SetPos(Vector(X+90100,0,0));combine:Spawn();combine.KillValue=100
 check(hook.Run("calculateNPCKillPay",hunter,combine)==nil,"на людей множитель не действует")
 local dmg=DamageInfo();dmg:SetDamage(500);dmg:SetAttacker(hunter);dmg:SetDamageType(DMG_BULLET)
 npc:TakeDamageInfo(dmg)
 check(ev.kills==1 and (C.GetStats(hunter).events or 0)==1,"убийство мутанта гона засчитано")
 M.advance(E.Config.HuntWaveInterval+1,1)
 check((ev.data.wave or 0)>=2,"следующая волна по таймеру")
 check(E.CountNPC()<=E.Config.MaxNPC,"лимит NPC событий соблюдается")
 check(E.Stop("hunt"),"администратор останавливает гон")
 check(E.RewardMult==1 and hook.Run("calculateNPCKillPay",hunter,zoneNPC)==nil,"после гона награда обычная")
 alive=0;for _,n in ipairs(ev.npcs) do if IsValid(n) then alive=alive+1 end end
 check(alive==0,"мутанты гона убраны")
 zoneNPC:Remove();combine:Remove()

 section("События: артефактный шторм")
 local Z=STALKER_ZONE
 Z.World.fields.evtest={id="evtest",name="Штормовое поле",pos={x=X+120000,y=0,z=0},radius=600,count=4,artifacts=2,types={electro=true}}
 Z.BuildField("evtest")
 local rt=Z.Runtime.fields.evtest
 local function fieldArtifacts() local n=0;for _,e in ipairs(rt.artifacts) do if IsValid(e) then n=n+1 end end;return n end
 local normal=fieldArtifacts();local maxBefore=Z.Config.MaxArtifacts
 check(normal==2,"тестовое поле: обычный лимит "..normal)
 check(E.Start("storm"),"«Артефактный шторм» запущен")
 check(fieldArtifacts()==4,"шторм удваивает артефакты поля: "..fieldArtifacts())
 check(Z.Config.MaxArtifacts==maxBefore and Z.World.fields.evtest.artifacts==2,"лимиты Зоны вернулись сразу после досыпки")
 check(MK.Get("stev.ev.storm.f1"),"метки шторма на полях")
 local stormer=join("Искатель",120100,0)
 hook.Run("STALKER_ZONE_ArtifactPicked",stormer,"flash")
 check((C.GetStats(stormer).events or 0)==1,"подбор артефакта в шторм — участие")
 check(E.Stop("storm"),"шторм остановлен")
 check(fieldArtifacts()==2,"после шторма поле вернулось к обычному лимиту: "..fieldArtifacts())
 Z.World.fields.evtest=nil
 for _,e in ipairs(rt.anomalies) do if IsValid(e) then e:Remove() end end
 for _,e in ipairs(rt.artifacts) do if IsValid(e) then e:Remove() end end
 Z.Runtime.fields.evtest=nil
 local savedFields=Z.World.fields;Z.World.fields={}
 ok,err=E.Start("storm");check(not ok and tostring(err):find("Нет полей",1,true),"без полей с артефактами шторм не начинается")
 Z.World.fields=savedFields

 section("События: военный рейд")
 local soldierKiller=join("Стрелок",140000,0)
 local soldierFriend=join("Военный сталкер",140200,0)
 soldierFriend:SetNW2Bool("stfw_joined",true);soldierFriend:SetNW2String("stfw_faction","military")
 -- Отношения NPC — движковая функция: на время проверки записываем их в сущность.
 local EM=FindMetaTable("Entity");D_LI,D_HT=3,1
 EM.AddEntityRelationship=function(self,p,d) self._rel=self._rel or {};self._rel[p]=d end
 check(E.Start("raid",{pos=Vector(X+140500,0,0)}),"«Военный рейд» запущен")
 ev=E.Active.raid
 local squad=E.AliveNPC(ev)
 check(squad[1] and squad[1]._rel and squad[1]._rel[soldierFriend]==D_LI and squad[1]._rel[soldierKiller]==nil,"бойцы «Военных» — союзники отряда")
 soldierFriend:SetNW2Bool("stfw_joined",false);M.advance(5.5)
 check(squad[1]._rel[soldierFriend]==D_HT,"покинувший «Военных» снова враг отряду")
 EM.AddEntityRelationship=nil;D_LI,D_HT=nil,nil
 local okSquad=#squad==E.Config.RaidSquad
 for _,s in ipairs(squad) do if s:GetClass()~="npc_combine_s" or s.KillValue~=E.Config.RaidReward or s:GetModel()~=E.RaidModel then okSquad=false end end
 check(okSquad,"отряд npc_combine_s с наградой за бойца: "..#squad)
 check(MK.Get("stev.ev.raid.squad") and newsHas("Военный рейд"),"метка и новость рейда")
 for _,s in ipairs(squad) do local d=DamageInfo();d:SetDamage(500);d:SetAttacker(soldierKiller);s:TakeDamageInfo(d) end
 M.advance(1.5)
 check(not E.Active.raid and newsHas("отбит"),"уничтоженный отряд завершает рейд")
 check((C.GetStats(soldierKiller).events or 0)==1,"участник рейда в статистике")

 section("События: охота за головой")
 local target=join("Цель",160000,0);local hunterB=join("Охотник Б",160300,0);local hunterC=join("Охотник В",160600,0)
 for _,p in ipairs({target,hunterB,hunterC}) do p:SetNW2Bool("stfw_joined",false) end
 local realHumans=player.GetHumans
 player.GetHumans=function() return {target} end
 ok,err=E.Start("bounty");check(not ok and tostring(err):find("два",1,true),"охоте нужен хотя бы один охотник")
 player.GetHumans=realHumans
 check(IsValid(E.PickBountyTarget()),"выбор цели среди сильных игроков")
 check(E.Start("bounty",{target=target}),"«Охота за головой» запущена")
 ev=E.Active.bounty
 mk=MK.Get("stev.ev.bounty.target")
 check(mk and MK.VisibleTo(mk,hunterB) and not MK.VisibleTo(mk,target),"метка цели видна всем, кроме самой цели")
 M.netSent={};E.SendState(target)
 local st=decode(lastSent("stalker_events.state",target))
 check(st and st.target and st.target.left>0,"цель знает, сколько продержаться")
 target:SetPos(Vector(X+161000,0,0));M.advance(E.Config.BountyUpdate+1)
 check(math.abs(MK.Get("stev.ev.bounty.target").pos.x-(X+161000))<1,"метка следует за целью")
 local money=hunterB._money
 M.kill(target,hunterB)
 check(hunterB._money==money+E.Config.BountyReward and not E.Active.bounty,"убийца цели получил награду")
 M.spawn(target)
 check(E.Start("bounty",{target=target}),"новая охота")
 money=target._money
 E.Active.bounty.ends=CurTime()+.5;M.advance(1.5)
 check(target._money==money+E.Config.BountySurvive and newsHas("пережил охоту"),"выжившая цель получила награду")
 -- Свои не в счёт: убийство цели соклановцем не оплачивается.
 for _,p in ipairs({target,hunterC}) do p:SetNW2Bool("stfw_joined",true);p:SetNW2String("stfw_faction","duty") end
 check(E.Start("bounty",{target=target}),"охота на члена группировки")
 money=hunterC._money
 M.kill(target,hunterC)
 check(hunterC._money==money and not E.Active.bounty and newsHas("своего"),"соклановец награду не получает")
 for _,p in ipairs({target,hunterC}) do p:SetNW2Bool("stfw_joined",false);p:SetNW2String("stfw_faction","loner") end
 M.spawn(target)
 check(E.Start("bounty",{target=target}),"охота перед выходом цели")
 hook.Run("PlayerDisconnected",target)
 check(not E.Active.bounty and newsHas("покинула Зону"),"выход цели отменяет охоту")

 section("События: планировщик")
 local savedWeights=table.Copy(E.Config.Weights)
 for id in pairs(E.Config.Weights) do E.Config.Weights[id]=0 end
 E.Config.Weights.cargo=1
 check(S.Set("events.scheduler",true),"планировщик включён настройкой")
 E.NextAt=CurTime()+.5;M.advance(1.5)
 check(E.Active.cargo,"планировщик запустил событие по весам")
 E.Stop("cargo","admin")
 local wait=E.NextAt-CurTime()
 check(wait>=E.Config.IntervalMin*60-1 and wait<=E.Config.IntervalMax*60+1,"следующее событие — через случайный интервал: "..math.floor(wait/60).." мин")
 check(S.Set("events.interval_max",10) and E.NextAt-CurTime()<=E.Config.IntervalMin*60+1,"смена интервала пересчитывает расписание")
 S.Set("events.interval_max",nil)
 for id in pairs(E.Config.Weights) do E.Config.Weights[id]=0 end
 E.NextAt=CurTime()+.5;M.advance(1.5)
 check(not E.MajorActive() and E.NextAt-CurTime()>200,"без доступных событий — повторная попытка позже")
 len,vals=packet({op="schedule",minutes=1});M.netReceive("stalker_events.admin",len,admin,vals)
 check(math.abs(E.NextAt-CurTime()-60)<1,"админ переносит следующее событие")
 for id,w in pairs(savedWeights) do E.Config.Weights[id]=w end
 M.advance(1)
 len,vals=packet({op="scheduler",on=false});M.netReceive("stalker_events.admin",len,admin,vals)
 check(E.Config.Scheduler==false,"админ выключает планировщик (тестовый мир возвращён в исходное состояние)")
 -- Включение после долгого перерыва не запускает событие в ту же секунду.
 E.NextAt=CurTime()-100;S.Set("events.scheduler",true);M.advance(1.5)
 check(not E.MajorActive() and E.NextAt-CurTime()>=E.Config.IntervalMin*60-2,"включённый планировщик отсчитывает новый интервал")
 S.Set("events.scheduler",false)

 section("События: маячки")
 local owner=join("Владелец маячков",200000,0,{aim=Vector(X+200100,0,0)})
 local friend=join("Соратник",200000,800);local stranger=join("Чужак",200040,0)
 check(SI.GiveItem(owner,"beacon",4),"маячки выданы")
 M.netSent={}
 SI.HandleAction(owner,"use","grid",TEST.gridIndex(owner,"beacon"))
 local prompt=decode(lastSent("stalker_events.beacon",owner))
 check(prompt and prompt.limit==E.Config.BeaconLimit and TEST.gridCount(owner,"beacon")==4,"«Использовать» спрашивает видимость, предмет не расходуется")
 len,vals=packet({mode="self",label="Схрон"})
 M.netReceive("stalker_events.beacon",len,owner,vals)
 local beacons=E.AllBeacons()
 local b1=beacons[#beacons]
 check(IsValid(b1) and b1.OwnerSID==owner:SteamID64() and b1:GetLabel()=="Схрон" and TEST.gridCount(owner,"beacon")==3,"маячок поставлен под прицелом, предмет израсходован")
 mk=MK.Get("stev.beacon."..b1:EntIndex())
 check(mk and mk.kind=="beacon" and mk.label=="Схрон" and MK.VisibleTo(mk,owner) and not MK.VisibleTo(mk,stranger),"личная метка маячка видна только владельцу")
 owner:SetNW2Bool("stfw_joined",false)
 ok,err=E.PlaceBeacon(owner,"faction","Сбор");check(not ok and tostring(err):find("группировке",1,true),"без группировки — только личный маячок")
 owner:SetNW2Bool("stfw_joined",true);owner:SetNW2String("stfw_faction","duty")
 friend:SetNW2Bool("stfw_joined",true);friend:SetNW2String("stfw_faction","duty")
 local okF,b2=E.PlaceBeacon(owner,"faction","Сбор")
 mk=okF and MK.Get("stev.beacon."..b2:EntIndex())
 check(mk and MK.VisibleTo(mk,friend) and MK.VisibleTo(mk,owner) and not MK.VisibleTo(mk,stranger),"маячок группировки виден своим")
 local ok3,b3=E.PlaceBeacon(owner,"self",string.rep("Я",40))
 check(ok3 and b3:GetLabel()=="Маячок","третий маячок: слишком длинная подпись заменена на «Маячок»")
 ok,err=E.PlaceBeacon(owner,"self","Лишний");check(not ok and tostring(err):find("максимум",1,true),"не больше "..E.Config.BeaconLimit.." маячков")
 local ok2,why=SI.Items.beacon.OnUse(owner);check(ok2==false and tostring(why):find("максимум",1,true),"лимит видно и при использовании предмета")
 b3:Remove()
 check(#E.AllBeacons()==2 and not MK.Get("stev.beacon."..b3:EntIndex()),"удалённый маячок освобождает место и метку")
 aimAt(owner,Vector(X+205000,0,0))
 ok,err=E.PlaceBeacon(owner,"self","Далеко");check(not ok and tostring(err):find("землю",1,true),"маячок ставится только на землю рядом")
 aimAt(owner,Vector(X+200100,0,0))
 M.netSent={};E.SendState(owner)
 st=decode(lastSent("stalker_events.state",owner))
 check(st and #st.beacons==2 and st.beacons[1].left>0,"КПК владельца видит свои маячки")
 b1:Use(stranger)
 check(IsValid(b1),"чужой маячок не забрать")
 local had=TEST.gridCount(owner,"beacon")
 b1:Use(owner)
 check(not IsValid(b1) and TEST.gridCount(owner,"beacon")==had+1 and not MK.Get("stev.beacon."..b1:EntIndex()),"владелец забрал маячок клавишей E")
 b2:SetExpires(CurTime()+.5);M.advance(1.5)
 check(not IsValid(b2),"разряженный маячок исчезает")
 for _,b in ipairs(ents.FindByClass("stalker_beacon")) do b:Remove() end
 owner:SetNW2Bool("stfw_joined",false);friend:SetNW2Bool("stfw_joined",false)

 section("События: точки интереса")
 M.advance(3)
 standAt(admin,Vector(X+300000,0,0))
 len,vals=packet({op="poi_add",name="Лагерь у моста",kind="camp",flag=true});M.netReceive("stalker_events.admin",len,admin,vals)
 reply=decode(lastSent("stalker_events.admin",admin))
 local poi=reply and reply.pois and reply.pois[1]
 check(poi and poi.kind=="camp" and poi.flag==true,"точка интереса поставлена")
 local pm=poi and MK.Get("stev.poi."..poi.id)
 check(pm and pm.kind=="poi" and pm.world==true and pm.label=="Лагерь · Лагерь у моста" and MK.VisibleTo(pm,plain),"метка kind=poi с флажком видна всем")
 len,vals=packet({op="poi_add",name="Ошибка",kind="spaceship"});M.netReceive("stalker_events.admin",len,admin,vals)
 reply=decode(lastSent("stalker_events.admin",admin))
 check(reply.result and not reply.result.ok and #reply.pois==1,"неизвестный тип точки отклонён")
 len,vals=packet({op="poi_edit",id=poi.id,flag=false});M.netReceive("stalker_events.admin",len,admin,vals)
 check(MK.Get("stev.poi."..poi.id).world==false,"флажок в мире выключается")
 E.World={version=1,seq=0,spots={},pois={}};MK.Clear("stev.poi.")
 E.LoadWorld()
 check(E.World.pois[poi.id] and E.World.pois[poi.id].name=="Лагерь у моста" and MK.Get("stev.poi."..poi.id),"точки интереса загружаются из файла карты")
 len,vals=packet({op="poi_remove",id=poi.id});M.netReceive("stalker_events.admin",len,admin,vals)
 check(not MK.Get("stev.poi."..poi.id) and not E.World.pois[poi.id],"точка удалена вместе с меткой")
 len,vals=packet({op="spot_remove",id=spotID});M.netReceive("stalker_events.admin",len,admin,vals)
 check(next(E.World.spots)==nil,"место события удалено")
 M.netSent={}
 len,vals=packet({op="state"});M.netReceive("stalker_events.admin",len,admin,vals)
 reply=decode(lastSent("stalker_events.admin",admin))
 check(reply and #reply.events==5 and reply.scheduler==false and reply.result==nil,"снимок админ-панели")
 -- Повреждённый файл не затирается.
 file.Write(E.WorldPath,"{broken");E.LoadWorld()
 check(E.WorldBroken and not E.EditWorld(function() return true end),"повреждённый файл мест блокирует правку")
 -- Ожидаемое предупреждение о повреждённом файле не засоряет итоги прогона.
 if tostring(M.warnings[#M.warnings]):find("Повреждён stalker_events",1,true) then table.remove(M.warnings) end
 file.Write(E.WorldPath,util.TableToJSON({version=1,seq=0,spots={},pois={}}));E.LoadWorld()
 check(not E.WorldBroken,"восстановленный файл снимает блокировку")

 section("События: очистка")
 E.StopAll("cleanup")
 check(next(E.Active)==nil and E.CountNPC()==0,"событий и NPC не осталось")
 check(E.Config.Scheduler==false,"планировщик выключен для следующих сценариев")
 for _,p in ipairs(players) do M.removePlayer(p) end
else
 section("События: клиент")
 local created={};local orig=vgui.Create
 vgui.Create=function(name,parent) local p=orig(name,parent);created[#created+1]=p;return p end
 -- Снимок админ-панели и ответ сервера.
 local snap={events={{id="cargo",name="Сбитый груз",desc="Ящик",active=true,left=300,where="Площадка",info="Охрана: 3",weight=30,minPlayers=2},
  {id="hunt",name="Гон мутантов",desc="Волны",active=false,weight=25,minPlayers=2}},scheduler=true,next=600,interval={25,50},players=4,npc=3,beacons=1,
  spots={{id="s1",name="Площадка",pos={x=10,y=20,z=0}}},pois={{id="p1",name="Мост",kind="camp",flag=true,pos={x=0,y=0,z=0}}},maxSpots=64,maxPOI=128,lastError="Нужно игроков в сети: 2",
  result={op="start",ok=true,message="Событие запущено"}}
 local l,v=packet(snap)
 M.protect("ответ админ-панели",M.netReceive,"stalker_events.admin",l,nil,v)
 check(E.Admin and E.Admin.events and #E.Admin.events==2,"снимок админ-панели принят")
 M.protect("админ-панель событий",E.BuildAdminPanel,M.stub("admin"))
 check(type(E.BuildAdminPanel)=="function","STALKER_EVENTS.BuildAdminPanel")
 local startBtn
 for _,p in ipairs(created) do if rawget(p,"Label")=="Остановить" then startBtn=p end end
 M.netSent={}
 if startBtn then M.protect("кнопка «Остановить»",startBtn.DoClick,startBtn) end
 local req=lastSent("stalker_events.admin")
 check(startBtn and req and tostring(req.data[2]):find('"stop"',1,true),"кнопка «Остановить» отправляет запрос серверу")
 E.Admin={denied=true};M.protect("панель без права",E.FillAdmin,M.stub("root"))
 E.Admin=nil;M.protect("панель до ответа",E.FillAdmin,M.stub("root"))
 E.Admin=snap
 M.protect("окно stev_menu",M.command,nil,"stev_menu")
 -- Состояние: вкладка КПК и значок.
 l,v=packet({active={{id="storm",name="Артефактный шторм",desc="Больше артефактов",left=120,info="Лимит ×2"}},beacons={{label="Схрон",faction="",left=900},{label="Сбор",faction="duty",left=60}},limit=3,target={left=300,reward=3000}})
 M.protect("состояние событий",M.netReceive,"stalker_events.state",l,nil,v)
 check(#E.State.active==1 and E.State.target,"состояние событий принято")
 check(C.PDATabs.events and C.PDATabs.events.title=="События" and C.PDATabs.events.badge()==1,"вкладка КПК «События» и значок")
 M.protect("вкладка КПК",C.PDATabs.events.build,M.stub("pda"))
 -- Выбор видимости маячка.
 l,v=packet({faction="duty",factionName="Долг",limit=3,have=1,minutes=30})
 M.protect("окно маячка",M.netReceive,"stalker_events.beacon",l,nil,v)
 check(E.BeaconFrame~=nil and type(E.BeaconSend)=="function","окно выбора видимости маячка")
 M.netSent={}
 M.protect("маячок: только мне",E.BeaconSend,"self")
 req=lastSent("stalker_events.beacon")
 check(req and tostring(req.data[2]):find('"self"',1,true),"выбор видимости отправлен серверу")
 l,v=packet({limit=3,have=0,minutes=30})
 M.protect("окно маячка без группировки",M.netReceive,"stalker_events.beacon",l,nil,v)
 vgui.Create=orig
 local painted=0
 for _,p in ipairs(created) do
  local paint=rawget(p,"Paint");if type(paint)=="function" then painted=painted+1;M.protect("отрисовка панели событий",paint,p,700,64) end
 end
 check(painted>15,"панели событий отрисованы: "..painted)
 -- Сущности и подсказки.
 local crate=ents.Create("stalker_cargo");crate:SetPos(Vector(X,0,0));crate:Spawn();crate:SetItemCount(4)
 M.protect("груз: эффекты",crate.Think,crate);M.protect("груз: модель",crate.Draw,crate)
 check(E.HintFor(crate,LocalPlayer()):find("Удерживайте E",1,true),"подсказка у невскрытого груза")
 crate:SetOpened(true);check(E.HintFor(crate,LocalPlayer()):find("4 шт",1,true),"подсказка у вскрытого груза")
 M.protect("груз: удаление",crate.OnRemove,crate)
 local beacon=ents.Create("stalker_beacon");beacon:SetPos(Vector(X,50,0));beacon:Spawn()
 beacon:SetLabel("Схрон");beacon:SetOwnerName("Клиент");beacon:SetOwnerSID(LocalPlayer():SteamID64())
 M.protect("маячок: огонь",beacon.DrawTranslucent,beacon);M.protect("маячок: свет",beacon.Think,beacon)
 beacon:SetFactionID("duty");M.protect("маячок группировки",beacon.DrawTranslucent,beacon)
 check(E.HintFor(beacon,LocalPlayer()):find("забрать",1,true),"владелец видит подсказку «E — забрать»")
 for _,ev in ipairs({{"HUDPaint"}}) do M.protect("HUD событий",hook.Run,unpack(ev)) end
 crate:Remove();beacon:Remove()
 E.State={active={},beacons={},limit=3};E.Admin=nil
end
