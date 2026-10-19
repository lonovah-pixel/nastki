-- Логова мутантов: NPC появляются вне поля зрения игроков, держат численность и платят DarkRP за убийство.
local Z=STALKER_ZONE

local function countMutants()
 local n=0
 for _,rt in pairs(Z.Runtime.zones) do for _,e in ipairs(rt.alive) do if IsValid(e) and e:Health()>0 then n=n+1 end end end
 return n
end
Z.CountMutants=countMutants

local function playerNear(pos,radius)
 for _,p in ipairs(player.GetHumans()) do if p:Alive() and p:GetPos():DistToSqr(pos)<radius*radius then return true end end
end

-- Стоячий hull NPC на точке пола: без застревания в стенах и других существах.
local function spawnable(pos,big)
 local size=big and 40 or 18
 local tr=util.TraceHull({start=pos+Vector(0,0,4),endpos=pos+Vector(0,0,4),mins=Vector(-size,-size,0),maxs=Vector(size,size,big and 100 or 72),mask=MASK_NPCSOLID})
 return not tr.Hit and not tr.StartSolid
end

function Z.SpawnMutant(zoneID)
 local zone=Z.World.zones[zoneID];local rt=Z.Runtime.zones[zoneID]
 if not zone or not rt then return end
 local keys={};for key in pairs(zone.types) do if Z.Mutants[key] then keys[#keys+1]=key end end
 if #keys==0 then return end
 table.sort(keys)
 local key=keys[math.random(#keys)];local def=Z.Mutants[key]
 local center=Vector(zone.pos.x,zone.pos.y,zone.pos.z)
 for _=1,6 do
  local pos=Z.GroundPoint(center,zone.radius)
  if pos and spawnable(pos,def.class=="npc_antlionguard") and not playerNear(pos,Z.Config.MutantSafeRadius) then
   local npc=ents.Create(def.class);if not IsValid(npc) then return end
   npc:SetPos(pos+Vector(0,0,4));npc:SetAngles(Angle(0,math.random(0,359),0))
   npc:Spawn();npc:Activate()
   local mult=tonumber(def.health) or 1
   if mult~=1 and npc:Health()>0 then local hp=math.max(1,math.floor(npc:Health()*mult));npc:SetMaxHealth(hp);npc:SetHealth(hp) end
   npc.KillValue=def.reward;npc.StalkerZone=zoneID;npc.StalkerMutant=key
   npc:SetNW2String("stz_mutant",def.name)
   rt.alive[#rt.alive+1]=npc
   hook.Run("STALKER_ZONE_MutantSpawned",npc,zoneID,key)
   return npc
  end
 end
end

local function zoneRuntime(id)
 local rt=Z.Runtime.zones[id];if not rt then rt={alive={},next=0};Z.Runtime.zones[id]=rt end
 return rt
end

function Z.ClearMutants(id)
 for zid,rt in pairs(Z.Runtime.zones) do
  if not id or zid==id then
   for _,e in ipairs(rt.alive) do if IsValid(e) then e:Remove() end end
   rt.alive={}
  end
 end
end

-- Первое заполнение после загрузки карты: логова поднимаются постепенно, без лавины NPC.
function Z.InitMutants()
 Z.Runtime.zones={}
 for id in pairs(Z.World.zones) do zoneRuntime(id).next=CurTime()+math.Rand(1,8) end
end
-- «Убрать мутантов»: живые исчезают, логова заселяются заново по обычному интервалу (не сразу).
function Z.RemoveMutants()
 local n=countMutants()
 Z.ClearMutants()
 for id,zone in pairs(Z.World.zones) do zoneRuntime(id).next=CurTime()+(tonumber(zone.respawn) or 60) end
 return n
end

timer.Create("STALKER_ZONE.Mutants",Z.Config.MutantTick,0,function()
 if not Z.WorldReady then return end
 local total=countMutants()
 for id,zone in SortedPairs(Z.World.zones) do
  local rt=zoneRuntime(id);local alive={}
  for _,e in ipairs(rt.alive) do if IsValid(e) and e:Health()>0 then alive[#alive+1]=e end end
  rt.alive=alive
  if #alive<zone.max and total<Z.Config.MaxMutants and CurTime()>=rt.next then
   -- Пока логово заполнено меньше чем наполовину, мутанты появляются быстрее; дальше — по интервалу.
   local npc=Z.SpawnMutant(id)
   if IsValid(npc) then total=total+1;rt.next=CurTime()+((#alive+1)<math.ceil(zone.max/2) and math.min(15,zone.respawn) or zone.respawn)
   else rt.next=CurTime()+15 end
  end
 end
 for id in pairs(Z.Runtime.zones) do if not Z.World.zones[id] then Z.ClearMutants(id);Z.Runtime.zones[id]=nil end end
end)

-- Серверные трупы мутантов из логов убираются после окна разделки, иначе они копятся до смены карты.
hook.Add("CreateEntityRagdoll","STALKER_ZONE.CorpseCleanup",function(npc,rag)
 if not IsValid(npc) or not npc.StalkerZone or not IsValid(rag) then return end
 timer.Simple(Z.Config.CorpseLifetime,function() if IsValid(rag) then rag:Remove() end end)
end)
