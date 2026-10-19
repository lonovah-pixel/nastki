-- STALKER Crafting: рецепты, крафт в поле и у верстака, ремонт, походные и постоянные костры, готовка и блюда,
-- админ-панель мастерских, вкладка КПК и настройки. Область мира X: 5 000 000…5 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local CR,C,MK,S,SI=STALKER_CRAFT,STALKER_CORE,STALKER_MARKERS,STALKER_SETTINGS,STALKER_INV
local X=5000000
local NEW={"toolkit","armor_kit","weapon_kit","campfire_kit","meat_fried","meat_dubious","shashlik","stew","tea"}

local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end

section("Крафт: загрузка ("..M.Realm..")")
check(CR and CR.Config and CR.Version and CR.Recipes and CR.ByID,"STALKER_CRAFT загружен")
for _,id in ipairs({"time_mult","cook_mult","repair_armor","repair_weapon","need_toolkit","station_range","move_tolerance","max_repeat","fire_minutes",
 "fire_limit","fire_heal","fire_heal_interval","fire_heal_radius","food_mult","toxic_dose","markers","max_benches","max_fires"}) do
 local def=S.Defs["craft."..id]
 check(def and def.category=="Крафт и готовка","настройка в категории «Крафт и готовка»: craft."..id)
end
check(S.Defs["craft.time_mult"].realm=="shared" and S.Defs["craft.need_toolkit"].type=="bool" and S.Defs["craft.fire_limit"].realm=="server","realm и тип настроек")
for _,id in ipairs(NEW) do
 local d=SI.Items[id]
 check(d and d.icon=="stalker_craft/items/"..id..".png" and file.Exists("materials/"..d.icon,"GAME"),"предмет и иконка 192×128: "..id)
 local price=STALKER_ZONE.ItemPrices[id]
 check(price and price.buy>price.sell and price.sell>0,"цена у торговцев Зоны: "..id)
