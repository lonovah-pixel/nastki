-- Сценарии первого выпуска: загрузка, инвентарь, торговля, Зона, смерть, мутанты, выброс, DarkRP.
local M,check,section=TEST.M,TEST.check,TEST.section
local count,gridCount,gridIndex=TEST.count,TEST.gridCount,TEST.gridIndex
local Z,S,N,F=STALKER_ZONE,STALKER_INV,STALKER_NPC,STFW
section("Загрузка ("..M.Realm..")")
check(Z and Z.ItemsReady,"STALKER_ZONE загружен и предметы зарегистрированы")
check(S and S.Items and S.Items.det_veles,"детектор в реестре инвентаря")
for id in pairs(Z.ItemPrices) do check(S.Items[id],"цена без предмета: "..id) end
for id,info in pairs(Z.Artifacts) do check(S.Items[id] and S.Items[id].category=="artifact","артефакт "..id) end
for id,d in pairs(S.Items) do
 if d.icon and d.icon~="" then
  local ok=false
  for _,a in ipairs(M.addons) do local f=io.open(a.."/materials/"..d.icon,"rb");if f then f:close();ok=true end end
  check(ok,"иконка предмета "..id..": materials/"..d.icon)
 end
end

if SERVER then
 section("Вход игрока и стартовый набор")
 local admin=M.addPlayer({superadmin=true,aim=Vector(400,0,0),nick="Админ"})
 hook.Run("PlayerInitialSpawn",admin);M.spawn(admin);M.advance(4)
 check(admin.StalkerInventory,"инвентарь загружен")
 for _,row in ipairs(Z.Config.Starter) do check(gridCount(admin,row[1])==row[2],"стартовый набор: "..row[1]) end
 check(admin:GetNW2String("stfw_faction","")=="loner","профиль группировки загружен")

 section("Склады торговцев")
 for id,profile in pairs(N.Config.Traders) do
  local stock=N.GetStock(id)
  if check(stock,"склад создаётся: "..id) then
   for _,row in ipairs(profile.stock) do check(profile.prices[row[1]] and profile.prices[row[1]].buy,"цена товара "..row[1].." у "..id) end
   check(table.Count(stock.grid)<=40,"склад помещается в 40 ячеек: "..id)
  end
 end
 local stock=N.GetStock("trader_duty")
 local before=0;for i,it in pairs(stock.grid) do if it.id=="medkit" then before=before+it.count;stock.grid[i]=nil end end
 check(before>0,"у Долга есть аптечки")
 check(Z.RestockTrader("trader_duty"),"восполнение склада срабатывает")
 local after=0;for _,it in pairs(N.Stocks.trader_duty.grid) do if it.id=="medkit" then after=after+it.count end end
 check(after>0 and after<=before,"аптечки восполнены частично ("..after.."/"..before..")")
 local deal=N.BuildTrade(admin.StalkerInventory,N.GetStock("sidor"),N.Config.Traders.sidor,{{side="buy",index=(function() for i,it in pairs(N.GetStock("sidor").grid) do if it.id=="det_echo" then return i end end end)(),count=1,uid=(function() for _,it in pairs(N.GetStock("sidor").grid) do if it.id=="det_echo" then return it.uid end end end)()}},100000,admin)
 check(deal and deal.total>0,"покупка детектора у Сидоровича считается")

 section("Редактор: поле аномалий")
 local ok,err,fieldID=Z.EditorAction(admin,{op="create",kind="field",placement="aim",name="Тестовое поле",radius=600,count=10,artifacts=5,
  types={electro=true,burner=true,springboard=true,vortex=true,acid=true}})
 check(ok,"поле создано: "..tostring(err))
 check(count("stalker_anomaly")>=6,"аномалии появились: "..count("stalker_anomaly"))
 check(count("stalker_artifact")==5,"артефакты появились: "..count("stalker_artifact"))
 check(file.Exists("stalker_zone/gm_test.json","DATA"),"настройка сохранена в data/stalker_zone")
 local bad=Z.EditorAction(admin,{op="create",kind="field",placement="aim",name="",radius=600,count=10,artifacts=5,types={electro=true}})
 check(not bad,"пустое название отклонено")
 local plain=M.addPlayer({nick="Без прав"});hook.Run("PlayerInitialSpawn",plain);M.spawn(plain);M.advance(3)
 check(not Z.EditorAction(plain,{op="regen",kind="field"}),"игрок без прав не редактирует Зону")

 section("Артефакт и детектор")
 local art=ents.FindByClass("stalker_artifact")[1]
 admin:SetPos(art:GetPos()-Vector(0,0,30))
 for i=1,40 do local it=admin.StalkerInventory.grid[i];if it and Z.Detectors[it.id] then admin.StalkerInventory.grid[i]=nil end end
 Z.PickupArtifact(admin,art)
 check(IsValid(art),"без детектора артефакт не подбирается")
 check(S.GiveItem(admin,"det_echo",1),"детектор выдан")
 local id=art:GetArtifactID()
 local had=gridCount(admin,id)
 Z.PickupArtifact(admin,art)
 check(not IsValid(art) and gridCount(admin,id)==had+1,"артефакт подобран детектором")

 section("Аномалии наносят урон")
 for i,kind in ipairs(Z.AnomalyOrder) do
  local a=ents.Create("stalker_anomaly");a:SetKind(kind);a:SetPos(Vector(20000+i*1000,0,0));a:Spawn()
  local victim=M.addPlayer({nick="Жертва "..kind,pos=Vector(20000+i*1000,0,0)})
  victim._center=24
  a:Think();M.now=M.now+1;a:Think()
  check(victim:Health()<100,"«"..Z.Anomalies[kind].name.."» ранит: здоровье "..victim:Health())
  M.removePlayer(victim);a:Remove()
 end

 section("Снаряжение")
 check(S.GiveItem(admin,"zarya",1),"костюм выдан")
 S.HandleAction(admin,"move","grid",gridIndex(admin,"zarya"),"equipment","armor")
 check(admin.StalkerInventory.equipment.armor and admin.StalkerInventory.equipment.armor.id=="zarya","костюм надет")
 check(Z.Gear[admin] and Z.Gear[admin].bulletResist==10,"пулестойкость костюма учтена")
 local dmg=DamageInfo();dmg:SetDamage(50);dmg:SetDamageType(DMG_BULLET);dmg:SetAttacker(M.world)
 -- Проверяем только сопротивление костюма: очки брони HL2 обнуляем.
 admin:SetArmor(0)
 local hp=admin:Health();admin:TakeDamageInfo(dmg)
 check(math.abs((hp-admin:Health())-45)<.01,"пуля ослаблена на 10%: "..(hp-admin:Health()))
 admin:SetHealth(100)
 check(S.GiveItem(admin,"sphere",1),"шлем выдан")
 S.HandleAction(admin,"move","grid",gridIndex(admin,"sphere"),"equipment","helmet")
 local head=DamageInfo();head:SetDamage(100);head:SetDamageType(DMG_BULLET)
 admin:SetArmor(0);admin._hitgroup=HITGROUP_HEAD;admin:TakeDamageInfo(head);admin._hitgroup=nil
 check(math.abs(head:GetDamage()-100*.55*.9)<.01,"шлем (45%) и костюм (10%) гасят выстрел в голову: "..head:GetDamage())
 admin:SetHealth(100)
 check(S.GiveItem(admin,"battery",1),"артефакт выдан")
 S.HandleAction(admin,"move","grid",gridIndex(admin,"battery"),"equipment","artifact1")
 check(admin:GetNW2Float("stz_speed",0)==8,"«Батарейка» ускоряет: "..tostring(admin:GetNW2Float("stz_speed",0)))

 section("Голод и жажда")
 admin.StalkerInventory.thirst=0;hp=admin:Health()
 M.advance(11)
 check(admin:Health()<hp,"обезвоживание отнимает здоровье")
 admin.StalkerInventory.thirst=80;admin:SetHealth(100)

 section("Рюкзак погибшего")
 local victim=M.addPlayer({nick="Погибший",pos=Vector(300,300,0)});hook.Run("PlayerInitialSpawn",victim);M.spawn(victim);M.advance(3)
 check(S.GiveItem(victim,"medkit_army",3),"предметы жертве выданы")
 local items=table.Count(victim.StalkerInventory.grid);local uids={}
 for _,it in pairs(victim.StalkerInventory.grid) do uids[it.uid]=true end
 M.kill(victim)
 local bag=ents.FindByClass("stalker_deathbag")[1]
 check(IsValid(bag) and #bag.Items==items,"рюкзак лежит на месте гибели ("..(bag and #bag.Items or 0).." из "..items..")")
 check(next(victim.StalkerInventory.grid)==nil,"рюкзак жертвы опустел")
 local looter=M.addPlayer({nick="Мародёр",pos=Vector(300,300,0)});hook.Run("PlayerInitialSpawn",looter);M.spawn(looter);M.advance(3)
 looter._pos=bag:GetPos()-Vector(0,0,40)
 Z.LootBag(looter,bag)
 local moved=0;for _,it in pairs(looter.StalkerInventory.grid) do if uids[it.uid] then moved=moved+1 end end
 check(moved==items and not IsValid(bag),"мародёр забрал всё ("..moved..")")
 M.spawn(victim);M.advance(1)
 check(victim.StalkerInventory.thirst>=Z.Config.Survival.RespawnMinimum,"после возрождения потребности не ниже минимума")

 section("Патроны переживают переподключение")
 local p=M.addPlayer({nick="Стрелок",pos=Vector(-8000,0,0)});hook.Run("PlayerInitialSpawn",p);M.spawn(p);M.advance(3)
 check(p:Alive(),"стрелок жив вдали от аномалий")
 p:GiveAmmo(45,"SMG1");hook.Run("PlayerDisconnected",p);M.removePlayer(p)
 local saved=sql.Query("SELECT payload FROM stz_ammo WHERE steamid="..sql.SQLStr(p._sid))
 check(saved and saved[1],"запас патронов записан при выходе")
 local back=M.addPlayer({nick="Стрелок",sid=p._sid,pos=Vector(-8000,0,0)});hook.Run("PlayerInitialSpawn",back);M.spawn(back);M.advance(3)
 check(back:GetAmmoCount("SMG1")==45,"запас SMG1 восстановлен: "..back:GetAmmoCount("SMG1"))

 section("Логово мутантов")
 admin._aim=Vector(-3000,0,0)
 ok,err=Z.EditorAction(admin,{op="create",kind="zone",placement="aim",name="Логово",radius=400,max=3,respawn=20,types={zombie=true,snork=true}})
 check(ok,"логово создано: "..tostring(err))
 for _,pl in ipairs(player.GetAll()) do pl._pos=Vector(-3000,0,0) end
 M.advance(15)
 check(count("npc_zombie")+count("npc_fastzombie")==0,"мутанты не появляются рядом с игроками")
 for _,pl in ipairs(player.GetAll()) do pl._pos=Vector(9000,9000,0) end
 M.advance(70)
 local npcs={};for _,c in ipairs({"npc_zombie","npc_fastzombie"}) do for _,e in ipairs(ents.FindByClass(c)) do npcs[#npcs+1]=e end end
 check(#npcs>=1 and #npcs<=3,"мутанты появились: "..#npcs)
 check(npcs[1] and npcs[1].KillValue and npcs[1].KillValue>0,"за мутанта платит DarkRP")
 check(F.Config.MutantClasses.npc_zombie=="zombies","репутация за зомби привязана к группировке")
 local rag=ents.Create("prop_ragdoll");hook.Run("CreateEntityRagdoll",npcs[1],rag)
 check(STALKER_BUTCHERING.Corpses[rag],"труп мутанта доступен для разделки")
 M.advance(Z.Config.CorpseLifetime+2,1)
 check(not IsValid(rag),"труп мутанта убран после окна разделки")

 section("Выброс перестраивает Зону")
 hook.Add("STEmissionCanDamage","test.noDamage",function() return false end)
 local firstAnomaly=ents.FindByClass("stalker_anomaly")[1]
 ST_EMISSION.Start();M.advance(175,.5)
 check(ST_EMISSION.State.phase==0,"выброс завершился")
 check(not IsValid(firstAnomaly) and count("stalker_anomaly")>=6,"аномалии сместились после выброса")
 local announced=false;for _,line in ipairs(admin._chat) do if line:find("новые артефакты") then announced=true end end
 check(announced,"игроки получили сообщение о новых артефактах")

 section("Вайп знает о новых данных")
 local wipe=io.open(os.getenv("GMOD_ROOT").."/stalker_survival/lua/autorun/000_stalker_wipe.lua"):read("*a")
 check(wipe:find('"stz_ammo"',1,true) and wipe:find('"stalker_zone"',1,true),"stz_ammo и data/stalker_zone в списке вайпа")
 for _,name in ipairs({"stalker_stash_intel","stalker_stats","stalker_events"}) do check(wipe:find('"'..name..'"',1,true),name.." в списке вайпа") end
end

if CLIENT then
 section("Клиент: детектор, эффекты, HUD, редактор, памятка")
 S.Inventory.grid[1]=S.NewItem("det_veles",1);hook.Run("STALKER_INV_Updated",S.Inventory)
 check(Z.LocalDetectorID=="det_veles","лучший детектор из рюкзака")
 local art=ents.Create("stalker_artifact");art:SetArtifactID("medusa");art:SetPos(Vector(150,0,0));art:Spawn()
 M.advance(1)
 check(art:Visibility()>0,"артефакт проявляется рядом с детектором")
 M.protect("artifact draw",art.DrawTranslucent,art)
 for _,kind in ipairs(Z.AnomalyOrder) do
  local a=ents.Create("stalker_anomaly");a:SetKind(kind);a:SetPos(Vector(200,0,0));a:Spawn();a:SetTriggered(CurTime())
  M.protect("anomaly think "..kind,a.Think,a);M.protect("anomaly draw "..kind,a.DrawTranslucent,a)
 end
 local bag=ents.Create("stalker_deathbag");bag:SetPos(Vector(50,0,0));bag:Spawn();M.protect("bag draw",bag.Draw,bag)
 local lp=LocalPlayer()
 for _,ev in ipairs({{"HUDPaint"},{"Think"},{"PostDrawTranslucentRenderables",false,false},{"RenderScreenspaceEffects"},{"HUDShouldDraw","CHudHealth"},
  {"CalcView",lp,Vector(0,0,64),Angle(0,0,0),90},{"DrawOverlay"},{"PlayerBindPress",lp,"+showscores",true}}) do M.protect("event "..ev[1],hook.Run,unpack(ev)) end
 M.command(nil,"stz_editor")
 check(Z.Editor,"редактор Зоны открывается")
 Z.EditorState={ready=true,stats={anomalies=3,artifacts=1,maxArtifacts=60},
  fields={{id="1",kind="field",name="Поле",pos={x=0,y=0,z=0},radius=500,count=5,artifacts=2,types={electro=true},liveAnomalies=5,liveArtifacts=1}},
  zones={{id="2",kind="zone",name="Логово",pos={x=0,y=0,z=0},radius=400,max=3,respawn=60,types={zombie=true},liveMutants=1}}}
 M.protect("editor rebuild",Z.Editor.Rebuild,Z.Editor,"1")
 Z.Editor.Kind="zone";Z.Editor.Selected="2";M.protect("editor zone form",Z.Editor.BuildForm,Z.Editor)
 M.protect("editor paint",Z.Editor.Paint,Z.Editor,900,600)
 M.protect("editor preview",hook.Run,"PostDrawTranslucentRenderables",false,false)
 M.command(nil,"stz_help")
 check(Z.HelpFrame,"памятка открывается")
 M.protect("pda online",hook.Run,"STALKER_INV_DrawPDA",M.stub("pda"),512,388)
end

-- Конфигурация DarkRP: профессии, категории, язык (сервер).
if SERVER then
 section("darkrpmodification")
 local jobs,cats,langs,chat={}, {}, {}, {}
 local nextTeam=1
 DarkRP.createJob=function(name,t) t.name=name;jobs[#jobs+1]=t;nextTeam=nextTeam+1;return nextTeam-1 end
 DarkRP.createCategory=function(t) cats[t.name]=t end
 DarkRP.addLanguage=function(code,t) langs[code]=t end
 DarkRP.addChatCommandsLanguage=function(code,t) chat[code]=t end
 DarkRP.disabledDefaults={}
 local root=os.getenv("GMOD_ROOT").."/darkrpmodification/lua/"
 for _,f in ipairs({"darkrp_config/settings.lua","darkrp_config/disabled_defaults.lua","darkrp_customthings/categories.lua","darkrp_customthings/jobs.lua",
  "darkrp_language/russian.lua","darkrp_language/chatcommands_ru.lua"}) do M.loadFile(root..f,f) end
 local models={}
 for _,m in ipairs({"alyx","breen","eli","gman_high","kleiner","monk","odessa","barney","magnusson","mossman","mossman_arctic","combine_soldier","combine_soldier_prisonguard",
  "combine_super_soldier","police","police_fem","soldier_stripped","arctic","gasmask","guerilla","leet","phoenix","riot","swat","urban","p2_chell","dod_german","dod_american"}) do models["models/player/"..m..".mdl"]=true end
 for i=1,9 do models["models/player/Group01/male_0"..i..".mdl"]=true;models["models/player/Group03/male_0"..i..".mdl"]=true;models["models/player/Group03m/male_0"..i..".mdl"]=true end
 for i=1,6 do models["models/player/Group01/female_0"..i..".mdl"]=true;models["models/player/Group03/female_0"..i..".mdl"]=true;models["models/player/Group03m/female_0"..i..".mdl"]=true end
 for _,i in ipairs({2,4,6,8}) do models["models/player/Group02/male_0"..i..".mdl"]=true end
 for i=1,4 do models["models/player/hostage/hostage_0"..i..".mdl"]=true end
 check(#jobs>=14,"профессии созданы: "..#jobs)
 local commands={}
 for _,job in ipairs(jobs) do
  check(cats[job.category],"категория профессии «"..job.name.."»: "..tostring(job.category))
  check(not commands[job.command],"команда профессии уникальна: "..job.command);commands[job.command]=true
  for _,m in ipairs(type(job.model)=="table" and job.model or {job.model}) do check(models[m],"модель из базового GMod: "..m) end
  if job.stalkerFaction then
   check(F.Factions[job.stalkerFaction] and F.Factions[job.stalkerFaction].playable,"группировка профессии существует: "..job.stalkerFaction)
   local member=M.addPlayer({nick="Проверка"});member:SetNW2Bool("stfw_joined",true);member:SetNW2String("stfw_faction",job.stalkerFaction)
   local stranger=M.addPlayer({nick="Чужой"});stranger:SetNW2Bool("stfw_joined",true);stranger:SetNW2String("stfw_faction","__other")
   check(job.customCheck(member) and not job.customCheck(stranger),"профессия «"..job.name.."» только для членов группировки")
   M.removePlayer(member);M.removePlayer(stranger)
  end
 end
 check(GAMEMODE.DefaultTeam==TEAM_STALKER and TEAM_STALKER,"профессия по умолчанию — Сталкер")
 check(GM.Config.currency=="₽" and GM.Config.startingmoney==3000,"валюта и стартовые деньги")
 check(DarkRP.disabledDefaults.jobs and DarkRP.disabledDefaults.jobs.citizen==true and DarkRP.disabledDefaults.modules.fadmin==true,"стандартные профессии и FAdmin отключены")
 check(langs.ru and langs.ru.become_job,"русский язык DarkRP загружен")
 check(chat.ru and chat.ru.g,"русские описания чат-команд")
end
