-- STALKER Quests: квестодатели и их расстановка, предложения из шаблонов, шесть типов заданий, сдача и награды,
-- лимиты и сроки, сохранение, «Путь новичка», метки и GUIDE LINE, вкладка КПК, окно разговора и админ-панель.
-- Область мира X: 4 500 000…4 900 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local Q,C,MK,S,SI=STALKER_QUESTS,STALKER_CORE,STALKER_MARKERS,STALKER_SETTINGS,STALKER_INV
local X=4500000
section("Задания: загрузка ("..M.Realm..")")
check(Q and Q.Config and Q.Version and Q.Templates and Q.Profiles,"STALKER_QUESTS загружен")
for _,id in ipairs({"quests.max_active","quests.daily_limit","quests.reward_mult","quests.tutorial","quests.offers","quests.offer_minutes",
 "quests.cooldown","quests.time_mult","quests.talk_distance","quests.visit_radius","quests.min_visit_distance","quests.guide_length","quests.history","quests.news"}) do
 check(S.Defs[id] and S.Defs[id].category=="Задания","настройка в категории «Задания»: "..id)
end
check(S.Defs["quests.max_active"].realm=="shared" and S.Defs["quests.tutorial"].type=="bool" and S.Defs["quests.reward_mult"].type=="number","realm и типы настроек")
check(SI.Items.quest_package and SI.Items.quest_package.name=="Посылка" and SI.Items.quest_package.stackable,"предмет «Посылка» в инвентаре")
check(scripted_ents.Get("stalker_quest_npc"),"сущность квестодателя зарегистрирована")
local perProfile,badTpl={},nil
for id,tpl in pairs(Q.Templates) do
 perProfile[tpl.profile]=(perProfile[tpl.profile] or 0)+1
 if not Q.Profiles[tpl.profile] or not Q.Types[tpl.type] or type(tpl.desc)~="string" or tpl.goal[1]>tpl.goal[2] then badTpl=id end
