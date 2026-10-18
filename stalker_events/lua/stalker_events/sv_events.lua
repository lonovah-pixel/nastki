-- Пять событий Зоны. Каждое: start (место, NPC, метки, новость), think (раз в секунду), stop (итог и награды).
local E=STALKER_EVENTS
local C=STALKER_CORE
local Cfg=E.Config
local function info(id,field) return E.Info[id] and E.Info[id][field] end
local function minutes(key) return function() return Cfg[key]*60 end end
local function weight(id) return function() return Cfg.Weights[id] or 0 end end

-- Взвешенный выбор строки: rows — массив, w(row) — вес.
local function pickWeighted(rows,w)
 local total=0;for _,row in ipairs(rows) do total=total+w(row) end
 if total<=0 then return end
 local roll=math.Rand(0,total)
 for _,row in ipairs(rows) do roll=roll-w(row);if roll<=0 then return row end end
 return rows[#rows]
end
E.PickWeighted=pickWeighted

--[[ Сбитый груз ]]
function E.RandomArtifact()
 local S=STALKER_INV;local Z=STALKER_ZONE;if not S or not S.Items then return end
 local pool={}
 for id,a in pairs(Z and Z.Artifacts or {}) do if S.Items[id] and type(a)=="table" then pool[#pool+1]={id=id,w=tonumber(a.weight) or 1} end end
 table.sort(pool,function(a,b) return a.id<b.id end)
 local row=pickWeighted(pool,function(r) return r.w end)
 if row then return row.id end
 if S.Items.artifact then return "artifact" end
end
-- Содержимое ящика: {{предмет, количество}, …} только из существующих предметов.
function E.RollCargo()
 local S=STALKER_INV;local items={}
 if not S or not S.Items then return items end
 local function add(id,n)
  if not S.Items[id] or n<1 then return end
  for _,row in ipairs(items) do if row[1]==id then row[2]=row[2]+n;return end end
  items[#items+1]={id,n}
 end
 for _,group in ipairs(E.CargoLoot) do
  if math.random()<=group.chance then
   local pool={};for _,row in ipairs(group.items) do if S.Items[row[1]] then pool[#pool+1]=row end end
   for _=1,math.random(group.rolls[1],group.rolls[2]) do
    local row=pickWeighted(pool,function(r) return r[4] end)
    if row then add(row[1],math.random(row[2],row[3])) end
   end
  end
 end
 if math.random(1,100)<=Cfg.CargoArtifactChance then local id=E.RandomArtifact();if id then add(id,1) end end
 return items
end
function E.CargoCount(crate)
 local n=0;for _,row in ipairs(crate and crate.Items or {}) do n=n+row[2] end
 return n
end

function E.UseCargo(ply,crate)
 if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not IsValid(crate) or C.Unconscious(ply) then return end
 if ply:GetShootPos():DistToSqr(crate:WorldSpaceCenter())>160*160 then return end
 if crate:GetOpened() then return E.TakeCargo(ply,crate) end
 if C.Hold.IsHolding(ply) then return end
 C.Hold.Start(ply,crate,Cfg.CargoHold,"Вскрытие груза",function(p,ent) E.OpenCargo(p,ent) end,
  {range=130,check=function(_,ent) if not IsValid(ent) then return "Груз пропал" end end})
end
function E.OpenCargo(ply,crate)
 if not IsValid(crate) or not IsValid(ply) then return end
 if not crate:GetOpened() then
  crate:SetOpened(true);crate:EmitSound("buttons/button14.wav",75,80)
  hook.Run("STALKER_EVENTS_CargoOpened",ply,crate)
  if crate.Event and E.Active.cargo==crate.Event then C.News(ply:Nick().." вскрыл сбитый груз.","event") end
 end
 E.TakeCargo(ply,crate)
end
-- Забрать из ящика всё, что влезает в рюкзак; остальное остаётся в ящике.
function E.TakeCargo(ply,crate)
 local S=STALKER_INV
 if not crate.Items or #crate.Items==0 then C.Notify(ply,"Ящик пуст","info",3);return end
 if not S or not S.InventoryReady or not S.InventoryReady(ply) then C.Notify(ply,"Инвентарь недоступен","warn",4);return end
 if hook.Run("STALKER_INV_CanPickup",ply,crate,{id=crate.Items[1][1],count=crate.Items[1][2]})==false then return end
 S.CaptureEquipment(ply)
 local inv=table.Copy(ply.StalkerInventory);local got,left={},{}
 for _,row in ipairs(crate.Items) do
  local id,count=row[1],row[2];local placed=0
  if S.Items[id] then
   -- S.Insert атомарен: ищем наибольшее количество, которое помещается.
   for n=count,1,-1 do local nextInv=S.Insert(inv,id,n);if nextInv then inv=nextInv;placed=n;break end end
   if placed>0 then got[#got+1]=S.Items[id].name.." ×"..placed end
   if count>placed then left[#left+1]={id,count-placed} end
  end
 end
 if #got==0 then C.Notify(ply,"Нет места в рюкзаке","warn",4);return end
 crate.Items=left;crate:SetItemCount(E.CargoCount(crate))
 S.Commit(ply,inv,"Из груза: "..table.concat(got,", "))
 ply:EmitSound("items/battery_pickup.wav",70,90)
 E.Participate(crate.Event,ply)
 if #left>0 then C.Notify(ply,"Не влезло в рюкзак — осталось в ящике: "..E.CargoCount(crate).." шт.","info",5)
 elseif crate.Event and E.Active.cargo==crate.Event then E.Stop("cargo","done") end
 return true
end

E.Register({id="cargo",name=info("cargo","name"),description=info("cargo","desc"),duration=minutes("CargoMinutes"),weight=weight("cargo"),minPlayers=1,
 canStart=function() if not STALKER_INV or not STALKER_INV.Items or not STALKER_INV.Insert then return false,"Не установлен аддон инвентаря" end;return true end,
 start=function(ev,opts)
  local pos,name=opts.pos,opts.pos and "под прицелом администратора" or nil
  if not pos then pos,name=E.PickPoint() end
  if not pos then return false,"Не найдено место для груза" end
  local crate=ents.Create("stalker_cargo");if not IsValid(crate) then return false,"Сущность груза недоступна" end
  crate:SetPos(pos+Vector(0,0,2));crate:SetAngles(Angle(0,math.random(0,359),0))
  crate.Event=ev;crate.Items=E.RollCargo()
  crate:Spawn();crate:SetItemCount(E.CargoCount(crate));crate:SetExpires(ev.ends)
  ev.data.crate=crate;ev.pos=pos;ev.where=name
  local fx=EffectData();fx:SetOrigin(pos);fx:SetMagnitude(1);fx:SetScale(1);util.Effect("Explosion",fx,true,true)
  local lo,hi=math.min(Cfg.CargoGuardsMin,Cfg.CargoGuardsMax),math.max(Cfg.CargoGuardsMin,Cfg.CargoGuardsMax)
  for _=1,math.random(lo,hi) do E.SpawnMutant(ev,E.Around(pos,180,520),E.PickMutant(nil,false)) end
  E.Marker(ev,"crate",{pos=pos,kind="cargo",label="Сбитый груз"})
  C.News("Сбитый груз! Вертолёт снабжения потерял ящик"..(name and (" ("..name..")") or "")..". Место отмечено, рядом бродят мутанты.","event")
  return true
 end,
 think=function(ev)
  local crate=ev.data.crate
  if not IsValid(crate) then E.Stop(ev.id,"done") end
 end,
 stop=function(ev,reason)
  local crate=ev.data.crate
  local opened=IsValid(crate) and crate:GetOpened()
  if IsValid(crate) then crate.Event=nil;crate:Remove() end
  if reason=="done" then C.News("Сбитый груз разобран.","event")
  elseif reason=="time" then C.News(opened and "Остатки сбитого груза растащили мутанты." or "Сбитый груз так никто и не вскрыл — ящик забрали военные.","event") end
 end})

--[[ Гон мутантов ]]
function E.HuntWave(ev)
 ev.data.wave=(ev.data.wave or 0)+1
 local n=Cfg.HuntWaveSize+math.floor(#player.GetHumans()/4)
 -- Последняя волна может привести сильного мутанта.
 local last=ev.ends-CurTime()<Cfg.HuntWaveInterval
 local spawned=0
 for i=1,n do
  local npc=E.SpawnMutant(ev,E.Around(ev.pos,250,800),E.PickMutant(ev.data.types,last and i==1))
  if IsValid(npc) then spawned=spawned+1;local target=E.NearestPlayer(ev.pos,4000);E.Steer(npc,target and target:GetPos() or ev.pos) end
 end
 ev.data.nextWave=CurTime()+Cfg.HuntWaveInterval
 return spawned
end
E.Register({id="hunt",name=info("hunt","name"),description=info("hunt","desc"),duration=minutes("HuntMinutes"),weight=weight("hunt"),minPlayers=2,
 start=function(ev,opts)
  local pos,name,src=opts.pos,opts.pos and "под прицелом администратора" or nil,nil
  if not pos then pos,name,src=E.PickPoint("lair") end
  if not pos then return false,"Не найдено место для гона" end
  ev.pos=pos;ev.where=name;ev.data.types=src and type(src.types)=="table" and next(src.types) and src.types or nil
  E.RewardMult=math.max(1,Cfg.HuntRewardMult)
  ev.info="Награда за мутантов ×"..E.RewardMult
  E.Marker(ev,"lair",{pos=pos,label="Гон мутантов"})
  E.HuntWave(ev)
  C.News("Гон мутантов"..(name and (" ("..name..")") or "").."! Мутанты выходят волнами. Награда за каждого мутанта ×"..E.RewardMult.." до конца гона.","danger")
  return true
 end,
 think=function(ev)
  local now=CurTime()
  if now>=(ev.data.nextWave or 0) and ev.ends-now>15 then E.HuntWave(ev) end
  -- Стая не стоит на месте: свободные от боя мутанты бегут к ближайшему игроку.
  if now>=(ev.data.nextSteer or 0) then
   ev.data.nextSteer=now+10
   for _,npc in ipairs(E.AliveNPC(ev)) do local p=E.NearestPlayer(npc:GetPos(),4000);if p then E.Steer(npc,p:GetPos()) end end
  end
 end,
 stop=function(ev,reason)
  E.RewardMult=1
  if reason=="time" then C.News("Гон мутантов закончился: стая ушла в логово. Убито мутантов: "..(ev.kills or 0)..".","event") end
 end})

--[[ Артефактный шторм: лимит артефактов (общий и каждого поля) временно умножается ]]
local function stormFields()
 local Z=STALKER_ZONE
 if not Z or not Z.World or type(Z.World.fields)~="table" or not Z.TopUpArtifacts or not Z.Config then return end
 local list={}
 for id,f in pairs(Z.World.fields) do if type(f)=="table" and (tonumber(f.artifacts) or 0)>0 then list[#list+1]=id end end
 table.sort(list)
 return list
end
function E.StormTopUp(ev)
 local Z=STALKER_ZONE;local fields=stormFields();if not fields or #fields==0 then return 0 end
 local before={};for _,e in ipairs(ents.FindByClass("stalker_artifact")) do before[e]=true end
 local mult=math.max(1,Cfg.StormMult)
 local savedMax,saved=Z.Config.MaxArtifacts,{}
 Z.Config.MaxArtifacts=math.floor(savedMax*mult+.5)
 for id,f in pairs(Z.World.fields) do saved[id]=f.artifacts;f.artifacts=math.floor((tonumber(f.artifacts) or 0)*mult+.5) end
 local ok,err=pcall(Z.TopUpArtifacts)
 -- Лимиты возвращаются сразу: настройки Зоны и файл полей не видят повышенных значений.
 Z.Config.MaxArtifacts=savedMax
 for id,f in pairs(Z.World.fields) do if saved[id]~=nil then f.artifacts=saved[id] end end
 if not ok then ErrorNoHalt("[STALKER Events] шторм: "..tostring(err).."\n") end
 local n=0;ev.data.spawned=ev.data.spawned or {}
 for _,e in ipairs(ents.FindByClass("stalker_artifact")) do if not before[e] then e.StalkerStorm=true;ev.data.spawned[#ev.data.spawned+1]=e;n=n+1 end end
 ev.data.total=(ev.data.total or 0)+n
 return n
end
-- После шторма в каждом поле остаётся не больше обычного лимита; первыми уходят «штормовые» артефакты.
function E.StormRelease(ev)
 local Z=STALKER_ZONE;local removed=0
 if Z and Z.World and Z.Runtime and type(Z.Runtime.fields)=="table" then
  for id,rt in pairs(Z.Runtime.fields) do
   local f=Z.World.fields[id];local alive={}
   for _,e in ipairs(rt.artifacts or {}) do if IsValid(e) and not e.Taken then alive[#alive+1]=e end end
   local surplus=#alive-(f and tonumber(f.artifacts) or 0)
   for i=#alive,1,-1 do if surplus>0 and alive[i].StalkerStorm then alive[i]:Remove();surplus=surplus-1;removed=removed+1 end end
  end
 end
 for _,e in ipairs(ev.data.spawned or {}) do if IsValid(e) then e.StalkerStorm=nil end end
 return removed
end
hook.Add("STALKER_ZONE_ArtifactPicked","STALKER_EVENTS.Storm",function(ply) if E.Active.storm then E.Participate(E.Active.storm,ply) end end)
E.Register({id="storm",name=info("storm","name"),description=info("storm","desc"),duration=minutes("StormMinutes"),weight=weight("storm"),minPlayers=1,
 canStart=function()
  local fields=stormFields()
  if not fields then return false,"Не установлен аддон Зоны (поля аномалий)" end
  if #fields==0 then return false,"Нет полей аномалий с артефактами" end
  return true
 end,
 start=function(ev)
  local Z=STALKER_ZONE
  E.StormTopUp(ev)
  ev.data.nextTick=CurTime()+Cfg.StormTick
  ev.info="Лимит артефактов ×"..math.max(1,Cfg.StormMult)
  -- Метки на полях с наибольшим числом артефактов.
  local rows={}
  for _,id in ipairs(stormFields()) do local rt=Z.Runtime.fields and Z.Runtime.fields[id];local n=0
   for _,e in ipairs(rt and rt.artifacts or {}) do if IsValid(e) then n=n+1 end end
   rows[#rows+1]={id=id,n=n}
  end
  table.sort(rows,function(a,b) if a.n~=b.n then return a.n>b.n end;return tostring(a.id)<tostring(b.id) end)
  for i=1,math.min(4,#rows) do local f=Z.World.fields[rows[i].id]
   E.Marker(ev,"f"..i,{pos=Vector(f.pos.x,f.pos.y,f.pos.z),label="Шторм: "..tostring(f.name),edge=false})
  end
  ev.where=rows[1] and tostring(Z.World.fields[rows[1].id].name) or nil
  C.News("Артефактный шторм! Аномальные поля выбрасывают артефакты — берите детекторы, пока шторм не утих.","event")
  return true
 end,
 think=function(ev) if CurTime()>=ev.data.nextTick then ev.data.nextTick=CurTime()+Cfg.StormTick;E.StormTopUp(ev) end end,
 stop=function(ev,reason)
  local removed=E.StormRelease(ev)
  if reason~="cleanup" then C.News("Артефактный шторм утих"..(removed>0 and (": "..removed.." несобранных артефактов рассеялось") or "")..".","event") end
 end})

--[[ Военный рейд ]]
E.RaidWeapons={"weapon_smg1","weapon_ar2"}
E.RaidModel="models/combine_soldier.mdl"
-- «Военные» — союзники отряда; покинувший группировку снова становится целью.
local function raidAllies(ev)
 ev.data.allies=ev.data.allies or {}
 for _,p in ipairs(player.GetHumans()) do
  local ally=C.Faction(p)=="military"
  if ally or ev.data.allies[p] then
   for _,npc in ipairs(ev.npcs) do E.Relate(npc,p,ally and "D_LI" or "D_HT") end
   ev.data.allies[p]=ally or nil
  end
 end
end
E.Register({id="raid",name=info("raid","name"),description=info("raid","desc"),duration=minutes("RaidMinutes"),weight=weight("raid"),minPlayers=2,
 start=function(ev,opts)
  local pos,name=opts.pos,opts.pos and "под прицелом администратора" or nil
  if not pos then pos,name=E.PickPoint() end
  if not pos then return false,"Не найдено место для высадки" end
  ev.pos=pos;ev.where=name
  for _=1,Cfg.RaidSquad do
   E.SpawnNPC(ev,"npc_combine_s",E.Around(pos,60,360),{model=E.RaidModel,reward=Cfg.RaidReward,name="Военный",
    keys={SquadName="stalker_raid",Numgrenades=1,additionalequipment=E.RaidWeapons[math.random(#E.RaidWeapons)]}})
  end
  if #ev.npcs==0 then return false,"Не удалось высадить отряд (нет места или лимит NPC)" end
  ev.data.size=#ev.npcs
  raidAllies(ev)
  ev.info="Бойцов: "..#ev.npcs.." · награда "..E.Money(Cfg.RaidReward).." за каждого"
  E.Marker(ev,"squad",{pos=pos,label="Военный рейд"})
  C.News("Военный рейд"..(name and (" ("..name..")") or "")..": армейский отряд высадился в Зоне. Награда за каждого бойца — "..E.Money(Cfg.RaidReward)..".","war")
  return true
 end,
 think=function(ev)
  local alive=E.AliveNPC(ev)
  if #alive==0 then ev.data.cleared=true;E.Stop(ev.id,"done");return end
  if CurTime()>=(ev.data.nextMark or 0) then
   ev.data.nextMark=CurTime()+5
   -- Метка следует за отрядом, а вступившие в «Военных» становятся союзниками.
   local sum=Vector(0,0,0);for _,npc in ipairs(alive) do sum=sum+npc:GetPos() end
   E.Marker(ev,"squad",{pos=sum/#alive,label="Военный рейд · бойцов: "..#alive})
   ev.info="Бойцов: "..#alive.." из "..(ev.data.size or #alive)
   raidAllies(ev);E.MarkDirty()
  end
 end,
 stop=function(ev,reason)
  if reason=="done" and ev.data.cleared then C.News("Военный рейд отбит: отряд уничтожен.","war")
  elseif reason=="time" then C.News("Военный отряд покинул Зону.","war") end
 end})

--[[ Охота за головой ]]
function E.BountyCandidates()
 local list={}
 for _,p in ipairs(player.GetHumans()) do
  if p:Alive() and C.SID(p) and not C.Unconscious(p) then
   local st=C.GetStats(p) or {}
   local score=(st.kills or 0)*3+(st.mutants or 0)+(st.captures or 0)*2+(st.events or 0)+p:Armor()/10+p:Health()/50
   list[#list+1]={p=p,score=score}
  end
 end
 table.sort(list,function(a,b) if a.score~=b.score then return a.score>b.score end;return a.p:SteamID64()<b.p:SteamID64() end)
 return list
end
-- Цель — случайный игрок из сильнейших (верхняя треть, не больше трёх).
function E.PickBountyTarget()
 local list=E.BountyCandidates();if #list<2 then return end
 local top=math.max(1,math.min(3,math.ceil(#list/3)))
 return list[math.random(top)].p
end
local function markTarget(ev)
 local t=ev.data.target;if not IsValid(t) then return end
 E.Marker(ev,"target",{pos=t:GetPos(),label="Цель: "..t:Nick(),visible={check=function(p) return p~=t end}})
 ev.data.nextMark=CurTime()+Cfg.BountyUpdate
end
function E.BountyKilled(ev,victim,attacker)
 if ev.data.resolved then return end
 ev.data.resolved=true
 local nick=victim:Nick()
 if IsValid(attacker) and attacker:IsPlayer() and attacker~=victim then
  local fa,fv=C.Faction(attacker),C.Faction(victim)
  if fa and fa==fv and fa~="loner" then
   C.News(nick.." погиб от руки своего — награда за голову сгорела.","event")
  else
   E.Participate(ev,attacker)
   E.Pay(attacker,Cfg.BountyReward,"Награда за голову")
   C.News(attacker:Nick().." получил награду за голову сталкера "..nick..".","event")
   hook.Run("STALKER_EVENTS_BountyClaimed",attacker,victim)
  end
 else
  C.News("Цель охоты "..nick.." погибла без помощи охотников — награда сгорела.","event")
 end
 E.Stop(ev.id,"done")
end
E.Register({id="bounty",name=info("bounty","name"),description=info("bounty","desc"),duration=minutes("BountyMinutes"),weight=weight("bounty"),minPlayers=3,
 canStart=function() if #E.BountyCandidates()<2 then return false,"Для охоты нужны минимум два живых сталкера в сети" end;return true end,
 start=function(ev,opts)
  local target=IsValid(opts.target) and opts.target or E.PickBountyTarget()
  if not IsValid(target) then return false,"Нет подходящей цели" end
  ev.data.target=target;ev.data.sid=C.SID(target);ev.where=target:Nick();ev.info="Цель: "..target:Nick()
  markTarget(ev)
  C.News("Охота за головой! За сталкера "..target:Nick().." назначена награда "..E.Money(Cfg.BountyReward)..
   ". Продержится "..E.FormatTime(ev.duration).." — награда "..E.Money(Cfg.BountySurvive).." достанется ему.","danger")
  C.Notify(target,"За вашу голову назначена награда! Продержитесь "..E.FormatTime(ev.duration).." — и награда ваша.","danger",10)
  return true
 end,
 think=function(ev)
  local t=ev.data.target
  if not IsValid(t) then C.News("Цель охоты покинула Зону — охота отменена.","event");E.Stop(ev.id,"done");return end
  if CurTime()>=(ev.data.nextMark or 0) then markTarget(ev) end
 end,
 stop=function(ev,reason)
  local t=ev.data.target
  if reason=="time" and not ev.data.resolved and IsValid(t) and t:Alive() then
   E.Participate(ev,t);E.Pay(t,Cfg.BountySurvive,"Вы пережили охоту")
   C.News(t:Nick().." пережил охоту за головой и забирает награду.","event")
  end
 end})
hook.Add("PlayerDeath","STALKER_EVENTS.Bounty",function(victim,_,attacker)
 local ev=E.Active.bounty
 if ev and victim==ev.data.target then E.BountyKilled(ev,victim,attacker) end
end)
hook.Add("PlayerDisconnected","STALKER_EVENTS.Bounty",function(ply)
 local ev=E.Active.bounty
 if ev and ply==ev.data.target and not ev.data.resolved then
  ev.data.resolved=true;C.News("Цель охоты покинула Зону — охота отменена.","event");E.Stop("bounty","done")
 end
end)
