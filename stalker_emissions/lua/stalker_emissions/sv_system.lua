local E=ST_EMISSION
for _,n in ipairs({"state","request","admin"}) do util.AddNetworkString("stem."..n) end
E.State={phase=0,started=0,ends=0,next=0};E.RoofCache=setmetatable({},{__mode="k"})
local path="stalker_emissions/settings.json"
file.CreateDir("stalker_emissions")
local saved=util.JSONToTable(file.Read(path,"DATA") or "")
if E.ValidSettings(saved) then E.Config.AutoStart=saved.auto;E.Config.IntervalMin=saved.min*60;E.Config.IntervalMax=saved.max*60 end
function E.Settings() return {auto=E.Config.AutoStart,min=E.Config.IntervalMin/60,max=E.Config.IntervalMax/60} end
function E.Schedule()
 -- Границы могут прийти из панели в любом порядке: минимум больше максимума не ломает планировщик.
 local a,b=math.floor(E.Config.IntervalMin),math.floor(E.Config.IntervalMax)
 E.State.next=E.Config.AutoStart and CurTime()+math.random(math.max(60,math.min(a,b)),math.max(60,a,b)) or 0
end
function E.Send(p)
 local raw=util.TableToJSON({state=E.State,settings=E.Settings()});if not raw or #raw>60000 then return end
 net.Start("stem.state");net.WriteUInt(#raw,16);net.WriteData(raw,#raw);if IsValid(p) then net.Send(p) else net.Broadcast() end
end
-- Обморок: игрок скрывается, вместо него падает рагдолл, камера клиента смотрит его глазами.
function E.CreateBody(p)
 if IsValid(p.StemRagdoll) then return end
 local rag=ents.Create("prop_ragdoll");if not IsValid(rag) then return end
 rag:SetModel(p:GetModel());rag:SetPos(p:GetPos());rag:SetAngles(Angle(0,p:EyeAngles().y,0))
 rag:SetSkin(p:GetSkin());rag:SetMaterial(p:GetMaterial());rag:SetColor(p:GetColor())
 for _,g in ipairs(p:GetBodyGroups()) do rag:SetBodygroup(g.id,p:GetBodygroup(g.id)) end
 rag:Spawn();rag:Activate();rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
 p:SetupBones()
 local vel=p:GetVelocity()
 for i=0,rag:GetPhysicsObjectCount()-1 do
  local phys=rag:GetPhysicsObjectNum(i)
  if IsValid(phys) then
   local pos,ang=p:GetBonePosition(rag:TranslatePhysBoneToBone(i))
   if pos and ang then phys:SetPos(pos);phys:SetAngles(ang) end
   phys:SetVelocity(vel);phys:Wake()
  end
 end
 rag.StemOwner=p;p.StemRagdoll=rag;p:SetNW2Entity("stem_ragdoll",rag)
 p.StemHidden=true;p.StemMoveType=p:GetMoveType()
 p:SetNoDraw(true);p:DrawShadow(false);p:SetNotSolid(true);p:DrawViewModel(false);p:DrawWorldModel(false);p:SetMoveType(MOVETYPE_NONE)
end
-- teleport: перенести игрока туда, где лежит тело (после пробуждения или смерти).
function E.RemoveBody(p,teleport)
 local rag=p.StemRagdoll;p.StemRagdoll=nil
 if p.StemHidden then
  p.StemHidden=nil;p:SetNoDraw(false);p:DrawShadow(true);p:SetNotSolid(false);p:DrawViewModel(true);p:DrawWorldModel(true)
  local move=p.StemMoveType;p.StemMoveType=nil
  p:SetMoveType((move==nil or move==MOVETYPE_NONE) and MOVETYPE_WALK or move)
 end
 p:SetNW2Entity("stem_ragdoll",NULL)
 if not IsValid(rag) then return end
 if teleport then
  local pos=rag:GetPos()
  local tr=util.TraceLine({start=pos+Vector(0,0,24),endpos=pos-Vector(0,0,72),filter={rag,p},mask=MASK_PLAYERSOLID})
  local ground=(tr.Hit and not tr.StartSolid and tr.HitPos or pos)+Vector(0,0,2)
  local mins,maxs=p:GetHull()
  local hull=util.TraceHull({start=ground,endpos=ground,mins=mins,maxs=maxs,filter={rag,p},mask=MASK_PLAYERSOLID})
  if not hull.StartSolid then p:SetPos(ground) end
 end
 rag:Remove()
end
function E.Wake(p,teleport)
 p:SetNW2Float("stem_unconscious",0);p:SetNW2Float("stem_unconscious_until",0)
 E.RemoveBody(p,teleport and p:Alive())
end
function E.Knockout(p)
 if p.StemKnocked or not p:Alive() then return end
 p.StemKnocked=true
 if p:InVehicle() then p:ExitVehicle() end
 local now,seconds=CurTime(),E.Config.KnockoutSeconds
 if seconds<=0 then return end
 p:SetNW2Float("stem_unconscious_start",now);p:SetNW2Float("stem_unconscious",now+seconds);p:SetNW2Float("stem_unconscious_until",now+seconds)
 E.CreateBody(p)
 hook.Run("STEmissionUnconscious",p,seconds)
end
function E.Start()
 if E.State.phase>0 then return false end
 for _,p in ipairs(player.GetAll()) do p.StemKnocked=nil;E.Wake(p,true) end
 E.State.phase=1;E.State.started=CurTime();E.State.ends=CurTime()+E.Config.Phases[1].duration;E.State.next=0
 E.Send();hook.Run("STEmissionStarted");hook.Run("STEmissionPhase",1,"warning");return true
end
function E.Stop(aborted)
 if E.State.phase==0 then return false end
 for _,p in ipairs(player.GetAll()) do E.Wake(p,true);p.StemKnocked=nil end
 E.State.phase=0;E.State.started=0;E.State.ends=0;E.Schedule();E.Send()
 hook.Run(aborted and "STEmissionAborted" or "STEmissionFinished");return true
end
function E.IsSheltered(ent)
 local override=hook.Run("STEmissionShelterOverride",ent);if type(override)=="boolean" then return override end
 local point=ent:WorldSpaceCenter()
 if not E.Config.AutoRoof then return false end
 local cache=E.RoofCache[ent]
 if cache and cache.untilTime>CurTime() and cache.pos:DistToSqr(point)<32^2 then return cache.safe,"roof" end
 -- MASK_SOLID_BRUSHONLY исключает переносимые пропы, транспорт и случайные предметы.
 local hits=0
 for _,offset in ipairs({Vector(0,0,0),Vector(32,0,0),Vector(-32,0,0),Vector(0,32,0),Vector(0,-32,0)}) do
  local origin=point+offset
  local tr=util.TraceLine({start=origin,endpos=origin+Vector(0,0,E.Config.RoofDistance),filter=ent,mask=MASK_SOLID_BRUSHONLY})
  if tr.Hit and not tr.HitSky and not tr.StartSolid then hits=hits+1 end
 end
 local safe=hits>=3
 E.RoofCache[ent]={pos=point,untilTime=CurTime()+E.Config.RoofCheckInterval,safe=safe==true};return safe==true,"roof"
end

local lastDamage=CurTime()
local function hurt(ent,damage)
 local dmg=DamageInfo();dmg:SetDamage(damage);dmg:SetDamageType(DMG_RADIATION);dmg:SetAttacker(game.GetWorld());dmg:SetInflictor(game.GetWorld());ent:TakeDamageInfo(dmg)
end
timer.Create("STEmission.Tick",.25,0,function()
 local state=E.State;local now=CurTime()
 -- Пробуждение по таймеру: тело убирается, игрок встаёт на его месте.
 for _,p in ipairs(player.GetAll()) do
  if p.StemHidden and (p:GetNW2Float("stem_unconscious",0)<=now or not IsValid(p.StemRagdoll)) then E.Wake(p,true) end
 end
 if state.phase==0 then if E.Config.AutoStart and state.next>0 and now>=state.next then E.Start() end;return end
 if now>=state.ends then
  state.phase=state.phase+1
  local phase=E.Config.Phases[state.phase]
  if not phase then E.Stop(false);return end
  state.started=now;state.ends=now+phase.duration;E.Send();hook.Run("STEmissionPhase",state.phase,phase.id)
 end
 if now-lastDamage<E.Config.DamageInterval then return end;lastDamage=now
 local phase=E.Config.Phases[state.phase]
 local progress=math.Clamp((now-state.started)/phase.duration,0,1)
 local damage=Lerp(progress,phase.damage,phase.damageEnd)*(E.Config.DamageScale or 1)
 for _,p in ipairs(player.GetAll()) do
  if p:Alive() then
   local sheltered=E.IsSheltered(p);p:SetNW2Bool("stem_sheltered",sheltered)
   if E.Config.DamagePlayers and not sheltered and hook.Run("STEmissionCanDamage",p,phase.id)~=false then
    -- На пике незащищённый сталкер падает в обморок (один раз за выброс).
    if phase.id=="peak" then E.Knockout(p) end
    hurt(p,damage)
   end
  end
 end
 -- Настройка «Выброс ранит NPC» (emission.damage_npcs): те же укрытия и хук STEmissionCanDamage, что у игроков.
 if E.Config.DamageNPCs then
  for _,n in ipairs(ents.FindByClass("npc_*")) do
   if n:Health()>0 and not E.IsSheltered(n) and hook.Run("STEmissionCanDamage",n,phase.id)~=false then hurt(n,damage) end
  end
 end
end)
local unconscious=E.IsUnconscious
-- PlayerSwitchWeapon — в sh_config.lua: там запрет возвращает true и работает и в предсказании клиента.
for _,name in ipairs({"PlayerUse","CanPlayerEnterVehicle","PlayerNoClip"}) do
 hook.Add(name,"STEmission.Unconscious",function(p) if unconscious(p) then return false end end)
end
-- Урон по лежащему телу получает сам игрок (тело — его «хитбокс» на время обморока).
hook.Add("EntityTakeDamage","STEmission.BodyDamage",function(ent,dmg)
 local p=ent.StemOwner
 if not IsValid(p) or p.StemRagdoll~=ent then return end
 if p:Alive() and not dmg:IsDamageType(DMG_CRUSH) and dmg:GetDamage()>0 then
  local copy=DamageInfo();copy:SetDamage(dmg:GetDamage());copy:SetDamageType(dmg:GetDamageType())
  copy:SetAttacker(IsValid(dmg:GetAttacker()) and dmg:GetAttacker() or game.GetWorld())
  copy:SetInflictor(IsValid(dmg:GetInflictor()) and dmg:GetInflictor() or game.GetWorld())
  copy:SetDamagePosition(dmg:GetDamagePosition());copy:SetDamageForce(dmg:GetDamageForce())
  p:TakeDamageInfo(copy)
 end
 return true
end)
-- Смерть в обмороке: игрок переносится к телу до создания трупа, тело убирается.
hook.Add("DoPlayerDeath","STEmission.Body",function(p)
 if p.StemHidden then p:SetNW2Float("stem_unconscious",0);p:SetNW2Float("stem_unconscious_until",0);E.RemoveBody(p,true) end
end)
hook.Add("PlayerDeath","STEmission.Wake",function(p) E.Wake(p,false) end)
hook.Add("PlayerSpawn","STEmission.Wake",function(p) E.Wake(p,false) end)
hook.Add("PlayerDisconnected","STEmission.Body",function(p) E.RemoveBody(p,false) end)
hook.Add("PlayerSilentDeath","STEmission.Wake",function(p) E.Wake(p,false) end)
E.Schedule()
local function rate(p)
 if (p.StemRequest or 0)>CurTime() then return false end;p.StemRequest=CurTime()+.3;return true
end
net.Receive("stem.request",function(len,p) if len==0 and rate(p) then E.Send(p) end end)
net.Receive("stem.admin",function(len,p)
 if not E.IsAdmin(p) or not rate(p) or len<16 or len>4096 then return end
 local size=net.ReadUInt(16);if size<2 or size>480 or len~=16+size*8 then return end
 local a=util.JSONToTable(net.ReadData(size));if type(a)~="table" then return end
 if a.op=="start" then E.Start() elseif a.op=="stop" then E.Stop(true)
 elseif a.op=="settings" then
  if not E.ValidSettings(a) then return end
  -- При наличии ядра настройки сохраняются в общем реестре (его видит и панель «Коменданта»).
  if STALKER_SETTINGS and STALKER_SETTINGS.Defs["emission.auto"] then
   local S=STALKER_SETTINGS
   if not (S.Set("emission.auto",a.auto,p) and S.Set("emission.interval_min",a.min,p) and S.Set("emission.interval_max",a.max,p)) then p:ChatPrint("Ошибка сохранения настроек");return end
   E.Send();p:ChatPrint("[Выброс] Выполнено: "..a.op);return
  end
  local raw=util.TableToJSON({auto=a.auto,min=a.min,max=a.max},true)
  if not raw then return end
  file.Write(path,raw)
  if file.Read(path,"DATA")~=raw then p:ChatPrint("Ошибка сохранения настроек");return end
  E.Config.AutoStart=a.auto;E.Config.IntervalMin=a.min*60;E.Config.IntervalMax=a.max*60
  if E.State.phase==0 then E.Schedule() end
 else return end
 E.Send();p:ChatPrint("[Выброс] Выполнено: "..a.op)
end)
concommand.Add("stem_start",function(p) if not IsValid(p) or E.IsAdmin(p) then E.Start() end end)
concommand.Add("stem_stop",function(p) if not IsValid(p) or E.IsAdmin(p) then E.Stop(true) end end)
hook.Add("PlayerInitialSpawn","STEmission.Sync",function(p) timer.Simple(2,function() if IsValid(p) then E.Send(p) end end) end)
-- Медленный клиент теряет пакет таймера в 2 с (ещё «Starting Lua»): досылаем, когда ядро видит загруженный клиент.
hook.Add("STALKER_PlayerReady","STEmission.Sync",function(p) if IsValid(p) then E.Send(p) end end)
hook.Add("PostCleanupMap","STEmission.Cleanup",function()
 E.Stop(true);E.RoofCache=setmetatable({},{__mode="k"})
 for _,p in ipairs(player.GetAll()) do if p.StemHidden then E.Wake(p,false) end end
end)
