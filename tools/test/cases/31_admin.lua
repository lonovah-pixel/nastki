-- «Комендант» и ULX: уровни = группы ULX, права stalker_* через ULib/CAMI, баны ULib, команды ULX,
-- настройки в общей админ-системе, вкладки подсистем и тема. Область мира X: 1 500 000…1 900 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local A,S=STALKER_ADMIN,STALKER_SETTINGS
local X=1500000
section("Комендант ("..M.Realm..")")
check(A and A.Config and A.Commands and A.Sections,"STALKER_ADMIN загружен")
check(A.Config.Version=="2.0.0","версия панели 2.0.0")
for _,id in ipairs({"admin.ban_moderator","admin.ban_admin","admin.log_days","admin.self_god","admin.max_targets"}) do
 check(S.Defs[id] and S.Defs[id].category=="Комендант","настройка в категории «Комендант»: "..id)
end
check(S.Defs["admin.ban_moderator"].realm=="shared" and S.Defs["admin.self_god"].type=="bool","типы и realm настроек")
for _,row in ipairs(A.Permissions) do
 local p=CAMI.GetPrivilege("stalker_"..row[1])
 check(p and (p.MinAccess=="admin" or p.MinAccess=="superadmin"),"CAMI-привилегия stalker_"..row[1])
end
check(CAMI.GetPrivilege("stalker_view").MinAccess=="admin" and CAMI.GetPrivilege("stalker_settings").MinAccess=="superadmin","MinAccess по ролям")
for _,s in ipairs({"Настройки","Радиация","Зона","События","Задания","Крафт","Группировки"}) do check(A.SectionByID[s],"раздел панели «"..s.."»") end
check(A.SectionByID["Радиация"].permission=="radiation" and A.SectionByID["Группировки"].permission=="factions","права вкладок подсистем")
check(A.SteamID("76561197960265729")=="STEAM_0:1:0" and A.SteamID64("STEAM_0:1:0")=="76561197960265729","перевод SteamID64 ↔ SteamID")

local function reply(p)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i]
  if s.name=="sta.response" and s.to==p then return util.JSONToTable(util.Decompress(s.data[2])) end
 end
end
local function says(p,pattern) for _,line in ipairs(p._chat) do if line:find(pattern,1,true) then return true end end;return false end

