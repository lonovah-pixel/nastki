-- STALKER Social: знакомства (Knows/DisplayName, SQLite), меню взаимодействия (представиться, рукопожатие, деньги,
-- предмет, контакты, приглашение, обыск, награды), нашивки, жесты и позы, имена в HUD и чате DarkRP, вкладки КПК.
-- Область мира X: 4 000 000…4 400 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local S,C,SET,SI,F=STALKER_SOCIAL,STALKER_CORE,STALKER_SETTINGS,STALKER_INV,STFW
local X=4000000
section("Знакомства: загрузка ("..M.Realm..")")
check(S and S.Config and S.Version and type(S.Knows)=="function" and type(S.DisplayName)=="function","STALKER_SOCIAL загружен, Knows/DisplayName")
for _,id in ipairs({"social.hide_names","social.admins_see_all","social.stranger_name","social.interact_distance","social.reply_distance","social.request_seconds",
 "social.patch_distance","social.max_patches","social.max_transfer","social.emote_cooldown","social.ach_hunter","social.ach_seeker","social.ach_survivor",
 "social.ach_tracker","social.ach_veteran","social.ach_executor","social.ach_cook","social.ach_master"}) do
 check(SET.Defs[id] and SET.Defs[id].category=="Знакомства и нашивки","настройка в категории «Знакомства и нашивки»: "..id)
