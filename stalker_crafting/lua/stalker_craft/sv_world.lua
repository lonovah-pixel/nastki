-- Верстаки и постоянные костры администратора: хранятся по картам в data/stalker_craft/<карта>.json и
-- возвращаются после перезапуска карты и очистки (PostCleanupMap). Походные костры игроков не сохраняются: живут FireMinutes.
local CR=STALKER_CRAFT
local C=STALKER_CORE
local Cfg=CR.Config
for _,n in ipairs({"open","start","cancel","repair","admin","state"}) do util.AddNetworkString("stalker_craft."..n) end
file.CreateDir("stalker_craft")
CR.WorldPath="stalker_craft/"..game.GetMap()..".json"
CR.World={version=1,seq=0,benches={},fires={}}
CR.FireStyles={ring="Костёр",barrel="Бочка с огнём"}

local function vec(t) return type(t)=="table" and C.Num(t.x,-1e7,1e7) and C.Num(t.y,-1e7,1e7) and C.Num(t.z,-1e7,1e7) end
local function cleanPlace(kind,p)
 if type(p)~="table" or not vec(p.pos) then return end
 local out={pos={x=p.pos.x,y=p.pos.y,z=p.pos.z},yaw=C.Num(p.yaw,-360,360) and p.yaw or 0}
 if kind=="fires" then out.style=CR.FireStyles[p.style or ""] and p.style or "ring" end
 return out
end
CR.CleanPlace=cleanPlace

function CR.LoadWorld()
 local world={version=1,seq=0,benches={},fires={}}
 local raw=file.Read(CR.WorldPath,"DATA")
 if raw then
  local data=util.JSONToTable(raw)
  if type(data)~="table" then
   -- Повреждённый файл не перезаписываем молча: правка мест блокируется до ручного восстановления.
   CR.WorldBroken=true;ErrorNoHalt("[STALKER Crafting] Повреждён "..CR.WorldPath.."; правка верстаков и костров заблокирована\n")
  else
   CR.WorldBroken=nil
   world.seq=C.Int(data.seq,0,1e9) and data.seq or 0
   for _,kind in ipairs({"benches","fires"}) do
    -- Лимит из настроек действует только на новые места: сниженный лимит не стирает уже поставленные.
    -- Жёсткий предел защищает от раздутого вручную файла.
    for id,p in SortedPairs(type(data[kind])=="table" and data[kind] or {}) do
     local clean=cleanPlace(kind,p);id=tostring(id)
     if clean and id:match("^[%w_]+$") and #id<=32 and table.Count(world[kind])<256 then clean.id=id;world[kind][id]=clean end
    end
   end
  end
 end
 CR.World=world
 return world
end
-- Атомарная запись: черновик → проверка → резервная копия → основной файл.
function CR.SaveWorld()
 if CR.WorldBroken then return false end
 local payload=util.TableToJSON(CR.World,true);if not payload then return false end
 local path=CR.WorldPath
 file.Write(path..".pending.json",payload)
 if file.Read(path..".pending.json","DATA")~=payload then return false end
 local old=file.Read(path,"DATA");if old then file.Write(path..".backup.json",old) end
 file.Write(path,payload)
 if file.Read(path,"DATA")~=payload then return false end
 file.Delete(path..".pending.json")
 return true
end
-- Изменение мест целиком или откат: fn(мир) → true | false,"причина".
function CR.EditWorld(fn)
 if CR.WorldBroken then return false,"Файл мест повреждён: восстановите data/"..CR.WorldPath end
 local backup=table.Copy(CR.World)
 local ok,err=fn(CR.World)
 if not ok then CR.World=backup;return false,err end
 if not CR.SaveWorld() then CR.World=backup;return false,"Ошибка записи файла мест" end
 CR.SpawnPlaces()
 return true
end

--[[ Сущности мест ]]
local function placed(class)
 local out={}
 for _,e in ipairs(ents.FindByClass(class)) do if IsValid(e) and e:GetPlaceID()~="" then out[e:GetPlaceID()]=e end end
 return out
end
local function spawnAt(class,p)
 local e=ents.Create(class);if not IsValid(e) then return end
 e:SetPos(Vector(p.pos.x,p.pos.y,p.pos.z));e:SetAngles(Angle(0,p.yaw or 0,0))
 if class=="stalker_campfire" then e:SetStyle(p.style or "ring") end
 e:SetPlaceID(p.id);e:Spawn();e:Activate()
 return e
end
-- Привести мир к файлу: недостающие места создаются, удалённые — убираются, стоящие не трогаются.
function CR.SpawnPlaces()
 for kind,class in pairs({benches="stalker_workbench",fires="stalker_campfire"}) do
  local have=placed(class)
  for id,e in pairs(have) do local p=CR.World[kind][id];if not p or (e.GetStyle and p.style and e:GetStyle()~=p.style) then e.StcraftRemoving=true;e:Remove();have[id]=nil end end
  for id,p in pairs(CR.World[kind]) do if not IsValid(have[id]) then spawnAt(class,p) end end
 end
 CR.RefreshMarkers()
end
function CR.RefreshMarkers()
 local MK=STALKER_MARKERS;if not MK then return end
 -- Временные метки «Показать места» (stcraft.show.*) не трогаем: они живут свои 2 минуты.
 MK.Clear("stcraft.bench.");MK.Clear("stcraft.fire.")
 if not Cfg.Markers then return end
 for id,p in pairs(CR.World.benches) do MK.Set("stcraft.bench."..id,{pos=Vector(p.pos.x,p.pos.y,p.pos.z),kind="poi",label="Верстак",world=false,edge=false,map=true,range=2500}) end
 for id,p in pairs(CR.World.fires) do MK.Set("stcraft.fire."..id,{pos=Vector(p.pos.x,p.pos.y,p.pos.z),kind="poi",label=CR.FireStyles[p.style] or "Костёр",world=false,edge=false,map=true,range=2500}) end