if SERVER then
 local U=ULib.ucl
 section("Комендант: права через ULib")
 check(A.UsesULib() and A.UsesULibBans() and A.UsesULX(),"ULib/ULX обнаружены")
 check(U.groups.moderator and U.groups.moderator.inherit_from=="operator","группа moderator создана (наследует operator)")
 local function allows(g,a) for _,x in ipairs(U.groups[g].allow) do if x==a then return true end end;return false end
 check(allows("operator","stalker_view") and allows("operator","stalker_teleport") and not allows("operator","stalker_kick"),"доступы оператора (Наблюдатель)")
 check(allows("moderator","stalker_kick") and allows("moderator","stalker_bans"),"доступы модератора")
 check(allows("admin","stalker_zone") and allows("admin","stalker_radiation") and not allows("admin","stalker_settings"),"доступы администратора")
 check(allows("superadmin","stalker_settings") and allows("superadmin","stalker_roles"),"доступы суперадмина")
 check(not allows("admin","stalker_view") and not allows("superadmin","stalker_zone") and allows("admin","stalker_kick"),"доступ выдан только нижней группе цепочки наследования")
 check(U.accessCategories["stalker_view"]=="STALKER" and U.accessStrings["stalker_view"]:find("Комендант",1,true),"категория STALKER и описание в XGUI")

 local super=M.addPlayer({nick="Комендант",superadmin=true,pos=Vector(X,0,0)})
 local admin=M.addPlayer({nick="Админ",admin=true,pos=Vector(X+100,0,0)})
 local user=TEST.join({nick="Сталкер",pos=Vector(X+200,0,0)})
 local mod=M.addPlayer({nick="Модератор",pos=Vector(X+300,0,0)})
 U.addUser(util.SteamIDFrom64(mod:SteamID64()),nil,nil,"moderator")
 check(mod:GetUserGroup()=="moderator" and A.Role(mod)=="moderator" and A.Rank(mod)==30,"группа ULX moderator → «Модератор»")
 check(A.Role(super)=="superadmin" and A.Role(admin)=="admin" and A.Role(user)=="user","уровни по группам ULX")
 check(A.Has(admin,"zone") and A.Has(admin,"events") and not A.Has(admin,"settings"),"права администратора через ucl.query")
 check(A.Has(super,"settings") and A.Has(super,"craft") and not A.Has(user,"view"),"права суперадмина и игрока")
 check(STALKER_CORE.CanAdmin(admin,"radiation") and not STALKER_CORE.CanAdmin(mod,"radiation"),"ядро спрашивает права у «Коменданта»")
 -- Владелец перенастраивает права в XGUI: панель сразу это учитывает.
 U.groupAllow("admin","stalker_settings")
 check(A.Has(admin,"settings"),"право выдано группе в XGUI")
 U.groupAllow("admin","stalker_settings",true)
 check(not A.Has(admin,"settings"),"право отозвано в XGUI")
 U.addUser(util.SteamIDFrom64(admin:SteamID64()),{},{"stalker_zone"},"admin")
 check(not A.Has(admin,"zone") and A.Has(admin,"loadout"),"личный запрет ULX сильнее группы")
 U.addUser(util.SteamIDFrom64(admin:SteamID64()),{},{},"admin")
 U.addGroup("headadmin",nil,"superadmin")
 local head=M.addPlayer({nick="Старший",pos=Vector(X+400,0,0)});U.addUser(util.SteamIDFrom64(head:SteamID64()),nil,nil,"headadmin")
 check(A.Role(head)=="superadmin" and A.Has(head,"settings"),"своя группа ULX, наследующая superadmin")

 section("Комендант: уровни = группы ULX")
 local offline="76561198123456789";local offlineID=util.SteamIDFrom64(offline)
 check(A.SetRole(nil,offline,"moderator"),"консоль назначает модератора офлайн")
 check(U.users[offlineID] and U.users[offlineID].group=="moderator" and A.OfflineRank(offline)==30,"офлайн-игрок в группе ULX moderator")
 check(A.ULXGroup(offline)=="moderator","группа ULX офлайн-игрока")
 check(A.SetRole(super,user:SteamID64(),"helper"),"суперадмин назначает наблюдателя")
 check(user:GetUserGroup()=="operator" and A.Role(user)=="helper" and A.Has(user,"view") and not A.Has(user,"kick"),"онлайн-игрок сразу в группе operator")
 check(not A.SetRole(super,admin:SteamID64(),"superadmin"),"нельзя выдать равный себе уровень")
 check(not A.SetRole(admin,user:SteamID64(),"moderator"),"у администратора нет права roles")
 check(not A.SetRole(super,super:SteamID64(),"admin"),"нельзя менять свой уровень")
 local r=A.Execute(super,{command="role",sid=user:SteamID64(),value="moderator"})
 check(r.ok and user:GetUserGroup()=="moderator","команда панели «Назначить уровень» меняет группу ULX")
 check(A.SetRole(nil,user:SteamID64(),"user") and user:GetUserGroup()=="user" and U.users[util.SteamIDFrom64(user:SteamID64())]==nil,"снятие уровня удаляет запись ULX")
 M.printed={}
 M.command(nil,"sta_setrole",offline,"admin")
 check(U.users[offlineID].group=="admin" and M.printed[1] and M.printed[1]:find("группа ULX: admin",1,true),"sta_setrole в консоли меняет группу ULX")
 M.command(nil,"sta_setrole",offline,"owner")
 check(A.Roles[offline]=="owner" and U.users[offlineID].group=="superadmin" and A.OfflineRank(offline)==100,"владелец: отметка sta_roles + группа superadmin")
 M.command(nil,"sta_setrole",offline,"helper")
 check(A.Roles[offline]==nil and U.users[offlineID].group=="operator","понижение владельца из консоли")
 -- Владелец из Owners попадает в superadmin при входе.
 local ownerSID="76561198111111111";A.Config.Owners[ownerSID]=true
 local owner=TEST.join({nick="Владелец",sid=ownerSID,pos=Vector(X+500,0,0)})
 check(A.Role(owner)=="owner" and owner:GetUserGroup()=="superadmin","владелец из Owners синхронизирован в superadmin")
 check(not A.SetRole(nil,ownerSID,"user"),"владельца из Owners нельзя понизить")
 -- Миграция уровней sta_roles → ULX (одноразовая).
 local legacy="76561198222222222"
 sql.Query("REPLACE INTO sta_roles VALUES('"..legacy.."','moderator')");A.Roles[legacy]="moderator"
 sql.Query("DELETE FROM sta_meta WHERE key='roles_migrated'")
 check(A.MigrateRoles()>=1 and U.users[util.SteamIDFrom64(legacy)].group=="moderator","уровень sta_roles перенесён в группу ULX")
 check(A.MigrateRoles()==0 and A.GetMeta("roles_migrated"),"миграция уровней выполняется один раз")
 A.Roles[legacy]=nil;sql.Query("DELETE FROM sta_roles WHERE sid='"..legacy.."'")

 section("Комендант: баны ULib")
 local victim=M.addPlayer({nick="Нарушитель",pos=Vector(X+600,0,0)})
 local victimID=util.SteamIDFrom64(victim:SteamID64())
 r=A.Execute(admin,{command="ban",targets={victim:SteamID64()},reason="Тестовый бан",minutes=20000})
 check(not r.ok and r.results[1].message:find("Лимит",1,true),"лимит бана администратора: "..tostring(r.results and r.results[1].message))
 check(S.Set("admin.ban_admin",30000) and A.Config.AdminBanMinutes==30000,"лимит бана меняется в настройках")
 r=A.Execute(admin,{command="ban",targets={victim:SteamID64()},reason="Тестовый бан",minutes=20000})
 check(r.ok and ULib.bans[victimID] and ULib.bans[victimID].reason=="Тестовый бан","бан записан в ULib.bans")
 check(victim._kicked,"забаненный отключён ULib")
 check(tonumber(sql.QueryValue("SELECT rank FROM sta_banmeta WHERE sid='"..victim:SteamID64().."'"))==60,"ранг автора бана сохранён")
 S.Set("admin.ban_admin",nil)
 check(A.Config.AdminBanMinutes==10080,"сброс лимита к значению по умолчанию")
 local ban=A.GetBan(victim:SteamID64())
 check(ban and ban.reason=="Тестовый бан" and ban.expires>os.time(),"активный бан ULib читается")
 local okPass,msg=hook.Run("CheckPassword",victim:SteamID64())
 check(okPass==false and tostring(msg):find("Блокировка",1,true),"вход забаненного отклоняется")
 local page=A.Page("bans",1);local listed=false
 for _,row in ipairs(page) do if row.sid==victim:SteamID64() then listed=row.name=="Нарушитель" end end
 check(listed,"реестр банов показывает бан ULib")
 r=A.Execute(mod,{command="ban",targets={user:SteamID64()},reason="Навсегда",minutes=0})
 check(not r.ok,"модератору недоступен бессрочный бан")
 r=A.Execute(mod,{command="unban",sid=victim:SteamID64()})
 check(not r.ok and r.results[1].message:find("более высоким",1,true),"модератор не снимает бан администратора")
 r=A.Execute(admin,{command="unban",sid=victim:SteamID64()})
 check(r.ok and ULib.bans[victimID]==nil and A.GetBan(victim:SteamID64())==nil,"разбан через ULib.unban")
 ULib.bans["STEAM_0:0:1"]={time=os.time()-100,unban=os.time()-10,reason="старый",name="Старый"}
 check(A.GetBan(A.SteamID64("STEAM_0:0:1"))==nil,"истёкший бан ULib не действует")
 local stale=false;for _,row in ipairs(A.Page("bans",1)) do if row.reason=="старый" then stale=true end end
 check(not stale,"истёкший бан не в реестре");ULib.bans["STEAM_0:0:1"]=nil
 -- Одноразовый перенос старых банов «Коменданта» в ULib.
 local old="76561198333333333"
 sql.Query("REPLACE INTO sta_bans VALUES('"..old.."','Старый нарушитель','Старая причина','CONSOLE',0,"..os.time()..",90)")
 sql.Query("DELETE FROM sta_meta WHERE key='bans_migrated'")
 check(A.MigrateBans()==1,"бан sta_bans перенесён")
 local moved=ULib.bans[util.SteamIDFrom64(old)]
 check(moved and moved.reason=="Старая причина" and moved.unban==0 and tonumber(sql.QueryValue("SELECT rank FROM sta_banmeta WHERE sid='"..old.."'"))==90,"перенос сохранил причину, срок и ранг")
 check(A.MigrateBans()==0,"перенос банов выполняется один раз")
 ULib.bans[util.SteamIDFrom64(old)]=nil;sql.Query("DELETE FROM sta_bans WHERE sid='"..old.."'")
 -- Кик через ULib.kick.
 local loud=M.addPlayer({nick="Шумный",pos=Vector(X+700,0,0)})
 M.ulibKicks={}
 r=A.Execute(mod,{command="kick",targets={loud:SteamID64()},reason="Флуд в эфире"})
 check(r.ok and M.ulibKicks[1] and M.ulibKicks[1].ply==loud and tostring(loud._kicked):find("Флуд",1,true),"кик через ULib.kick")
 local logged=false;for _,line in ipairs(ulx.logs) do if line:find("[Комендант]",1,true) and line:find("kick",1,true) and line:find("выполнено",1,true) then logged=true end end
 check(logged,"журнал продублирован в ulx.logString")

 section("Комендант: подтверждение и снимок панели")
 M.netSent={}
 A.Plan(mod,{kind="execute",command="kick",targets={loud:SteamID64()},reason="Повторный флуд"})
 local confirm=reply(mod)
 check(confirm and confirm.kind=="confirm" and confirm.token,"опасная команда требует подтверждения")
 M.netSent={}
 local raw=util.TableToJSON({kind="confirm",token=confirm.token})
 M.netReceive("sta.request",#raw*8+16,mod,{#raw,raw})
 local done=reply(mod)
 check(done and done.kind=="result" and done.ok,"подтверждение выполняет команду")
 M.netSent={}
 raw=util.TableToJSON({kind="state"});M.netReceive("sta.request",#raw*8+16,admin,{#raw,raw})
 local state=reply(admin)
 check(state and state.kind=="state" and state.integrations.ulib and state.integrations.ulx and state.integrations.ulibBans,"снимок: интеграция ULib/ULX")
 check(state.tabs.zone and state.tabs.radiation and not state.tabs.settings and not state.tabs.factions,"снимок: права вкладок администратора")
 local groupShown=false;for _,row in ipairs(state.players) do if row.sid==mod:SteamID64() then groupShown=row.group=="moderator" end end
 check(groupShown and state.group=="admin","снимок: группа ULX игроков")
 local roleULX=false;for _,row in ipairs(state.catalog.roles) do if row.name:find("ULX:",1,true) then roleULX=true end end
 check(roleULX and state.limits.admin==10080,"снимок: уровни с группами ULX и лимиты бана")
 M.netSent={}
 raw=util.TableToJSON({kind="state"});M.netReceive("sta.request",#raw*8+16,user,{#raw,raw})
 check(reply(user) and reply(user).kind=="denied","без права view панель не открывается")

 section("Комендант: команды ULX")
 include("ulx/modules/sh/stalker_admin.lua")
 local names={};for _,c in ipairs(ulx.cmdsByCategory.STALKER or {}) do names[c.cmd]=true end
 for _,cmd in ipairs({"ulx stalkeritem","ulx stalkerdose","ulx stalkerfaction","ulx emissionstart","ulx emissionstop","ulx zonerebuild","ulx stalkerrestock","ulx stalkerevent","ulx stalkerstopevent"}) do
  check(names[cmd],"команда ULX: "..cmd)
 end
 check(allows("admin","ulx stalkeritem") and allows("admin","ulx emissionstart"),"доступ к командам ULX по умолчанию — admin")
 local target=TEST.join({nick="Получатель",pos=Vector(X+800,0,0)})
 local itemID=STALKER_INV.Items.bandage and "bandage" or next(STALKER_INV.Items)
 local before=TEST.gridCount(target,itemID)
 check(M.ulxRun(admin,"ulx stalkeritem",{target},itemID,2) and TEST.gridCount(target,itemID)==before+2,"ulx stalkeritem выдаёт предмет")
 local echoed=false;for _,line in ipairs(ulx.logs) do if line:find("Админ выдал Получатель",1,true) then echoed=true end end
 check(echoed,"ulx stalkeritem пишет в журнал ULX")
 M.ulxRun(admin,"ulx stalkerdose",{target},25)
 check(target:GetNW2Float("stalker_dose",0)==25,"ulx stalkerdose ставит дозу")
 M.ulxRun(admin,"ulx stalkerfaction",{target},"duty")
 check(target:GetNW2String("stfw_faction","")=="duty","ulx stalkerfaction назначает группировку")
 M.ulxRun(admin,"ulx emissionstart")
 check(ST_EMISSION.State.phase>0,"ulx emissionstart запускает выброс")
 M.ulxRun(admin,"ulx emissionstop")
 check(ST_EMISSION.State.phase==0,"ulx emissionstop останавливает выброс")
 local rebuilt=0;hook.Add("STALKER_ZONE_Regenerated","STALKER.AdminTest",function() rebuilt=rebuilt+1 end)
 M.ulxRun(admin,"ulx zonerebuild")
 check(rebuilt==1,"ulx zonerebuild перестраивает Зону");hook.Remove("STALKER_ZONE_Regenerated","STALKER.AdminTest")
 M.ulibSay={}
 M.ulxRun(admin,"ulx stalkerrestock")
 local restocked=false;for _,s in ipairs(M.ulibSay) do if s.text:find("Пополнено складов",1,true) then restocked=true end end
 check(restocked,"ulx stalkerrestock пополняет склады")
 -- События: подменяем аддон событий на время проверки.
 local savedEvents=STALKER_EVENTS;local started,stopped
 STALKER_EVENTS={List=function() return {{id="test_storm",name="Буря"}} end,Start=function(id) started=id;return true end,Stop=function(id) stopped=id;return false,"Событие не идёт" end}
 M.ulibSay={}
 M.ulxRun(admin,"ulx stalkerevent","test_storm")
 check(started=="test_storm","ulx stalkerevent запускает событие")
 M.ulxRun(admin,"ulx stalkerstopevent","test_storm")
 local refused=false;for _,s in ipairs(M.ulibSay) do if s.error and s.text:find("Событие не идёт",1,true) then refused=true end end
 check(stopped=="test_storm" and refused,"отказ аддона событий показан вызвавшему")
 r=A.Execute(admin,{command="event_start",value="unknown"})
 check(not r.ok,"неизвестное событие отклонено")
 STALKER_EVENTS=savedEvents
 check(not M.ulxRun(user,"ulx stalkeritem",{target},itemID,1),"игрок без доступа не вызывает команду ULX")
 -- Доступ к команде ULX без права stalker_loadout: «Комендант» всё равно откажет.
 local op=M.addPlayer({nick="Оператор",pos=Vector(X+900,0,0)});U.addUser(util.SteamIDFrom64(op:SteamID64()),{"ulx stalkeritem"},nil,"operator")
 M.ulibSay={};before=TEST.gridCount(target,itemID)
 M.ulxRun(op,"ulx stalkeritem",{target},itemID,1)
 local denied=false;for _,s in ipairs(M.ulibSay) do if s.error and s.text:find("Недостаточный допуск",1,true) then denied=true end end
 check(denied and TEST.gridCount(target,itemID)==before,"права stalker_* проверяются и для команд ULX")

 section("Комендант: настройки и бессмертие")
 check(S.Set("admin.self_god",false) and A.Config.AllowSelfGod==false,"AllowSelfGod из настроек")
 r=A.Execute(super,{command="god_on",targets={super:SteamID64()}})
 check(not r.ok,"бессмертие для себя запрещено настройкой")
 S.Set("admin.self_god",nil)
 r=A.Execute(super,{command="god_on",targets={super:SteamID64()}})
 check(r.ok and super:HasGodMode(),"бессмертие для себя после сброса")
 A.Execute(super,{command="god_off",targets={super:SteamID64()}})
 check(S.Set("admin.log_days",30) and A.Config.LogDays==30,"срок хранения журнала из настроек");S.Set("admin.log_days",nil)
 r=A.Execute(super,{command="restock"})
 check(r.ok and r.results[1].message:find("Пополнено",1,true),"команда панели «Пополнить склады»")

 section("Комендант: без ULib — прежние таблицы")
 local savedULib=ULib;ULib=nil
 check(not A.UsesULib() and not A.UsesULibBans(),"ULib отключён")
 local legacyUser=M.addPlayer({nick="Без ULX",pos=Vector(X+1000,0,0)})
 check(A.SetRole(super,legacyUser:SteamID64(),"moderator") and A.Roles[legacyUser:SteamID64()]=="moderator" and A.Role(legacyUser)=="moderator","уровень хранится в sta_roles")
 check(A.Has(legacyUser,"kick") and not A.Has(legacyUser,"zone"),"права из таблицы уровней")
 r=A.Execute(admin,{command="ban_sid",sid="76561198444444444",reason="Без ULib",minutes=60})
 check(r.ok and sql.QueryValue("SELECT reason FROM sta_bans WHERE sid='76561198444444444'")=="Без ULib","бан в sta_bans без ULib")
 check(A.GetBan("76561198444444444") and A.Page("bans",1)[1],"реестр банов без ULib")
 r=A.Execute(admin,{command="unban",sid="76561198444444444"})
 check(r.ok and A.GetBan("76561198444444444")==nil,"разбан без ULib")
 r=A.Execute(admin,{command="kick",targets={legacyUser:SteamID64()},reason="Проверка кика"})
 check(r.ok and legacyUser._kicked=="Проверка кика","кик без ULib")
 A.SetRole(nil,legacyUser:SteamID64(),"user")
 ULib=savedULib
 check(A.UsesULib(),"ULib снова доступен")

 -- Уборка: игроки, записи ULX, отметки владельца — следующие сценарии начинают с чистого UCL.
 local sids={offline,ownerSID,legacy}
 for _,p in ipairs({super,admin,user,mod,head,owner,victim,loud,target,op,legacyUser}) do sids[#sids+1]=p:SteamID64();M.removePlayer(p) end
 A.Config.Owners[ownerSID]=nil
 for _,id in ipairs(sids) do
  local key=util.SteamIDFrom64(id);if U.users[key] then U.removeUser(key) end
  sql.Query("DELETE FROM sta_roles WHERE sid='"..id.."'");A.Roles[id]=nil
 end
 check(next(U.users)==nil,"записи ULX после сценария убраны")
else
 section("Комендант: тема и панель (клиент)")
 local T=STALKER_THEME
 check(A.C.edge==T.C.line and A.C.red==T.C.danger and A.C.green==T.C.ok and A.C.raised==T.C.panel2,"старые цвета панели → токены темы")
 T.Apply("pda");check(A.C.accent==T.C.accent and A.C.accent.g==T.Presets.pda.accent.g,"смена темы перекрашивает панель");T.Apply("zone")
 check(A.F.body=="STALKER.Body" and A.F.title=="STALKER.Title","шрифты ядра")
 check(A.Lower("ПРИВЕТ Ёжик Zone")=="привет ёжик zone","поиск без учёта регистра кириллицы")
 check(A.SnapSetting({min=0,max=100,step=5},37)==35 and A.SnapSetting({min=0,max=1,decimals=2},0.456)==0.46,"шаг и точность ползунка")
 check(A.FormatSetting({type="number",decimals=1},2)=="2.0" and A.FormatSetting({type="bool"},true)=="вкл." and A.FormatSetting({type="choice",choices={{"a","Альфа"}}},"a")=="Альфа","формат значений настроек")
 -- Заглушки Derma в моке «невалидны»; на время проверки окна делаем созданные панели валидными.
 local create=vgui.Create
 vgui.Create=function(...) local p=create(...);if type(p)=="table" and rawget(p,"_stub") then rawset(p,"IsValid",function() return true end) end;return p end
 local frame
 M.protect("admin open",function() frame=A.Open() end)
 check(frame,"окно «Коменданта» создаётся")
 local players={{sid="76561198000000077",name="Сталкер Тест",role="moderator",group="moderator",rank=30,health=100,armor=10,alive=true,ping=40,team="Сталкер",faction="duty",frozen=false,god=false,dose=12}}
 local state={kind="state",players=players,permissions={},tabs={logs=true,bans=true,settings=true,radiation=true,zone=true,events=true,quests=true,craft=true,factions=false,roles=true},
  role="superadmin",group="superadmin",map="gm_test",max=32,catalog={weapons={{id="weapon_pistol",name="weapon_pistol"}},items={{id="bandage",name="Бинт"}},factions={{id="duty",name="Долг"}},maps={},
  roles={{id="helper",name="Наблюдатель — ULX: operator",rank=10}},events={{id="storm",name="Буря"}}},limits={moderator=1440,admin=10080,max=525600,targets=16},
  integrations={inventory=true,factions=true,radiation=true,emissions=true,darkrp=true,zone=true,restock=true,events=true,ulib=true,ulx=true,ulibBans=true}}
 for id in pairs(A.Commands) do state.permissions[id]=true end
 M.protect("admin state",A.HandleResponse,state)
 check(A.State==state and frame.Initialized,"снимок сервера принят, окно инициализировано")
 M.protect("admin roster paint",A.PaintRosterRow,players[1],280,78,true,false)
 M.protect("admin header paint",A.PaintHeader,1380,860)
 M.protect("admin frame paint",frame.Paint,frame,1380,860)
 A.Toggle(players[1].sid);check(A.Selected[players[1].sid],"игрок отмечается в составе")
 -- Все разделы строятся без ошибок; вкладки подсистем — через BuildAdminPanel или «Аддон не установлен».
 local savedQuests,savedCraft=STALKER_QUESTS,STALKER_CRAFT
 local built
 STALKER_QUESTS={BuildAdminPanel=function(parent) built=parent end}
 STALKER_CRAFT={BuildAdminPanel=function() error("сломанная вкладка") end}
 local errors={};local errorNoHalt=ErrorNoHalt;ErrorNoHalt=function(s) errors[#errors+1]=s end
 for _,s in ipairs(A.Sections) do
  M.protect("admin section "..s.id,A.SelectSection,s.id)
  check(A.Category==s.id,"раздел открывается: "..s.id)
 end
 ErrorNoHalt=errorNoHalt
 check(built~=nil,"вкладка «Задания» построена аддоном")
 check(errors[1] and errors[1]:find("Крафт",1,true),"ошибка чужой вкладки перехвачена")
 STALKER_QUESTS,STALKER_CRAFT=savedQuests,savedCraft
 -- Формы всех команд.
 A.SelectSection("Дисциплина")
 for id,c in pairs(A.Commands) do M.protect("admin form "..id,A.ShowForm,c) end
 check(A.ActiveCommand~=nil,"формы команд строятся")
 -- Реестры.
 A.SelectSection("Журнал")
 M.protect("admin logs",A.FillPage,{kind="page",section="logs",page=1,ok=true,rows={{time=os.time(),actor="CONSOLE",action="kick",target="76561198000000077",detail="",status="success"}}})
 A.SelectSection("Реестр банов")
 M.protect("admin bans",A.FillPage,{kind="page",section="bans",page=1,ok=true,rows={{sid="76561198000000099",name="Нарушитель",reason="Тест",expires=0}}})
 check(A.Table and A.Table.Section=="bans","таблица банов")
 -- Настройки: список с сервера, поиск, обновление на месте.
 A.SelectSection("Настройки")
 check(A.SettingsView,"вкладка «Настройки» открыта")
 local list={
  {id="admin.ban_moderator",category="Комендант",label="Лимит бана модератора, мин",type="number",min=10,max=525600,step=10,decimals=0,default=1440,value=1440,order=1,changed=false},
  {id="admin.self_god",category="Комендант",label="Бессмертие для себя",type="bool",default=true,value=false,order=5,changed=true},
  {id="core.theme",category="Интерфейс",label="Тема интерфейса",type="choice",choices={{"zone","Зона"},{"pda","КПК"}},default="zone",value="pda",order=1,changed=true},
  {id="test.text",category="Прочее",label="Текст",type="string",default="",value="abc",order=1,changed=false}}
 M.protect("admin settings list",A.OnSettingsList,list)
 local SV=A.SettingsView;local n=0;for _ in pairs(SV.rows) do n=n+1 end
 check(n==4 and SV.total==4 and SV.changed==2,"строки настроек по типам: "..n)
 for id,row in pairs(SV.rows) do M.protect("admin setting paint "..id,row.Paint,row,900,58) end
 SV.filter="ЛИМИТ";M.protect("admin settings search",A.RenderSettings)
 n=0;for _ in pairs(SV.rows) do n=n+1 end
 check(n==1 and SV.rows["admin.ban_moderator"],"поиск по настройкам (кириллица)")
 SV.filter="";A.RenderSettings()
 local updated=table.Copy(list);updated[1].value=2000;updated[1].changed=true
 local row=SV.rows["admin.ban_moderator"]
 M.protect("admin settings update",hook.Run,"STALKER_SettingsList",updated,{id="admin.ban_moderator",ok=true})
 check(SV.rows["admin.ban_moderator"]==row and row.Def.value==2000 and SV.changed==3,"ответ сервера обновляет строку на месте")
 SV.changedOnly=true;A.RenderSettings();n=0;for _ in pairs(SV.rows) do n=n+1 end
 check(n==3,"фильтр «Только изменённые»")
 -- Подтверждение, результат, отказ.
 M.protect("admin confirm",A.HandleResponse,{kind="confirm",token="1:2",label="Отключить",targets={"Сталкер [7656…]"},detail="Флуд"})
 check(A.ConfirmFrame,"окно подтверждения в теме")
 M.netSent={}
 M.protect("admin confirm close",A.ConfirmFrame.OnRemove,A.ConfirmFrame)
 local cancelled=false;for _,s in ipairs(M.netSent) do if s.name=="sta.request" and tostring(s.data[2]):find("cancel",1,true) then cancelled=true end end
 check(cancelled,"закрытие подтверждения отменяет команду")
 M.protect("admin result",A.HandleResponse,{kind="result",ok=false,message="Есть ошибки",results={{name="Сталкер",ok=false,message="Цель недоступна"}}})
 -- Камера наблюдения.
 local watched=M.addPlayer({nick="Цель камеры"});LocalPlayer():SetNW2Entity("sta_watch",watched)
 M.protect("admin camera hud",hook.Run,"HUDPaint")
 local view=hook.Run("CalcView",LocalPlayer(),Vector(0,0,0),Angle(0,0,0),90)
 check(type(view)=="table" and view.origin,"камера наблюдения переключает вид")
 LocalPlayer():SetNW2Entity("sta_watch",NULL);M.removePlayer(watched)
 M.protect("admin close",frame.OnRemove,frame)
 M.protect("admin denied",A.HandleResponse,{kind="denied",message="Нет доступа"})
 vgui.Create=create
 -- Без ULX кнопка XGUI неактивна, вкладки подсистем без прав закрыты.
 check(A.SectionAllowed(A.SectionByID["Настройки"]) and not A.SectionAllowed(A.SectionByID["Группировки"]),"права вкладок из снимка")
end
