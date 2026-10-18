-- STALKER PDA: окно КПК (F4, !кпк, stalker_pda), вкладки и их порядок, сводка, карта со своей меткой, новости, статистика,
-- энциклопедия, справочник, личные сообщения (в сети и офлайн, лимиты, прочтение, удаление, служебные), работа без соседних аддонов.
-- Область мира: X 3 500 000…3 900 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local P,C,S,MK=STALKER_PDA,STALKER_CORE,STALKER_SETTINGS,STALKER_MARKERS
local X=3500000
section("КПК: загрузка ("..M.Realm..")")
check(P and P.Config and P.Config.MessageLength==300 and P.Config.MessageInterval==2,"STALKER_PDA загружен, лимиты по умолчанию")
for _,id in ipairs({"pda.message_length","pda.message_days","pda.message_interval","pda.unread_limit","pda.history_limit","pda.message_toast",
 "pda.f4","pda.emission_forecast","pda.waypoint_reach","pda.rules_link"}) do
 check(S.Defs[id] and S.Defs[id].category=="КПК","настройка "..id)
end
check(S.Defs["pda.message_length"].realm=="shared" and S.Defs["pda.message_interval"].realm=="shared","длина и частота известны клиенту")
check(P.CleanText("  привет\nмир  ")=="привет мир","управляющие символы и края убираются")
check(P.CleanText(string.rep("я",300))~=nil and P.CleanText(string.rep("я",301))==nil,"лимит 300 символов (UTF-8, не байты)")
check(P.CleanText("   ")==nil and P.CleanText(nil)==nil,"пустое сообщение отклоняется")
check(P.Lower("ВЫБРОС Ёж Zone")=="выброс ёж zone","нижний регистр с кириллицей")
check(P.ValidSID("76561198000000001") and not P.ValidSID("sys.x") and P.IsSystem("sys.sidor") and not P.IsSystem("76561198000000001"),"проверка адресатов")

