-- Поля аномалий и логова мутантов: настройка хранится по картам в data/stalker_zone/<карта>.json.
-- Аномалии и артефакты пересобираются после каждого выброса и при загрузке карты.
local Z=STALKER_ZONE
Z.World={version=1,fields={},zones={}}
Z.Runtime={fields={},zones={}}
file.CreateDir("stalker_zone")
local path="stalker_zone/"..game.GetMap()..".json"

function Z.Log(text) print("[STALKER Zone] "..text) end

function Z.LoadWorld()
 local raw=file.Read(path,"DATA")
 if not raw then Z.WorldReady=true;return end
 local data=util.JSONToTable(raw)
 if type(data)~="table" or type(data.fields)~="table" or type(data.zones)~="table" then
  -- Повреждённый файл не перезаписываем: редактор блокируется до ручного восстановления.
  Z.WorldReady=false;ErrorNoHalt("[STALKER Zone] Повреждён "..path.."; редактор заблокирован\n");return
 end
 local world={version=1,fields={},zones={}}
 for id,f in pairs(data.fields) do local clean=Z.ValidateEntry("field",f);if clean then clean.id=tostring(id);world.fields[clean.id]=clean end end
 for id,zn in pairs(data.zones) do local clean=Z.ValidateEntry("zone",zn);if clean then clean.id=tostring(id);world.zones[clean.id]=clean end end
 Z.World=world;Z.WorldReady=true
end

function Z.SaveWorld()
 if not Z.WorldReady then return false end
 local payload=util.TableToJSON(Z.World,true);if not payload then return false end
 file.Write(path..".pending.json",payload)
 if file.Read(path..".pending.json","DATA")~=payload then return false end
 local old=file.Read(path,"DATA");if old then file.Write(path..".backup.json",old) end
 file.Write(path,payload);if file.Read(path,"DATA")~=payload then return false end
 file.Delete(path..".pending.json");return true
end

local function int(v,lo,hi) return type(v)=="number" and v==v and v%1==0 and v>=lo and v<=hi end
local function vec(t) return type(t)=="table" and type(t.x)=="number" and type(t.y)=="number" and type(t.z)=="number" and math.abs(t.x)<=65536 and math.abs(t.y)<=65536 and math.abs(t.z)<=65536 end
-- Единая проверка записи: из файла, из редактора и при правке.
function Z.ValidateEntry(kind,a)
 if type(a)~="table" or type(a.name)~="string" or not vec(a.pos) or type(a.types)~="table" then return nil,"Проверьте название и параметры" end
 local name=a.name:match("^%s*(.-)%s*$")
 if #name<1 or #name>128 or name:find("[%c]") then return nil,"Название: от 1 до 64 символов" end
 local catalog=kind=="field" and Z.Anomalies or Z.Mutants
 local types={}
 for key,on in pairs(a.types) do if on==true and catalog[key] then types[key]=true end end
 if not next(types) then return nil,"Выберите хотя бы один тип" end
 local out={name=name,pos={x=a.pos.x,y=a.pos.y,z=a.pos.z},types=types}
 if kind=="field" then
  if not int(a.radius,150,4000) or not int(a.count,1,40) or not int(a.artifacts,0,15) then return nil,"Радиус 150–4000, аномалий 1–40, артефактов 0–15" end
  out.radius,out.count,out.artifacts=a.radius,a.count,a.artifacts
 else
  if not int(a.radius,100,3000) or not int(a.max,1,16) or not int(a.respawn,10,3600) then return nil,"Радиус 100–3000, мутантов 1–16, интервал 10–3600 с" end
  out.radius,out.max,out.respawn=a.radius,a.max,a.respawn
 end
 return out
end