end

--[[ Походные костры игроков ]]
function CR.TempFires(sid)
 local out={}
 for _,e in ipairs(ents.FindByClass("stalker_campfire")) do
  if IsValid(e) and e:GetPlaceID()=="" and (not sid or e:GetOwnerSID()==sid) then out[#out+1]=e end
 end
 table.sort(out,function(a,b) return a:GetExpires()<b:GetExpires() end)
 return out
end
-- Точка для костра: земля под прицелом (до 150 units) или под ногами чуть впереди.
function CR.PlacePos(ply)
 local start=ply:EyePos();local aim=ply:GetAimVector()
 local tr=util.TraceLine({start=start,endpos=start+aim*150,filter=ply,mask=MASK_SOLID})
 local pos=tr.Hit and not tr.HitSky and tr.HitNormal.z>=.7 and tr.HitPos or nil
 if not pos then
  local fwd=Vector(aim.x,aim.y,0);if fwd:Length()<.01 then fwd=Vector(1,0,0) end;fwd:Normalize()
  local from=ply:GetPos()+fwd*48+Vector(0,0,32)
  local down=util.TraceLine({start=from,endpos=from-Vector(0,0,128),filter=ply,mask=MASK_SOLID})
  if not down.Hit or down.HitSky or down.HitNormal.z<.7 then return nil,"Нужна ровная земля перед вами" end
  pos=down.HitPos
 end
 if bit.band(util.PointContents(pos+Vector(0,0,4)),CONTENTS_WATER)~=0 then return nil,"В воде костёр не разжечь" end
 return pos
end
-- Разжечь походный костёр из предмета (вызывается из OnUse: true — предмет расходуется).
function CR.PlaceCampfire(ply)
 if not IsValid(ply) or not ply:Alive() then return false,"Сейчас нельзя" end
 if C.Unconscious(ply) then return false,"Вы без сознания" end
 local pos,err=CR.PlacePos(ply);if not pos then return false,err end
 for _,e in ipairs(ents.FindByClass("stalker_campfire")) do
  if IsValid(e) and e:IsLit() and e:GetPos():DistToSqr(pos)<80*80 then return false,"Здесь уже горит костёр" end
 end
 local sid=C.SID(ply) or ply:SteamID64() or ""
 local mine=CR.TempFires(sid)
 -- Лимит: самый старый свой костёр гаснет, чтобы новый можно было разжечь на привале.
 while #mine>=math.max(1,Cfg.FireLimit) do local old=table.remove(mine,1);if IsValid(old) then old:Remove() end end
 local e=ents.Create("stalker_campfire");if not IsValid(e) then return false,"Не удалось разжечь костёр" end
 e:SetPos(pos);e:SetAngles(Angle(0,ply:EyeAngles().y,0));e:SetStyle("ring")
 e:SetOwnerSID(sid);e:SetOwnerName(ply:Nick());e:SetExpires(CurTime()+math.max(1,Cfg.FireMinutes)*60)
 e:Spawn();e:Activate()
 e:EmitSound("ambient/fire/ignite.wav",70,100)
 C.Notify(ply,"Костёр разожжён на "..math.max(1,Cfg.FireMinutes).." мин. E — готовить; рядом с огнём раны медленно заживают.","ok",6)
 hook.Run("STALKER_CRAFT_FireLit",ply,e)
 return true
end

-- Раз в секунду: гаснут истёкшие костры; раз в FireHealInterval — лечение у огня.
CR.NextHeal=CR.NextHeal or 0
function CR.HealTick()
 local heal=math.floor(tonumber(Cfg.FireHeal) or 0);if heal<=0 then return 0 end
 local fires={}
 for _,e in ipairs(ents.FindByClass("stalker_campfire")) do if IsValid(e) and e:IsLit() then fires[#fires+1]=e:GetPos() end end
 if #fires==0 then return 0 end
 local r2=(tonumber(Cfg.FireHealRadius) or 160)^2;local n=0
 for _,p in ipairs(player.GetAll()) do
  if IsValid(p) and p:Alive() and p:Health()<p:GetMaxHealth() then
   local pos=p:GetPos()
   for _,f in ipairs(fires) do
    if f:DistToSqr(pos)<=r2 then p:SetHealth(math.min(p:GetMaxHealth(),p:Health()+heal));n=n+1;break end
   end
  end
 end
 return n
end
timer.Create("STALKER_CRAFT.Fires",1,0,function()
 local now=CurTime()
 for _,e in ipairs(ents.FindByClass("stalker_campfire")) do
  if IsValid(e) and not e:IsLit() then
   local owner=C.PlayerBySID(e:GetOwnerSID())
   if IsValid(owner) then C.Notify(owner,"Ваш костёр догорел","info",4) end
   e:Remove()
  end
 end
 if now>=CR.NextHeal then CR.NextHeal=now+math.max(1,tonumber(Cfg.FireHealInterval) or 5);CR.HealTick() end
end)

hook.Add("InitPostEntity","STALKER_CRAFT.World",function() CR.LoadWorld();CR.SpawnPlaces() end)
hook.Add("PostCleanupMap","STALKER_CRAFT.World",function() CR.SpawnPlaces() end)
CR.LoadWorld()