local function lastTo(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end

if SERVER then
 local function req(ply,tbl) local l,v=packet(tbl);M.netReceive("stalker_pda.req",l,ply,v) end
 local function count(where) return tonumber(sql.QueryValue("SELECT COUNT(*) FROM stalker_pda_messages WHERE "..where)) or 0 end
 section("КПК: сообщения в сети")
 check(sql.TableExists("stalker_pda_messages"),"таблица stalker_pda_messages")
 local a=TEST.join({nick="Связной",pos=Vector(X,0,0)})
 local b=TEST.join({nick="Адресат",pos=Vector(X+500,0,0)})
 local sa,sb=a:SteamID64(),b:SteamID64()
 M.advance(3);M.netSent={}
 local ok,msg=P.SendMessage(a,sb,"Привет, есть хабар?")
 check(ok and type(msg)=="table" and msg.id and msg.text=="Привет, есть хабар?","сообщение отправлено")
 local got=decode(lastTo("stalker_pda.data",b))
 check(got and got.kind=="msg" and got.msg.from==sa and got.name=="Связной" and got.unread==1,"получатель в сети получил сообщение сразу")
 local okFast,errFast=P.SendMessage(a,sb,"Ещё одно")
 check(not okFast and tostring(errFast):find("Подождите",1,true),"пауза между сообщениями: "..tostring(errFast))
 M.advance(2.1)
 check(P.SendMessage(a,sb,"Ещё одно"),"после паузы сообщение уходит")
 M.advance(2.1)
 local okLong,errLong=P.SendMessage(a,sb,string.rep("я",301))
 check(not okLong and errLong=="Слишком длинное сообщение","длинное сообщение отклонено")
 check(P.SendMessage(a,sb,string.rep("я",300)),"сообщение ровно в 300 символов")
 M.advance(2.1)
 check(not P.SendMessage(a,sa,"сам себе"),"нельзя написать себе")
 check(not P.SendMessage(a,"76561198099999999","кому-то"),"неизвестный офлайн-адресат отклонён")
 check(not P.SendMessage(a,"abc","x") and not P.SendMessage(a,{},"x"),"неверный SteamID отклонён")
 check(not P.SendMessage(a,"sys.sidor","x"),"служебному отправителю ответить нельзя")
 check(not P.SendMessage(a,sb,"   "),"пустое сообщение не отправляется")
 check(P.UnreadCount(sb)==3,"непрочитанных у адресата: "..P.UnreadCount(sb))

 M.netSent={}
 req(b,{op="inbox"})
 local inbox=decode(lastTo("stalker_pda.data",b))
 local conv=inbox and inbox.list and inbox.list[1]
 check(inbox and inbox.kind=="inbox" and inbox.unread==3,"список переписок: непрочитанных 3")
 check(conv and conv.sid==sa and conv.unread==3 and conv.online==true and conv.name=="Связной","переписка со Связным в сети")
 M.netSent={}
 req(b,{op="thread",sid=sa})
 local th=decode(lastTo("stalker_pda.data",b))
 check(th and th.kind=="thread" and #th.messages==3 and th.messages[1].text=="Привет, есть хабар?" and th.messages[1].mine==false and th.unread==0,
  "переписка загружена по порядку, входящие прочитаны")
 local seen=decode(lastTo("stalker_pda.data",a))
 check(seen and seen.kind=="seen" and seen.sid==sb,"отправитель видит отметку «прочитано»")
 check(P.UnreadCount(sb)==0,"непрочитанных не осталось")
 M.netSent={}
 req(b,{op="send",to=sa,text="Есть. Встречаемся у бара."})
 local res=decode(lastTo("stalker_pda.data",b))
 check(res and res.kind=="result" and res.ok==true and res.msg and res.msg.to==sa and res.next==2,"ответ через сеть принят")
 local back=decode(lastTo("stalker_pda.data",a))
 check(back and back.kind=="msg" and back.msg.text=="Есть. Встречаемся у бара.","ответ доставлен собеседнику")
 req(b,{op="send",to=sa,text="И ещё"})
 res=decode(lastTo("stalker_pda.data",b))
 check(res and res.ok==false and tostring(res.error):find("Подождите",1,true),"частота отправки проверяется и по сети")
 local thA=P.Thread(a,sb)
 check(#thA==4 and thA[1].mine==true and thA[1].seen==true and thA[4].mine==false,"переписка глазами отправителя")

 section("КПК: офлайн-доставка")
 hook.Run("PlayerDisconnected",b);M.removePlayer(b)
 M.advance(2.1)
 check(P.SendMessage(a,sb,"Ты где? Напиши, как вернёшься."),"офлайн-адресату можно написать (был в сети)")
 check(P.UnreadCount(sb)==1,"сообщение ждёт адресата в базе")
 M.netSent={}
 local b2=TEST.join({nick="Адресат",pos=Vector(X+500,0,0),sid=sb})
 M.advance(3)
 local note=decode(lastTo("stalker_core.notify",b2))
 check(note and tostring(note.text):find("Непрочитанных сообщений в КПК: 1",1,true),"уведомление о непрочитанных при входе")
 local un=decode(lastTo("stalker_pda.data",b2))
 check(un and un.kind=="unread" and un.n==1,"значок непрочитанных после входа")
 local list=P.Inbox(b2)
 check(list[1] and list[1].sid==sa and list[1].unread==1 and list[1].last=="Ты где? Напиши, как вернёшься.","офлайн-сообщение в списке переписок")
 -- Писать можно и тому, с кем уже переписывались, даже если о нём не помнит сеанс сервера.
 P.Seen[sb]=nil
 M.removePlayer(b2)
 M.advance(2.1)
 check(P.SendMessage(a,sb,"Жду ответа"),"по прошлой переписке офлайн-адресат известен")
 check(P.KnownName(sa,sb)=="Адресат","имя офлайн-собеседника из переписки")

 section("КПК: лимиты, служебные сообщения, удаление")
 local b3=TEST.join({nick="Адресат",pos=Vector(X+500,0,0),sid=sb})
 local spam=TEST.join({nick="Спамер",pos=Vector(X+900,0,0)})
 S.Set("pda.message_interval",0);S.Set("pda.unread_limit",5)
 local sent=0;for i=1,7 do if P.SendMessage(spam,sa,"спам "..i) then sent=sent+1 end end
 check(sent==5,"лимит непрочитанных от одного отправителя: "..sent)
 S.Set("pda.message_interval",nil);S.Set("pda.unread_limit",nil)
 check(P.Config.MessageInterval==2 and P.Config.UnreadLimit==50,"настройки КПК сброшены")
 M.netSent={}
 check(P.SystemMessage(a,"Есть работа для тебя. Зайди.",{key="sidor",name="Сидорович"}),"служебное сообщение")
 local sys=decode(lastTo("stalker_pda.data",a))
 check(sys and sys.kind=="msg" and sys.msg.from=="sys.sidor" and sys.msg.system==true and sys.name=="Сидорович","служебное сообщение доставлено")
 local sysConv;for _,c in ipairs(P.Inbox(a)) do if c.sid=="sys.sidor" then sysConv=c end end
 check(sysConv and sysConv.system==true and sysConv.name=="Сидорович","служебная рассылка в списке переписок")
 check(P.SystemMessage(sb,"Офлайн-рассылка",{key="bad key!"}),"служебное сообщение офлайн-адресату")
 check(count("sender='sys.bad_key_'")==1,"ключ служебного отправителя очищается")
 M.advance(1)
 req(a,{op="delete",sid="sys.sidor"})
 check(count("sender='sys.sidor'")==0,"служебная рассылка удаляется у получателя")
 M.advance(1)
 req(b3,{op="delete",sid=sa})
 local afterB=decode(lastTo("stalker_pda.data",b3))
 local still=false;for _,c in ipairs(afterB and afterB.list or {}) do if c.sid==sa then still=true end end
 check(afterB and afterB.kind=="inbox" and not still,"переписка скрыта у удалившего")
 local visibleA=false;for _,c in ipairs(P.Inbox(a)) do if c.sid==sb then visibleA=true end end
 check(visibleA,"у собеседника переписка осталась")
 req(a,{op="delete",sid=sb})
 check(count("(sender="..sql.SQLStr(sa).." AND recipient="..sql.SQLStr(sb)..") OR (sender="..sql.SQLStr(sb).." AND recipient="..sql.SQLStr(sa)..")")==0,
  "переписка, скрытая обеими сторонами, удалена из базы")
 sql.Query("INSERT INTO stalker_pda_messages (sender,recipient,sender_name,recipient_name,body,sent) VALUES('76561198000000501','76561198000000502','x','y','старое',"..(os.time()-40*86400)..")")
 P.Purge()
 check(count("body='старое'")==0,"сообщения старше срока хранения удаляются")

 section("КПК: защита сети и чат")
 M.advance(5)
 M.protect("битый пакет КПК",M.netReceive,"stalker_pda.req",64,a,{9999,"мусор"})
 M.protect("КПК: неверные поля",req,a,{op="thread",sid={}})
 M.protect("КПК: неизвестная операция",req,a,{op="nope"})
 M.netSent={}
 M.protect("КПК: неверный адресат",req,a,{op="send",to=123,text={}})
 local bad=decode(lastTo("stalker_pda.data",a))
 check(bad and bad.kind=="result" and bad.ok==false,"неверный адресат по сети — отказ")
 M.advance(5);M.netSent={}
 for _=1,30 do req(a,{op="inbox"}) end
 local replies=0;for _,s in ipairs(M.netSent) do if s.name=="stalker_pda.data" and s.to==a then replies=replies+1 end end
 check(replies<=11,"частота запросов ограничена: "..replies)
 local say=hook.GetTable().PlayerSay["STALKER_PDA.Chat"]
 a._concommands=nil
 check(say(a,"!КПК")=="" and tostring(a._concommands):find("stalker_pda",1,true),"!КПК в чате открывает КПК")
 check(say(a," !pda ")=="" and say(a,"/кпк")=="","!pda и /кпк")
 check(say(a,"привет всем")==nil,"обычный чат не перехватывается")
 for _,p in ipairs({a,b3,spam}) do hook.Run("PlayerDisconnected",p);M.removePlayer(p) end
else
 local lp=LocalPlayer();local oldPos=lp:GetPos();lp:SetPos(Vector(X,0,0))
 section("КПК: клиент — окно и вкладки")
 check(type(P.Open)=="function" and type(P.OpenMessages)=="function" and C.PDAOpen~=nil,"API КПК: Open, OpenMessages, PDAOpen")
 local ids={};for _,def in ipairs(P.TabList()) do ids[#ids+1]=def.id end
 check(table.concat(ids,",",1,7)=="summary,map,news,stats,encyclopedia,messages,guide","порядок своих вкладок: "..table.concat(ids,","))
 C.RegisterPDATab("zz_test",{title="Модуль",order=1,build=function(p) p.Built=true end,badge=function() return 2 end})
 C.RegisterPDATab("zz_bad",{title="Сломанная",order=2,build=function() error("сбой вкладки") end,badge=function() error("сбой значка") end})
 local list=P.TabList()
 check(list[8] and list[8].id=="zz_test" and list[9].id=="zz_bad","вкладки модулей идут после своих")
 local hasFactions=false;for i=8,#list do if list[i].id=="factions" then hasFactions=true end end
 check(hasFactions,"вкладка группировок среди модулей")
 check(P.Badge(P.FindTab("zz_test"))==2 and P.Badge(P.FindTab("zz_bad"))==nil,"значки вкладок модулей (ошибка значка не ломает окно)")

 local created={};local orig=vgui.Create
 vgui.Create=function(name,parent) local p=orig(name,parent);created[#created+1]=p;return p end
 P.LastError=nil;P.Frame=nil
 check(M.protect("открыть КПК",P.Open,"summary") and P.Frame~=nil and P.Current=="summary","окно КПК открывается на «Сводке»")
 for _,id in ipairs({"map","news","stats","encyclopedia","messages","guide","factions","zz_test"}) do
  M.protect("вкладка "..id,P.Select,id);check(P.Current==id,"вкладка "..id)
 end
 check(P.Content.Built==true,"вкладка модуля построена в контейнере")
 check(P.LastError==nil,"вкладки строятся без ошибок: "..tostring(P.LastError and P.LastError.error))
 M.protect("сломанная вкладка",P.Select,"zz_bad")
 check(P.LastError and P.LastError.tab=="zz_bad","ошибка вкладки модуля перехвачена");P.LastError=nil
 C.PDATabs.zz_test=nil;C.PDATabs.zz_bad=nil
 check(P.FindTab("unknown")==nil and (M.protect("неизвестная вкладка",P.Select,"unknown")) and P.Current=="summary","неизвестная вкладка открывает первую")

 section("КПК: клиент — сводка")
 lp:SetNW2Float("stalker_dose",35);lp:SetNW2Float("stalker_rad_rate",.5)
 local dose,rate,thr=P.Radiation()
 check(dose==35 and rate==.5 and thr==30,"доза, фон и порог радиации")
 local inv=STALKER_INV.Inventory;local oldH,oldT=inv.hunger,inv.thirst
 inv.hunger=40;inv.thirst=15
 local hunger,thirst=P.Needs();check(hunger==40 and thirst==15,"сытость и вода из инвентаря")
 local E=ST_EMISSION;local oldState=E.State
 E.State={phase=0,started=0,ends=0,next=CurTime()+12*60}
 local title,token,detail=P.EmissionStatus()
 check(title=="Зона спокойна" and detail:find("через 10–15 мин",1,true),"прогноз выброса: "..tostring(detail))
 P.Config.EmissionForecast=false
 _,_,detail=P.EmissionStatus();check(not detail:find("Прогноз",1,true),"прогноз выброса отключается настройкой")
 P.Config.EmissionForecast=true
 E.State={phase=3,started=CurTime(),ends=CurTime()+20,next=0}
 title,token=P.EmissionStatus();check(title:find("ПИК ВЫБРОСА",1,true) and token=="danger","идущий выброс: "..title)
 check(P.QuestSummary()==nil,"без модуля заданий — нет списка")
 STALKER_QUESTS={ActiveSummary=function() return {{title="Принести хвост",progress=1,goal=3},"мусор"} end}
 local qs=P.QuestSummary();check(qs and #qs==1 and qs[1].goal==3 and qs[1].title=="Принести хвост","активные задания из STALKER_QUESTS.ActiveSummary")
 STALKER_QUESTS={ActiveSummary=function() error("сбой") end}
 check(P.QuestSummary() and #P.QuestSummary()==0,"ошибка модуля заданий не ломает сводку")
 local stranger=M.addPlayer({nick="Чужак",pos=Vector(X+300,0,0)})
 STALKER_SOCIAL={DisplayName=function(viewer,target) return target==stranger and "Незнакомец" or nil end}
 check(P.NameFor(lp,stranger)=="Незнакомец","имена через STALKER_SOCIAL.DisplayName")
 STALKER_SOCIAL=nil
 check(P.NameFor(lp,stranger)=="Чужак","без модуля знакомств — ник")
 lp:SetNW2Bool("stfw_joined",true);lp:SetNW2String("stfw_faction","duty");lp:SetNW2Int("stfw_frank",4)
 check(P.RankText(lp)=="Офицер","звание в группировке");lp:SetNW2Bool("stfw_leader",true);check(P.RankText(lp)=="лидер группировки","лидер")
 M.protect("сводка с данными",P.Select,"summary")

 section("КПК: клиент — карта и своя метка")
 P.Select("map")
 local map=P.Content.Map
 check(map and map.ToScreen and map.Zoom,"панель карты создана")
 MK.SetLocal("pda.test1",{pos=Vector(X+1000,500,0),label="Тайник",kind="stash",radius=200})
 MK.SetLocal("pda.test2",{pos=Vector(X-800,-600,0),label="Лагерь",kind="poi",map=false})
 local hidden=false;for _,m in ipairs(P.MapMarkers()) do if m.id=="pda.test2" then hidden=true end end
 check(not hidden,"метки с map=false на карте не показываются")
 M.protect("карта: схема",map.Paint,map,900,600)
 check(map.Scale and map.Scale>0,"масштаб схемы подобран по меткам и игроку")
 local px,py=map:ToScreen(X,0,900,600);local wx,wy=map:ToWorld(px,py,900,600)
 check(math.abs(wx-X)<1e-6 and math.abs(wy)<1e-6,"преобразование мир ↔ экран обратимо")
 map.LocalCursorPos=function() return 450,300 end
 M.protect("карта: курсор и подсказка",map.Paint,map,900,600)
 local s0=map.Scale;local cx,cy=map:ToWorld(450,300,900,600)
 map:OnMouseWheeled(1);check(map.Scale>s0,"колесо увеличивает масштаб")
 local cx2,cy2=map:ToWorld(450,300,900,600)
 check(math.abs(cx-cx2)<1e-6 and math.abs(cy-cy2)<1e-6,"точка под курсором не смещается при масштабе")
 map:OnMouseWheeled(-1)
 for _=1,40 do map:OnMouseWheeled(-1) end;check(map.Scale>=map.MinScale,"масштаб ограничен снизу")
 map:Reset();M.protect("карта: сброс",map.Paint,map,900,600)
 local before=map.CX
 map:OnMousePressed(MOUSE_LEFT);map:OnCursorMoved(520,300);map:OnMouseReleased(MOUSE_LEFT)
 check(map.CX<before and P.Waypoint==nil,"перетаскивание сдвигает карту и не ставит метку")
 map:OnMousePressed(MOUSE_LEFT);map:OnMouseReleased(MOUSE_LEFT)
 local wpx,wpy=map:ToWorld(450,300,900,600)
 local wp=MK.Local[P.WaypointID]
 check(P.Waypoint and wp and wp.edge==true and math.abs(P.Waypoint.x-wpx)<1 and math.abs(P.Waypoint.y-wpy)<1,"клик ставит свою метку со стрелкой у края экрана")
 local inAll=false;for _,m in ipairs(MK.All()) do if m.id==P.WaypointID then inAll=true end end
 check(inAll,"своя метка видна HUD ядра")
 M.protect("карта: со своей меткой",map.Paint,map,900,600)
 map:OnMousePressed(MOUSE_RIGHT)
 check(P.Waypoint==nil and MK.Local[P.WaypointID]==nil,"ПКМ убирает свою метку")
 P.MapHidden.stash=true
 check(#P.MapMarkers()<#P.MapMarkers(true),"фильтр по типу скрывает метки")
 P.MapHidden={}
 P.SetWaypoint(Vector(X+60,0,0),true);M.advance(.6)
 check(P.Waypoint==nil,"своя метка снимается, когда игрок дошёл")
 local oldGet=cookie.GetString
 cookie.GetString=function() return "120 -340 0" end
 hook.GetTable().InitPostEntity["STALKER_PDA.Waypoint"]()
 check(P.Waypoint and P.Waypoint.x==120 and P.Waypoint.y==-340,"своя метка восстанавливается после перезахода")
 cookie.GetString=oldGet;P.ClearWaypoint()
 local b1,b2,b3=P.ParseBounds({x1=10,y1=20,x2=0,y2=0}),P.ParseBounds({0,0,10,20}),P.ParseBounds({mins=Vector(0,0,0),maxs=Vector(10,20,0)})
 check(b1 and b2 and b3 and b1.maxx==10 and b2.maxy==20 and b3.minx==0 and b3.maxy==20 and P.ParseBounds({1,1,1,1})==nil,"форматы границ карты")
 local conf=STALKER_INV.Config;conf.MapBounds=conf.MapBounds or {}
 conf.MapMaterials["gm_test"]="stalker_pda/test.png";conf.MapBounds["gm_test"]={min=Vector(X-5000,-4000,0),max=Vector(X+5000,6000,0)}
 P.MapMats["stalker_pda/test.png"]=M.stub("mat")
 local mat,bounds=P.MapImage()
 check(mat and bounds and bounds.minx==X-5000 and bounds.maxy==6000,"подложка карты из STALKER_INV.Config")
 map:Reset();M.protect("карта: подложка",map.Paint,map,900,600)
 check(math.abs(map.CX-X)<1 and math.abs(map.CY-1000)<1,"карта центрируется по границам подложки")
 conf.MapMaterials["gm_test"]=nil;conf.MapBounds["gm_test"]=nil;P.MapMats["stalker_pda/test.png"]=nil
 MK.RemoveLocal("pda.test1");MK.RemoveLocal("pda.test2")

 section("КПК: клиент — новости и статистика")
 local l,v=packet({items={{t=os.time(),text="Внимание! Выброс.",kind="emission"},{t=os.time(),text="Торговец привёз товар",kind="trade"}},history=true})
 P.Select("news")
 M.netReceive("stalker_core.news",l,nil,v)
 check(#P.FilterNews({emission=true})>=1 and #P.FilterNews(nil)>=2,"фильтр ленты новостей")
 check(P.NewsKind("emission")=="Выброс" and select(2,P.NewsKind("unknown"))=="info","подписи видов новостей")
 M.netSent={}
 P.StatsData=nil;P.Select("stats")
 local sreq=decode(lastTo("stalker_core.stats"))
 check(sreq and sreq.top=="kills","запрос статистики и топа")
 l,v=packet({mine={kills=3,playtime=125},names={kills="Убито сталкеров",playtime="Время в Зоне, мин",custom="Свой счётчик"},
  top={key="kills",list={{sid="76561198000000123",name="Меченый",value=10},{sid=lp:SteamID64(),value=3}}}})
 M.netReceive("stalker_core.stats",l,nil,v)
 check(P.StatsData and P.StatsData.mine.kills==3 and P.StatsData.top.list[1].name=="Меченый","статистика получена")
 local keys=P.StatKeys({kills="a",playtime="b",custom="c"})
 check(keys[1]=="playtime" and keys[2]=="kills" and keys[3]=="custom","порядок счётчиков")
 check(P.FormatStat("playtime",125)=="2 ч 5 мин" and P.FormatStat("kills",1234)=="1 234","форматирование счётчиков")
 check(P.TopName({sid="76561198000000123",name="Меченый"})=="Меченый" and P.TopName({sid="1"})=="Сталкер (не в сети)","имена в топе")

 section("КПК: клиент — энциклопедия и справочник")
 local data=P.EncyclopediaData();local by,items={},{}
 for _,g in ipairs(data) do by[g.title]=#g.items;for _,it in ipairs(g.items) do items[it.id]=it end end
 check(by["Аномалии"]==5,"аномалии: "..tostring(by["Аномалии"]))
 check((by["Артефакты и детекторы"] or 0)>=14,"артефакты и детекторы: "..tostring(by["Артефакты и детекторы"]))
 check(by["Мутанты"]==8 and by["Группировки"]==11,"мутанты и группировки")
 check(by["Выбросы"]==1 and by["Радиация"]==2,"выбросы и радиация")
 local bubbleRad,price=false,false
 for _,blk in ipairs(items["artifact.bubble"] and items["artifact.bubble"].blocks or {}) do
  if type(blk)=="table" and blk[1]=="Радиация" and blk[3]=="ok" then bubbleRad=true end
  if type(blk)=="table" and blk[1]=="Торговцы платят до" then price=true end
 end
 check(bubbleRad and price,"артефакт: характеристики и цена")
 check(items["anomaly.electro"] and items["anomaly.electro"].color,"аномалия с цветом из конфига")
 local cure=false;for _,blk in ipairs(items["radiation.help"].blocks) do if type(blk)=="table" and blk[1]=="Антирад" then cure=true end end
 check(cure,"антирад в списке средств от радиации")
 check(P.CatalogMatch(items["emission.main"],P.Lower("ВЫБРОС")) and not P.CatalogMatch(items["anomaly.electro"],"выброс"),"поиск по энциклопедии")
 local guide=P.GuideData();local gi={}
 for _,g in ipairs(guide) do for _,it in ipairs(g.items) do gi[it.id]=it end end
 check(guide[1] and guide[1].title=="Основы" and gi["guide.controls"] and gi["guide.rules"],"разделы справочника")
 local f4=false;for _,blk in ipairs(gi["guide.controls"].blocks) do if type(blk)=="table" and blk[1]=="F4" then f4=true end end
 check(f4,"клавиша F4 в справочнике")
 local n=0;for _ in pairs(gi) do n=n+1 end;check(n>=10,"разделов справочника: "..n)
 P.Config.RulesLink="https://example.org/rules"
 local linked=false;for _,g in ipairs(P.GuideData()) do for _,it in ipairs(g.items) do for _,blk in ipairs(it.blocks) do if type(blk)=="table" and blk[2]=="https://example.org/rules" then linked=true end end end end
 check(linked,"ссылка на правила из настройки");P.Config.RulesLink=""
 P.AddGuide("zz_mod",{title="Модуль",blocks={"Текст модуля"}})
 local modAdded=false;for _,g in ipairs(P.GuideData()) do for _,it in ipairs(g.items) do if it.id=="guide.zz_mod" then modAdded=g.title=="Системы Зоны" end end end
 check(modAdded,"другие аддоны добавляют разделы справочника");P.Guide.zz_mod=nil

 section("КПК: клиент — сообщения")
 local other="76561198000000777"
 l,v=packet({kind="inbox",list={{sid=other,name="Бармен",last="Привет",t=os.time(),unread=2}},unread=2})
 M.netReceive("stalker_pda.data",l,nil,v)
 check(P.Unread==2 and P.FindConversation(other),"список переписок с сервера")
 check(P.Badge(P.FindTab("messages"))==2,"значок вкладки «Сообщения»")
 local toastsBefore=#C.Toasts
 l,v=packet({kind="msg",msg={id=5,from=other,to=lp:SteamID64(),text="Заходи в бар",t=os.time()},name="Бармен",unread=3})
 M.netReceive("stalker_pda.data",l,nil,v)
 check(P.Unread==3 and P.FindConversation(other).unread==3 and P.FindConversation(other).last=="Заходи в бар","новое сообщение: непрочитанные и превью")
 local toast=C.Toasts[#C.Toasts]
 check((#C.Toasts>toastsBefore or #C.Toasts==5) and toast and toast.text:find("Бармен",1,true),"уведомление о новом сообщении")
 l,v=packet({kind="thread",sid=other,name="Бармен",messages={{id=4,mine=false,text="Привет",t=os.time()},{id=5,mine=false,text="Заходи в бар",t=os.time()}},unread=0})
 M.netReceive("stalker_pda.data",l,nil,v)
 check(#P.Threads[other].messages==2 and P.Unread==0 and P.FindConversation(other).unread==0,"переписка загружена, непрочитанные сброшены")
 M.netSent={};P.NextSend=0
 check(P.Send(other,"Иду"),"отправка сообщения")
 local sendReq=decode(lastTo("stalker_pda.req"))
 check(sendReq and sendReq.op=="send" and sendReq.to==other and sendReq.text=="Иду","запрос отправки на сервер")
 check(not P.Send(other,"Ещё"),"пауза между отправками на клиенте")
 check(not P.Send("sys.sidor","ответ"),"служебной рассылке не отвечают")
 l,v=packet({kind="result",ok=true,to=other,msg={id=6,from=lp:SteamID64(),to=other,text="Иду",t=os.time()},next=2})
 M.netReceive("stalker_pda.data",l,nil,v)
 local msgs=P.Threads[other].messages
 check(#msgs==3 and msgs[3].mine and msgs[3].text=="Иду" and P.FindConversation(other).mine,"отправленное сообщение в переписке")
 l,v=packet({kind="seen",sid=other});M.netReceive("stalker_pda.data",l,nil,v)
 check(msgs[3].seen==true,"отметка «прочитано»")
 l,v=packet({kind="result",ok=false,to=other,error="Адресат ещё не прочитал ваши прошлые сообщения"})
 M.netReceive("stalker_pda.data",l,nil,v)
 check(P.SendError=="Адресат ещё не прочитал ваши прошлые сообщения" and (P.NextSend or 0)==0,"ошибка отправки показана")
 l,v=packet({kind="msg",msg={id=9,from="sys.sidor",to=lp:SteamID64(),text="Есть работа",t=os.time(),system=true},name="Сидорович",unread=1})
 M.netReceive("stalker_pda.data",l,nil,v)
 check(P.FindConversation("sys.sidor") and P.FindConversation("sys.sidor").system,"служебная рассылка на клиенте")
 M.netSent={}
 M.protect("открыть переписку",P.OpenMessages,other)
 check(P.Chat==other and P.Current=="messages","STALKER_PDA.OpenMessages(sid) открывает переписку")
 local threadReq=false;for _,s in ipairs(M.netSent) do local d=s.name=="stalker_pda.req" and decode(s);if d and d.op=="thread" and d.sid==other then threadReq=true end end
 check(threadReq,"переписка запрошена у сервера")
 M.protect("обновление списка",P.Refresh,"inbox");M.protect("обновление переписки",P.Refresh,"thread",other)
 M.protect("КПК: прочие обработчики",P.HandleData,{kind="unread",n=0,sid=other})
 check(P.Unread==0,"непрочитанные обновлены")
 for _,bad in ipairs({{kind="msg"},{kind="msg",msg={from=1}},{kind="thread"},{kind="inbox",list="x"},{kind="seen",sid={}},{kind="zzz"}}) do M.protect("КПК: битые данные",P.HandleData,bad) end

 section("КПК: клиент — F4 и команды")
 P.Frame=nil
 check(hook.Run("PlayerBindPress",lp,"gm_showspare2",true)==true and P.Frame~=nil,"F4 открывает КПК и не пускает бинд в меню DarkRP")
 rawset(P.Frame,"IsValid",function() return true end)
 hook.Run("PlayerBindPress",lp,"gm_showspare2",true)
 check(P.Frame==nil,"повторное F4 закрывает КПК")
 check(hook.GetTable().PlayerBindPress["STALKER_PDA.F4"](lp,"+jump",true)==nil,"другие бинды не перехватываются")
 P.Config.F4Key=false
 check(hook.GetTable().PlayerBindPress["STALKER_PDA.F4"](lp,"gm_showspare2",true)==nil,"F4 отключается настройкой");P.Config.F4Key=true
 M.command(nil,"stalker_pda","map");check(P.Current=="map" and P.Frame~=nil,"stalker_pda map — открыть на карте")
 local frame=P.Frame
 check(type(rawget(frame,"OnKeyCodePressed"))=="function" and frame.OnKeyCodePressed(frame,P.ToggleKey())==true,"F4 в открытом окне закрывает его")
 M.protect("окно: шапка",rawget(frame,"Paint"),frame,1120,720);M.protect("окно: проверка обморока",rawget(frame,"Think"),frame)
 C.OpenPDA("guide");check(P.Current=="guide","STALKER_CORE.OpenPDA открывает КПК")

 section("КПК: клиент — без соседних аддонов")
 local names={"STALKER_ZONE","STFW","ST_EMISSION","STALKER_RAD","STALKER_INV","STALKER_BUTCHERING"}
 local saved={};for i,name in ipairs(names) do saved[i]=rawget(_G,name);rawset(_G,name,nil) end
 check(#P.EncyclopediaData()==0,"без аддонов Зоны энциклопедия пуста")
 check(P.Needs()==nil and P.EmissionStatus()=="Нет данных о выбросах" and P.MapImage()==nil,"сводка и карта без инвентаря и выбросов")
 for _,id in ipairs({"summary","map","news","stats","encyclopedia","messages","guide"}) do M.protect("без аддонов: "..id,P.Select,id) end
 check(P.LastError==nil,"вкладки без соседних аддонов: "..tostring(P.LastError and P.LastError.error))
 local paintedBare=0
 for _,p in ipairs(created) do local paint=rawget(p,"Paint");if type(paint)=="function" then paintedBare=paintedBare+1;M.protect("без аддонов: отрисовка",paint,p,600,160) end end
 local mapBare=P.Select("map") and P.Content.Map;if mapBare then M.protect("без аддонов: карта",mapBare.Paint,mapBare,900,600) end
 for i,name in ipairs(names) do rawset(_G,name,saved[i]) end

 -- Отрисовка и раскладка всех созданных панелей (вкладки, карточки, строки, пузыри сообщений).
 vgui.Create=orig
 local painted=0
 for _,p in ipairs(created) do
  for _,fn in ipairs({"PerformLayout","Paint","Think"}) do
   local f=rawget(p,fn);if type(f)=="function" then if fn=="Paint" then painted=painted+1 end;M.protect("КПК: "..fn,f,p,600,160) end
  end
 end
 check(painted>60,"панели КПК отрисованы: "..painted)
 for _,ev in ipairs({{"HUDPaint"},{"Think"}}) do M.protect("HUD "..ev[1],hook.Run,unpack(ev)) end
 -- Уборка: состояние клиента для следующих сценариев.
 P.Frame=nil;P.Body=nil;P.Content=nil;P.Chat=nil;P.Inbox={};P.Threads={};P.Unread=0
 E.State=oldState;inv.hunger,inv.thirst=oldH,oldT;STALKER_QUESTS=nil
 lp:SetNW2Float("stalker_dose",0);lp:SetNW2Float("stalker_rad_rate",0)
 lp:SetNW2Bool("stfw_joined",false);lp:SetNW2String("stfw_faction","");lp:SetNW2Int("stfw_frank",0);lp:SetNW2Bool("stfw_leader",false)
 M.removePlayer(stranger);lp:SetPos(oldPos)
end