end
check(SET.Defs["social.hide_names"].realm=="shared" and SET.Defs["social.hide_names"].type=="bool" and SET.Defs["social.reply_distance"].realm=="server","realm и тип настроек")
check(#S.Gestures==11 and #S.Poses==4 and #S.Achievements==8 and #S.Awards==4,"каталоги: 11 жестов, 4 позы, 8 достижений, 4 награды")
for _,g in ipairs(S.Gestures) do check(S.Act(g.act)~=nil,"ACT жеста «"..g.name.."»") end
local info=S.PatchInfo("faction_duty")
check(info and info.kind=="faction" and info.name:find("Долг",1,true) and info.icon=="stalker_factions/emblems/duty.png","нашивка группировки — эмблема STALKER Factions")
check(S.PatchInfo("rank_3") and S.PatchInfo("rank_3").name=="Звание: Ветеран","нашивка звания по STFW.Ranks")
check(S.PatchInfo("ach_hunter").name=="Охотник" and S.PatchInfo("ach_hunter").goal==50 and S.PatchInfo("award_medic").name=="Медик отряда","достижения и награды")
check(S.PatchInfo("rank_9")==nil and S.PatchInfo("faction_nope")==nil and S.PatchInfo("ach_x")==nil and S.PatchInfo("bad")==nil,"неизвестные нашивки отклоняются")
check(S.ValidToken("faction") and S.ValidToken("rank") and S.ValidToken("ach_cook") and S.ValidToken("award_scout") and not S.ValidToken("faction_duty") and not S.ValidToken("x"),"жетоны выбора нашивок")
for id in pairs(S.AchievementByID) do check(file.Exists("materials/stalker_social/patches/ach_"..id..".png","GAME"),"иконка достижения "..id) end
for id in pairs(S.AwardByID) do check(file.Exists("materials/stalker_social/patches/award_"..id..".png","GAME"),"иконка награды "..id) end
for n=1,5 do check(file.Exists("materials/stalker_social/patches/rank_"..n..".png","GAME"),"иконка звания "..n) end

local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end
local function fakeCmd(keys,forward)
 local c={keys=keys or {},fwd=forward or 0,removed={}}
 function c:KeyDown(k) return self.keys[k]==true end
 function c:RemoveKey(k) self.keys[k]=nil;self.removed[#self.removed+1]=k end
 function c:GetForwardMove() return self.fwd end
 function c:GetSideMove() return 0 end
 function c:ClearButtons() self.keys={} end
 function c:ClearMovement() self.fwd=0 end
 function c:SetImpulse() end
 return c
end

if SERVER then
 local players={}
 local function join(nick,x,y,extra)
  local o=extra or {};o.nick=nick;o.pos=Vector(X+x,y or 0,0);o.aim=o.aim or Vector(X+x+100,y or 0,0)
  local p=TEST.join(o);p.StfwProtected=0;players[#players+1]=p;return p
 end
 -- Действие меню от игрока (сбрасываем ведро частоты: сценарий шлёт запросы быстрее человека).
 local function act(p,tbl)
  if p.StalkerRate then p.StalkerRate["social.act"]=nil end
  local len,vals=packet(tbl);M.netReceive("stalker_social.act",len,p,vals)
 end
 local function notice(p) local d=decode(lastSent("stalker_core.notify",p));return d and d.text or "" end
 local a=join("Сталкер Альфа",0,0)
 local b=join("Сталкер Бета",60,0)
 local c=join("Сталкер Гамма",1000,0)
 local admin=join("Админ знакомств",0,400,{superadmin=true})
 local bid,cid=b:EntIndex(),c:EntIndex()

 section("Знакомства: имена")
 check(not S.Knows(a,b) and not S.Knows(b,a),"незнакомцы не знают имён друг друга")
 check(S.DisplayName(a,b)=="Незнакомец" and S.Label(a,b)=="Незнакомец","DisplayName — «Незнакомец»")
 check(S.Knows(a,a) and S.Knows(admin,a) and S.DisplayName(admin,a)=="Сталкер Альфа","себя и администратор видят настоящие имена")
 SET.Set("social.admins_see_all",false)
 check(not S.Knows(admin,a),"настройка «Администраторы видят имена» выключается")
 SET.Set("social.admins_see_all",nil)
 SET.Set("social.hide_names",false)
 check(S.Knows(a,b) and S.DisplayName(a,b)=="Сталкер Бета","скрытие имён выключено — имена видны всем")
 SET.Set("social.hide_names",nil)
 SET.Set("social.stranger_name","Неизвестный")
 check(S.DisplayName(a,b)=="Неизвестный","подпись незнакомца из настроек")
 SET.Set("social.stranger_name",nil)
 check(S.Config.HideNames==true and S.Config.StrangerName=="Незнакомец","настройки сброшены")

 section("Знакомства: представиться")
 M.netSent={}
 act(a,{op="intro",t=bid})
 check(S.Knows(b,a) and not S.Knows(a,b),"цель узнала имя, представившийся — ещё нет")
 check(S.DisplayName(b,a)=="Сталкер Альфа","DisplayName после знакомства — настоящее имя")
 local req=decode(lastSent("stalker_social.request",b))
 check(req and req.kind=="intro" and req.ent==a:EntIndex() and req.name=="Сталкер Альфа","цели предложено представиться в ответ")
 local known=decode(lastSent("stalker_social.known",b))
 check(known and #known.list==1 and known.list[1].sid==a:SteamID64() and known.list[1].name=="Сталкер Альфа","список знакомых отправлен цели")
 check(notice(b):find("Сталкер Альфа представился",1,true) and notice(a):find("Вы представились",1,true),"уведомления обоим")
 local row=sql.Query("SELECT name,contact FROM stalker_social_known WHERE sid="..sql.SQLStr(b:SteamID64()).." AND target="..sql.SQLStr(a:SteamID64()))
 check(row and row[1] and row[1].name=="Сталкер Альфа" and row[1].contact=="0","знакомство сохранено в SQLite stalker_social_known")
 local waved=false;for _,g in ipairs(M.gestures) do if g.ply==a and g.act==ACT_GMOD_GESTURE_WAVE then waved=true end end
 check(waved and lastSent("stalker_social.gesture"),"при знакомстве — жест «помахать» всем рядом")
 act(a,{op="intro",t=bid})
 check(notice(a):find("уже знает",1,true),"повторное знакомство отклонено")
 act(a,{op="intro",t=cid})
 check(not S.Knows(c,a) and notice(a):find("Подойдите ближе",1,true),"дальше дистанции — отказ")
 act(a,{op="intro",t=a:EntIndex()})
 check(notice(a):find("не найден",1,true),"представиться себе нельзя")
 act(b,{op="intro",t=a:EntIndex()})
 check(S.Knows(a,b) and not (b.StsocOffers and b.StsocOffers[a] and b.StsocOffers[a].intro),"ответное знакомство: оба знают имена, предложение снято")
 -- Кэш сбрасывается — данные читаются из базы.
 S.KnownCache[b:SteamID64()]=nil
 check(S.Knows(b,a),"знакомство читается из SQLite после сброса кэша")
 local dead=join("Погибший",90,0);M.kill(dead)
 act(a,{op="intro",t=dead:EntIndex()})
 check(not S.Knows(dead,a) and notice(a):find("мёртв",1,true),"мёртвому не представиться")
 M.spawn(dead)

 section("Знакомства: контакты")
 act(a,{op="contact",t=bid})
 check(S.LoadKnown(a)[b:SteamID64()].contact==true and notice(a):find("контакты",1,true),"знакомый добавлен в контакты КПК")
 c:SetPos(Vector(X+30,40,0))
 act(a,{op="contact",t=cid})
 check(not S.KnowsRaw(a,c) and notice(a):find("Сначала познакомьтесь",1,true),"незнакомца в контакты не добавить")
 act(a,{op="uncontact",sid=b:SteamID64()})
 check(S.LoadKnown(a)[b:SteamID64()].contact==false and S.Knows(a,b),"контакт удалён, знакомство осталось")
 act(a,{op="uncontact",sid="bad sid"})
 check(S.LoadKnown(a)[b:SteamID64()]~=nil,"некорректный SID игнорируется")
 act(a,{op="contact",t=bid})
 local cl=decode(lastSent("stalker_social.known",a))
 check(cl and cl.list[1] and cl.list[1].contact==true,"клиент получает отметку контакта")

 section("Взаимодействие: рукопожатие")
 M.gestures={}
 act(a,{op="shake",t=bid})
 check(b.StsocOffers and b.StsocOffers[a] and b.StsocOffers[a].shake and #M.gestures==0,"рука протянута, ждём ответа")
 req=decode(lastSent("stalker_social.request",b))
 check(req and req.kind=="shake" and req.name=="Сталкер Альфа" and req.seconds==30,"цели пришло предложение (знакомый — по имени)")
 b:SetPos(Vector(X+200,0,0))
 act(b,{op="shake",t=a:EntIndex()})
 local both={};for _,g in ipairs(M.gestures) do if g.act==ACT_GMOD_GESTURE_ITEM_GIVE then both[g.ply]=true end end
 check(both[a] and both[b] and not b.StsocOffers[a].shake,"ответ на рукопожатие (в пределах дистанции ответа): жесты обоим")
 b:SetPos(Vector(X+60,0,0))
 act(a,{op="shake",t=bid});M.advance(31)
 M.gestures={}
 act(b,{op="shake",t=a:EntIndex()})
 check(#M.gestures==0 and a.StsocOffers and a.StsocOffers[b] and a.StsocOffers[b].shake,"просроченное предложение — ответ становится новым предложением")
 a.StsocOffers[b]=nil

 section("Взаимодействие: деньги")
 a._money=1000;local bm=b._money
 act(a,{op="money",t=bid,amount=300})
 check(a._money==700 and b._money==bm+300,"перевод 300 ₽")
 check(notice(b):find("Получено от Сталкер Альфа",1,true),"получатель уведомлён")
 act(a,{op="money",t=bid,amount=5000})
 check(a._money==700 and notice(a):find("Недостаточно",1,true),"нехватка денег — отказ")
 for _,bad in ipairs({-5,0,1.5,"100",200000}) do act(a,{op="money",t=bid,amount=bad}) end
 check(a._money==700 and b._money==bm+300,"некорректные суммы отклонены")
 SET.Set("social.max_transfer",0)
 act(a,{op="money",t=bid,amount=10})
 check(a._money==700 and notice(a):find("отключены",1,true),"переводы выключаются настройкой")
 SET.Set("social.max_transfer",nil)
 act(a,{op="money",t=c:EntIndex(),amount=10})
 c:SetPos(Vector(X+1000,0,0))
 act(a,{op="money",t=cid,amount=10})
 check(notice(a):find("Подойдите ближе",1,true),"перевод дальнему — отказ")

 section("Взаимодействие: предмет")
 a.StalkerInventory.grid={};b.StalkerInventory.grid={}
 SI.GiveItem(a,"scrap",5)
 local uid;for _,it in pairs(a.StalkerInventory.grid) do if it.id=="scrap" then uid=it.uid end end
 act(a,{op="item",t=bid,uid=uid,count=2})
 check(SI.CountItem(a,"scrap")==3 and SI.CountItem(b,"scrap")==2,"предмет передан через STALKER_INV.GiveFromTo")
 act(a,{op="item",t=bid,uid="нет такого",count=1})
 check(SI.CountItem(a,"scrap")==3 and notice(a)~="","несуществующий UID — отказ")
 act(a,{op="item",t=bid,uid=uid,count=99})
 check(SI.CountItem(a,"scrap")==3,"количество больше стака — отказ")

 section("Жесты и позы")
 M.gestures={};M.netSent={}
 check(S.Gesture(a,"salute") and M.gestures[1] and M.gestures[1].act==ACT_GMOD_TAUNT_SALUTE and M.gestures[1].slot==GESTURE_SLOT_CUSTOM,"S.Gesture(ply, id) — AnimRestartGesture(GESTURE_SLOT_CUSTOM)")
 local g=lastSent("stalker_social.gesture")
 check(g and g.data[1]==a and g.data[2]==ACT_GMOD_TAUNT_SALUTE,"жест разослан клиентам рядом")
 check(S.Gesture(a,ACT_GMOD_GESTURE_BOW) and not S.Gesture(a,"nope") and not S.Gesture(a,-1) and not S.Gesture(NULL,"wave"),"S.Gesture(ply, ACT) и проверки")
 local len,vals=packet({id="wave"});a.StsocEmoteAt=0;M.netReceive("stalker_social.emote",len,a,vals)
 check(M.gestures[#M.gestures].act==ACT_GMOD_GESTURE_WAVE,"жест из меню эмоций")
 local n=#M.gestures;a.StalkerRate=nil
 len,vals=packet({id="wave"});M.netReceive("stalker_social.emote",len,a,vals)
 check(#M.gestures==n,"пауза между жестами")
 check(hook.Run("PlayerSay",a,"!emote")=="" and tostring(a._concommands):find("stsoc_emotes",1,true),"!emote открывает меню эмоций")
 a.StsocEmoteAt=0
 check(hook.Run("PlayerSay",a,"!emote sit")=="" and S.GetPose(a)=="sit","!emote sit — поза «сидеть»")
 local ideal,seq=hook.Run("CalcMainActivity",a,Vector(0,0,0))
 check(ideal==ACT_MP_STAND_IDLE and seq==1,"CalcMainActivity: последовательность позы")
 check(hook.Run("UpdateAnimation",a,Vector(5,0,0),0)==true and a._playbackRate==1,"UpdateAnimation: поза проигрывается с обычной скоростью")
 local cmd=fakeCmd({},200);hook.Run("StartCommand",a,cmd)
 check(S.GetPose(a)=="","движение снимает позу")
 a.LookupBone=M.socialLookupBone
 a.StsocEmoteAt=0;check(S.Emote(a,"crossarms") and S.GetPose(a)=="crossarms","поза «скрестить руки»")
 local bone=a:LookupBone("ValveBiped.Bip01_R_UpperArm")
 check(a._boneAng and a._boneAng[bone] and a._boneAng[bone].p==20,"повороты костей позы")
 check(hook.Run("CalcMainActivity",a,Vector(0,0,0))==nil,"поза костями не меняет последовательность")
 cmd=fakeCmd({[IN_ATTACK]=true});hook.Run("StartCommand",a,cmd)
 check(not cmd.keys[IN_ATTACK] and #cmd.removed==2 and S.GetPose(a)=="","в позе нельзя стрелять: атака снята, поза снята")
 check(a._boneAng[bone].p==0,"кости вернулись в исходное положение")
 a.StsocEmoteAt=0;S.Emote(a,"kneel")
 local d=DamageInfo();d:SetDamage(5);d:SetDamageType(DMG_CLUB);a:TakeDamageInfo(d)
 check(S.GetPose(a)=="","урон снимает позу")
 a.StsocEmoteAt=0;S.Emote(a,"sit");M.kill(a)
 check(S.GetPose(a)=="","смерть снимает позу");M.spawn(a)
 a._air=true;a.StsocEmoteAt=0
 local ok,err=S.Emote(a,"sit")
 check(not ok and err=="Встаньте на землю","в воздухе поза недоступна");a._air=nil
 a.StsocEmoteAt=0;S.Emote(a,"sit");a.StsocEmoteAt=0;S.Emote(a,"sit")
 check(S.GetPose(a)=="","повтор позы — встать");S.Emote(a,"stand")

 section("Взаимодействие: обыск")
 M.netSent={}
 act(a,{op="search",t=bid})
 check(not lastSent("stalker_social.search") and notice(a):find("поднятыми руками",1,true),"без поднятых рук обыск запрещён")
 b.StsocEmoteAt=0;check(S.Emote(b,"surrender") and S.GetPose(b)=="surrender","цель подняла руки")
 act(a,{op="search",t=bid})
 local res=decode(lastSent("stalker_social.search",a))
 check(res and res.ent==bid and res.name=="Сталкер Бета" and #res.items==1 and res.items[1].id=="scrap" and res.items[1].count==2,"обыск: список предметов рюкзака цели")
 check(SI.CountItem(b,"scrap")==2 and notice(b):find("Вас обыскивает",1,true),"обыск только просмотр, цель уведомлена")
 S.ClearPose(b,"test")

 section("Нашивки")
 check(S.RankOf(a)==1,"звание по опыту STFW")
 S.RefreshPatches(a)
 check(a:GetNW2String("stsoc_patches","")=="rank_1","без группировки видно звание")
 C.AddStat(a,"mutants",50);S.RefreshPatches(a)
 check(a:GetNW2String("stsoc_patches","")=="rank_1,ach_hunter","достижение «Охотник» за 50 мутантов")
 check(F.SetFaction(a,"scientists",true) and F.SetFaction(b,"scientists",true),"оба в «Учёных»")
 M.advance(1)
 check(a:GetNW2String("stsoc_patches","")=="faction_scientists,rank_1,ach_hunter","нашивка группировки после вступления")
 check(S.VisibleFaction(a)=="scientists" and S.Label(c,a)=="Незнакомец · Учёные","незнакомец видит нашивку группировки")
 SET.Set("social.max_patches",2);S.RefreshPatches(a)
 check(#S.VisiblePatches(a)==2,"максимум видимых нашивок из настроек")
 SET.Set("social.max_patches",nil)
 M.netSent={}
 act(a,{op="visible",ids={"ach_hunter","rank"}})
 check(a:GetNW2String("stsoc_patches","")=="ach_hunter,rank_1","выбор видимых нашивок")
 local st=decode(lastSent("stalker_social.patches",a))
 check(st and st.chosen and st.visible[1]=="ach_hunter" and st.max==3 and #st.items==2+#S.Awards+#S.Achievements,"состояние нашивок для КПК")
 local prog;for _,it in ipairs(st.items) do if it.token=="ach_seeker" then prog=it end end
 check(prog and prog.owned==false and prog.value==0 and prog.goal==10,"прогресс достижения")
 act(a,{op="visible",ids={"ach_seeker"}})
 check(a:GetNW2String("stsoc_patches","")=="ach_hunter,rank_1" and notice(a):find("нет",1,true),"чужую нашивку не показать")
 act(a,{op="visible",ids={"faction","rank","ach_hunter","award_medic"}})
 check(a:GetNW2String("stsoc_patches","")=="ach_hunter,rank_1","больше максимума — отказ")
 act(a,{op="visible",ids={}})
 check(a:GetNW2String("stsoc_patches","")=="","можно ничего не показывать")
 S.DataCache[a:SteamID64()]=nil
 check(S.LoadData(a).chosen and #S.LoadData(a).visible==0,"выбор сохранён в SQLite stalker_social_patches")
 act(a,{op="visible",ids={"faction","rank"}})

 section("Нашивки: награды лидера и приглашение")
 check(F.Editor(admin,{op="leader",faction="scientists",sid=a:SteamID64()}) and F.IsLeader(a),"Альфа — лидер «Учёных»")
 act(a,{op="award",t=bid,award="medic"})
 check(S.LoadData(b).awards.medic and S.LoadData(b).awards.medic.by=="Сталкер Альфа","награда «Медик отряда» выдана")
 check(b:GetNW2String("stsoc_patches",""):find("award_medic",1,true) and notice(b):find("наградил",1,true),"награда на рукаве, награждённый уведомлён")
 act(b,{op="award",t=a:EntIndex(),award="scout"})
 check(not S.LoadData(a).awards.scout and notice(b):find("только лидер",1,true),"не лидер награждать не может")
 act(a,{op="award",t=bid,award="nope"})
 check(notice(a):find("Неизвестная награда",1,true),"неизвестная награда")
 c:SetPos(Vector(X+30,40,0))
 act(a,{op="award",t=cid,award="medic"})
 check(not S.LoadData(c).awards.medic and notice(a):find("не состоит",1,true),"награда только своим")
 act(a,{op="invite",t=cid})
 check(F.Invites[c:SteamID64()] and F.Invites[c:SteamID64()].faction=="scientists" and notice(a):find("Приглашение отправлено",1,true),"приглашение в группировку через STFW.Invite")
 act(b,{op="invite",t=cid})
 check(notice(b)~="" and not notice(b):find("Приглашение отправлено",1,true),"рядовой не приглашает (ответ STFW)")
 act(a,{op="award",t=bid,award="medic"})
 check(not S.LoadData(b).awards.medic and not b:GetNW2String("stsoc_patches",""):find("award_medic",1,true),"повторное нажатие снимает награду")
 act(a,{op="award",t=bid,award="assault"})
 F.Expel(b);M.advance(1)
 local owned=false;for _,it in ipairs(S.Collect(b)) do if it.token=="award_assault" then owned=it.owned end end
 check(not owned and not b:GetNW2String("stsoc_patches",""):find("award_assault",1,true),"награда не действует вне группировки")

 section("Знакомства: забыть и вход")
 act(a,{op="forget",sid=b:SteamID64()})
 check(not S.Knows(a,b) and not sql.Query("SELECT 1 FROM stalker_social_known WHERE sid="..sql.SQLStr(a:SteamID64()).." AND target="..sql.SQLStr(b:SteamID64())),"знакомство забыто (и в SQLite)")
 a._nick="Альфа Новая";hook.GetTable().PlayerInitialSpawn["STALKER_SOCIAL.Store"](a)
 local r=sql.Query("SELECT name FROM stalker_social_known WHERE sid="..sql.SQLStr(b:SteamID64()).." AND target="..sql.SQLStr(a:SteamID64()))
 a._nick="Сталкер Альфа"
 check(r and r[1] and r[1].name=="Альфа Новая" and S.LoadKnown(b)[a:SteamID64()].name=="Альфа Новая","при входе имя обновляется в чужих списках")
 check(S.ResolveTarget(a,99999)==nil,"цель по несуществующему индексу")
 M.netSent={}
 M.netReceive("stalker_social.act",16+8*4,a,{4,"Z:{}"})
 M.netReceive("stalker_social.act",8,a,{60000,""})
 check(true,"битые пакеты не роняют сервер")

 section("Знакомства: очистка")
 for _,p in ipairs({a,b,c}) do if F.Load(p) and F.Load(p).joined then F.Expel(p) end end
 for _,p in ipairs(players) do S.ClearPose(p,"cleanup");M.removePlayer(p) end
else
 section("Знакомства: клиент")
 local me=LocalPlayer();local oldPos=me:GetPos();me:SetPos(Vector(X,0,0))
 local stranger=M.addPlayer({nick="Чужак",pos=Vector(X+60,0,0)})
 local friend=M.addPlayer({nick="Друг",pos=Vector(X+40,30,0)})
 local meta=FindMetaTable("Player")
 for _,p in ipairs({stranger,friend}) do for _,k in ipairs({"Nick","Name","GetName"}) do p[k]=function(self,...) return meta[k](self,...) end end end
 check(not S.Knows(me,stranger),"до списка с сервера все чужие — незнакомцы")
 local l,v=packet({list={{sid=friend:SteamID64(),name="Друг",at=os.time(),contact=true}}})
 M.protect("список знакомых",M.netReceive,"stalker_social.known",l,nil,v)
 check(S.Knows(me,friend) and S.Knows(nil,friend) and not S.Knows(me,stranger),"клиент знает свой список")
 check(S.DisplayName(me,friend)=="Друг" and S.DisplayName(me,stranger)=="Незнакомец","DisplayName на клиенте")
 check(S.Knows(friend,stranger),"для чужого зрителя клиент имя не скрывает")
 stranger:SetNW2String("stsoc_patches","faction_duty,rank_2,ach_hunter")
 check(S.VisibleFaction(stranger)=="duty" and S.Label(me,stranger)=="Незнакомец · Долг" and #S.VisiblePatches(stranger)==3,"видимая нашивка группировки у незнакомца")

 section("Знакомства: имя над головой и в чате")
 local drawn
 meta.drawPlayerInfo=function(self) drawn=self:Nick() end
 meta.drawWantedInfo=function(self) drawn="wanted:"..self:Nick() end
 S.InstallNameHooks();S.InstallNameHooks()
 stranger:drawPlayerInfo()
 check(drawn=="Незнакомец · Долг" and stranger:Nick()=="Чужак","drawPlayerInfo DarkRP: имя незнакомца подменено только на время отрисовки")
 friend:drawPlayerInfo();check(drawn=="Друг","знакомый — настоящее имя")
 stranger:drawWantedInfo();check(drawn=="wanted:Незнакомец · Долг","drawWantedInfo тоже скрывает имя")
 meta.drawPlayerInfo=function() error("сбой отрисовки") end;S.InstallNameHooks()
 local before=#M.warnings;stranger:drawPlayerInfo()
 check(stranger:Nick()=="Чужак" and #M.warnings==before+1,"ошибка в отрисовке не ломает Nick()")
 table.remove(M.warnings)
 meta.drawPlayerInfo=nil;meta.drawWantedInfo=nil
 local said={};local oldAdd=chat.AddNonParsedText
 chat.AddNonParsedText=function(...) said[#said+1]=table.concat((function(t) local o={};for _,x in ipairs(t) do if type(x)=="string" then o[#o+1]=x end end;return o end)({...})) end
 DarkRP.getPhrase=function(k) return ({whisper="Шёпот",yell="Крик",ooc="OOC"})[k] or k end
 local col=Color(255,255,255)
 check(hook.Run("OnPlayerChat",stranger,"привет",false,false,"Чужак",col,col)==true and said[1]=="Незнакомец · Долг: привет","локальный чат: имя незнакомца скрыто")
 check(hook.Run("OnPlayerChat",stranger,"тише",false,false,"(Шёпот) Чужак",col,col)==true and said[2]=="(Шёпот) Незнакомец · Долг: тише","шёпот тоже")
 check(hook.Run("OnPlayerChat",stranger,"всем",false,false,"(OOC) Чужак",col,col)==nil and #said==2,"OOC не трогаем")
 check(hook.Run("OnPlayerChat",stranger,"лс",false,false,"(PM) Чужак",col,col)==nil,"личные сообщения не трогаем")
 check(hook.Run("OnPlayerChat",friend,"здорово",false,false,"Друг",col,col)==nil,"знакомого не трогаем")
 check(hook.Run("ChatText","0","Чужак машет рукой","Чужак машет рукой","darkrp")==true and said[3]=="Незнакомец · Долг машет рукой","/me: имя незнакомца скрыто")
 check(hook.Run("ChatText","0","Игрок вошёл","Игрок вошёл","joinleave")==nil,"системные сообщения не трогаем")
 chat.AddNonParsedText=oldAdd;DarkRP.getPhrase=nil

 section("Взаимодействие: клиент")
 local created={};local orig=vgui.Create
 vgui.Create=function(name,parent) local p=orig(name,parent);created[#created+1]=p;return p end
 l,v=packet({kind="shake",ent=stranger:EntIndex(),name="Незнакомец",seconds=30})
 M.protect("предложение рукопожатия",M.netReceive,"stalker_social.request",l,nil,v)
 check(S.OfferFrom(stranger,"shake") and #S.ActiveOffers()==1,"входящее предложение")
 check(C.PDATabs.contacts and C.PDATabs.contacts.title=="Контакты" and C.PDATabs.contacts.badge()==1 and C.PDATabs.patches and C.PDATabs.patches.title=="Нашивки","вкладки КПК «Контакты» (со значком) и «Нашивки»")
 M.protect("подсказка предложений",hook.Run,"HUDPaint")
 me._aimEntity=stranger
 check(S.AimedPlayer()==stranger,"цель взгляда в пределах дистанции")
 local f
 M.protect("меню взаимодействия",function() f=S.OpenInteract(stranger) end)
 check(f and f.Target==stranger and #f.Buttons>=7,"меню взаимодействия открыто: "..tostring(f and #f.Buttons))
 local byID={};for _,b in ipairs(f and f.Buttons or {}) do if b.ActionID then byID[b.ActionID]=b end;M.protect("кнопка меню",b.Think,b) end
 check(byID.shake and byID.shake.Label=="Ответить на рукопожатие" and byID.shake.Kind=="accent","ответ на рукопожатие подсвечен")
 check(byID.money and byID.item and byID.patches and byID.contact and byID.search and not byID.award,"кнопки по состоянию (не лидер — без наград)")
 M.netSent={}
 M.protect("представиться",byID.intro.DoClick,byID.intro)
 local sent=lastSent("stalker_social.act")
 check(sent and tostring(sent.data[2]):find('"intro"',1,true),"«Представиться» отправляет запрос серверу")
 M.protect("рукопожатие",byID.shake.DoClick,byID.shake)
 check(not S.OfferFrom(stranger,"shake") and tostring(lastSent("stalker_social.act").data[2]):find('"shake"',1,true),"ответ на рукопожатие")
 for _,page in ipairs({"card","money","item","patches","award"}) do M.protect("страница "..page,S.MenuPages[page],M.stub("body"),stranger) end
 M.protect("страница обыска",S.MenuPages.search,M.stub("body"),{name="Незнакомец",items={{id="medkit",count=2,durability=40}},weight=3})
 M.protect("кадр меню",f.Think,f)
 stranger:SetPos(Vector(X+900,0,0));M.protect("цель ушла",f.Think,f);stranger:SetPos(Vector(X+60,0,0))
 l,v=packet({ent=stranger:EntIndex(),name="Незнакомец",items={{id="medkit",count=1,durability=100}}})
 M.protect("результат обыска",M.netReceive,"stalker_social.search",l,nil,v)
 check(S.SearchWindow~=nil,"окно обыска")
 M.protect("клавиша G",S.InteractKey)
 me._aimEntity=nil

 section("Эмоции и позы: клиент")
 local menu;M.protect("меню эмоций",function() menu=S.OpenEmotes() end)
 check(menu and S.EmoteMenu==menu,"меню эмоций")
 local wave;for _,p in ipairs(created) do if rawget(p,"EmoteID")=="wave" then wave=p end end
 M.netSent={}
 if wave then M.protect("кнопка жеста",wave.DoClick,wave) end
 check(wave and tostring(lastSent("stalker_social.emote").data[2]):find('"wave"',1,true),"жест отправлен серверу")
 M.gestures={}
 M.protect("жест с сервера",M.netReceive,"stalker_social.gesture",32,nil,{stranger,ACT_GMOD_GESTURE_WAVE})
 check(M.gestures[1] and M.gestures[1].ply==stranger and M.gestures[1].act==ACT_GMOD_GESTURE_WAVE,"клиент проигрывает жест AnimRestartGesture")
 me:SetNW2String("stsoc_pose","sit")
 local ideal,seq=hook.Run("CalcMainActivity",me,Vector(0,0,0))
 check(ideal==ACT_MP_STAND_IDLE and seq==1,"поза на клиенте: CalcMainActivity")
 M.netSent={}
 local cmd=fakeCmd({[IN_ATTACK]=true});M.protect("предсказание",hook.Run,"StartCommand",me,cmd)
 check(not cmd.keys[IN_ATTACK] and tostring((lastSent("stalker_social.emote") or {data={}}).data[2]):find('"stand"',1,true),"клиент снимает выстрел и просит встать")
 me:SetNW2String("stsoc_pose","")
 M.protect("клавиши",hook.Run,"Think")

 section("Нашивки и КПК: клиент")
 stranger.LookupBone=M.socialLookupBone
 local pos,ang=S.ShoulderFrame(stranger)
 check(pos and ang and math.abs(pos.y-(8+2.9))<.5,"плоскость нашивки на левом плече")
 local oldEye=EyePos;EyePos=function() return stranger:GetPos()+Vector(100,0,64) end
 M.protect("нашивки на плече",hook.Run,"PostPlayerDraw",stranger)
 EyePos=oldEye
 M.protect("значок нашивки",S.DrawPatch,"award_medic",0,0,48,255,true)
 M.protect("вкладка «Контакты»",C.PDATabs.contacts.build,M.stub("pda"))
 local rows=S.KnownRows(true);check(#rows==1 and rows[1].name=="Друг" and rows[1].online,"контакты: в сети")
 l,v=packet({items={{token="faction",id="faction_duty",owned=true},{token="rank",owned=false},{token="ach_hunter",id="ach_hunter",owned=false,value=12,goal=50},
  {token="award_medic",id="award_medic",owned=true,by="Командир",faction="duty"}},visible={"faction"},chosen=true,max=3})
 M.protect("состояние нашивок",M.netReceive,"stalker_social.patches",l,nil,v)
 check(S.PatchState and #S.PatchState.items==4,"состояние нашивок принято")
 check(S.PatchHint(S.PatchState.items[3],false)=="12 / 50" and S.PatchHint(S.PatchState.items[1],true)=="На рукаве" and S.PatchHint(S.PatchState.items[4],false)=="Выдал: Командир","подсказки нашивок")
 M.protect("вкладка «Нашивки»",C.PDATabs.patches.build,M.stub("pda"))
 M.netSent={}
 S.ToggleVisible("award_medic")
 local vis=decode(lastSent("stalker_social.act"))
 check(vis and vis.op=="visible" and vis.ids[1]=="faction" and vis.ids[2]=="award_medic","переключение видимой нашивки")
 S.ToggleVisible("faction");vis=decode(lastSent("stalker_social.act"))
 check(vis and #vis.ids==0,"снять нашивку")
 vgui.Create=orig
 local painted=0
 for _,p in ipairs(created) do
  local paint=rawget(p,"Paint");if type(paint)=="function" then painted=painted+1;M.protect("отрисовка панели знакомств",paint,p,600,60) end
  local think=rawget(p,"Think");if type(think)=="function" and p~=f then M.protect("кадр панели",think,p) end
 end
 check(painted>20,"панели знакомств отрисованы: "..painted)
 S.Offers={};S.PatchState=nil;S.MyKnown={}
 M.removePlayer(stranger);M.removePlayer(friend);me:SetPos(oldPos)
end
