-- Ревью радиации и событий: позиция зоны из Vector GMod, досылка состояния событий загрузившемуся клиенту,
-- награда рейда союзникам-«Военным», соклановцы цели охоты (выход и повторное вступление), общий лимит артефактов
-- после шторма, имя владельца маячка для незнакомца. Область мира: X 50 000 000…50 400 000
-- (зоны радиации — в углу карты 16 000 000, ближе к центру их не пускает предел координат R.Limits.coord).
local M,check,section=TEST.M,TEST.check,TEST.section
local R,E,C=STALKER_RAD,STALKER_EVENTS,STALKER_CORE
local X=50000000

local function lastTo(name,to)
 for i=#(M.netSent or {}),1,-1 do local s=M.netSent[i];if s.name==name and (to==nil or s.to==to) then return s end end
end
local function decode(s) if not s or not s.data then return end;return util.JSONToTable(util.Decompress(s.data[2]) or "") end

-- В GMod type(Vector) — "Vector" (garrysmod/lua/includes/util.lua: function isvector(v) return type(v)=="Vector" end),
-- в моке вектор — таблица. На время вызова fn код аддонов видит векторы как в игре, код мока — как раньше.
local VM=getmetatable(Vector(0,0,0));local rawtype=type
local function gmodType(v)
 local t=rawtype(v)
 if t=="table" and getmetatable(v)==VM and not tostring(debug.getinfo(2,"S").source):find("mock_gmod",1,true) then return "Vector" end
 return t
end
local function asGMod(fn,...)
 type=gmodType
 local r={pcall(fn,...)}
 type=rawtype
 return unpack(r)
end

section("Ревью радиации: позиция зоны из Vector GMod ("..M.Realm..")")
do
 local ok,pos=asGMod(R.CleanPos,Vector(16000000.26,16000000,3))
 check(ok and rawtype(pos)=="table" and pos.x==16000000.3 and pos.y==16000000 and pos.z==3,"CleanPos принимает Vector (type → \"Vector\" в GMod): "..tostring(pos))
 check(select(2,asGMod(R.CleanPos,{x=1,y=2,z=3})) and select(2,asGMod(R.CleanPos,"1 2 3"))==nil,"таблица {x,y,z} принимается, строка — нет")
end