end
check(SI.Items.armor_kit.stats.repair==40 and SI.Items.weapon_kit.stats.repair==40,"карточка ремкомплекта: +40% состояния")
check(SI.Items.meat_fried.stats.hunger==45 and SI.Items.meat_fried.stats.health==5 and SI.Items.tea.stats.thirst==45 and SI.Items.tea.stats.health==3,"карточки блюд: сытость, жажда, здоровье")
check(SI.Items.meat_dubious.stats.doseGain==CR.Config.ToxicDose and SI.StatFormat.doseGain and SI.StatFormat.doseGain.bad,"сомнительное мясо: доза радиации в карточке")
check(SI.Items.stew.stats.hunger>0 and SI.Items.stew.stats.thirst>0,"похлёбка утоляет голод и жажду")
check(scripted_ents.Get("stalker_workbench") and scripted_ents.Get("stalker_campfire"),"сущности верстака и костра зарегистрированы")
check(#CR.Recipes>=15 and #CR.List()==#CR.Recipes,"все рецепты доступны при установленных Зоне, разделке и событиях: "..#CR.List())
check(#CR.List("cook")==5 and CR.ByID.meat_fried.station=="fire" and CR.ByID.weapon_kit.station=="bench" and CR.ByID.ammo_pistol.station=="tool","виды и станции рецептов")
for _,r in ipairs(CR.Recipes) do
 local d=CR.Duration(r)
 if r.kind=="craft" then check(d>=2 and d<=6,"время крафта 2–6 с: "..r.id) end
end
local ids=CR.GroupIDs("meat_clean")
check(#ids==3 and ids[1]=="stb_meat_partial_clean" and ids[3]=="stb_meat_perfect_clean","группа «мясо чистое»: худшие образцы первыми")
check(#CR.GroupIDs("hide_clean")==3 and not table.HasValue(CR.GroupIDs("hide_clean"),"stb_hide_success_toxic") and #CR.GroupIDs("hide")==6,"группы шкур: чистые и любые")
local take,rows=CR.Resolve(CR.ByID.armor_kit,{scrap=3,stb_hide_success_toxic=1})
check(take==nil and rows[1].have==3 and rows[1].need==4 and not rows[1].ok and rows[2].ok,"нехватка: строки «есть / нужно»")
take=CR.Resolve(CR.ByID.armor_kit,{scrap=4,stb_hide_success_toxic=1})
check(take and take.scrap==4 and take.stb_hide_success_toxic==1,"список списания по рецепту")
check(CR.Resolve(CR.ByID.bandage,{stb_hide_perfect_toxic=2})==nil,"бинты только из чистой шкуры")
check(CR.Possible(CR.ByID.armor_kit,{scrap=9,stb_hide_partial_clean=5})==2,"на сколько изделий хватает")
check(CR.NeedText(CR.ByID.stew):find("Вода",1,true) and CR.FormatTime(75)=="01:15" and CR.Seconds(2.5)=="2.5 с","подписи рецептов и времени")
local beacon=SI.Items.beacon
SI.Items.beacon=nil
check(CR.ByID.beacon and not CR.Available(CR.ByID.beacon),"без аддона событий рецепт маячка скрыт")
SI.Items.beacon=beacon
check(CR.Available(CR.ByID.beacon),"с маячком событий рецепт доступен")
check(not pcall(CR.RegisterRecipe,{id="bad id",need={},give={{"scrap",1}}}),"некорректный id рецепта отклонён")

if SERVER then
 local players={}
 local function join(nick,x,y,extra)
  local o=extra or {};o.nick=nick;o.pos=Vector(X+x,y or 0,0);o.aim=o.aim or Vector(X+x+100,y or 0,0)
  local p=TEST.join(o);p.StfwProtected=0;players[#players+1]=p
  -- Стартовый набор не нужен: проверки считают предметы точно.
  p.StalkerInventory.grid={};p.StalkerInventory.quickbar={}
  return p
 end
 local function give(p,id,n) return SI.GiveItem(p,id,n or 1) end
 local count=TEST.gridCount
 local function wait(id,times) M.advance(CR.Duration(CR.ByID[id])*(times or 1)+.3*(times or 1),.1) end
 local function admin(ply,op,data)
  data=data or {};data.op=op;M.netSent={}
  local len,vals=packet(data);M.netReceive("stalker_craft.admin",len,ply,vals)
  return decode(lastSent("stalker_craft.admin",ply))
 end

 local N=STALKER_NPC
 if N and N.Config and N.Config.Traders and N.Config.Traders.sidor then
  local sidor=N.Config.Traders.sidor;local inStock=false
  for _,row in ipairs(sidor.stock or {}) do if row[1]=="toolkit" then inStock=true end end
  check(sidor.prices.toolkit and sidor.prices.toolkit.buy==STALKER_ZONE.ItemPrices.toolkit.buy and inStock,"торговцы подхватили цены и ассортимент крафта")
 end

 section("Крафт: в поле с набором инструментов")
 local smith=join("Мастер",0,0)
 -- Без инвентаря рецепты недоступны, но ничего не падает.
 local savedSI=STALKER_INV;STALKER_INV=nil
 local ok,err=CR.Start(smith,"ammo_pistol")
 check(not ok and #CR.List()==0 and CR.RegisterItems()==false,"без STALKER Inventory крафт недоступен, ошибок нет")
 STALKER_INV=savedSI
 ok,err=CR.Start(smith,"ammo_pistol")
 check(not ok and tostring(err):find("набор инструментов",1,true),"без набора и верстака простой рецепт недоступен")
 give(smith,"scrap",9);give(smith,"toolkit")
 ok,err=CR.Start(smith,"weapon_kit")
 check(not ok and err=="Нужен верстак","сложный рецепт в поле недоступен")
 ok,err=CR.Start(smith,"ammo_pistol",2)
 check(ok and CR.Jobs[smith] and CR.Jobs[smith].total==2,"работа поставлена: 2 изделия ("..tostring(err)..")")
 check(smith:GetNW2String("stcraft_recipe","")=="ammo_pistol" and smith:GetNW2Float("stcraft_end",0)>CurTime() and smith:GetNW2Int("stcraft_left",0)==1,"прогресс в сетевых переменных")
 local ok2,err2=CR.Start(smith,"campfire_kit")
 check(not ok2 and tostring(err2):find("заняты",1,true),"вторая работа одновременно не начинается")
 check(count(smith,"scrap")==9,"ингредиенты не списаны до окончания работы")
 wait("ammo_pistol")
 check(count(smith,"ammo_pistol")==1 and count(smith,"scrap")==7,"первое изделие: патроны выданы, детали списаны")
 check(CR.Jobs[smith] and CR.Jobs[smith].done==1,"очередь продолжается")
 wait("ammo_pistol")
 check(count(smith,"ammo_pistol")==2 and count(smith,"scrap")==5 and not CR.Jobs[smith],"очередь выполнена")
 check(smith:GetNW2Float("stcraft_end",1)==0,"полоса работы снята")
 check((C.GetStats(smith).crafted or 0)==2,"статистика crafted")
 check(count(smith,"toolkit")==1,"набор инструментов не расходуется")
 ok=CR.Start(smith,"campfire_kit")
 smith:SetPos(Vector(X+300,0,0));M.advance(1,.1)
 check(ok and not CR.Jobs[smith] and count(smith,"scrap")==5 and count(smith,"campfire_kit")==0,"сошёл с места — работа прервана без списания")
 smith:SetPos(Vector(X,0,0))
 ok,err=CR.Start(smith,"armor_kit")
 check(not ok and tostring(err):find("Шкура мутанта",1,true),"нехватка ингредиентов названа: "..tostring(err))
 ok=CR.Start(smith,"campfire_kit")
 SI.Exchange(smith,{toolkit=1},{});M.advance(.5,.1)
 check(ok and not CR.Jobs[smith],"набор инструментов пропал из рюкзака — работа прервана")
 give(smith,"toolkit")
 local savedGrid=table.Copy(smith.StalkerInventory.grid)
 for i=1,40 do if not smith.StalkerInventory.grid[i] then smith.StalkerInventory.grid[i]=SI.NewItem("jacket",1) end end
 ok,err=CR.Start(smith,"campfire_kit")
 check(not ok and tostring(err):find("Рюкзак",1,true),"заполненный рюкзак выясняется до начала работы")
 smith.StalkerInventory.grid=savedGrid
 ok=CR.Start(smith,"campfire_kit")
 local npc=ents.Create("npc_citizen");npc:SetPos(Vector(X+2000,0,0));npc:Spawn()
 local radiation=DamageInfo();radiation:SetDamage(1);radiation:SetAttacker(M.world);radiation:SetDamageType(DMG_RADIATION)
 smith:TakeDamageInfo(radiation)
 check(ok and CR.Jobs[smith],"радиация и падения работу не прерывают")
 local shot=DamageInfo();shot:SetDamage(1);shot:SetAttacker(npc);shot:SetDamageType(DMG_BULLET)
 smith:TakeDamageInfo(shot)
 check(not CR.Jobs[smith],"нападение прерывает работу")
 npc:Remove();smith:SetHealth(100)
 local len,vals=packet({id="campfire_kit",count=500})
 M.netReceive("stalker_craft.start",len,smith,vals)
 check(CR.Jobs[smith] and CR.Jobs[smith].recipe.id=="campfire_kit" and CR.Jobs[smith].total==1,"запрос клиента запускает работу (количество проверено)")
 M.netReceive("stalker_craft.cancel",0,smith,{})
 check(not CR.Jobs[smith] and count(smith,"scrap")==5,"запрос клиента отменяет работу")
 len,vals=packet({id="no_such_recipe"});M.netReceive("stalker_craft.start",len,smith,vals)
 check(not CR.Jobs[smith],"неизвестный рецепт отклонён")
 M.netSent={}
 SI.HandleAction(smith,"use","grid",TEST.gridIndex(smith,"toolkit"))
 check(count(smith,"toolkit")==1 and decode(lastSent("stalker_craft.open",smith)).mode=="craft","«Использовать» набор инструментов — мастерская, набор цел")
 check(hook.Run("PlayerSay",smith,"!craft")=="" and tostring(smith._concommands):find("stcraft_menu",1,true),"!craft открывает мастерскую")
 S.Set("craft.need_toolkit",false)
 local fieldCounts=CR.Counts({grid={}})
 check(CR.StationFor(smith,CR.ByID.ammo_pistol,fieldCounts)==true,"настройка: простые рецепты без набора инструментов")
 S.Set("craft.need_toolkit",nil)
 check(CR.StationFor(smith,CR.ByID.ammo_pistol,fieldCounts)==nil,"настройка сброшена: снова нужен набор")
 S.Set("craft.time_mult",2)
 check(CR.Duration(CR.ByID.ammo_pistol)==6 and SI.Items.armor_kit,"множитель времени крафта")
 S.Set("craft.time_mult",nil)

 section("Крафт: верстак (админ)")
 local boss=join("Админ мастерских",49500,0,{superadmin=true,aim=Vector(X+50000,0,0)})
 local plain=join("Без права craft",49000,600)
 local reply=admin(boss,"bench_add")
 check(reply and reply.result and reply.result.ok and #reply.benches==1,"верстак поставлен под прицелом")
 local benchID=reply and reply.benches[1] and reply.benches[1].id or ""
 local function placed(class,id) for _,e in ipairs(ents.FindByClass(class)) do if e:GetPlaceID()==id then return e end end end
 local bench=placed("stalker_workbench",benchID)
 check(IsValid(bench) and math.abs(bench:GetPos().x-(X+50000))<1,"сущность верстака на месте")
 local saved=file.Read("stalker_craft/gm_test.json","DATA")
 check(saved and saved:find(benchID,1,true),"верстак сохранён в data/stalker_craft/<карта>.json")
 local mk=MK.Get("stcraft.bench."..benchID)
 check(mk and mk.kind=="poi" and mk.map==true and MK.VisibleTo(mk,plain),"метка верстака на карте КПК")
 reply=admin(boss,"bench_add")
 check(reply.result and not reply.result.ok and #reply.benches==1,"второй верстак в той же точке отклонён")
 reply=admin(plain,"bench_add")
 check(reply and reply.denied and table.Count(CR.World.benches)==1,"игрок без права craft не ставит верстаки")
 reply=admin(plain,"remove",{kind="benches",id=benchID})
 check(reply.denied and IsValid(bench),"игрок без права craft не убирает верстаки")

 local worker=join("Работник",49900,0)
 give(worker,"scrap",20)
 ok,err=CR.Start(worker,"weapon_kit")
 check(ok and CR.Jobs[worker] and CR.Jobs[worker].ent==bench,"сложный рецепт у верстака ("..tostring(err)..")")
 wait("weapon_kit")
 check(count(worker,"weapon_kit")==1 and count(worker,"scrap")==13,"оружейный набор изготовлен у верстака")
 give(worker,"ammo_buckshot",2)
 ok=CR.Start(worker,"grenade");wait("grenade")
 check(ok and count(worker,"grenade")==1 and count(worker,"ammo_buckshot")==0 and count(worker,"scrap")==8,"граната из деталей и дроби")
 give(worker,"stb_organ_success_clean",1)
 ok=CR.Start(worker,"beacon");wait("beacon")
 check(ok and count(worker,"beacon")==1 and count(worker,"scrap")==0,"маячок событий собран у верстака")
 give(worker,"scrap",2)
 ok=CR.Start(worker,"ammo_pistol")
 check(ok and CR.Jobs[worker].ent==bench,"простой рецепт у верстака — без набора инструментов")
 worker:SetPos(Vector(X+49500,0,0));M.advance(.5,.1)
 check(not CR.Jobs[worker] and count(worker,"scrap")==2,"отошёл от верстака — работа прервана")
 worker:SetPos(Vector(X+49900,0,0))
 M.netSent={};bench:Use(worker)
 local open=decode(lastSent("stalker_craft.open",worker))
 check(open and open.mode=="craft","E по верстаку открывает мастерскую")
 M.netSent={};bench:Use(plain)
 check(not lastSent("stalker_craft.open",plain),"издалека верстак не открыть")

 section("Крафт: ремонт")
 worker.StalkerInventory.equipment.armor=SI.NewItem("jacket",1,30)
 give(worker,"armor_kit",2)
 local okR,msg=CR.Repair(worker,"armor_kit","armor")
 check(okR and worker.StalkerInventory.equipment.armor.durability==70 and count(worker,"armor_kit")==1,"ремкомплект: +40% костюму ("..tostring(msg)..")")
 okR=CR.Repair(worker,"armor_kit","pistol");check(not okR,"набор брони не подходит к оружию")
 okR,msg=CR.Repair(worker,"armor_kit","helmet");check(not okR and msg=="Слот пуст","пустой слот не чинится")
 SI.HandleAction(worker,"use","grid",TEST.gridIndex(worker,"armor_kit"))
 check(worker.StalkerInventory.equipment.armor.durability==100 and count(worker,"armor_kit")==0,"«Использовать» чинит самый изношенный надетый предмет")
 give(worker,"armor_kit")
 SI.HandleAction(worker,"use","grid",TEST.gridIndex(worker,"armor_kit"))
 check(count(worker,"armor_kit")==1,"нечего чинить — набор не расходуется")
 okR,msg=CR.Repair(worker,"armor_kit","armor");check(not okR and tostring(msg):find("порядке",1,true),"целый костюм не чинится")
 worker.StalkerInventory.equipment.pistol=SI.NewItem("pistol",1,50)
 len,vals=packet({kit="weapon_kit",slot="pistol"});M.netReceive("stalker_craft.repair",len,worker,vals)
 check(worker.StalkerInventory.equipment.pistol.durability==90 and count(worker,"weapon_kit")==0,"оружейный набор из окна ремонта: +40%")
 S.Set("craft.repair_armor",25)
 check(CR.KitAmount("armor_kit")==25 and SI.Items.armor_kit.stats.repair==25,"настройка процента ремонта меняет набор и карточку")
 S.Set("craft.repair_armor",nil)
 check(CR.KitAmount("armor_kit")==40,"настройка ремонта сброшена")

 section("Готовка: походный костёр")
 local cook=join("Повар",100000,0)
 give(cook,"campfire_kit",3)
 SI.HandleAction(cook,"use","grid",TEST.gridIndex(cook,"campfire_kit"))
 local sid=cook:SteamID64()
 local fire=CR.TempFires(sid)[1]
 check(IsValid(fire) and fire:IsLit() and not fire:IsPermanent() and count(cook,"campfire_kit")==2,"костёр разожжён из предмета, предмет израсходован")
 check(fire and math.abs(fire:TimeLeft()-CR.Config.FireMinutes*60)<1 and fire:GetOwnerName()=="Повар","срок походного костра: "..CR.Config.FireMinutes.." мин")
 local okF,errF=CR.PlaceCampfire(cook)
 check(not okF and tostring(errF):find("уже горит",1,true),"второй костёр в том же месте не разжечь")
 cook:SetHealth(50);M.advance(CR.Config.FireHealInterval+.5,.5)
 check(cook:Health()>50 and cook:Health()<=50+2*CR.Config.FireHeal,"тепло костра медленно лечит: "..cook:Health())
 local far=join("Далеко от огня",100000,2000);far:SetHealth(50);M.advance(CR.Config.FireHealInterval+.5,.5)
 check(far:Health()==50,"вдали от огня лечения нет")
 cook:SetHealth(100)

 section("Готовка: блюда у костра")
 give(cook,"stb_meat_perfect_clean",1);give(cook,"stb_meat_partial_clean",3);give(cook,"stb_meat_success_toxic",1)
 give(cook,"water",3);give(cook,"bread",1)
 ok,err=CR.Start(cook,"meat_fried")
 check(ok and CR.Jobs[cook] and CR.Jobs[cook].ent==fire,"готовка у костра ("..tostring(err)..")")
 local So=STALKER_SOCIAL
 if So and So.GetPose then check(So.GetPose(cook)=="sit","у огня сталкер садится (поза STALKER Social)") end
 wait("meat_fried")
 check(count(cook,"meat_fried")==1 and count(cook,"stb_meat_partial_clean")==2 and count(cook,"stb_meat_perfect_clean")==1,"жареное мясо: расходуется худший образец")
 if So and So.GetPose then check(So.GetPose(cook)=="","после готовки сталкер встаёт") end
 check((C.GetStats(cook).cooked or 0)==1 and (C.GetStats(cook).crafted or 0)==0,"статистика cooked")
 check(CR.Duration(CR.ByID.meat_dubious)>CR.Duration(CR.ByID.meat_fried),"токсичное мясо жарится дольше")
 ok=CR.Start(cook,"meat_dubious");wait("meat_dubious")
 check(ok and count(cook,"meat_dubious")==1 and count(cook,"stb_meat_success_toxic")==0,"токсичное мясо → «сомнительное мясо»")
 ok=CR.Start(cook,"shashlik");wait("shashlik")
 check(ok and count(cook,"shashlik")==1 and count(cook,"stb_meat_partial_clean")==0,"шашлык из двух кусков мяса")
 ok=CR.Start(cook,"stew");wait("stew")
 check(ok and count(cook,"stew")==1 and count(cook,"water")==2 and count(cook,"bread")==0 and count(cook,"stb_meat_perfect_clean")==0,"похлёбка: мясо, вода и хлеб")
 ok=CR.Start(cook,"tea",2);wait("tea",2)
 check(ok and count(cook,"tea")==2 and count(cook,"water")==0,"чай ×2 из воды")
 check((C.GetStats(cook).cooked or 0)==6,"приготовлено блюд: "..tostring(C.GetStats(cook).cooked))
 ok,err=CR.Start(cook,"tea");check(not ok and tostring(err):find("Вода",1,true),"без воды чай не сварить")
 ok,err=CR.Start(cook,"ammo_pistol");check(not ok,"у костра не крафтят без набора и верстака")
 M.netSent={};fire:Use(cook)
 check(decode(lastSent("stalker_craft.open",cook)).mode=="cook","E по костру открывает готовку")

 section("Готовка: блюда в инвентаре")
 local inv=cook.StalkerInventory
 inv.hunger=20;inv.thirst=30;cook:SetHealth(60)
 SI.HandleAction(cook,"use","grid",TEST.gridIndex(cook,"meat_fried"))
 inv=cook.StalkerInventory
 check(inv.hunger==65 and cook:Health()==65 and count(cook,"meat_fried")==0,"жареное мясо: сытость +45 и +5 HP")
 SI.HandleAction(cook,"use","grid",TEST.gridIndex(cook,"tea"))
 check(cook.StalkerInventory.thirst==75 and cook:Health()==68 and count(cook,"tea")==1,"чай: жажда +45 и +3 HP")
 local dose=tonumber(cook.StalkerInventory.dose) or 0
 SI.HandleAction(cook,"use","grid",TEST.gridIndex(cook,"meat_dubious"))
 check(math.abs((tonumber(cook.StalkerInventory.dose) or 0)-(dose+CR.Config.ToxicDose))<.01 and cook:GetNW2Float("stalker_dose",0)>=CR.Config.ToxicDose,
  "сомнительное мясо: доза радиации +"..CR.Config.ToxicDose)
 check(cook.StalkerInventory.hunger==100 and count(cook,"meat_dubious")==0,"сомнительное мясо утоляет голод")
 cook.StalkerInventory.thirst=100;cook:SetHealth(100)
 SI.HandleAction(cook,"use","grid",TEST.gridIndex(cook,"shashlik"))
 check(count(cook,"shashlik")==1,"сытому шашлык не лезет — блюдо не расходуется")
 cook.StalkerInventory.thirst=50
 SI.HandleAction(cook,"use","grid",TEST.gridIndex(cook,"stew"))
 check(count(cook,"stew")==0 and cook.StalkerInventory.thirst==80,"похлёбка утоляет жажду и сытому")
 S.Set("craft.food_mult",2)
 check(CR.FoodValue("meat_fried","hunger")==90 and SI.Items.meat_fried.stats.hunger==90 and CR.FoodValue("meat_fried","health")==5,"множитель сытости блюд")
 S.Set("craft.food_mult",nil)
 check(SI.Items.meat_fried.stats.hunger==45,"множитель сытости сброшен")

 section("Готовка: срок и лимит костров")
 cook._aim=Vector(X+100000,100,0)
 local okL=CR.PlaceCampfire(cook)
 local mine=CR.TempFires(sid)
 check(okL and not IsValid(fire) and #mine==1,"лимит походных костров: старый гаснет")
 local second=mine[1]
 give(cook,"water",2)
 ok=CR.Start(cook,"tea")
 second:SetExpires(CurTime()+.3);M.advance(1.5,.1)
 check(ok and not CR.Jobs[cook] and count(cook,"water")==2,"погасший костёр прерывает готовку")
 check(not IsValid(second) and #CR.TempFires(sid)==0,"догоревший костёр исчезает")
 ok,err=CR.Start(cook,"tea");check(not ok and err=="Нужен горящий костёр рядом","без огня не приготовить")
 S.Set("craft.fire_minutes",3)
 SI.HandleAction(cook,"use","grid",TEST.gridIndex(cook,"campfire_kit"))
 local third=CR.TempFires(sid)[1]
 check(IsValid(third) and math.abs(third:TimeLeft()-180)<1,"настройка срока костра")
 S.Set("craft.fire_minutes",nil)

 section("Готовка: постоянные костры (админ)")
 boss:SetPos(Vector(X+149500,0,0));boss._aim=Vector(X+150000,0,0)
 reply=admin(boss,"fire_add",{style="barrel"})
 check(reply and reply.result and reply.result.ok and #reply.fires==1 and reply.fires[1].style=="barrel","бочка с огнём поставлена под прицелом")
 local fireID=reply and reply.fires[1] and reply.fires[1].id or ""
 local perm=placed("stalker_campfire",fireID)
 check(IsValid(perm) and perm:IsPermanent() and perm:IsLit() and perm:TimeLeft()==nil and perm:GetStyle()=="barrel","постоянный костёр горит всегда")
 check(MK.Get("stcraft.fire."..fireID) and MK.Get("stcraft.fire."..fireID).label=="Бочка с огнём","метка постоянного костра")
 local guest=join("Гость костра",149900,0)
 M.netSent={};perm:Use(guest)
 check(decode(lastSent("stalker_craft.open",guest)).mode=="cook","E по постоянному костру — готовка")
 give(guest,"water",1);ok=CR.Start(guest,"tea");wait("tea")
 check(ok and count(guest,"tea")==1,"чай у постоянного костра")
 perm:Remove();CR.SpawnPlaces()
 perm=placed("stalker_campfire",fireID)
 check(IsValid(perm) and perm:GetStyle()=="barrel","пропавший постоянный костёр возвращается")
 bench:Remove()
 CR.World={version=1,seq=0,benches={},fires={}};CR.LoadWorld();CR.SpawnPlaces()
 bench=placed("stalker_workbench",benchID)
 check(CR.World.benches[benchID] and CR.World.fires[fireID] and IsValid(bench),"места загружаются из файла карты после перезапуска")

 section("Крафт: админ-панель")
 reply=admin(boss,"state")
 check(reply and #reply.benches==1 and #reply.fires==1 and #reply.temp==1 and reply.temp[1].owner=="Повар" and reply.result==nil and reply.path=="data/stalker_craft/gm_test.json",
  "снимок админ-панели: места, походные костры")
 reply=admin(boss,"show")
 local shown=MK.Get("stcraft.show."..boss:SteamID64().."."..benchID)
 check(reply.result.ok and shown and MK.VisibleTo(shown,boss) and not MK.VisibleTo(shown,plain),"места показаны только этому администратору")
 S.Set("craft.markers",false)
 check(not MK.Get("stcraft.bench."..benchID) and MK.Get("stcraft.show."..boss:SteamID64().."."..benchID),"настройка: метки мест на карте выключены")
 S.Set("craft.markers",nil)
 check(MK.Get("stcraft.bench."..benchID),"метки мест возвращены")
 reply=admin(boss,"go",{kind="benches",id=benchID})
 check(reply.result.ok and boss:GetPos():Distance(bench:GetPos())<100,"переход к месту")
 reply=admin(boss,"clear_temp")
 check(reply.result.ok and #reply.temp==0 and not IsValid(third),"походные костры потушены администратором")
 M.command(boss,"stcraft_list")
 check(table.concat(boss._chat,"\n"):find("benches "..benchID,1,true),"stcraft_list выводит места")
 reply=admin(boss,"remove",{kind="benches",id=benchID})
 check(reply.result.ok and not IsValid(bench) and next(CR.World.benches)==nil and not MK.Get("stcraft.bench."..benchID),"верстак убран вместе с меткой")
 reply=admin(boss,"remove",{kind="fires",id=fireID})
 check(reply.result.ok and not IsValid(perm) and next(CR.World.fires)==nil,"постоянный костёр убран")
 reply=admin(boss,"remove",{kind="fires",id=fireID})
 check(reply.result and not reply.result.ok,"повторное удаление — «Место не найдено»")
 -- Чужие поля и повреждённые записи файла не загружаются.
 file.Write(CR.WorldPath,util.TableToJSON({version=1,seq=5,benches={["bad id!"]={pos={x=1,y=2,z=3}},b9={pos={x="a",y=0,z=0}},b7={pos={x=X,y=0,z=0},yaw=15}},
  fires={f3={pos={x=X,y=50,z=0},style="lava"}}}))
 CR.LoadWorld()
 check(table.Count(CR.World.benches)==1 and CR.World.benches.b7 and CR.World.fires.f3 and CR.World.fires.f3.style=="ring" and CR.World.seq==5,"проверка записей файла мест")
 file.Write(CR.WorldPath,"{broken");CR.LoadWorld()
 check(CR.WorldBroken and not CR.EditWorld(function() return true end),"повреждённый файл мест блокирует правку")
 if tostring(M.warnings[#M.warnings]):find("Повреждён stalker_craft",1,true) then table.remove(M.warnings) end
 file.Write(CR.WorldPath,util.TableToJSON({version=1,seq=0,benches={},fires={}}));CR.LoadWorld();CR.SpawnPlaces()
 check(not CR.WorldBroken and #ents.FindByClass("stalker_workbench")==0,"восстановленный файл снимает блокировку")

 section("Крафт: смерть и выход")
 local victim=join("Неудачник",200000,0)
 give(victim,"scrap",3);give(victim,"toolkit")
 ok=CR.Start(victim,"campfire_kit")
 M.kill(victim)
 check(ok and not CR.Jobs[victim],"гибель прерывает работу")
 M.spawn(victim)
 give(victim,"scrap",3);give(victim,"toolkit")
 ok=CR.Start(victim,"campfire_kit")
 hook.Run("PlayerDisconnected",victim)
 check(ok and not CR.Jobs[victim],"выход с сервера снимает работу")

 section("Крафт: очистка")
 for p in pairs(CR.Jobs) do CR.Cancel(p,nil,true) end
 for _,e in ipairs(ents.FindByClass("stalker_campfire")) do e:Remove() end
 for _,e in ipairs(ents.FindByClass("stalker_workbench")) do e:Remove() end
 MK.Clear("stcraft.")
 check(next(CR.Jobs)==nil and #ents.FindByClass("stalker_campfire")==0,"работ и костров не осталось")
 for _,p in ipairs(players) do M.removePlayer(p) end
else
 section("Крафт: клиент")
 local created={};local orig=vgui.Create
 vgui.Create=function(name,parent) local p=orig(name,parent);created[#created+1]=p;return p end
 local lp=LocalPlayer()
 local savedPos,savedInv=lp:GetPos(),SI.Inventory
 lp:SetPos(Vector(X,0,0))
 local inv=SI.EmptyInventory()
 inv.grid={[1]=SI.NewItem("scrap",30),[2]=SI.NewItem("toolkit",1),[3]=SI.NewItem("stb_meat_success_clean",2),[4]=SI.NewItem("water",1),[5]=SI.NewItem("armor_kit",1)}
 inv.equipment.armor=SI.NewItem("jacket",1,40);inv.revision=7
 SI.Inventory=inv
 local counts=CR.ClientCounts()
 check(counts.scrap==30 and counts.toolkit==1 and counts.stb_meat_success_clean==2,"клиент считает рюкзак")
 local can,rows,why,station,possible=CR.RecipeStatus(CR.ByID.ammo_pistol,counts)
 check(can and station==true and possible==CR.Config.MaxRepeat,"простой рецепт в поле с набором инструментов")
 can,rows,why=CR.RecipeStatus(CR.ByID.weapon_kit,counts)
 check(not can and why=="Нужен верстак","сложный рецепт требует верстак")
 can,rows,why=CR.RecipeStatus(CR.ByID.meat_fried,counts)
 check(not can and why=="Нужен горящий костёр рядом","готовка требует костёр")
 can,rows,why=CR.RecipeStatus(CR.ByID.armor_kit,counts)
 check(not can and tostring(why):find("Шкура мутанта",1,true),"окно называет недостающее")
 local text,token=CR.StationText("craft")
 check(token=="info" and text:find("простые",1,true),"подпись места работы: в поле")
 check(#CR.Grouped("craft")==4 and #CR.Grouped("cook")==2,"категории рецептов в окне")

 M.protect("мастерская",CR.Open,"craft")
 check(CR.Frame~=nil and CR.Mode=="craft" and CR.Details and CR.Details.Recipe,"окно мастерской с выбранным рецептом")
 local card
 for _,p in ipairs(created) do if rawget(p,"Recipe") and rawget(p,"Recipe").id=="campfire_kit" then card=p end end
 if card then M.protect("выбор рецепта",card.OnMousePressed,card) end
 check(card and CR.Selected.craft=="campfire_kit" and CR.Details.Recipe.id=="campfire_kit","выбор рецепта в списке")
 local go
 for _,p in ipairs(created) do if rawget(p,"Label")=="Изготовить" then go=p end end
 M.netSent={}
 if go then M.protect("кнопка «Изготовить»",go.DoClick,go) end
 local req=lastSent("stalker_craft.start")
 check(go and req and tostring(util.Decompress(req.data[2])):find('"campfire_kit"',1,true),"кнопка «Изготовить» отправляет запрос")
 M.protect("готовка",CR.Open,"cook")
 check(CR.Mode=="cook","окно готовки")
 M.protect("ремонт",CR.Open,"repair")
 local repairBtn
 for _,p in ipairs(created) do if not repairBtn and rawget(p,"Label")=="Починить" then repairBtn=p end end
 M.netSent={}
 if repairBtn then M.protect("кнопка «Починить»",repairBtn.DoClick,repairBtn) end
 req=lastSent("stalker_craft.repair")
 check(repairBtn and req and tostring(util.Decompress(req.data[2])):find('"armor_kit"',1,true),"кнопка «Починить» отправляет запрос")
 M.protect("stcraft_menu",M.command,nil,"stcraft_menu","craft")
 local l,v=packet({mode="cook"})
 M.protect("сервер открывает окно",M.netReceive,"stalker_craft.open",l,nil,v)
 check(CR.Mode=="cook","сервер открывает окно готовки")
 l,v=packet({crafted=7,cooked=3})
 M.protect("счётчики",M.netReceive,"stalker_craft.state",l,nil,v)
 check(CR.State.crafted==7 and CR.State.cooked==3,"счётчики крафта для КПК")
 check(C.PDATabs.craft and C.PDATabs.craft.title=="Крафт" and C.PDATabs.craft.order==65 and C.PDATabs.craft.badge()==nil,"вкладка КПК «Крафт»")
 M.protect("вкладка КПК «Крафт»",C.PDATabs.craft.build,M.stub("pda"))
 -- Текущая работа: сетевые переменные сервера.
 lp:SetNW2Float("stcraft_start",CurTime()-1);lp:SetNW2Float("stcraft_end",CurTime()+2)
 lp:SetNW2String("stcraft_label","Изготовление: Патроны (1/2)");lp:SetNW2String("stcraft_recipe","ammo_pistol");lp:SetNW2Int("stcraft_left",1)
 local job=CR.ClientJob()
 check(job and math.abs(job.ratio-1/3)<.01 and C.PDATabs.craft.badge()==1,"текущая работа и значок вкладки")
 M.netSent={}
 if go then M.protect("кнопка «Отменить работу»",go.DoClick,go) end
 check(lastSent("stalker_craft.cancel"),"во время работы кнопка отменяет её")
 -- Админ-панель.
 local snap={benches={{id="b1",pos={x=X,y=0,z=0}}},fires={{id="f1",pos={x=X+10,y=0,z=0},style="barrel"}},temp={{owner="Повар",left=300,pos={x=X,y=5,z=0}}},
  jobs=1,broken=true,maxBenches=32,maxFires=32,path="data/stalker_craft/gm_test.json",result={op="bench_add",ok=true,message="Верстак поставлен и сохранён"}}
 l,v=packet(snap)
 M.protect("ответ админ-панели",M.netReceive,"stalker_craft.admin",l,nil,v)
 check(CR.Admin and #CR.Admin.benches==1 and #CR.Admin.temp==1,"снимок мастерских принят")
 M.netSent={}
 M.protect("админ-панель крафта",CR.BuildAdminPanel,M.stub("admin"))
 req=lastSent("stalker_craft.admin")
 check(type(CR.BuildAdminPanel)=="function" and req and tostring(util.Decompress(req.data[2])):find('"state"',1,true),"STALKER_CRAFT.BuildAdminPanel запрашивает снимок")
 local addBtn,removeBtn
 for _,p in ipairs(created) do
  if rawget(p,"Label")=="Верстак под прицелом" then addBtn=p end
  if rawget(p,"Label")=="Убрать" then removeBtn=p end
 end
 M.netSent={}
 if addBtn then M.protect("кнопка «Верстак под прицелом»",addBtn.DoClick,addBtn) end
 req=lastSent("stalker_craft.admin")
 check(addBtn and req and tostring(util.Decompress(req.data[2])):find('"bench_add"',1,true),"кнопка «Верстак под прицелом»")
 M.netSent={}
 if removeBtn then M.protect("кнопка «Убрать»",removeBtn.DoClick,removeBtn) end
 req=lastSent("stalker_craft.admin")
 check(removeBtn and req and tostring(util.Decompress(req.data[2])):find('"remove"',1,true),"кнопка «Убрать» отправляет запрос")
 CR.Admin={denied=true};M.protect("панель без права",CR.FillAdmin,M.stub("root"))
 CR.Admin=nil;M.protect("панель до ответа",CR.FillAdmin,M.stub("root"))
 CR.Admin=snap
 M.protect("окно stcraft_admin",M.command,nil,"stcraft_admin")
 -- Сущности, подсказки и места работы.
 local fire=ents.Create("stalker_campfire");fire:SetPos(Vector(X,100,0));fire:Spawn()
 fire:SetExpires(CurTime()+300);fire:SetOwnerName("Повар")
 M.protect("костёр: огонь и дым",fire.Think,fire);M.protect("костёр: камни",fire.Draw,fire);M.protect("костёр: свечение",fire.DrawTranslucent,fire)
 fire:SetStyle("barrel");M.protect("костёр: бочка",fire.Draw,fire)
 check(CR.HintFor(fire):find("готовить",1,true) and CR.HintFor(fire):find("Повар",1,true),"подсказка у костра")
 text,token=CR.StationText("cook")
 check(token=="ok" and text:find("догорит",1,true),"окно готовки видит костёр рядом")
 local bench=ents.Create("stalker_workbench");bench:SetPos(Vector(X,-100,0));bench:Spawn()
 M.protect("верстак",bench.Draw,bench)
 check(CR.HintFor(bench):find("верстак",1,true),"подсказка у верстака")
 inv.revision=8
 can=CR.RecipeStatus(CR.ByID.weapon_kit,CR.ClientCounts())
 check(can==true and select(2,CR.StationText("craft"))=="ok","у верстака доступны сложные рецепты")
 can=CR.RecipeStatus(CR.ByID.meat_fried,CR.ClientCounts())
 check(can==true,"у костра можно жарить мясо")
 -- Без инвентаря окна показывают пояснения вместо рецептов.
 local savedSI=STALKER_INV;STALKER_INV=nil
 M.protect("мастерская без инвентаря",CR.Open,"craft")
 M.protect("ремонт без инвентаря",CR.Open,"repair")
 M.protect("книга рецептов без инвентаря",CR.BuildPDATab,M.stub("pda"))
 check(#CR.List()==0 and next(CR.ClientCounts())==nil,"без STALKER Inventory окна крафта не падают")
 STALKER_INV=savedSI
 vgui.Create=orig
 local painted,thought=0,0
 for _,p in ipairs(created) do
  local think=rawget(p,"Think");if type(think)=="function" then thought=thought+1;M.protect("логика панели крафта",think,p) end
  local paint=rawget(p,"Paint");if type(paint)=="function" then painted=painted+1;M.protect("отрисовка панели крафта",paint,p,700,64) end
 end
 check(painted>30 and thought>5,"панели крафта отрисованы: "..painted)
 CR.Frame=nil;lp._aim=Vector(X,100,0);lp._aimEntity=fire
 M.protect("HUD крафта",hook.Run,"HUDPaint")
 lp._aimEntity=nil
 -- Справочник КПК.
 local P=STALKER_PDA
 if P and P.Guide then
  local g,cookGuide=P.Guide.craft,P.Guide.cooking
  local ok1,blocks=pcall(g and g.blocks or error);local ok2,cookBlocks=pcall(cookGuide and cookGuide.blocks or error)
  check(ok1 and ok2 and #blocks>4 and #cookBlocks>6 and g.subtitle=="Детали, верстаки, ремонт","разделы справочника КПК «Крафт» и «Готовка» от модуля")
 end
 fire:Remove();bench:Remove()
 lp:SetNW2Float("stcraft_end",0);lp:SetPos(savedPos);SI.Inventory=savedInv
 CR.Admin=nil;CR.Frame=nil;CR.State={crafted=0,cooked=0}
end