end
check(not badTpl,"шаблоны корректны: "..tostring(badTpl))
check((perProfile.barman or 0)>=5 and (perProfile.professor or 0)>=5 and (perProfile.hunter or 0)>=5 and (perProfile.courier or 0)>=4,"у каждого квестодателя свои шаблоны")
local types={};for _,tpl in pairs(Q.Templates) do types[tpl.type]=true end
check(types.fetch and types.kill and types.artifact and types.visit and types.deliver and types.emission,"все шесть типов заданий")
check(#Q.TutorialSteps==6 and Q.TutorialSteps[1].id=="trader" and Q.TutorialSteps[6].id=="recruiter","шесть шагов обучения")
if SERVER then check(C.StatNames.quests,"статистика «Выполнено заданий»") end
check(Q.Fill("{n} шт. у {place}",{n=3,place="моста"})=="3 шт. у моста","подстановка в тексты")
local organs=Q.ResolveItems({patterns={"stb_organ_*_clean"}});local cleanOnly=#organs>0
for _,id in ipairs(organs) do if not id:match("^stb_organ_.*_clean$") then cleanOnly=false end end
check(cleanOnly,"образцы разделки по шаблону stb_organ_*_clean: "..#organs)
local arts=Q.ResolveItems({category="artifact"});local hasMedusa=false
for _,id in ipairs(arts) do if id=="medusa" then hasMedusa=true end end
check(hasMedusa and #Q.ResolveItems({ids={"bread","nope"}})==1,"предметы по категории и списку (только существующие)")
check(Q.Objective({type="deliver",toName="Бармен"})=="Доставьте посылку: Бармен" and Q.RewardText({money=100})~="","цель и награда одной строкой")

local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end

if SERVER then
 local players={}
 local function join(nick,x,y,extra)
  local o=extra or {};o.nick=nick;o.pos=Vector(X+x,y or 0,0);o.aim=o.aim or Vector(X+x+100,y or 0,0)
  local p=TEST.join(o);p.StfwProtected=0;players[#players+1]=p;return p
 end
 local function standAt(p,pos) p:SetPos(pos-Vector(500,0,0));p._aim=pos end
 -- Частота запросов проверяется отдельно; в сценарии сбрасываем ведро, чтобы шаги шли подряд.
 local function act(p,tbl) p.StalkerRate=nil;local len,vals=packet(tbl);M.netReceive("stalker_quests.action",len,p,vals) end
 local function adminAs(p,tbl) p.StalkerRate=nil;local len,vals=packet(tbl);M.netReceive("stalker_quests.admin",len,p,vals);return decode(lastSent("stalker_quests.admin",p)) end
 local function use(ent,p) p.StalkerRate=nil;M.netSent={};ent:Use(p);return decode(lastSent("stalker_quests.dialog",p)) end
 local function near(p,ent,dx) p:SetPos(ent:GetPos()+Vector(dx or 60,0,0)) end
 local function rep(p,f) local d=STFW and STFW.Load and STFW.Load(p);return d and d.rep[f] or 0 end
 local admin=join("Комендант заданий",0,0,{superadmin=true})
 local plain=join("Без права заданий",0,600)

 section("Задания: квестодатели (админ)")
 M.netSent={}
 standAt(admin,Vector(X+10000,0,0))
 local reply=adminAs(admin,{op="npc_add",profile="barman",name="Шустрый"})
 check(reply and reply.result and reply.result.ok and #reply.npcs==1,"квестодатель поставлен под прицелом")
 local barmanID=reply and reply.npcs[1] and reply.npcs[1].id
 local barman=Q.FindNPC(barmanID)
 check(IsValid(barman) and barman:GetProfile()=="barman" and barman:GetModel()=="models/odessa.mdl" and math.abs(barman:GetPos().x-(X+10000))<1,"Бармен на карте с моделью профиля")
 check(IsValid(barman) and Q.NPCName(barman)=="Бармен «Шустрый»","имя квестодателя с прозвищем")
 local saved=file.Read("stalker_quests/gm_test.json","DATA")
 check(saved and saved:find("Шустрый",1,true),"расстановка сохраняется в data/stalker_quests/<карта>.json")
 standAt(admin,Vector(X+12000,0,0));adminAs(admin,{op="npc_add",profile="professor"})
 standAt(admin,Vector(X+14000,0,0));adminAs(admin,{op="npc_add",profile="hunter"})
 standAt(admin,Vector(X+16000,0,0));reply=adminAs(admin,{op="npc_add",profile="courier"})
 check(reply and #reply.npcs==4 and #reply.profiles==4,"четыре квестодателя и четыре профиля в снимке")
 local ids={}
 for _,row in ipairs(reply.npcs) do ids[row.profile]=row.id end
 reply=adminAs(admin,{op="npc_add",profile="nope"})
 check(reply.result and not reply.result.ok and #reply.npcs==4,"неизвестный профиль отклонён")
 reply=adminAs(admin,{op="npc_add",profile="barman",name=string.rep("Я",60)})
 check(reply.result and not reply.result.ok,"слишком длинное имя отклонено")
 M.netSent={}
 reply=adminAs(plain,{op="npc_add",profile="barman"})
 check(reply and reply.denied and table.Count(Q.World.npcs)==4,"игрок без права quests не ставит квестодателей")
 standAt(admin,Vector(X+30000,0,0))
 reply=adminAs(admin,{op="point_add",name="Старая водокачка"})
 check(reply.result and reply.result.ok and #reply.points==1 and reply.points[1].name=="Старая водокачка","место заданий добавлено")
 local pointID=reply.points[1] and reply.points[1].id
 reply=adminAs(admin,{op="point_add",name=""})
 check(reply.result and not reply.result.ok and #reply.points==1,"пустое название места отклонено")
 adminAs(admin,{op="show"})
 local shown=MK.Get("stq.admin."..admin:SteamID64()..".n"..barmanID)
 check(shown and MK.VisibleTo(shown,admin) and not MK.VisibleTo(shown,plain),"показ квестодателей — только этому администратору")
 standAt(admin,Vector(X+18000,0,0))
 reply=adminAs(admin,{op="npc_add",profile="barman",name="Временный"})
 local temp;for _,row in ipairs(reply.npcs) do if row.name=="Временный" then temp=Q.FindNPC(row.id) end end
 admin._aimEntity=temp
 reply=adminAs(admin,{op="npc_remove",aim=true})
 admin._aimEntity=nil
 check(reply.result and reply.result.ok and not IsValid(temp) and table.Count(Q.World.npcs)==4,"квестодатель под прицелом убран")
 reply=adminAs(admin,{op="npc_remove",aim=true})
 check(reply.result and not reply.result.ok,"без квестодателя под прицелом — отказ")
 local row1;for _,row in ipairs(reply.npcs) do if row.id==ids.barman then row1=row end end
 check(row1 and row1.spawned and type(row1.available)=="number","снимок показывает доступные шаблоны квестодателя")
 -- Перезагрузка карты: квестодатели восстанавливаются из файла с теми же ID.
 Q.World={version=1,seq=0,npcs={},points={}}
 Q.LoadWorld();Q.RestoreNPCs()
 local barmanE,prof,hunter,courier=Q.FindNPC(ids.barman),Q.FindNPC(ids.professor),Q.FindNPC(ids.hunter),Q.FindNPC(ids.courier)
 check(IsValid(barmanE) and barmanE~=barman and IsValid(prof) and IsValid(hunter) and IsValid(courier) and #ents.FindByClass("stalker_quest_npc")==4,"квестодатели восстановлены из файла")
 barman=barmanE
 check(Q.World.points[pointID] and Q.World.points[pointID].name=="Старая водокачка","места заданий загружены из файла")
 local realValid=util.IsValidModel
 util.IsValidModel=function(m) return m==Q.FallbackModel end
 local fallback=Q.SpawnNPC({id="tmpfb",profile="professor",name="Профессор",pos={x=X+20000,y=0,z=0},yaw=0})
 util.IsValidModel=realValid
 check(IsValid(fallback) and fallback:GetModel()==Q.FallbackModel,"нет модели профиля — резервная модель HL2")
 fallback:Remove();Q.NPCEnts.tmpfb=nil

 section("Задания: разговор и предложения")
 local stalker=join("Сталкер-трудяга",10100,0)
 local dlg=use(barman,stalker)
 check(dlg and dlg.name=="Бармен «Шустрый»" and #dlg.offers>=1 and #dlg.offers<=Q.Config.Offers and dlg.greeting~="","окно разговора: приветствие и предложения ("..tostring(dlg and #dlg.offers)..")")
 local firstKeys={};for _,o in ipairs(dlg and dlg.offers or {}) do firstKeys[#firstKeys+1]=o.key end
 local again=use(barman,stalker)
 local sameKeys={};for _,o in ipairs(again and again.offers or {}) do sameKeys[#sameKeys+1]=o.key end
 check(table.concat(firstKeys,",")==table.concat(sameKeys,","),"повторный разговор не перебирает предложения")
 local offerOK=true
 for _,o in ipairs(dlg and dlg.offers or {}) do if Q.Templates[o.key] or not o.reward or (o.reward.money or 0)<=0 or o.time<1 then offerOK=false end end
 check(offerOK,"у предложений есть награда и срок")
 local far=join("Далёкий",13000,3000)
 check(use(barman,far)==nil,"издалека с квестодателем не поговорить")

 section("Задания: принести предметы")
 local key=Q.AddOffer(stalker,barman,"bar_food")
 act(stalker,{op="accept",npc=barman:EntIndex(),key=key})
 local d=Q.Data(stalker)
 local q=d.active[1]
 check(q and q.tpl=="bar_food" and q.goal>=3 and q.goal<=5 and d.tracked==q.uid,"задание «Провизия для бара» взято и отслеживается")
 dlg=decode(lastSent("stalker_quests.dialog",stalker))
 check(dlg and dlg.result and dlg.result.ok and #dlg.turnins==1 and dlg.turnins[1].ready==false,"окно обновлено: задание в списке сдачи, ещё не готово")
 act(stalker,{op="accept",npc=barman:EntIndex(),key=key})
 check(#d.active==1,"одно предложение нельзя взять дважды")
 act(stalker,{op="turnin",npc=barman:EntIndex(),uid=q.uid})
 dlg=decode(lastSent("stalker_quests.dialog",stalker))
 check(#d.active==1 and dlg.result and not dlg.result.ok and tostring(dlg.result.message):find("Не хватает",1,true),"без предметов сдать нельзя")
 local breadBefore=TEST.gridCount(stalker,"bread")
 check(SI.GiveItem(stalker,"bread",q.goal),"хлеб выдан")
 M.netSent={};M.advance(1.5)
 check(q.progress==q.goal,"прогресс сбора считается по рюкзаку")
 local st=decode(lastSent("stalker_quests.state",stalker))
 check(st and st.active[1] and st.active[1].ready and st.npcs[ids.barman],"КПК: задание готово, у Бармена значок сдачи")
 local mk=MK.Get("stq."..stalker:SteamID64().."."..q.uid)
 check(mk and mk.kind=="quest" and mk.edge==true and MK.VisibleTo(mk,stalker) and not MK.VisibleTo(mk,plain) and math.abs(mk.pos.x-barman:GetPos().x)<1,"метка «Сдать» ведёт к Бармену и видна только исполнителю")
 local money,repBefore=stalker._money,rep(stalker,"loner")
 act(stalker,{op="turnin",npc=barman:EntIndex(),uid=q.uid})
 check(#d.active==0 and TEST.gridCount(stalker,"bread")==breadBefore and stalker._money==money+q.reward.money,"сдача: хлеб забран, деньги выплачены ("..q.reward.money..")")
 check(not STFW or rep(stalker,"loner")==repBefore+q.reward.rep,"репутация у группировки квестодателя")
 check((C.GetStats(stalker).quests or 0)==1 and d.done==1 and d.history[1].status=="done" and d.history[1].title=="Провизия для бара","статистика, счётчик и история")
 check(Q.OnCooldown(d,"bar_food"),"шаблон на откате")
 local cooled=true;for _,o in ipairs(Q.Offers(stalker,barman,true)) do if o.q.tpl=="bar_food" then cooled=false end end
 check(cooled,"шаблон на откате не предлагается")
 M.advance(1.1)
 check(not MK.Get("stq."..stalker:SteamID64().."."..q.uid),"метка сданного задания убрана")

 section("Задания: охота на мутантов")
 local Z=STALKER_ZONE
 Z.World.zones.qtest={id="qtest",name="Логово у фермы",pos={x=X+60000,y=0,z=0},radius=500,max=1,respawn=600,types={zombie=true,snork=true}}
 near(stalker,hunter)
 key=Q.AddOffer(stalker,hunter,"hunt_zombie")
 act(stalker,{op="accept",npc=hunter:EntIndex(),key=key})
 q=d.active[1]
 check(q and q.type=="kill" and q.hint and q.hint.name=="Логово «Логово у фермы»","задание охоты подсказывает логово")
 M.advance(1.5)
 mk=MK.Get("stq."..stalker:SteamID64().."."..q.uid)
 check(mk and math.abs(mk.pos.x-(X+60000))<1 and mk.label=="Логово «Логово у фермы»","метка ведёт к логову")
 local function kill(class,key2,by)
  local npc=ents.Create(class);npc:SetPos(Vector(X+61000,0,0));npc:Spawn();npc.StalkerMutant=key2
  local dmg=DamageInfo();dmg:SetDamage(500);dmg:SetAttacker(by or stalker);dmg:SetDamageType(DMG_BULLET);npc:TakeDamageInfo(dmg)
 end
 kill("npc_zombie","zombie")
 check(q.progress==1,"убитый зомбированный засчитан")
 kill("npc_antlion","blinddog")
 check(q.progress==1,"слепой пёс в задание на зомби не идёт")
 kill("npc_fastzombie",nil)
 check(q.progress==2,"NPC без метки Зоны засчитан по классу")
 kill("npc_zombie","zombie",plain)
 check(q.progress==2,"чужое убийство не засчитано")
 q.progress=q.goal-1
 kill("npc_zombie","snork")
 check(q.done and q.progress==q.goal,"охота выполнена")
 M.advance(1.5)
 mk=MK.Get("stq."..stalker:SteamID64().."."..q.uid)
 check(mk and math.abs(mk.pos.x-hunter:GetPos().x)<1,"после выполнения метка ведёт к Охотнику")
 near(stalker,barman)
 act(stalker,{op="turnin",npc=barman:EntIndex(),uid=q.uid})
 check(#d.active==1,"охоту не сдать Бармену")
 near(stalker,hunter)
 money=stalker._money
 act(stalker,{op="turnin",npc=hunter:EntIndex(),uid=q.uid})
 check(#d.active==0 and stalker._money==money+q.reward.money and d.done==2,"охота сдана Охотнику")

 section("Задания: поиск артефактов")
 Z.World.fields.qtest={id="qtest",name="Поле у оврага",pos={x=X+70000,y=0,z=0},radius=500,count=2,artifacts=2,types={electro=true}}
 near(stalker,prof)
 key=Q.AddOffer(stalker,prof,"prof_measure")
 act(stalker,{op="accept",npc=prof:EntIndex(),key=key})
 q=d.active[1]
 check(q and q.type=="artifact" and q.hint and q.hint.name=="Поле «Поле у оврага»","«Полевые замеры» подсказывают поле аномалий")
 for _=1,q.goal do hook.Run("STALKER_ZONE_ArtifactPicked",stalker,"flash") end
 check(q.done,"подбор артефактов засчитан")
 local sciBefore=rep(stalker,"scientists")
 act(stalker,{op="turnin",npc=prof:EntIndex(),uid=q.uid})
 check(#d.active==0 and (not STFW or rep(stalker,"scientists")==sciBefore+q.reward.rep),"сдано Профессору, репутация «Учёных»")
 key=Q.AddOffer(stalker,prof,"prof_tissue")
 act(stalker,{op="accept",npc=prof:EntIndex(),key=key})
 q=d.active[1]
 check(q and q.goal==2 and #q.items>0,"«Образцы тканей»: органы мутантов")
 SI.GiveItem(stalker,"stb_organ_success_toxic",2)
 M.advance(1.5)
 check(q.progress==0,"токсичные образцы не подходят")
 SI.GiveItem(stalker,"stb_organ_perfect_clean",1);SI.GiveItem(stalker,"stb_organ_partial_clean",1)
 M.advance(1.5)
 act(stalker,{op="turnin",npc=prof:EntIndex(),uid=q.uid})
 check(#d.active==0 and TEST.gridCount(stalker,"stb_organ_perfect_clean")==0 and TEST.gridCount(stalker,"stb_organ_partial_clean")==0 and TEST.gridCount(stalker,"stb_organ_success_toxic")==2,
  "забраны только подходящие образцы")

 section("Задания: разведка")
 near(stalker,courier)
 key=Q.AddOffer(stalker,courier,"cour_check")
 act(stalker,{op="accept",npc=courier:EntIndex(),key=key})
 q=d.active[1]
 check(q and q.type=="visit" and q.place and q.place.radius==Q.Config.VisitRadius,"разведка: место и радиус")
 M.advance(1.5)
 mk=MK.Get("stq."..stalker:SteamID64().."."..q.uid)
 check(mk and mk.label=="Разведка: "..q.place.name and math.abs(mk.pos.x-q.place.pos.x)<1,"метка места разведки")
 stalker:SetPos(Vector(q.place.pos.x+q.place.radius+200,q.place.pos.y,0));M.advance(1.5)
 check(not q.done,"за пределами радиуса место не засчитано")
 stalker:SetPos(Vector(q.place.pos.x+q.place.radius-50,q.place.pos.y,0));M.advance(1.5)
 check(q.done,"место посещено")
 near(stalker,courier)
 act(stalker,{op="turnin",npc=courier:EntIndex(),uid=q.uid})
 check(#d.active==0,"разведка сдана Связному")

 section("Задания: доставка")
 key=Q.AddOffer(stalker,courier,"cour_parcel")
 act(stalker,{op="accept",npc=courier:EntIndex(),key=key})
 q=d.active[1]
 local target=q and Q.FindNPC(q.to)
 check(q and q.type=="deliver" and IsValid(target) and target~=courier and TEST.gridCount(stalker,"quest_package")==1,"посылка выдана, адресат — другой квестодатель")
 M.advance(1.5)
 mk=MK.Get("stq."..stalker:SteamID64().."."..q.uid)
 check(mk and math.abs(mk.pos.x-target:GetPos().x)<1,"метка ведёт к адресату")
 act(stalker,{op="turnin",npc=courier:EntIndex(),uid=q.uid})
 check(#d.active==1,"отправителю посылку не сдать")
 near(stalker,target)
 st=decode(lastSent("stalker_quests.state",stalker))
 dlg=use(target,stalker)
 local tin=dlg and dlg.turnins[1]
 check(tin and tin.deliver and tin.ready,"адресат принимает посылку")
 money=stalker._money
 act(stalker,{op="turnin",npc=target:EntIndex(),uid=q.uid})
 check(#d.active==0 and TEST.gridCount(stalker,"quest_package")==0 and stalker._money==money+q.reward.money,"посылка доставлена, награда выплачена")
 near(stalker,courier)
 key=Q.AddOffer(stalker,courier,"cour_docs")
 act(stalker,{op="accept",npc=courier:EntIndex(),key=key})
 q=d.active[1]
 check(TEST.gridCount(stalker,"quest_package")==1,"вторая посылка")
 act(stalker,{op="abandon",uid=q.uid})
 check(#d.active==0 and TEST.gridCount(stalker,"quest_package")==0 and d.history[1].status=="abandoned","отказ: посылка возвращена, в истории — отказ")
 -- Рюкзак полон: посылку не выдать, задание не берётся.
 key=Q.AddOffer(stalker,courier,"cour_urgent")
 local savedGrid=table.Copy(stalker.StalkerInventory.grid)
 for i=1,40 do if not stalker.StalkerInventory.grid[i] then stalker.StalkerInventory.grid[i]=SI.NewItem("scrap",1) end end
 act(stalker,{op="accept",npc=courier:EntIndex(),key=key})
 check(#d.active==0,"без места в рюкзаке доставку не взять")
 stalker.StalkerInventory.grid=savedGrid

 section("Задания: пережить выброс")
 near(stalker,barman)
 key=Q.AddOffer(stalker,barman,"bar_emission")
 act(stalker,{op="accept",npc=barman:EntIndex(),key=key})
 q=d.active[1]
 local victim=join("Неудачник",10150,0)
 local vkey=Q.AddOffer(victim,barman,"bar_emission")
 act(victim,{op="accept",npc=barman:EntIndex(),key=vkey})
 local vq=Q.Data(victim).active[1]
 hook.Run("STEmissionStarted")
 check(q.armed and vq and vq.armed,"начало выброса отмечено")
 M.kill(victim);M.spawn(victim)
 hook.Run("STEmissionFinished")
 check(q.done and not vq.done,"переживший выброс выполнил задание, погибший — нет")
 act(stalker,{op="turnin",npc=barman:EntIndex(),uid=q.uid})
 check(#d.active==0,"«Пережить выброс» сдано")
 hook.Run("STEmissionStarted");hook.Run("STEmissionFinished")
 check(vq.done,"следующий выброс засчитан")

 section("Задания: лимиты, сроки, отслеживание")
 check(S.Set("quests.max_active",2) and Q.Config.MaxActive==2,"лимит активных заданий меняется настройкой")
 local k1=Q.AddOffer(stalker,barman,"bar_meds");act(stalker,{op="accept",npc=barman:EntIndex(),key=k1})
 local k2=Q.AddOffer(stalker,barman,"bar_scout");act(stalker,{op="accept",npc=barman:EntIndex(),key=k2})
 local k3=Q.AddOffer(stalker,barman,"bar_artifact");act(stalker,{op="accept",npc=barman:EntIndex(),key=k3})
 dlg=decode(lastSent("stalker_quests.dialog",stalker))
 check(#d.active==2 and dlg.result and not dlg.result.ok and tostring(dlg.result.message):find("2",1,true),"третье задание сверх лимита не берётся")
 check(dlg.offers[1]==nil or dlg.offers[1].blocked~=nil,"предложения помечены недоступными")
 S.Set("quests.max_active",nil)
 check(S.Set("quests.daily_limit",1),"суточный лимит")
 act(stalker,{op="accept",npc=barman:EntIndex(),key=k3})
 dlg=decode(lastSent("stalker_quests.dialog",stalker))
 check(#d.active==2 and tostring(dlg.result and dlg.result.message):find("сутки",1,true),"сверх суточного лимита не берётся")
 S.Set("quests.daily_limit",nil)
 local meds,scout=d.active[1],d.active[2]
 act(stalker,{op="track",uid=scout.uid})
 check(d.tracked==scout.uid,"отслеживание переключается")
 M.advance(1.5)
 check(MK.Get("stq."..stalker:SteamID64().."."..scout.uid).edge==true,"стрелка у края — у отслеживаемого задания")
 act(stalker,{op="track",uid="q9999"})
 check(d.tracked==scout.uid,"чужой uid не отслеживается")
 scout.expires=os.time()-1;M.advance(1.5)
 check(#d.active==1 and d.history[1].status=="expired" and d.tracked==meds.uid and not MK.Get("stq."..stalker:SteamID64().."."..scout.uid),"просроченное задание провалено, отслеживается следующее")
 act(stalker,{op="abandon",uid=meds.uid})
 check(#d.active==0 and Q.OnCooldown(d,"bar_meds"),"отказ ставит шаблон на откат")

 section("Задания: сохранение")
 key=Q.AddOffer(stalker,hunter,"hunt_season")
 near(stalker,hunter);act(stalker,{op="accept",npc=hunter:EntIndex(),key=key})
 d.active[1].progress=3
 Q.Save(stalker)
 local sid=stalker:SteamID64()
 Q.Players[sid]=nil
 local d2=Q.Data(stalker)
 check(d2~=d and #d2.active==1 and d2.active[1].tpl=="hunt_season" and d2.active[1].progress==3 and d2.done==d.done and #d2.history==#d.history and d2.cooldowns.bar_food,
  "профиль заданий восстановлен из SQLite stalker_quests")
 d=d2
 local ghost=M.addPlayer({nick="Повреждённый",pos=Vector(X+5000,0,0)})
 sql.Query("REPLACE INTO stalker_quests VALUES("..sql.SQLStr(ghost:SteamID64())..",'{broken')")
 local gd=Q.Data(ghost)
 check(gd and #gd.active==0 and sql.QueryValue("SELECT COUNT(*) FROM stalker_quests WHERE sid LIKE "..sql.SQLStr("broken:"..ghost:SteamID64()..":%"))=="1","повреждённый профиль сохранён копией, игрок начинает заново")
 if tostring(M.warnings[#M.warnings]):find("Повреждён профиль заданий",1,true) then table.remove(M.warnings) end
 M.removePlayer(ghost)

 section("Задания: путь новичка")
 check(S.Set("quests.tutorial",true),"обучение включено")
 local trader=ents.Create("stalker_npc_trader");trader:SetTraderID("sidor");trader:SetPos(Vector(X+200000,0,0));trader:Spawn()
 local recruiter=ents.Create("stalker_recruiter");recruiter:SetFactionID("duty");recruiter:SetPos(Vector(X+260000,0,0));recruiter:Spawn()
 Z.World.fields.qtut={id="qtut",name="Поле новичков",pos={x=X+230000,y=0,z=0},radius=400,count=2,artifacts=1,types={electro=true}}
 local newbie=join("Новичок",200300,0)
 local nd=Q.Data(newbie)
 check(nd.tut and nd.tut.state=="active" and nd.tut.step==1 and nd.tracked=="tutorial","новичку начато обучение, оно отслеживается")
 M.netSent={};M.advance(1.5)
 local tmk=MK.Get("stq."..newbie:SteamID64()..".tut")
 check(tmk and tmk.kind=="quest" and tmk.edge==true and math.abs(tmk.pos.x-(X+200000))<1 and tostring(tmk.label):find("Сидорович",1,true),"метка шага ведёт к ближайшему торговцу")
 M.netSent={};Q.Changed(newbie);M.advance(1.1)
 st=decode(lastSent("stalker_quests.state",newbie))
 check(st and st.tutorial and st.tutorial.state=="active" and st.tutorial.id=="trader" and st.tutorial.pos and st.tutorial.total==6,"состояние обучения в КПК")
 money=newbie._money
 hook.Run("PlayerUse",newbie,trader)
 check(nd.tut.step==2 and newbie._money==money+300,"шаг 1: разговор с торговцем, награда")
 M.advance(1.5)
 check(nd.tut.step==2,"без детектора шаг 2 не засчитан")
 SI.GiveItem(newbie,"det_echo",1);M.advance(1.5)
 check(nd.tut.step==3,"шаг 2: детектор в рюкзаке")
 M.advance(1.5)
 tmk=MK.Get("stq."..newbie:SteamID64()..".tut")
 check(tmk and math.abs(tmk.pos.x-(X+230000))<1 and tostring(tmk.label):find("Поле новичков",1,true),"метка шага 3 — ближайшее поле аномалий")
 local bandages=TEST.gridCount(newbie,"bandage")
 SI.GiveItem(newbie,"medusa",1);hook.Run("STALKER_ZONE_ArtifactPicked",newbie,"medusa")
 check(nd.tut.step==4 and TEST.gridCount(newbie,"bandage")==bandages+2,"шаг 3: артефакт подобран, награда — бинты")
 M.advance(1.5)
 tmk=MK.Get("stq."..newbie:SteamID64()..".tut")
 local nearestBarman=Q.NearestEnt("stalker_quest_npc",newbie:GetPos(),function(e) return e:GetProfile()=="barman" end)
 check(tmk and IsValid(nearestBarman) and math.abs(tmk.pos.x-nearestBarman:GetPos().x)<1,"метка шага 4 — Бармен")
 near(newbie,barman)
 dlg=use(barman,newbie)
 check(dlg and dlg.tutorial and dlg.tutorial.handover and dlg.tutorial.handover.can and dlg.tutorial.handover.item=="Медуза","Бармен предлагает сдать артефакт")
 money=newbie._money
 act(newbie,{op="handover",npc=barman:EntIndex()})
 check(nd.tut.step==5 and TEST.gridCount(newbie,"medusa")==0 and newbie._money==money+Q.ArtifactPrice("medusa")+700,"шаг 4: артефакт сдан Бармену (цена + награда)")
 act(newbie,{op="handover",npc=barman:EntIndex()})
 check(nd.tut.step==5,"повторная сдача не нужна")
 act(newbie,{op="pda"})
 check(nd.tut.step==6,"шаг 5: КПК открыт")
 M.advance(1.5)
 tmk=MK.Get("stq."..newbie:SteamID64()..".tut")
 check(tmk and math.abs(tmk.pos.x-(X+260000))<1 and tostring(tmk.label):find("Долг",1,true),"метка шага 6 — вербовщик")
 money=newbie._money
 newbie:SetPos(Vector(X+260000+80,0,0));M.advance(1.5)
 check(nd.tut.state=="done" and nd.done==1 and newbie._money==money+1000 and (C.GetStats(newbie).quests or 0)==1,"шаг 6: вербовщик — обучение пройдено")
 check(not MK.Get("stq."..newbie:SteamID64()..".tut") and Q.TutorialView(newbie,nd)==nil and nd.history[1].title=="Путь новичка","метка обучения убрана, запись в истории")
 -- Продажа торговцу: артефактов меньше, денег больше, игрок в диалоге торговца.
 local seller=join("Продавец",200100,0)
 local sd=Q.Data(seller)
 sd.tut.step=4;seller.StalkerQuestSnap=nil
 SI.GiveItem(seller,"flash",2);M.advance(1.5)
 SI.Exchange(seller,{flash=1},{});M.advance(1.5)
 check(sd.tut.step==4,"выброшенный без денег артефакт продажей не считается")
 local N=STALKER_NPC
 N.Sessions[seller]={id=7,entity=trader,profile="sidor",node="greeting",nodeRevision=0,expires=CurTime()+60}
 SI.Exchange(seller,{flash=1},{});seller:addMoney(2600);M.advance(1.5)
 N.Sessions[seller]=nil
 check(sd.tut.step==5,"шаг 4: продажа артефакта торговцу распознана")
 hook.Run("ShowSpare2",seller)
 check(sd.tut.step==6,"F4 (ShowSpare2) засчитывает шаг «КПК»")
 money=seller._money
 act(seller,{op="tutorial_skip"})
 check(sd.tut.state=="done" and seller._money==money,"пропуск шага — без награды")
 local lazy=join("Ленивый",200200,0)
 local ld=Q.Data(lazy)
 act(lazy,{op="tutorial_stop"})
 check(ld.tut.state=="skipped" and ld.tracked==nil,"обучение отложено")
 M.advance(1.5)
 check(ld.tut.state=="skipped" and not MK.Get("stq."..lazy:SteamID64()..".tut"),"отложенное обучение не возобновляется само")
 act(lazy,{op="tutorial_resume"})
 check(ld.tut.state=="active" and ld.tracked=="tutorial","обучение продолжено")
 M.advance(1.5)
 check(Q.Data(stalker).tut==nil,"опытному сталкеру обучение не начинается")
 S.Set("quests.tutorial",false)
 check(Q.TutorialView(lazy,ld)==nil and not Q.TutorialActive(ld),"выключенное обучение скрыто")
 M.advance(1.5)
 check(not MK.Get("stq."..lazy:SteamID64()..".tut"),"метка выключенного обучения убрана")

 section("Задания: квестодатель убран")
 near(stalker,barman)
 local kb=Q.AddOffer(stalker,barman,"bar_artifact")
 act(stalker,{op="accept",npc=barman:EntIndex(),key=kb})
 local qa;for _,x in ipairs(Q.Data(stalker).active) do if x.tpl=="bar_artifact" then qa=x end end
 check(qa,"задание Бармена взято")
 reply=adminAs(admin,{op="npc_remove",id=ids.barman})
 check(reply.result and reply.result.ok and not IsValid(barman) and not Q.World.npcs[ids.barman],"Бармен убран из списка")
 check(Q.TurnInHere(qa,hunter) and Q.TurnInHere(qa,courier),"без Барменов задание сдаётся любому квестодателю")
 SI.GiveItem(stalker,"crystal",1);M.advance(1.5)
 near(stalker,hunter)
 act(stalker,{op="turnin",npc=hunter:EntIndex(),uid=qa.uid})
 check(TEST.gridCount(stalker,"crystal")==0,"задание сдано другому квестодателю")

 section("Задания: консоль и снимок")
 M.netSent={}
 reply=adminAs(admin,{op="state"})
 check(reply and #reply.npcs==3 and reply.result==nil and reply.players>=1,"снимок админ-панели")
 M.printed={};M.command(nil,"stq_list")
 local listed=false;for _,line in ipairs(M.printed) do if line:find("Старая водокачка",1,true) then listed=true end end
 check(listed,"stq_list выводит квестодателей и места")
 file.Write(Q.WorldPath,"{broken");Q.LoadWorld()
 check(Q.WorldBroken and not Q.EditWorld(function() return true end),"повреждённый файл квестодателей блокирует правку")
 if tostring(M.warnings[#M.warnings]):find("Повреждён stalker_quests",1,true) then table.remove(M.warnings) end
 file.Write(Q.WorldPath,util.TableToJSON({version=1,seq=0,npcs={},points={}}));Q.LoadWorld()
 check(not Q.WorldBroken,"восстановленный файл снимает блокировку")

 section("Задания: очистка")
 Q.RestoreNPCs()
 check(#ents.FindByClass("stalker_quest_npc")==0,"квестодатели сняты")
 trader:Remove();recruiter:Remove()
 Z.World.zones.qtest=nil;Z.World.fields.qtest=nil;Z.World.fields.qtut=nil
 for _,p in ipairs(players) do MK.Clear("stq."..p:SteamID64()..".");M.removePlayer(p) end
 M.advance(6)
else
 section("Задания: клиент")
 local created={};local orig=vgui.Create
 vgui.Create=function(name,parent) local p=orig(name,parent);created[#created+1]=p;return p end
 local function find(label) for _,p in ipairs(created) do if rawget(p,"Label")==label then return p end end end
 local function findLast(label) local out;for _,p in ipairs(created) do if rawget(p,"Label")==label then out=p end end;return out end
 local function click(label) local b=find(label);if b then M.netSent={};M.protect("кнопка «"..label.."»",b.DoClick,b) end;return b,decode(lastSent("stalker_quests.action") or lastSent("stalker_quests.admin")) end
 -- Состояние: два задания (второе отслеживается, цель в 600 units), обучение на шаге «КПК», история.
 local lp=LocalPlayer();lp:SetPos(Vector(0,0,0))
 local state={tracked="q2",max=5,daily=15,today=2,done=4,npcs={n1=true},
  active={{uid="q1",title="Провизия для бара",desc="Принеси еды",type="fetch",objective="Принесите: еда",progress=1,goal=3,ready=false,left=1200,giverName="Бармен",reward={money=500,rep=5,faction="loner",items={{"bandage",1}}}},
   {uid="q2",title="Разведка",desc="Сходи к водокачке",type="visit",objective="Посетите место «Водокачка»",progress=0,goal=1,ready=false,left=200,giverName="Связной",
    reward={money=700},pos={x=600,y=0,z=0},label="Разведка: Водокачка"}},
  history={{title="Тушканы",status="done",t=os.time(),money=600,giver="Охотник"},{title="Посылка",status="expired",t=os.time()}},
  tutorial={state="active",step=5,total=6,id="pda",title="КПК",text="Откройте КПК клавишей F4",reward={money=300,items={}}}}
 local l,v=packet(state)
 M.protect("состояние заданий",M.netReceive,"stalker_quests.state",l,nil,v)
 check(#Q.State.active==2 and Q.State.tutorial.id=="pda","состояние заданий принято")
 local sum=Q.ActiveSummary()
 check(#sum==3 and sum[1].title=="Разведка" and sum[1].goal==1 and sum[2].title:find("Путь новичка",1,true) and sum[3].progress==1,"STALKER_QUESTS.ActiveSummary(): отслеживаемое первым")
 check(C.PDATabs.quests and C.PDATabs.quests.title=="Задания" and C.PDATabs.quests.badge()==nil,"вкладка КПК «Задания»")
 M.netSent={}
 M.protect("вкладка КПК",C.PDATabs.quests.build,M.stub("pda"))
 local req=lastSent("stalker_quests.action")
 check(req and tostring(req.data[2]):find('"pda"',1,true),"открытие вкладки засчитывает шаг обучения «КПК»")
 local t=Q.Tracked()
 check(t and t.uid=="q2" and Q.TrackedPos() and Q.TrackedPos().x==600,"отслеживаемая цель")
 local ok,painted=M.protect("трекер",Q.PaintTracker)
 check(ok and painted==true,"трекер в правом верхнем углу")
 -- GUIDE LINE: шевроны лежат на земле между игроком и целью и тают к концу линии.
 local list=Q.GuideChevrons()
 local okLine=list and #list>=5
 for _,ch in ipairs(list or {}) do if ch.pos.x<=0 or ch.pos.x>=600 or math.abs(ch.pos.y)>.01 or ch.pos.z~=3 or ch.alpha<=0 or ch.alpha>235 then okLine=false end end
 check(okLine,"направляющая линия: шевроны от игрока к цели ("..tostring(list and #list)..")")
 check(Q.Guide and Q.Guide.samples[0]==0,"профиль земли под линией")
 state.active[2].pos={x=50000,y=0,z=0};l,v=packet(state);M.protect("цель вдали",M.netReceive,"stalker_quests.state",l,nil,v)
 list=Q.GuideChevrons()
 local maxX=0;for _,ch in ipairs(list or {}) do maxX=math.max(maxX,ch.pos.x) end
 check(list and #list>0 and maxX<=Q.Config.GuideLength,"линия не длиннее "..Q.Config.GuideLength.." units")
 GetConVar("stq_guideline"):SetString("0")
 check(Q.GuideChevrons()==nil and Q.Guide==nil,"stq_guideline 0 выключает линию")
 GetConVar("stq_guideline"):SetString("1")
 M.protect("отрисовка линии",hook.Run,"PostDrawTranslucentRenderables",false,false)
 local drawn=0;M.protect("линия",function() drawn=Q.DrawGuide() end)
 check(drawn>0,"шевроны нарисованы: "..drawn)
 M.advance(2.5)
 M.netSent={}
 M.protect("F4",hook.Run,"PlayerBindPress",lp,"gm_showspare2",true)
 req=lastSent("stalker_quests.action")
 check(req and tostring(req.data[2]):find('"pda"',1,true),"F4 сообщает серверу об открытии КПК")
 -- Кнопки вкладки КПК.
 local b,sent=click("Отслеживать")
 check(b and sent and sent.op=="track" and sent.uid=="tutorial","«Отслеживать» обучение")
 b=findLast("Отслеживать");M.netSent={}
 if b then M.protect("отслеживать задание",b.DoClick,b) end
 sent=decode(lastSent("stalker_quests.action"))
 check(sent and sent.op=="track" and sent.uid=="q1","«Отслеживать» задание отправляет запрос")
 b=find("Отказаться");M.netSent={}
 if b then M.protect("отказ 1",b.DoClick,b) end
 check(b and b.Label=="Точно отказаться?" and lastSent("stalker_quests.action")==nil,"отказ требует подтверждения")
 if b then M.protect("отказ 2",b.DoClick,b) end
 sent=decode(lastSent("stalker_quests.action"))
 check(sent and sent.op=="abandon","подтверждённый отказ отправлен")
 M.protect("журнал без КПК",M.command,nil,"stq_journal")
 -- Окно разговора.
 local dialog={npc=77,id="n1",name="Бармен «Шустрый»",title="Хозяин бара",about="Общие поручения",profile="barman",greeting="Заходи!",active=2,max=5,daily=15,today=2,
  offers={{key="o5",title="Аптечки для раненых",desc="Принеси аптечки",type="fetch",objective="Принесите: медикаменты",goal=3,time=45,reward={money=740,rep=6,faction="loner"}},
   {key="o6",title="Пережить выброс",desc="Скоро рванёт",type="emission",objective="Переживите выброс",goal=1,time=180,reward={money=900},blocked="Лимит"}},
  turnins={{uid="q1",title="Провизия для бара",objective="Принесите: еда",progress=3,goal=3,ready=true,reward={money=500}}},
  tutorial={step=4,total=6,title="Хабар",text="Сдайте артефакт",handover={item="Медуза",price=1400,can=true}},result={op="accept",ok=true,message="Задание взято"}}
 l,v=packet(dialog)
 M.protect("окно разговора",M.netReceive,"stalker_quests.dialog",l,nil,v)
 check(Q.Dialog and Q.Dialog.npc==77 and Q.DialogFrame~=nil,"окно разговора открыто")
 b,sent=click("Взять задание")
 check(sent and sent.op=="accept" and sent.key=="o5" and sent.npc==77,"«Взять задание» отправляет ключ предложения")
 b,sent=click("Сдать")
 check(sent and sent.op=="turnin" and sent.uid=="q1","«Сдать» отправляет задание")
 b,sent=click("Сдать артефакт")
 check(sent and sent.op=="handover","«Сдать артефакт» Бармену")
 -- Админ-панель.
 local snap={npcs={{id="n1",name="Шустрый",profile="barman",pos={x=10,y=0,z=0},spawned=true,available=4,missing={"Зачистка: Нет логов"}},{id="n2",name="Профессор",profile="professor",pos={x=0,y=0,z=0},spawned=false}},
  points={{id="p1",name="Водокачка",pos={x=0,y=0,z=0}}},profiles={{id="barman",name="Бармен"},{id="hunter",name="Охотник"}},maxNPC=48,maxPoints=96,players=3,active=5,templates=27,
  result={op="npc_add",ok=true,message="Поставлен"}}
 l,v=packet(snap)
 M.protect("снимок админ-панели",M.netReceive,"stalker_quests.admin",l,nil,v)
 M.protect("админ-панель",Q.BuildAdminPanel,M.stub("admin"))
 check(type(Q.BuildAdminPanel)=="function" and Q.Admin and #Q.Admin.npcs==2,"STALKER_QUESTS.BuildAdminPanel")
 b,sent=click("Поставить под прицелом")
 check(sent and sent.op=="npc_add" and sent.profile=="barman","«Поставить под прицелом» отправляет профиль")
 b,sent=click("Убрать под прицелом")
 check(sent and sent.op=="npc_remove" and sent.aim==true,"«Убрать под прицелом»")
 Q.Admin={denied=true};M.protect("панель без права",Q.FillAdmin,M.stub("root"))
 Q.Admin=nil;M.protect("панель до ответа",Q.FillAdmin,M.stub("root"))
 Q.Admin=snap
 M.protect("окно stq_menu",M.command,nil,"stq_menu")
 vgui.Create=orig
 local paintedN=0
 for _,p in ipairs(created) do
  local paint=rawget(p,"Paint");if type(paint)=="function" then paintedN=paintedN+1;M.protect("отрисовка панели заданий",paint,p,700,160) end
 end
 check(paintedN>20,"панели заданий отрисованы: "..paintedN)
 -- Квестодатель: подпись, значок сдачи, подсказка.
 local npc=ents.Create("stalker_quest_npc");npc:SetPos(Vector(100,0,0));npc:Spawn()
 npc:SetProfile("barman");npc:SetQuestName("Шустрый");npc:SetNpcID("n1")
 M.protect("квестодатель: отрисовка",npc.Draw,npc)
 check(Q.NPCLabel(npc)=="Бармен «Шустрый»" and Q.NPCMark(npc)=="?","подпись и значок «?» над квестодателем")
 check(Q.HintFor(npc,lp)=="E — поговорить: Бармен «Шустрый»","подсказка «E — поговорить»")
 M.protect("HUD заданий",hook.Run,"HUDPaint")
 npc:Remove()
 Q.State={active={},history={},npcs={},max=5,daily=15,today=0,done=0};Q.Dialog=nil;Q.Admin=nil;Q.Guide=nil
 check(#Q.ActiveSummary()==0 and Q.PaintTracker()==false,"без заданий трекер скрыт")
end
