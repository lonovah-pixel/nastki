-- Квестодатели и места заданий на карте: хранятся по картам в data/stalker_quests/<карта>.json.
-- Квестодатели ставит администратор (панель «Задания» в «Коменданте» или окно stq_menu), при загрузке карты
-- и после очистки они восстанавливаются из файла.
local Q=STALKER_QUESTS
local C=STALKER_CORE
local Cfg=Q.Config
file.CreateDir("stalker_quests")
Q.WorldPath="stalker_quests/"..game.GetMap()..".json"
Q.World={version=1,seq=0,npcs={},points={}}
Q.NPCEnts=Q.NPCEnts or {}

local function vec(t) return type(t)=="table" and C.Num(t.x,-1e7,1e7) and C.Num(t.y,-1e7,1e7) and C.Num(t.z,-1e7,1e7) end
function Q.CleanName(s,maxChars)
 if type(s)~="string" then return end
 s=s:match("^%s*(.-)%s*$")
 if C.Str(s,(maxChars or 48)*2) and (utf8.len(s) or #s)<=(maxChars or 48) then return s end
end
local function cleanID(id) id=tostring(id or "");if id:match("^[%w_]+$") and #id<=32 then return id end end

-- Единая проверка записей: из файла и из админ-панели.
function Q.ValidNPC(a)
 if type(a)~="table" or not vec(a.pos) or not Q.Profiles[a.profile or ""] then return end
 local name=Q.CleanName(a.name) or Q.Profiles[a.profile].name
 return {profile=a.profile,name=name,pos={x=a.pos.x,y=a.pos.y,z=a.pos.z},yaw=C.Num(a.yaw,-360,360) and math.Round(a.yaw) or 0}
end
function Q.ValidPoint(a)
 if type(a)~="table" or not vec(a.pos) then return end
 local name=Q.CleanName(a.name);if not name then return end
 return {name=name,pos={x=a.pos.x,y=a.pos.y,z=a.pos.z}}
end

function Q.LoadWorld()
 local world={version=1,seq=0,npcs={},points={}}
 local raw=file.Read(Q.WorldPath,"DATA")
 if raw then
  local data=util.JSONToTable(raw)
  if type(data)~="table" then
   -- Повреждённый файл не перезаписываем молча: правка блокируется до ручного восстановления.
   Q.WorldBroken=true;ErrorNoHalt("[STALKER Quests] Повреждён "..Q.WorldPath.."; правка квестодателей заблокирована\n")
  else
   Q.WorldBroken=nil
   world.seq=C.Int(data.seq,0,1e9) and data.seq or 0
   for id,a in SortedPairs(type(data.npcs)=="table" and data.npcs or {}) do
    local rec,key=Q.ValidNPC(a),cleanID(id)
    if rec and key and table.Count(world.npcs)<Cfg.MaxNPC then rec.id=key;world.npcs[key]=rec end
   end
   for id,a in SortedPairs(type(data.points)=="table" and data.points or {}) do
    local rec,key=Q.ValidPoint(a),cleanID(id)
    if rec and key and table.Count(world.points)<Cfg.MaxPoints then rec.id=key;world.points[key]=rec end
   end
  end
 end
 Q.World=world
 return world
end

-- Атомарная запись: черновик → проверка → резервная копия → основной файл.
function Q.SaveWorld()
 if Q.WorldBroken then return false end
 local payload=util.TableToJSON(Q.World,true);if not payload then return false end
 local path=Q.WorldPath
 file.Write(path..".pending.json",payload)
 if file.Read(path..".pending.json","DATA")~=payload then return false end
 local old=file.Read(path,"DATA");if old then file.Write(path..".backup.json",old) end
 file.Write(path,payload)
 if file.Read(path,"DATA")~=payload then return false end
 file.Delete(path..".pending.json")
 return true
end
-- Изменение целиком или откат: fn(мир) → true | false,"причина".
function Q.EditWorld(fn)
 if Q.WorldBroken then return false,"Файл квестодателей повреждён: восстановите data/"..Q.WorldPath end
 local backup=table.Copy(Q.World)
 local ok,err=fn(Q.World)
 if not ok then Q.World=backup;return false,err end
 if not Q.SaveWorld() then Q.World=backup;return false,"Ошибка записи файла квестодателей" end
 return true
end
-- Новый ID не совпадает с существующими, даже если счётчик в файле правили вручную.
function Q.NextID(prefix)
 local w=Q.World;local id
 repeat w.seq=(w.seq or 0)+1;id=prefix..w.seq until not w.npcs[id] and not w.points[id]
 return id
end

--[[ Сущности квестодателей ]]
function Q.FindNPC(id)
 local ent=id and Q.NPCEnts[id]
 if IsValid(ent) then return ent end
 for _,e in ipairs(ents.FindByClass("stalker_quest_npc")) do if e:GetNpcID()==id then Q.NPCEnts[id]=e;return e end end
end
function Q.NPCList()
 local out={}
 for _,e in ipairs(ents.FindByClass("stalker_quest_npc")) do if IsValid(e) and e:GetNpcID()~="" then out[#out+1]=e end end
 return out
end
function Q.AnyNPCOfProfile(profile)
 for _,e in ipairs(Q.NPCList()) do if e:GetProfile()==profile then return e end end
end
-- Подпись квестодателя: «Бармен» или «Бармен «Шустрый»», если администратор задал своё имя.
function Q.NPCName(ent)
 if not IsValid(ent) then return "квестодатель" end
 local prof=Q.Profiles[ent:GetProfile()];local base=prof and prof.name or "Квестодатель";local name=ent:GetQuestName()
 if name=="" or name==base then return base end
 return base.." «"..name.."»"
end
function Q.SpawnNPC(rec)
 local old=Q.FindNPC(rec.id);if IsValid(old) then old:Remove() end
 local ent=ents.Create("stalker_quest_npc");if not IsValid(ent) then return end
 ent:SetProfile(rec.profile);ent:SetNpcID(rec.id)
 ent:SetQuestName(rec.name~=(Q.Profiles[rec.profile] or {}).name and rec.name or "")
 ent:SetPos(Vector(rec.pos.x,rec.pos.y,rec.pos.z));ent:SetAngles(Angle(0,rec.yaw or 0,0))
 ent:Spawn();ent:Activate()
 Q.NPCEnts[rec.id]=ent
 return ent
end
function Q.RestoreNPCs()
 for _,e in ipairs(ents.FindByClass("stalker_quest_npc")) do if IsValid(e) then e:Remove() end end
 Q.NPCEnts={}
 for _,rec in SortedPairs(Q.World.npcs) do Q.SpawnNPC(rec) end
 if Q.RefreshAll then Q.RefreshAll() end
end

--[[ Места для заданий «Разведка»: места администратора, точки интереса событий, поля аномалий и логова Зоны. ]]
function Q.Places(kind)
 local out={}
 local function add(id,name,p,extra)
  if vec(p) then local row={id=id,name=name,pos=Vector(p.x,p.y,p.z)};if extra then for k,v in pairs(extra) do row[k]=v end end;out[#out+1]=row end
 end
 if kind=="point" then
  for id,p in SortedPairs(Q.World.points) do add("point:"..id,p.name,p.pos) end
 elseif kind=="poi" then
  local E=STALKER_EVENTS;local pois=E and E.World and E.World.pois
  if type(pois)=="table" then for id,p in SortedPairs(pois) do if type(p)=="table" and type(p.name)=="string" then add("poi:"..tostring(id),p.name,p.pos) end end end
 elseif kind=="field" or kind=="lair" then
  local Z=STALKER_ZONE;local list=Z and Z.World and Z.World[kind=="field" and "fields" or "zones"]
  if type(list)=="table" then
   for id,row in SortedPairs(list) do
    if type(row)=="table" and type(row.name)=="string" then add(kind..":"..tostring(id),row.name,row.pos,{radius=row.radius,types=row.types,artifacts=row.artifacts}) end
   end
  end
 end
 return out
end
-- Ближайшее к точке место из списка (для подсказок к логову или полю).
function Q.Nearest(list,pos,filter)
 local best,bestD
 for _,row in ipairs(list) do
  if not filter or filter(row) then
   local d=row.pos:DistToSqr(pos)
   if not bestD or d<bestD then best,bestD=row,d end
  end
 end
 return best
end

-- Точка под прицелом администратора (до 4000 units).
function Q.AimPos(ply)
 local start=ply:EyePos()
 local tr=util.TraceLine({start=start,endpos=start+ply:GetAimVector()*4000,filter=ply,mask=MASK_SOLID})
 if not tr.Hit or tr.HitSky then return end
 return tr.HitPos
end

hook.Add("InitPostEntity","STALKER_QUESTS.World",function() Q.LoadWorld();Q.RestoreNPCs() end)
hook.Add("PostCleanupMap","STALKER_QUESTS.World",function() timer.Simple(0,function() Q.RestoreNPCs() end) end)
Q.LoadWorld()
