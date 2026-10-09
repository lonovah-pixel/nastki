local E=ST_EMISSION
for _,n in ipairs({"state","request","admin"}) do util.AddNetworkString("stem."..n) end
E.State={phase=0,started=0,ends=0,next=0};E.RoofCache=setmetatable({},{__mode="k"})
local path="stalker_emissions/settings.json"
file.CreateDir("stalker_emissions")
local saved=util.JSONToTable(file.Read(path,"DATA") or "")
if E.ValidSettings(saved) then E.Config.AutoStart=saved.auto;E.Config.IntervalMin=saved.min*60;E.Config.IntervalMax=saved.max*60 end
function E.Settings() return {auto=E.Config.AutoStart,min=E.Config.IntervalMin/60,max=E.Config.IntervalMax/60} end
function E.Schedule() E.State.next=E.Config.AutoStart and CurTime()+math.random(E.Config.IntervalMin,E.Config.IntervalMax) or 0 end
function E.Send(p)
 local raw=util.TableToJSON({state=E.State,settings=E.Settings()});if not raw or #raw>60000 then return end
 net.Start("stem.state");net.WriteUInt(#raw,16);net.WriteData(raw,#raw);if IsValid(p) then net.Send(p) else net.Broadcast() end
end
function E.Wake(p) p:SetNW2Float("stem_unconscious",0) end
function E.Knockout(p)
 if p.StemKnocked or not p:Alive() then return end
 p.StemKnocked=true;p:SetNW2Float("stem_unconscious",CurTime()+E.Config.KnockoutSeconds);hook.Run("STEmissionUnconscious",p,E.Config.KnockoutSeconds)
 if p:InVehicle() then p:ExitVehicle() end
end
function E.Start()
 if E.State.phase>0 then return false end
 for _,p in ipairs(player.GetAll()) do p.StemKnocked=nil;E.Wake(p) end
 E.State.phase=1;E.State.started=CurTime();E.State.ends=CurTime()+E.Config.Phases[1].duration;E.State.next=0
 E.Send();hook.Run("STEmissionStarted");hook.Run("STEmissionPhase",1,"warning");return true
end
function E.Stop(aborted)
 if E.State.phase==0 then return false end
 for _,p in ipairs(player.GetAll()) do E.Wake(p);p.StemKnocked=nil end
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
timer.Create("STEmission.Tick",.25,0,function()
 local state=E.State;local now=CurTime()
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
 local damage=Lerp(progress,phase.damage,phase.damageEnd)
 if not E.Config.DamagePlayers then return end
 for _,p in ipairs(player.GetAll()) do
  if p:Alive() and not E.IsSheltered(p) and hook.Run("STEmissionCanDamage",p,phase.id)~=false then
   if phase.id=="peak" then E.Knockout(p) end
   local dmg=DamageInfo();dmg:SetDamage(damage);dmg:SetDamageType(DMG_RADIATION);dmg:SetAttacker(game.GetWorld());dmg:SetInflictor(game.GetWorld());p:TakeDamageInfo(dmg)
  end
 end
end)
local function unconscious(p) return p:Alive() and p:GetNW2Float("stem_unconscious",0)>CurTime() end
hook.Add("StartCommand","STEmission.Unconscious",function(p,cmd)
 if unconscious(p) then cmd:ClearButtons();cmd:ClearMovement() end
end)
hook.Add("SetupMove","STEmission.Unconscious",function(p,mv)
 if unconscious(p) then mv:SetForwardSpeed(0);mv:SetSideSpeed(0);mv:SetUpSpeed(0);mv:SetMaxSpeed(0);mv:SetMaxClientSpeed(0) end
end)
for _,name in ipairs({"PlayerUse","PlayerSwitchWeapon","CanPlayerEnterVehicle","PlayerNoClip"}) do
 hook.Add(name,"STEmission.Unconscious",function(p) if unconscious(p) then return false end end)
end
hook.Add("PlayerDeath","STEmission.Wake",E.Wake)
hook.Add("PlayerSpawn","STEmission.Wake",E.Wake)
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
hook.Add("PostCleanupMap","STEmission.Cleanup",function() E.Stop(true);E.RoofCache=setmetatable({},{__mode="k"}) end)