if SERVER then
 if R.Ready then
  -- Зона по прицелу и «под собой» (сеть, консоль) приходит в AddZone/UpdateZone вектором из GetEyeTrace/GetPos.
  local ok,id,why=asGMod(R.AddZone,{name="Ревью: угол карты",pos=Vector(16000000,16000000,0),radius=300,rate=1})
  check(ok and id and R.ByID[id],"AddZone с позицией Vector создаёт зону: "..tostring(why))
  if id and R.ByID[id] then
   local okMove,moved,err=asGMod(R.UpdateZone,id,{pos=Vector(16000100,16000000,0)})
   check(okMove and moved==true and R.ByID[id].pos.x==16000100,"UpdateZone переносит зону в Vector: "..tostring(err))
   R.RemoveZone(id)
  end
 else
  check(false,"файл зон радиации готов к правке (оставлен сценарием 32): "..tostring(R.LoadError))
 end

 local players={}
 local function join(nick,x,y) local p=TEST.join({nick=nick,pos=Vector(X+x,y or 0,0),aim=Vector(X+x+100,y or 0,0)});p.StfwProtected=0;players[#players+1]=p;return p end
 local function setFaction(p,id) p:SetNW2Bool("stfw_joined",id~=nil);p:SetNW2String("stfw_faction",id or "loner") end

 section("Ревью событий: досылка состояния загрузившемуся клиенту")
 local slow=join("Ревью: медленный клиент",0)
 M.netSent={}
 hook.Run("STALKER_PlayerReady",slow)
 local st=decode(lastTo("stalker_events.state",slow))
 check(st and type(st.active)=="table" and type(st.beacons)=="table","STALKER_PlayerReady досылает снимок событий (таймер 4 с медленный клиент теряет)")

 section("Ревью событий: рейд и союзники-«Военные»")
 check(not E.MajorActive(),"крупных событий нет перед проверкой")
 local mil=join("Ревью: военный",100000);local stalker=join("Ревью: сталкер",100200)
 setFaction(mil,"military");setFaction(stalker,nil)
 check(E.Start("raid",{pos=Vector(X+100500,0,0)}),"рейд запущен")
 local squad=E.Active.raid and E.AliveNPC(E.Active.raid) or {}
 local npc=squad[1]
 check(IsValid(npc) and hook.Run("canEarnNPCKillPay",mil,npc)==false,"«Военный» не получает DarkRP-награду за бойца союзного отряда")
 check(IsValid(npc) and hook.Run("canEarnNPCKillPay",stalker,npc)~=false,"сталкер получает награду за бойца рейда")
 if IsValid(npc) then local d=DamageInfo();d:SetDamage(500);d:SetAttacker(mil);d:SetDamageType(DMG_BULLET);npc:TakeDamageInfo(d) end
 check((C.GetStats(mil).events or 0)==0,"убийство союзного бойца не засчитано участием в событии")
 if squad[2] then local d=DamageInfo();d:SetDamage(500);d:SetAttacker(stalker);squad[2]:TakeDamageInfo(d) end
 check((C.GetStats(stalker).events or 0)==1,"сталкеру участие засчитано")
 E.Stop("raid","admin")
 setFaction(mil,nil)

 section("Ревью событий: охота за головой и соклановцы")
 local tgt=join("Ревью: цель",150000);local mate=join("Ревью: соклановец",150300)
 local recruit=join("Ревью: новобранец",150600);local outsider=join("Ревью: охотник",150900)
 setFaction(tgt,"duty");setFaction(mate,"duty");setFaction(recruit,nil);setFaction(outsider,nil)
 check(E.Start("bounty",{target=tgt}),"охота на бойца «Долга»")
 -- Свой выходит из группировки перед выстрелом (потом лидер примет его обратно).
 setFaction(mate,nil)
 local m0=mate._money
 M.kill(tgt,mate)
 check(mate._money==m0 and not E.Active.bounty,"вышедший перед выстрелом соклановец не получает награду за голову")
 M.spawn(tgt);setFaction(tgt,"duty")
 check(E.Start("bounty",{target=tgt}),"вторая охота")
 -- Вступил во время охоты, вышел и выстрелил.
 setFaction(recruit,"duty");E.Defs.bounty.think(E.Active.bounty);setFaction(recruit,nil)
 m0=recruit._money
 M.kill(tgt,recruit)
 check(recruit._money==m0,"вступивший во время охоты и вышедший — тоже свой, награды нет")
 M.spawn(tgt);setFaction(tgt,"duty")
 -- Цель сама выходит из группировки, чтобы награда досталась своему.
 setFaction(mate,"duty")
 check(E.Start("bounty",{target=tgt}),"третья охота")
 setFaction(tgt,nil)
 m0=mate._money
 M.kill(tgt,mate)
 check(mate._money==m0,"цель вышла из группировки перед смертью — соклановец всё равно без награды")
 M.spawn(tgt);setFaction(tgt,"duty");setFaction(mate,nil)
 check(E.Start("bounty",{target=tgt}),"четвёртая охота")
 m0=outsider._money
 M.kill(tgt,outsider)
 check(outsider._money==m0+E.Config.BountyReward,"посторонний охотник получает награду")
 M.spawn(tgt);setFaction(tgt,nil)

 section("Ревью событий: шторм возвращает общий лимит артефактов")
 local Z=STALKER_ZONE
 if Z and Z.World and Z.BuildField and Z.CountArtifacts and Z.Config then
  local savedMax=Z.Config.MaxArtifacts
  -- Общий лимит карты меньше лимита поля: в обычное время поле держит 2 артефакта из 4.
  Z.Config.MaxArtifacts=Z.CountArtifacts()+2
  Z.World.fields.rv94={id="rv94",name="Ревью-поле",pos={x=X+200000,y=0,z=0},radius=600,count=4,artifacts=4,types={electro=true}}
  Z.BuildField("rv94")
  local rt=Z.Runtime.fields.rv94
  local function fieldCount() local n=0;for _,e in ipairs(rt.artifacts) do if IsValid(e) then n=n+1 end end;return n end
  check(fieldCount()==2 and Z.CountArtifacts()==Z.Config.MaxArtifacts,"до шторма поле упирается в общий лимит: "..fieldCount())
  check(E.Start("storm"),"шторм запущен")
  check(fieldCount()>2,"шторм поднял общий лимит: в поле "..fieldCount())
  E.Stop("storm","admin")
  check(Z.CountArtifacts()<=Z.Config.MaxArtifacts and fieldCount()==2,"после шторма общий лимит карты снова соблюдается: "..Z.CountArtifacts().."/"..Z.Config.MaxArtifacts)
  for _,e in ipairs(rt.anomalies) do if IsValid(e) then e:Remove() end end
  for _,e in ipairs(rt.artifacts) do if IsValid(e) then e:Remove() end end
  Z.World.fields.rv94=nil;Z.Runtime.fields.rv94=nil;Z.Config.MaxArtifacts=savedMax
 end

 section("Ревью событий: чужой маячок не называет владельца")
 local owner=join("Ревью: Владелец Тайный",300000);local passer=join("Ревью: прохожий",300040)
 STALKER_INV.GiveItem(owner,"beacon",1)
 local okB,b=E.PlaceBeacon(owner,"self","Схрон")
 check(okB and IsValid(b),"маячок поставлен")
 if okB then
  M.netSent={};b:Use(passer)
  local n=decode(lastTo("stalker_core.notify",passer))
  check(IsValid(b) and n and n.text and n.text:find("Схрон",1,true) and not n.text:find("Владелец Тайный",1,true),"прохожему — подпись маячка без имени владельца: "..tostring(n and n.text))
  b:Remove()
 end

 E.StopAll("cleanup")
 for _,p in ipairs(players) do M.removePlayer(p) end
else
 section("Ревью событий: имя владельца маячка у незнакомца (клиент)")
 local SO=STALKER_SOCIAL;local lp=LocalPlayer();local sid="76561198000949494"
 local b=ents.Create("stalker_beacon");b:SetPos(Vector(X,100,0));b:Spawn()
 b:SetLabel("Схрон");b:SetOwnerName("Тайный Вася");b:SetOwnerSID(sid)
 if type(SO)=="table" and type(SO.Config)=="table" then
  local hide,known=SO.Config.HideNames,SO.MyKnown
  SO.Config.HideNames=true;SO.MyKnown={}
  local text=E.HintFor(b,lp) or ""
  check(not text:find("Тайный Вася",1,true) and text:find("Незнакомец",1,true),"незнакомец не видит имя владельца маячка: "..text)
  SO.MyKnown={[sid]={name="Тайный Вася",at=0}}
  check((E.HintFor(b,lp) or ""):find("Тайный Вася",1,true),"знакомый видит имя владельца")
  SO.Config.HideNames,SO.MyKnown=hide,known
 end
 b:SetOwnerSID(lp:SteamID64());b:SetOwnerName(lp:Nick())
 local own=E.HintFor(b,lp) or ""
 check(own:find("E — забрать",1,true) and own:find(lp:Nick(),1,true),"свой маячок: своё имя и «E — забрать»")
 b:Remove()
end
