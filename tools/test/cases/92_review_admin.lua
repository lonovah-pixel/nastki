-- Ревью «Коменданта», выбросов, разделки и торговцев: перезапись чужого бана младшим уровнем, право выброса (events),
-- запрет смены оружия в обмороке, настройка «Выброс ранит NPC», правка butcher.* посреди разделки, выход трофея 0,
-- досылка состояния выброса по STALKER_PlayerReady. Область мира: X 30 000 000…30 100 000.
local M,check,section=TEST.M,TEST.check,TEST.section
local A,S,E,B=STALKER_ADMIN,STALKER_SETTINGS,ST_EMISSION,STALKER_BUTCHERING
local X=30000000

section("Ревью: выбросы, разделка, «Комендант» ("..M.Realm..")")
-- GM:PlayerSwitchWeapon: «Return true to prevent the switch» (gamemodes/base/gamemode/player_shd.lua).
-- Хук общий: на клиенте он нужен для предсказания (иначе оружие «переключается» и откатывается сервером).
do
 local p=SERVER and TEST.join({nick="Р92 Обморок",pos=Vector(X,0,0)}) or LocalPlayer()
 local wasAlive=p._alive;p._alive=true
 p:SetNW2Float("stem_unconscious",CurTime()+5)
 check(E.IsUnconscious(p) and hook.Run("PlayerSwitchWeapon",p,NULL,NULL)==true,"в обмороке смена оружия запрещена (хук возвращает true)")
 p:SetNW2Float("stem_unconscious",0)
 check(hook.Run("PlayerSwitchWeapon",p,NULL,NULL)==nil,"в сознании хук не вмешивается в смену оружия")
 p._alive=wasAlive
 if SERVER then M.removePlayer(p) end
end

