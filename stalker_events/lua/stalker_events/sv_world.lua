-- Места событий и точки интереса администратора: хранятся по картам в data/stalker_events/<карта>.json.
-- Без размеченных мест события берут центры полей аномалий и логов Зоны или случайную землю рядом с игроками.
local E=STALKER_EVENTS
local C=STALKER_CORE
local Cfg=E.Config
file.CreateDir("stalker_events")
E.WorldPath="stalker_events/"..game.GetMap()..".json"
E.World={version=1,seq=0,spots={},pois={}}

local function vec(t) return type(t)=="table" and C.Num(t.x,-1e7,1e7) and C.Num(t.y,-1e7,1e7) and C.Num(t.z,-1e7,1e7) end
local function cleanName(s)
 if type(s)~="string" then return end
 s=s:match("^%s*(.-)%s*$")
 if C.Str(s,96) and (utf8.len(s) or #s)<=48 then return s end
end
E.CleanName=cleanName

-- Единая проверка записей: из файла и из админ-панели.
function E.ValidSpot(a)
 if type(a)~="table" or not vec(a.pos) then return end
 local name=cleanName(a.name);if not name then return end
 return {name=name,pos={x=a.pos.x,y=a.pos.y,z=a.pos.z}}
end
function E.ValidPOI(a)
 if type(a)~="table" or not vec(a.pos) then return end
 local name=cleanName(a.name);if not name or not E.POITypeName[a.kind or ""] then return end
 return {name=name,kind=a.kind,flag=a.flag==true,pos={x=a.pos.x,y=a.pos.y,z=a.pos.z}}
end

function E.LoadWorld()
 local world={version=1,seq=0,spots={},pois={}}
 local raw=file.Read(E.WorldPath,"DATA")
 if raw then
  local data=util.JSONToTable(raw)
  if type(data)~="table" then
   -- Повреждённый файл не перезаписываем молча: правка мест блокируется до ручного восстановления.
   E.WorldBroken=true;ErrorNoHalt("[STALKER Events] Повреждён "..E.WorldPath.."; правка мест заблокирована\n")
  else
   E.WorldBroken=nil
   world.seq=C.Int(data.seq,0,1e9) and data.seq or 0
   for id,s in pairs(type(data.spots)=="table" and data.spots or {}) do
    local clean=E.ValidSpot(s);id=tostring(id)
    if clean and id:match("^[%w_]+$") and #id<=32 and table.Count(world.spots)<Cfg.MaxSpots then clean.id=id;world.spots[id]=clean end
   end
   for id,p in pairs(type(data.pois)=="table" and data.pois or {}) do
    local clean=E.ValidPOI(p);id=tostring(id)
    if clean and id:match("^[%w_]+$") and #id<=32 and table.Count(world.pois)<Cfg.MaxPOI then clean.id=id;world.pois[id]=clean end
   end
  end
 end
 E.World=world
 E.RefreshPOIMarkers()
 return world
end

-- Атомарная запись: черновик → проверка → резервная копия → основной файл.
function E.SaveWorld()
 if E.WorldBroken then return false end
 local payload=util.TableToJSON(E.World,true);if not payload then return false end
 local path=E.WorldPath
 file.Write(path..".pending.json",payload)
 if file.Read(path..".pending.json","DATA")~=payload then return false end
 local old=file.Read(path,"DATA");if old then file.Write(path..".backup.json",old) end
 file.Write(path,payload)
 if file.Read(path,"DATA")~=payload then return false end
 file.Delete(path..".pending.json")
 return true
end

-- Изменение мира целиком или откат: fn(копия) → true | false,"причина".
function E.EditWorld(fn)
 if E.WorldBroken then return false,"Файл мест повреждён: восстановите "..E.WorldPath end
 local backup=table.Copy(E.World)
 local ok,err=fn(E.World)
 if not ok then E.World=backup;return false,err end
 if not E.SaveWorld() then E.World=backup;E.RefreshPOIMarkers();return false,"Ошибка записи файла мест" end
 E.RefreshPOIMarkers()
 return true
end
function E.NextID(prefix) E.World.seq=(E.World.seq or 0)+1;return prefix..E.World.seq end

--[[ Точки интереса: метки kind="poi" для всех ]]
function E.RefreshPOIMarkers()
 STALKER_MARKERS.Clear("stev.poi.")
 for id,p in pairs(E.World.pois) do
  STALKER_MARKERS.Set("stev.poi."..id,{pos=Vector(p.pos.x,p.pos.y,p.pos.z),kind="poi",label=(E.POITypeName[p.kind] or "Точка").." · "..p.name,world=p.flag==true,map=true})
 end
end

--[[ Земля и выбор места ]]
-- Точка пола под позицией: без неба, воды и крутых склонов.
function E.Ground(pos,lift)
 if not pos then return end
 local start=pos+Vector(0,0,lift or 128)
 local tr=util.TraceLine({start=start,endpos=start-Vector(0,0,1200),mask=MASK_SOLID_BRUSHONLY})
 if not tr.Hit or tr.StartSolid or tr.HitSky or tr.HitNormal.z<.6 then return end
 local p=tr.HitPos
 if not util.IsInWorld(p+Vector(0,0,16)) or bit.band(util.PointContents(p+Vector(0,0,8)),CONTENTS_WATER)~=0 then return end
 return p
end
-- Случайная точка земли в кольце вокруг центра (для NPC и грузов).
function E.Around(center,rMin,rMax)
 for _=1,10 do
  local a=math.Rand(0,math.pi*2);local d=math.Rand(rMin,rMax)
  local p=E.Ground(center+Vector(math.cos(a)*d,math.sin(a)*d,0))
  if p then
   local tr=util.TraceHull({start=p+Vector(0,0,6),endpos=p+Vector(0,0,6),mins=Vector(-18,-18,0),maxs=Vector(18,18,72),mask=MASK_NPCSOLID})
   if not tr.Hit and not tr.StartSolid then return p end
  end
 end
end

-- Центры полей аномалий (kind="fields") или логов (kind="zones") STALKER Zone.
function E.ZonePoints(kind)
 local Z=STALKER_ZONE;local out={}
 local list=Z and Z.World and Z.World[kind]
 if type(list)~="table" then return out end
 for id,row in SortedPairs(list) do
  if type(row)=="table" and vec(row.pos) then out[#out+1]={id=kind..":"..tostring(id),name=row.name,pos=Vector(row.pos.x,row.pos.y,row.pos.z),radius=row.radius,types=row.types} end
 end
 return out
end

-- Место события. prefer: "lair" (логова), "field" (поля аномалий) или nil.
-- Порядок: места администратора → объекты Зоны → случайная земля рядом с живым игроком.
function E.PickPoint(prefer)
 local cands={}
 for id,s in SortedPairs(E.World.spots) do cands[#cands+1]={id="spot:"..id,name=s.name,pos=Vector(s.pos.x,s.pos.y,s.pos.z)} end
 if prefer=="lair" then local lairs=E.ZonePoints("zones");if #lairs>0 and (#cands==0 or math.random()<.6) then cands=lairs end end
 if prefer=="field" then local fields=E.ZonePoints("fields");if #fields>0 and (#cands==0 or math.random()<.6) then cands=fields end end
 if #cands==0 then
  for _,row in ipairs(E.ZonePoints("fields")) do cands[#cands+1]=row end
  for _,row in ipairs(E.ZonePoints("zones")) do cands[#cands+1]=row end
 end
 -- Одно и то же место два раза подряд — скучно.
 if #cands>1 then for i=#cands,1,-1 do if cands[i].id==E.LastPoint then table.remove(cands,i) end end end
 if #cands>0 then
  local c=cands[math.random(#cands)];E.LastPoint=c.id
  return E.Ground(c.pos) or c.pos,c.name,c
 end
 local alive={}
 for _,p in ipairs(player.GetHumans()) do if p:Alive() then alive[#alive+1]=p end end
 if #alive==0 then return end
 local p=alive[math.random(#alive)]
 local pos=E.Around(p:GetPos(),Cfg.RandomMin,Cfg.RandomMax)
 if pos then E.LastPoint=nil;return pos,"окрестности" end
end
-- Подпись места для новостей: «у логова „Свалка“».
function E.Where(name) return name and ("«"..name.."»") or "неизвестный район" end

-- Место под прицелом администратора (до 4000 units).
function E.AimPos(ply)
 local start=ply:EyePos()
 local tr=util.TraceLine({start=start,endpos=start+ply:GetAimVector()*4000,filter=ply,mask=MASK_SOLID})
 if not tr.Hit or tr.HitSky then return end
 return tr.HitPos
end

hook.Add("InitPostEntity","STALKER_EVENTS.World",function() E.LoadWorld() end)
E.LoadWorld()