--[[ Размещение на земле ]]
local function avoidPoints()
 local list={}
 for _,class in ipairs({"stalker_npc_trader","stalker_recruiter","info_player_start","info_player_deathmatch","info_player_terrorist","info_player_counterterrorist"}) do
  for _,e in ipairs(ents.FindByClass(class)) do list[#list+1]=e:GetPos() end
 end
 return list
end
-- Случайная точка пола внутри круга: без воды, неба, крутых склонов и близких занятых мест.
function Z.GroundPoint(center,radius,taken,gap,avoid)
 for _=1,30 do
  local a=math.Rand(0,math.pi*2);local d=radius*math.sqrt(math.Rand(0,1))
  for _,lift in ipairs({64,220}) do
   local start=center+Vector(math.cos(a)*d,math.sin(a)*d,lift)
   local tr=util.TraceLine({start=start,endpos=start-Vector(0,0,lift+700),mask=MASK_SOLID_BRUSHONLY})
   if tr.Hit and not tr.StartSolid and not tr.HitSky and tr.HitNormal.z>=.7 and math.abs(tr.HitPos.z-center.z)<=480 then
    local pos=tr.HitPos
    local ok=util.IsInWorld(pos+Vector(0,0,16)) and bit.band(util.PointContents(pos+Vector(0,0,8)),CONTENTS_WATER)==0
    for _,other in ipairs(taken or {}) do if ok and other:DistToSqr(pos)<gap*gap then ok=false end end
    for _,other in ipairs(avoid or {}) do if ok and other:DistToSqr(pos)<300*300 then ok=false end end
    if ok then return pos end
    break
   end
  end
 end
end

--[[ Поля аномалий ]]
local function clearField(id)
 local rt=Z.Runtime.fields[id];if not rt then return end
 for _,e in ipairs(rt.anomalies or {}) do if IsValid(e) then e:Remove() end end
 for _,e in ipairs(rt.artifacts or {}) do if IsValid(e) then e:Remove() end end
 Z.Runtime.fields[id]=nil
end
function Z.CountArtifacts() return #ents.FindByClass("stalker_artifact") end

local function pickArtifact(kind)
 local pool,total={},0
 for id,info in pairs(Z.Artifacts) do
  if STALKER_INV.Items[id] and (info.anomalies[kind] or false) then pool[#pool+1]=info;total=total+info.weight end
 end
 if total==0 then for id,info in pairs(Z.Artifacts) do if STALKER_INV.Items[id] then pool[#pool+1]=info;total=total+info.weight end end end
 local roll=math.Rand(0,total)
 for _,info in ipairs(pool) do roll=roll-info.weight;if roll<=0 then return info end end
 return pool[#pool]
end

function Z.SpawnArtifacts(id)
 local field=Z.World.fields[id];local rt=Z.Runtime.fields[id]
 if not field or not rt then return 0 end
 local alive={};for _,e in ipairs(rt.artifacts) do if IsValid(e) then alive[#alive+1]=e end end
 rt.artifacts=alive
 local anomalies={};for _,e in ipairs(rt.anomalies) do if IsValid(e) then anomalies[#anomalies+1]=e end end
 if #anomalies==0 then return 0 end
 local spawned=0
 while #rt.artifacts<field.artifacts and Z.CountArtifacts()<Z.Config.MaxArtifacts do
  local host=anomalies[math.random(#anomalies)];local cfg=host:Config()
  local info=pickArtifact(host:GetKind());if not info then break end
  local taken={};for _,e in ipairs(rt.artifacts) do taken[#taken+1]=e:GetPos() end
  local pos=Z.GroundPoint(host:GetPos(),math.max(60,cfg.radius+30),taken,48)
  if not pos then break end
  local e=ents.Create("stalker_artifact")
  if not IsValid(e) then break end
  e:SetArtifactID(info.id);e:SetPos(pos+Vector(0,0,2));e:SetAngles(Angle(0,math.random(0,359),0));e:Spawn()
  if not IsValid(e) then break end
  rt.artifacts[#rt.artifacts+1]=e;spawned=spawned+1
 end
 return spawned
end

function Z.BuildField(id)
 clearField(id)
 local field=Z.World.fields[id];if not field then return end
 local rt={anomalies={},artifacts={}};Z.Runtime.fields[id]=rt
 local center=Vector(field.pos.x,field.pos.y,field.pos.z)
 local kinds={};for kind in pairs(field.types) do kinds[#kinds+1]=kind end
 table.sort(kinds)
 local taken,avoid={},avoidPoints()
 for _=1,field.count do
  local pos=Z.GroundPoint(center,field.radius,taken,Z.Config.AnomalyMinGap,avoid)
  if not pos then break end
  local e=ents.Create("stalker_anomaly")
  if IsValid(e) then
   e:SetKind(kinds[math.random(#kinds)]);e:SetPos(pos+Vector(0,0,1));e:Spawn()
   rt.anomalies[#rt.anomalies+1]=e;taken[#taken+1]=pos
  end
 end
 Z.SpawnArtifacts(id)
end

function Z.RegenerateAll(announce)
 for id in pairs(Z.Runtime.fields) do clearField(id) end
 for id in SortedPairs(Z.World.fields) do Z.BuildField(id) end
 if announce and Z.Config.AnnounceRegen and next(Z.World.fields) then
  for _,p in ipairs(player.GetHumans()) do p:ChatPrint("[КПК] Выброс закончился. Аномалии сместились — в Зоне появились новые артефакты.") end
 end
 hook.Run("STALKER_ZONE_Regenerated")
end

function Z.TopUpArtifacts()
 local total=0
 for id in pairs(Z.World.fields) do total=total+Z.SpawnArtifacts(id) end
 return total
end

--[[ Подбор артефакта ]]
function Z.PickupArtifact(p,ent)
 if not IsValid(ent) or ent.Taken or not p:Alive() then return end
 if p:GetShootPos():DistToSqr(ent:WorldSpaceCenter())>Z.Config.ArtifactPickupRange^2 then return end
 if ST_EMISSION and ST_EMISSION.IsUnconscious and ST_EMISSION.IsUnconscious(p) then return end
 local inv=p.StalkerInventory
 if not inv or p.StalkerLoadError then return end
 if not Z.BestDetector(inv) then p:ChatPrint("[КПК] Без детектора в рюкзаке артефакт не нащупать");return end
 if hook.Run("STALKER_INV_CanPickup",p,ent,{id=ent:GetArtifactID(),count=1})==false then return end
 local id=ent:GetArtifactID()
 local ok,err=STALKER_INV.GiveItem(p,id,1)
 if not ok then p:ChatPrint("[КПК] "..tostring(err));return end
 ent.Taken=true;ent:Remove()
 local d=STALKER_INV.Items[id]
 p:EmitSound("items/battery_pickup.wav",70,110)
 p:ChatPrint("[КПК] Найден артефакт: "..(d and d.name or id))
 hook.Run("STALKER_ZONE_ArtifactPicked",p,id)
end

--[[ Жизненный цикл карты ]]
hook.Add("InitPostEntity","STALKER_ZONE.World",function()
 Z.LoadWorld()
 timer.Simple(5,function() Z.RegenerateAll(false);if Z.InitMutants then Z.InitMutants() end end)
end)
hook.Add("PostCleanupMap","STALKER_ZONE.World",function()
 Z.Runtime.fields={}
 timer.Simple(1,function() Z.RegenerateAll(false);if Z.InitMutants then Z.InitMutants() end end)
end)
hook.Add("STEmissionFinished","STALKER_ZONE.Regenerate",function() Z.RegenerateAll(true) end)
timer.Create("STALKER_ZONE.ArtifactRefresh",60,0,function()
 local minutes=Z.Config.ArtifactRefreshMinutes;if minutes<=0 then return end
 Z.RefreshCounter=(Z.RefreshCounter or 0)+1
 if Z.RefreshCounter>=minutes then Z.RefreshCounter=0;Z.TopUpArtifacts() end
end)
