--[[ Захват по действию. На каждой точке стоит флаг (stalker_flag). Захват чужой или ничьей точки начинается
 только после удержания E на флаге: точка «вооружается» для группировки, и прогресс идёт только у неё.
 Если все атакующие ушли дольше окна CaptureWindow — захват сбрасывается. Защитники сбрасывают его удержанием E. ]]
local F=STFW
F.ArmIdle=F.ArmIdle or {}

-- Сколько бойцов каждой группировки сейчас реально участвуют в борьбе за точку.
function F.PointPresence(point)
 local counts={}
 for _,q in ipairs(player.GetHumans()) do local f=F.Eligible(q,point);if f then counts[f]=(counts[f] or 0)+1 end end
 return counts
end
-- Причина, по которой игрок не может начать захват (nil — может).
function F.ArmBlock(p,point)
 local d=F.Load(p);if not d or not d.joined then return "capture_need_member" end
 if point.owner==d.faction then return "capture_own" end
 if point.owner~="" and F.Relation(d.faction,point.owner)~="war" then return "territory_war" end
 if F.Eligible(p,point)~=d.faction then return "capture_enter" end
 for id,n in pairs(F.PointPresence(point)) do if n>0 and id~=d.faction then return "territory_contested" end end
 if point.armed==d.faction then return "capture_armed" end
end
local function defendBlock(p,point)
 local d=F.Load(p)
 if not d or not d.joined or d.faction~=point.owner then return "unauthorized" end
 if not point.armed and (point.progress or 0)<=0 then return "capture_own" end
 if F.Eligible(p,point)~=d.faction then return "capture_enter" end
end
-- Удержание E через ядро; без ядра действие выполняется сразу.
function F.StartHold(p,ent,seconds,label,onDone,check)
 local H=STALKER_CORE and STALKER_CORE.Hold
 if H and H.Start then return H.Start(p,ent,seconds,label,onDone,{range=F.Config.FlagUseRange,check=check}) end
 onDone(p,ent);return true
end