if SERVER then
 local U=ULib.ucl
 local function rankOf(sid) return tonumber(sql.QueryValue("SELECT rank FROM sta_banmeta WHERE sid="..sql.SQLStr(sid))) end

 section("Ревью: повторный бан не перезаписывает бан старшего уровня")
 local super=M.addPlayer({nick="Р92 Комендант",superadmin=true,pos=Vector(X+100,0,0)})
 local admin=M.addPlayer({nick="Р92 Админ",admin=true,pos=Vector(X+200,0,0)})
 local mod=M.addPlayer({nick="Р92 Модератор",pos=Vector(X+300,0,0)})
 U.addUser(util.SteamIDFrom64(mod:SteamID64()),nil,nil,"moderator")
 check(A.Rank(super)==90 and A.Rank(admin)==60 and A.Rank(mod)==30,"уровни участников")
 local sid="76561198555555501";local id=util.SteamIDFrom64(sid)
 local r=A.Execute(super,{command="ban_sid",sid=sid,reason="Вечный бан",minutes=0})
 check(r.ok and ULib.bans[id] and ULib.bans[id].unban==0 and rankOf(sid)==90,"Комендант выдал бессрочный бан")
 r=A.Execute(mod,{command="ban_sid",sid=sid,reason="Сокращаю",minutes=10})
 check(not r.ok,"модератор не перезаписывает бессрочный бан Коменданта десятиминутным")
 check(ULib.bans[id] and ULib.bans[id].unban==0 and ULib.bans[id].reason=="Вечный бан" and rankOf(sid)==90,"срок, причина и ранг автора бана не изменились")
 r=A.Execute(admin,{command="ban_sid",sid=sid,reason="Присваиваю",minutes=60})
 local unban=A.Execute(admin,{command="unban",sid=sid})
 check(not r.ok and not unban.ok and A.GetBan(sid)~=nil,"администратор не «присваивает» бан старшего повторным баном, чтобы снять его")
 r=A.Execute(super,{command="ban_sid",sid=sid,reason="Замена",minutes=120})
 check(r.ok and ULib.bans[id].unban>os.time() and rankOf(sid)==90,"автор того же уровня меняет свой бан")
 -- Свой бан младший уровень по-прежнему продлевает.
 local sid2="76561198555555502"
 check(A.Execute(mod,{command="ban_sid",sid=sid2,reason="Флуд",minutes=30}).ok and A.Execute(mod,{command="ban_sid",sid=sid2,reason="Флуд снова",minutes=60}).ok,
  "модератор продлевает собственный бан")
 for _,s in ipairs({sid,sid2}) do ULib.unban(util.SteamIDFrom64(s));sql.Query("DELETE FROM sta_banmeta WHERE sid="..sql.SQLStr(s)) end
 -- Без ULib: та же проверка для таблицы sta_bans.
 local savedULib=ULib;ULib=nil
 r=A.Execute(super,{command="ban_sid",sid=sid,reason="Вечный бан",minutes=0})
 local cut=A.Execute(mod,{command="ban_sid",sid=sid,reason="Сокращаю",minutes=10})
 local ban=A.GetBan(sid)
 check(r.ok and not cut.ok and ban and tonumber(ban.expires)==0 and tonumber(ban.rank)==90,"без ULib бан старшего тоже не перезаписывается")
 sql.Query("DELETE FROM sta_bans WHERE sid="..sql.SQLStr(sid))
 ULib=savedULib

 section("Ревью: выброс — право events и в «Коменданте»")
 if E.State.phase>0 then E.Stop(true) end
 U.groupAllow("admin","stalker_events",true)
 check(A.Has(admin,"zone") and not A.Has(admin,"events") and not E.IsAdmin(admin),"у администратора отозвано право events (zone осталось)")
 r=A.Execute(admin,{command="emission_start"})
 check(not r.ok and E.State.phase==0,"без права events выброс не запускается и через «Коменданта» (как stem_start)")
 if E.State.phase>0 then E.Stop(true) end
 U.groupAllow("admin","stalker_events")
 r=A.Execute(admin,{command="emission_start"})
 check(r.ok and E.State.phase>0,"с правом events выброс запускается")
 r=A.Execute(admin,{command="emission_stop"})
 check(r.ok and E.State.phase==0,"и останавливается")
 for _,p in ipairs({super,admin,mod}) do local key=util.SteamIDFrom64(p:SteamID64());if U.users[key] then U.removeUser(key) end;M.removePlayer(p) end

 section("Ревью: досылка состояния выброса загрузившемуся клиенту")
 local late=M.addPlayer({nick="Р92 Поздний",pos=Vector(X+400,0,0)})
 M.netSent={}
 hook.Run("STALKER_PlayerReady",late)
 local sent=false;for _,s in ipairs(M.netSent) do if s.name=="stem.state" and s.to==late then sent=true end end
 check(sent,"STALKER_PlayerReady досылает stem.state")
 M.removePlayer(late)

 section("Ревью: настройка «Выброс ранит NPC»")
 local savedHooks={};for k,v in pairs(hook.GetTable().STEmissionCanDamage or {}) do savedHooks[k]=v end
 for k in pairs(savedHooks) do hook.Remove("STEmissionCanDamage",k) end
 local npc=ents.Create("npc_zombie");npc:SetPos(Vector(X+5000,0,0));npc:Spawn();npc:SetHealth(1000)
 -- Урон только по своему NPC: игроки других сценариев не страдают.
 hook.Add("STEmissionCanDamage","R92.OnlyNPC",function(ent) if ent~=npc then return false end end)
 check(S.Set("emission.damage_npcs",true) and E.Config.DamageNPCs==true,"настройка включена")
 E.Start();M.advance(20,.5)
 check(npc:Health()<1000,"выброс ранит NPC вне укрытия: "..tostring(npc:Health()))
 E.Stop(true)
 S.Set("emission.damage_npcs",nil);local hp=npc:Health()
 E.Start();M.advance(10,.5);E.Stop(true)
 check(npc:Health()==hp and E.Config.DamageNPCs==false,"по умолчанию NPC не страдают")
 hook.Remove("STEmissionCanDamage","R92.OnlyNPC");for k,v in pairs(savedHooks) do hook.Add("STEmissionCanDamage",k,v) end
 npc:Remove()

 section("Ревью: разделка — правка butcher.* посреди сессии")
 local cutter=TEST.join({nick="Р92 Мясник",pos=Vector(X+8000,0,0)})
 cutter:Give("weapon_crowbar");cutter:SelectWeapon("weapon_crowbar")
 S.Set("butcher.rounds",1)
 local rag=ents.Create("prop_ragdoll");rag:SetPos(Vector(X+8050,0,0))
 check(B.RegisterCorpse(rag,"npc_zombie"),"туша зарегистрирована")
 local ok,err=B.startButchering(rag,cutter,nil,1)
 local s=B.Sessions[cutter]
 check(ok and s and #s.rounds==1,"разделка в один разрез началась: "..tostring(err))
 local finished;hook.Add("STB_Finished","R92",function(_,_,res) finished=res end)
 -- Попадание 100% в первом разрезе: центр полосы под маркером в момент удара.
 local function aim(s) local round=s.rounds[1];round.center=B.Marker(CurTime()-s.lag-s.start,round.speed,round.offset);round.width=.5 end
 if s then
  S.Set("butcher.rounds",3)
  M.advance(s.start-CurTime()+1,.05);aim(s)
  M.netReceive("stb.hit",34,cutter,{s.token,1})
  check(s.hits[1] and s.hits[1]>.99,"попадание в первом разрезе засчитано")
  -- Второго разреза в этой сессии нет, хотя в настройке их теперь три.
  M.advance(s.start+2.2+.05-CurTime(),.05)
  check(B.Sessions[cutter]==s,"сессия ещё идёт (окно второго разреза по новой настройке)")
  local called,e=pcall(M.netReceive,"stb.hit",34,cutter,{s.token,2})
  check(called and s.hits[2]==nil,"удар по несуществующему разрезу отклонён без ошибки: "..tostring(e))
  M.advance(2)
  check(B.Sessions[cutter]==nil and finished and math.abs(finished.score-1)<1e-6,"счёт делится на число разрезов сессии: "..tostring(finished and finished.score))
 end
 -- Время разреза тоже из сессии: укороченная настройка не отнимает окно у уже начатой разделки.
 S.Set("butcher.rounds",1);M.advance(3)
 local rag2=ents.Create("prop_ragdoll");rag2:SetPos(Vector(X+7950,0,0));B.RegisterCorpse(rag2,"npc_zombie")
 ok,err=B.startButchering(rag2,cutter,nil,1);s=B.Sessions[cutter]
 check(ok and s and s.seconds==2.2,"вторая разделка началась: "..tostring(err))
 if s then
  S.Set("butcher.round_seconds",1)
  M.advance(s.start-CurTime()+1.5,.05);aim(s)
  M.netReceive("stb.hit",34,cutter,{s.token,1})
  check(s.hits[1] and s.hits[1]>.99,"удар на 1,5 с засчитан в окне сессии (2,2 с), хотя настройка уже 1 с")
  M.advance(3)
 end
 hook.Remove("STB_Finished","R92")
 S.Set("butcher.rounds",nil);S.Set("butcher.round_seconds",nil)
 M.removePlayer(cutter)
end

section("Ревью: выход трофея 0 ("..M.Realm..")")
do
 local meat;for _,part in ipairs(B.Config.Parts) do if part.id=="meat" then meat=part end end
 local base=meat.base;meat.base=0
 local r=B.Roll(B.Config.Mutants.npc_zombie,meat,1,function() return .5 end)
 check(r.grade=="perfect" and r.count==0,"выход 0 в настройке — трофей не выдаётся: "..tostring(r.count))
 meat.base=base
 r=B.Roll(B.Config.Mutants.npc_headcrab,B.Config.Parts[2],.4,function() return .5 end)
 check(r.count==1,"малый выход по-прежнему округляется до одной штуки")
end
