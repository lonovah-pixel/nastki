-- Ревью заданий: досылка состояния загрузившемуся клиенту (STALKER_PlayerReady), «Пережить выброс» и перезаход
-- посреди выброса, перебор предложений перезаходом, дальность разговора на клиенте, GUIDE LINE к далёкой цели.
-- Область мира X: 70 000 000…70 400 000 (квестодатели ставятся напрямую: предел координат файла карты — 1e7).
local M,check,section=TEST.M,TEST.check,TEST.section
local Q,C,S=STALKER_QUESTS,STALKER_CORE,STALKER_SETTINGS
local X=70000000

local function lastSent(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end
local function packet(tbl) local data=C.Pack(tbl);return 16+#data*8,{#data,data} end

section("Ревью заданий: настройки ("..M.Realm..")")
-- Клиент закрывает окно разговора и показывает «E — поговорить» по Q.Config.TalkDistance: без realm=shared у него
-- всегда значение по умолчанию (170), что бы ни выставил администратор.
check(S.Defs["quests.talk_distance"] and S.Defs["quests.talk_distance"].realm=="shared","дальность разговора доходит до клиента (realm=shared)")

if SERVER then
 local players={}
 local function join(nick,x,sid)
  local p=TEST.join({nick=nick,pos=Vector(X+x,0,0),aim=Vector(X+x+100,0,0),sid=sid});p.StfwProtected=0;players[#players+1]=p;return p
 end
 local function leave(p) hook.Run("PlayerDisconnected",p);M.removePlayer(p) end
 local function act(p,tbl) p.StalkerRate=nil;local len,vals=packet(tbl);M.netReceive("stalker_quests.action",len,p,vals) end
 local function use(ent,p) p.StalkerRate=nil;M.netSent={};ent:Use(p);return decode(lastSent("stalker_quests.dialog",p)) end
 local barman=Q.SpawnNPC({id="rvq_bar",profile="barman",name="Бармен",pos={x=X+1000,y=0,z=0},yaw=0})
 check(IsValid(barman),"квестодатель ревью поставлен")

 section("Ревью заданий: досылка состояния по STALKER_PlayerReady")
 local slow=join("Медленный клиент",1060)
 check(Q.Loaded(slow),"профиль заданий загружен после входа")
 -- Пакет из таймера PlayerInitialSpawn клиент на «Starting Lua» теряет; ядро зовёт STALKER_PlayerReady, когда Lua готов.
 Q.Dirty[slow]=nil;M.netSent={}
 hook.Run("STALKER_PlayerReady",slow)
 check(Q.Dirty[slow]==true,"STALKER_PlayerReady помечает состояние заданий к отправке")
 M.advance(1.1)
 local st=decode(lastSent("stalker_quests.state",slow))
 check(st and type(st.active)=="table","загрузившийся клиент получает состояние заданий")

 section("Ревью заданий: выброс и перезаход")
 local runner=join("Беглец",1050)
 local sid=runner:SteamID64()
 local key=Q.AddOffer(runner,barman,"bar_emission")
 act(runner,{op="accept",npc=barman:EntIndex(),key=key})
 local q=Q.Data(runner).active[1]
 check(q and q.tpl=="bar_emission","«Пережить выброс» взято")
 hook.Run("STEmissionStarted")
 check(q and q.armed,"выброс начался, сталкер жив — задание вооружено")
 -- Застигнутый выбросом под открытым небом выходит и заходит снова: возрождается у точки появления, как после гибели.
 leave(runner)
 local back=join("Беглец",1050,sid)
 local bq=Q.Data(back).active[1]
 check(bq and bq.tpl=="bar_emission" and not bq.armed,"после перезахода задание не вооружено (выход посреди выброса — как гибель)")
 hook.Run("STEmissionFinished")
 check(bq and not bq.done,"перезаход посреди выброса не засчитывает «Пережить выброс»")
 hook.Run("STEmissionStarted");hook.Run("STEmissionFinished")
 check(bq and bq.done,"следующий пережитый выброс засчитан")

 section("Ревью заданий: предложения и перезаход")
 local picky=join("Привереда",1080)
 local psid=picky:SteamID64()
 local dlg=use(barman,picky)
 local keys={};for _,o in ipairs(dlg and dlg.offers or {}) do keys[#keys+1]=o.key end
 check(#keys>0,"Бармен предлагает задания ("..#keys..")")
 leave(picky)
 local picky2=join("Привереда",1080,psid)
 local dlg2=use(barman,picky2)
 local keys2={};for _,o in ipairs(dlg2 and dlg2.offers or {}) do keys2[#keys2+1]=o.key end
 check(table.concat(keys,",")==table.concat(keys2,","),"перезаход не перебирает предложения и награды ("..table.concat(keys,",").." / "..table.concat(keys2,",")..")")

 section("Ревью заданий: очистка")
 for _,p in ipairs(players) do if IsValid(p) then STALKER_MARKERS.Clear("stq."..p:SteamID64()..".");leave(p) end end
 barman:Remove();Q.NPCEnts.rvq_bar=nil
 M.advance(2)
else
 section("Ревью заданий: GUIDE LINE к далёкой цели")
 local lp=LocalPlayer();local was=lp:GetPos()
 lp:SetPos(Vector(X,0,0))
 local function track(dist)
  local state={tracked="q1",max=5,daily=15,today=1,done=0,npcs={},history={},
   active={{uid="q1",title="Разведка",type="visit",objective="Посетите место",progress=0,goal=1,left=600,giverName="Связной",reward={money=700},
    pos={x=X+dist,y=0,z=0},label="Разведка: Дальний хутор"}}}
  local l,v=packet(state);M.protect("состояние: цель в "..dist,M.netReceive,"stalker_quests.state",l,nil,v)
  Q.Guide=nil
  return Q.GuideChevrons()
 end
 local near=track(5000)
 check(near and #near>=5,"цель в 5000 units: линия из шевронов ("..tostring(near and #near)..")")
 -- Цель дальше 200 шагов шеврона (≈15 000 units, ~290 м) — обычное расстояние на картах Зоны.
 for _,dist in ipairs({20000,60000}) do
  local list=track(dist)
  local nearest,farthest=math.huge,0
  for _,ch in ipairs(list or {}) do local dx=ch.pos.x-X;nearest=math.min(nearest,dx);farthest=math.max(farthest,dx) end
  check(list and #list>=5 and nearest<300 and farthest<=Q.Config.GuideLength,
   "цель в "..dist.." units: линия от игрока на "..Q.Config.GuideLength.." units ("..tostring(list and #list).." шевронов, ближний "..tostring(nearest)..")")
 end
 lp:SetPos(was)
 Q.State={active={},history={},npcs={},max=5,daily=15,today=0,done=0};Q.Guide=nil
end