local function ownersOnline(id)
 local list={}
 if id=="" then return list end
 for _,q in ipairs(player.GetHumans()) do local d=F.Profiles[q:SteamID64()];if d and d.joined and d.faction==id then list[#list+1]=q end end
 return list
end
-- Точка «вооружена»: оповещаем владельцев (уведомление и лента КПК) и атакующих.
function F.ArmPoint(p,id)
 local point=F.World.points[id];if not point then return false,"denied" end
 local block=F.ArmBlock(p,point);if block then F.Toast(p,F.L(block),"warn");return false,block end
 local d=F.Load(p);local w=table.Copy(F.World);local pt=w.points[id]
 pt.armed=d.faction;pt.armedBy=p:SteamID64()
 if pt.attacker~=d.faction then pt.attacker=nil;pt.progress=0 end
 if not F.Commit(w,{},"arm "..id.." "..d.faction) then F.Notify(p,"storage");return false,"storage" end
 F.ArmIdle[id]=0
 local C=STALKER_CORE;local owners=ownersOnline(pt.owner)
 for _,q in ipairs(owners) do F.Toast(q,"Начат захват точки «"..pt.name.."»: "..F.Name(d.faction).."! Удерживайте E на флаге, чтобы сбросить захват.","danger",10) end
 if C and C.News and #owners>0 then C.News("Начат захват точки «"..pt.name.."»","war",owners) end
 F.AlertFaction(d.faction,"Точка «"..pt.name.."» готова к захвату: удерживайте зону. Окно "..math.floor(F.Config.CaptureWindow).." с.","ok")
 F.SyncFlags()
 return true
end
-- Защитник сбросил захват своей точки.
function F.DefendPoint(p,id)
 local point=F.World.points[id];if not point then return false,"denied" end
 local block=defendBlock(p,point);if block then F.Toast(p,F.L(block),"warn");return false,block end
 local w=table.Copy(F.World);local pt=w.points[id];local attacker=pt.armed or pt.attacker
 pt.armed=nil;pt.armedBy=nil;pt.progress=0;pt.attacker=nil
 if not F.Commit(w,{},"defend "..id.." "..p:SteamID64()) then F.Notify(p,"storage");return false,"storage" end
 F.ArmIdle[id]=nil
 F.AlertFaction(pt.owner,"Захват точки «"..pt.name.."» сорван: "..p:Nick(),"ok")
 if attacker then F.AlertFaction(attacker,"Защитники сбросили захват точки «"..pt.name.."»","warn") end
 F.SyncFlags()
 return true
end
-- Нажатие E на флаге: защитник сбрасывает захват, остальные начинают его.
function F.FlagUse(p,ent)
 if not IsValid(p) or not p:IsPlayer() or not p:Alive() or not IsValid(ent) then return end
 if (p.StfwFlagUse or 0)>CurTime() then return end;p.StfwFlagUse=CurTime()+.5
 local id=ent:GetPointID();local point=F.World.points[id];if not point then return end
 local d=F.Load(p)
 if d and d.joined and point.owner~="" and d.faction==point.owner then
  local block=defendBlock(p,point)
  if block then F.Toast(p,F.L(block),block=="capture_own" and "ok" or "warn");return end
  return F.StartHold(p,ent,F.Config.DefendActionSeconds,"Сброс захвата: "..point.name,function(q) F.DefendPoint(q,id) end,function(q)
   local pt=F.World.points[id];if not pt then return "Точка удалена" end
   local b=defendBlock(q,pt);if b then return F.L(b) end
  end)
 end
 local block=F.ArmBlock(p,point);if block then F.Toast(p,F.L(block),"warn");return end
 return F.StartHold(p,ent,F.Config.CaptureActionSeconds,"Подготовка захвата: "..point.name,function(q) F.ArmPoint(q,id) end,function(q)
  local pt=F.World.points[id];if not pt then return "Точка удалена" end
  local b=F.ArmBlock(q,pt);if b then return F.L(b) end
 end)
end

--[[ Окно захвата: вызывается таймером захвата для каждой точки копии мира.
 Если вооружение снято, возвращает группировку и причину: "window" — атакующие ушли дольше окна, "peace" — война окончена. ]]
function F.ArmWindowStep(id,point,counts,dt,world)
 if not point.armed then F.ArmIdle[id]=nil;return end
 local armed=point.armed
 local valid=F.Factions[armed] and armed~=point.owner and (point.owner=="" or F.Relation(armed,point.owner,world)=="war")
 if (counts[armed] or 0)>0 then F.ArmIdle[id]=0 else F.ArmIdle[id]=(F.ArmIdle[id] or 0)+dt end
 if valid and F.ArmIdle[id]<=F.Config.CaptureWindow then return end
 point.armed=nil;point.armedBy=nil;point.progress=0;point.attacker=nil;F.ArmIdle[id]=nil
 return armed,valid and "window" or "peace"
end

--[[ Флаги и метки карты: сверка сущностей с точками (создать недостающие, убрать лишние, обновить состояние). ]]
F.FlagMarkers=F.FlagMarkers or {}
function F.SyncFlags()
 local points=F.World.points or {}
 local seen={}
 for id in pairs(F.ArmIdle) do if not points[id] then F.ArmIdle[id]=nil end end
 for _,e in ipairs(ents.FindByClass("stalker_flag")) do
  local id=e:GetPointID();local pt=points[id]
  if not pt or seen[id] then e:Remove() else seen[id]=e end
 end
 for id,pt in pairs(points) do
  local e=seen[id];local pos=Vector(pt.pos.x,pt.pos.y,pt.pos.z)
  if not IsValid(e) then
   e=ents.Create("stalker_flag")
   if IsValid(e) then e:SetPointID(id);e:SetPos(pos);e:SetAngles(Angle(0,0,0));e:Spawn();e:Activate() end
  elseif e:GetPos():DistToSqr(pos)>1 then e:SetPos(pos) end
  if IsValid(e) then
   e:SetOwnerID(pt.owner or "");e:SetArmedID(pt.armed or "");e:SetPointName(pt.name or "")
   e:SetProgress(pt.progress or 0);e:SetContested(pt.contested==true)
  end
 end
 local MK=STALKER_MARKERS
 if MK and MK.Set then
  local keys={}
  for id,pt in pairs(points) do
   local key="stfw.flag."..id
   local label=pt.name.." — "..(pt.owner~="" and F.Name(pt.owner) or "ничья")
   if pt.armed then label=label.." (захват: "..F.Name(pt.armed)..")" end
   -- Метку обновляем только при изменении: таймер вызывает сверку каждую секунду.
   local sig=label.."|"..pt.pos.x.."|"..pt.pos.y.."|"..pt.pos.z.."|"..pt.radius;keys[key]=sig
   if F.FlagMarkers[key]~=sig or not MK.Get(key) then
    local f=F.Factions[pt.owner or ""]
    MK.Set(key,{pos=Vector(pt.pos.x,pt.pos.y,pt.pos.z),label=label,kind="flag",world=false,radius=pt.radius,
     color=f and Color(f.color[1],f.color[2],f.color[3]) or nil,icon=pt.owner~="" and ("stalker_factions/emblems/"..pt.owner..".png") or nil})
   end
  end
  for key in pairs(F.FlagMarkers) do if not keys[key] then MK.Remove(key) end end
  F.FlagMarkers=keys
 end
end
hook.Add("InitPostEntity","STFW.Flags",function() F.SyncFlags() end)
hook.Add("PostCleanupMap","STFW.Flags",function() F.SyncFlags() end)
hook.Add("PhysgunPickup","STFW.FlagLock",function(_,e) if IsValid(e) and e:GetClass()=="stalker_flag" then return false end end)
hook.Add("CanTool","STFW.FlagLock",function(_,tr) if IsValid(tr.Entity) and tr.Entity:GetClass()=="stalker_flag" then return false end end)
