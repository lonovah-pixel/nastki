-- Ревью STALKER Factions: доказательства найденных ошибок (каждая проверка падала до исправления).
-- Область мира: X 20 000 000 и дальше.
local M,check,section=TEST.M,TEST.check,TEST.section
local F,C=STFW,STALKER_CORE

local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end

if SERVER then
 local X=20000000
 local players={}
 local function join(nick,x,extra)
  local o=extra or {};o.nick=nick;o.pos=Vector(X+x,0,0)
  local p=TEST.join(o);p.StfwProtected=0;players[#players+1]=p;return p
 end
 local admin=join("Ревизор ГП",0,{superadmin=true})
 local leader=join("Лидер ренегатов",1000)
 local member=join("Боец ренегатов",1100)
 local outsider=join("Посторонний",1200)
 check(F.World.leaders.renegades==nil,"у «Ренегатов» нет лидера до проверки")
 F.SetFaction(leader,"renegades",true);F.SetFaction(member,"renegades",true)
 F.Editor(admin,{op="leader",faction="renegades",sid=leader:SteamID64()})
 check(F.IsLeader(leader),"лидер «Ренегатов» назначен")

 section("Ревью группировок: сохранение профилей при входе и выходе")
 -- Профили всех, кто когда-либо заходил, держатся в памяти. Вход и выход игрока не должны переписывать их все.
 local fake={}
 for i=1,300 do local sid=string.format("7656119909%07d",i);local d=F.ProfileDefaults(F.NewProfile());d.name="Архив "..i;F.Profiles[sid]=d;fake[#fake+1]=sid end
 local orig=sql.Query;local writes=0
 sql.Query=function(q) if type(q)=="string" and q:find("INTO stfw_profiles",1,true) then writes=writes+1 end;return orig(q) end
 local newcomer=join("Новичок ревизии",1300)
 local joinWrites=writes;writes=0
 local row=orig("SELECT payload FROM stfw_profiles WHERE sid="..sql.SQLStr(newcomer:SteamID64()))
 hook.Run("PlayerDisconnected",newcomer)
 local leaveWrites=writes
 sql.Query=orig
 check(joinWrites<=2,"вход игрока сохраняет только его профиль, записей: "..joinWrites)
 check(leaveWrites<=2,"выход игрока сохраняет только его профиль, записей: "..leaveWrites)
 check(row and util.JSONToTable(row[1].payload).name=="Новичок ревизии","новый профиль записан в SQLite при входе")
 M.removePlayer(newcomer)
 for _,sid in ipairs(fake) do F.Profiles[sid]=nil end
 sql.Query("DELETE FROM stfw_profiles WHERE sid LIKE '7656119909%'")

 section("Ревью группировок: stfw_approve и пустой отзыв допуска")
 local rev=F.World.revision
 for _=1,12 do M.command(leader,"stfw_approve",outsider:SteamID64()) end
 local commits=F.World.revision-rev
 check(commits>=1 and commits<=3,"stfw_approve ограничен по частоте, записей мира: "..commits)
 check(F.HasAdmission(F.Load(outsider),"renegades"),"допуск выдан")
 check(F.GrantAdmission(leader,outsider:SteamID64(),true),"действующий допуск отозван")
 rev=F.World.revision;M.netSent={}
 local ok,err=F.GrantAdmission(leader,outsider:SteamID64(),true)
 local toasted=false;for _,s in ipairs(M.netSent) do if s.to==outsider then toasted=true end end
 check(not ok and F.World.revision==rev and not toasted,"отзыв несуществующего допуска: без записи и без уведомления цели ("..tostring(err)..")")

 section("Ревью группировок: способности без сознания")
 local w=table.Copy(F.World);F.Prog(w,"renegades").credits=500;F.Commit(w,{})
 check(ST_EMISSION and ST_EMISSION.IsUnconscious,"система выбросов загружена")
 leader:SetNW2Float("stem_unconscious_until",CurTime()+60)
 check(C.Unconscious(leader),"лидер без сознания")
 local credits=F.ProgRead("renegades").credits
 ok,err=F.UseAbility(leader,"rally")
 check(not ok and err=="unconscious" and F.ProgRead("renegades").credits==credits and F.CooldownLeft("renegades","rally")==0,"без сознания способность не применяется: "..tostring(err))
 check(F.L("unconscious")~="unconscious","текст отказа без сознания")
 leader:SetNW2Float("stem_unconscious_until",0)
 check(F.UseAbility(leader,"rally"),"в сознании способность применяется")
 STALKER_MARKERS.Clear("stfw.rally.")

 section("Ревью группировок: ответ на stfw.cmd не повторяет данные клиента")
 local junk=string.rep("x",1500)
 local data=C.Pack({op=junk});M.netSent={}
 M.netReceive("stfw.cmd",16+#data*8,leader,{#data,data})
 local st=decode(lastSent("stfw.state",leader))
 check(st and st.reply and st.reply.cmd and st.reply.op==nil,"неизвестная команда не возвращается клиенту: "..tostring(st and st.reply and st.reply.op and #st.reply.op))
 data=C.Pack({op="unban"});M.advance(1);M.netSent={}
 M.netReceive("stfw.cmd",16+#data*8,leader,{#data,data})
 st=decode(lastSent("stfw.state",leader))
 check(st and st.reply and st.reply.op=="unban","известная команда в ответе сохраняется")

 section("Ревью группировок: кошелёк DarkRP ещё не загружен")
 -- DarkRP: addMoney = getDarkRPVar("money")+amount; до загрузки данных игрока (DarkRPUnInitialized) money=nil.
 w=table.Copy(F.World);F.Prog(w,"renegades").treasury=1000;F.Commit(w,{})
 local wallet=leader._money;leader._money=nil;leader.DarkRPUnInitialized=true
 local done,okw,errw=pcall(F.TreasuryWithdraw,leader,100)
 check(done and not okw and errw=="no_darkrp" and F.Treasury("renegades")==1000,"снятие при незагруженном кошельке отклонено до списания казны: "..tostring(errw))
 leader._money=wallet;leader.DarkRPUnInitialized=nil
 admin:SetPos(Vector(X+5000,0,0))
 local okp,_,lonerPoint=F.Editor(admin,{op="create",placement="feet",name="Ревизия: лагерь",pointType="camp",radius=300,height=200,radiation=0,anomaly=0,base=false,owner="loner"})
 admin:SetPos(Vector(X,0,0))
 local fresh=join("Одиночка без кошелька",6000);local ready=join("Одиночка с кошельком",6100)
 F.SetFaction(fresh,"loner",true);F.SetFaction(ready,"loner",true)
 fresh._money=nil;fresh.DarkRPUnInitialized=true
 local m=ready._money
 local ran,err2=pcall(F.RunIncome)
 check(okp and ran,"доход одиночек не падает на незагруженном кошельке: "..tostring(err2))
 check(ready._money>m and fresh._money==nil,"доход получил только игрок с загруженным кошельком")
 fresh._money=3000;fresh.DarkRPUnInitialized=nil
 F.Editor(admin,{op="delete",id=lonerPoint})

 section("Ревью группировок: повторное включение в ту же группировку")
 for _=1,3 do F.SetRank(leader,member:SteamID64(),1) end
 check(F.Load(member).frank==4,"боец повышен до офицера")
 local fired=0;hook.Add("STFW_FactionChanged","TEST.Review91",function(p,id) if id=="renegades" then fired=fired+1 end end)
 check(F.SetFaction(leader,"renegades",true),"администратор повторно включает лидера в его группировку")
 check(F.IsLeader(leader) and leader:GetNW2Bool("stfw_leader",false),"лидерство сохранено при повторном включении")
 check(F.SetFaction(member,"renegades",true) and F.Load(member).frank==4,"звание сохранено при повторном включении: "..F.Load(member).frank)
 check(fired==2,"хук STFW_FactionChanged вызван (DarkRP заново выдаёт профессию)")
 hook.Remove("STFW_FactionChanged","TEST.Review91")
 check(F.SetFaction(member,"bandits",true) and F.IsMember(member,"bandits") and F.Load(member).frank==1,"переход в другую группировку сбрасывает звание")

 section("Ревью группировок: очистка")
 F.Editor(admin,{op="leader",faction="renegades",sid=""})
 for _,p in ipairs(players) do F.ExpelSID(p:SteamID64()) end
 w=table.Copy(F.World);F.Prog(w,"renegades").credits=0;F.Prog(w,"renegades").cooldowns={};F.Commit(w,{})
 check(F.MemberCount("renegades")==0 and F.World.leaders.renegades==nil,"тестовые профили исключены")
 for _,p in ipairs(players) do if p._valid then M.removePlayer(p) end end
else
 section("Ревью группировок: меню командования не сбрасывает выбор из-за прогресса захвата")
 local sid=LocalPlayer():SteamID64()
 local function state(progress)
  return {me={faction="renegades",joined=true,xp=0,rep={},captures=0,kills=0,frank=5,role="leader"},role="leader",leader=true,
   points={p1={id="p1",name="Хутор",kind="camp",owner="duty",pos={x=0,y=0,z=0},radius=300,height=200,radiation=0,anomaly=0,progress=progress,armed="freedom"}},
   relations={},leaders={renegades=sid},proposals={},history={},top={},members={},traders={},progression={renegades={credits=10,levels={},treasury=100}},revision=0,
   command={role="leader",leader=sid,roster={{sid=sid,name="Я",frank=5,online=true,leader=true,xp=0}},candidates={},count=1,cap=15,online=1,credits=10,
    income={money=0,supply=0,held=0,interval=60},cooldowns={},buffs={},treasury=100,ledger={},approvals={},banCost=500000}}
 end
 local builds={};local origPages={}
 for _,id in ipairs({"treasury","overview"}) do
  origPages[id]=F.CommandPages[id]
  F.CommandPages[id]=function(...) builds[id]=(builds[id] or 0)+1;return origPages[id](...) end
 end
 F.State=state(.2);F.StateAt=CurTime()
 M.protect("меню командования: казна",F.OpenCommand,"treasury")
 -- Окно в моке — заглушка: делаем его «живым», как настоящую панель.
 if F.CommandFrame then rawset(F.CommandFrame,"IsValid",function() return true end) end
 F.CommandTab("treasury")
 local before=builds.treasury or 0
 check(before>=1,"вкладка «Казна» построена")
 F.State=state(.4);hook.Run("STFW_StateUpdated",F.State)
 check((builds.treasury or 0)==before,"вкладка «Казна» не перестраивается из-за прогресса захвата: "..((builds.treasury or 0)-before))
 F.CommandTab("overview");before=builds.overview or 0
 F.State=state(.6);hook.Run("STFW_StateUpdated",F.State)
 check((builds.overview or 0)==before+1,"«Обзор» обновляет прогресс захвата")
 for id,fn in pairs(origPages) do F.CommandPages[id]=fn end
 if IsValid(F.CommandFrame) then F.CommandFrame:Remove() end
 F.CommandFrame=nil;F.CommandCurrent=nil

 section("Ревью группировок: кнопка способности после перезарядки")
 -- Снимки приходят каждые 3 с, а вкладка не перестраивается (перезарядки не входят в отпечаток окна).
 local U=STALKER_STYLE;local origButton=U.Button;local buttons={}
 U.Button=function(parent,label,fn,kind)
  local b=origButton(parent,label,fn,kind)
  if label=="Применить" then buttons[#buttons+1]=b;rawset(b,"SetEnabled",function(self,v) rawset(self,"_on",v) end) end
  return b
 end
 local s=state(.2);s.command.cooldowns={rally=100};s.command.credits=100;F.State=s;F.StateAt=CurTime()
 M.protect("вкладка способностей",F.CommandPages.abilities,M.stub("body"),s,s.command)
 U.Button=origButton
 local rally=buttons[1]
 check(F.AbilityOrder[1]=="rally" and rally and type(rawget(rally,"Think"))=="function","кнопка «Сбор» построена")
 if rally then
  rally.Think(rally);check(rawget(rally,"_on")==false,"на перезарядке кнопка неактивна")
  local s2=state(.2);s2.command.cooldowns={rally=0};s2.command.credits=100;F.State=s2;F.StateAt=CurTime()
  rally.Think(rally);check(rawget(rally,"_on")==true,"после перезарядки кнопка снова активна без перестройки окна")
 end
 F.State=nil
end
