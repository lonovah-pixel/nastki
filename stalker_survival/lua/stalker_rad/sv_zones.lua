-- Радиационные зоны карты: файл data/stalker_radiation/<карта>.json, миграция старого формата, API правки.
-- Формат 2: {version=2, map, next, zones={{id,name,pos={x,y,z},radius,rate,falloff,enabled}}}.
-- Запись атомарная: сначала копия .pending.json с проверкой чтением, затем основной файл с проверкой.
-- Повреждённый файл не перезаписывается: редактирование блокируется до исправления и stalker_rad_reload.
local R=STALKER_RAD
local C=STALKER_CORE
R.Dir="stalker_radiation"
R.Path=R.Dir.."/"..game.GetMap()..".json"
R.PendingPath=R.Path..".pending.json"
R.Zones=R.Zones or {}
R.ByID=R.ByID or {}
R.Revision=R.Revision or 0

local function reindex()
 R.ByID={}
 for _,z in ipairs(R.Zones) do R.ByID[z.id]=z end
end
-- Числовой хвост id ("rad_12" → 12): счётчик не должен выдать уже занятый id.
local function suffix(id) return tonumber(tostring(id):match("_(%d+)$")) or 0 end

local function fail(msg,keepZones)
 R.Ready=false
 R.LoadError=msg..(file.Exists(R.PendingPath,"DATA") and " (есть незавершённая копия "..R.PendingPath..")" or "")
 if not keepZones then R.Zones={};reindex() end
 ErrorNoHalt("[Radiation] "..R.Path..": "..R.LoadError.."; редактирование зон заблокировано\n")
 return false
end

-- Запись состояния. Возвращает true только если оба файла прочитались обратно байт в байт.
local function save(zones,nextID)
 local payload=util.TableToJSON({version=2,map=game.GetMap(),next=nextID,zones=zones},true)
 if not payload then return false end
 file.CreateDir(R.Dir)
 file.Write(R.PendingPath,payload)
 if file.Read(R.PendingPath,"DATA")~=payload then return false end
 file.Write(R.Path,payload)
 if file.Read(R.Path,"DATA")~=payload then return false end
 file.Delete(R.PendingPath)
 return true
end

-- Полная проверка сохранённой зоны (формат 2).
local function cleanStored(z)
 if type(z)~="table" then return nil,"запись не является таблицей" end
 if type(z.id)~="string" or #z.id>32 or not z.id:match(R.IDPattern) then return nil,"некорректный id" end
 local f,err=R.CleanFields(z,false);if not f then return nil,err end
 f.pos=R.CleanPos(z.pos);if not f.pos then return nil,"некорректные координаты" end
 f.id=z.id
 return f
end
local function isList(t) return type(t)=="table" and table.Count(t)==#t end

-- Старый формат — массив {pos,radius,rate}. Ничего не теряем: значения приводятся к границам,
-- бездействовавшие зоны (доза ≤ 0) переносятся выключенными, исходный файл сохраняется копией.
local function migrate(list,raw)
 if not isList(list) then return fail("старый формат: ожидался массив зон") end
 local L=R.Limits;local zones,skipped={},0
 for i,z in ipairs(list) do
  local pos=type(z)=="table" and R.CleanPos(z.pos)
  local radius=type(z)=="table" and tonumber(z.radius)
  local rate=type(z)=="table" and tonumber(z.rate)
  if pos and R.Finite(radius) and R.Finite(rate) then
   local n=#zones+1
   zones[n]={id="rad_"..n,name="Зона "..i,pos=pos,radius=math.Clamp(math.Round(radius),L.radiusMin,L.radiusMax),
    rate=math.Clamp(math.Round(rate,2),L.rateMin,L.rateMax),falloff=false,enabled=rate>0}
  else skipped=skipped+1 end
 end
 R.Zones=zones;R.NextID=#zones+1;reindex()
 local backup=R.Dir.."/"..game.GetMap()..".v1_"..os.time()..".json"
 file.Write(backup,raw)
 if file.Read(backup,"DATA")~=raw then return fail("не удалось сохранить копию старого файла "..backup,true) end
 if not save(zones,R.NextID) then return fail("не удалось записать новый формат (исходник: "..backup..")",true) end
 R.Ready=true;R.LoadError=nil
 R.Migrated={count=#zones,skipped=skipped,backup=backup}
 print(string.format("[Radiation] %s: перенесено зон %d, пропущено %d, копия старого файла: data/%s",R.Path,#zones,skipped,backup))
 return true
end

-- Чтение файла зон текущей карты. Вызывается при загрузке и командой stalker_rad_reload.
function R.Load()
 file.CreateDir(R.Dir)
 R.Zones={};R.NextID=1;R.Ready=false;R.LoadError=nil;R.Migrated=nil;reindex()
 local raw=file.Read(R.Path,"DATA")
 if raw==nil then R.Ready=true;R.Revision=R.Revision+1;return true end
 local data=util.JSONToTable(raw)
 if type(data)~="table" then return fail("файл не читается как JSON") end
 if data.version==nil and data.zones==nil then local ok=migrate(data,raw);R.Revision=R.Revision+1;return ok end
 if data.version~=2 or not isList(data.zones) then return fail("неизвестный формат файла (version="..tostring(data.version)..")") end
 local zones,seen,bad,top={},{},nil,0
 for i,z in ipairs(data.zones) do
  local clean,err=cleanStored(z)
  if clean and seen[clean.id] then clean,err=nil,"повторяющийся id "..clean.id end
  if clean then seen[clean.id]=true;zones[#zones+1]=clean;top=math.max(top,suffix(clean.id))
  else bad=bad or ("зона №"..i..": "..tostring(err)) end
 end
 -- Исправные зоны продолжают работать, но файл с ошибкой не перезаписываем.
 R.Zones=zones;R.NextID=math.max(math.floor(tonumber(data.next) or 1),top+1);reindex();R.Revision=R.Revision+1
 if bad then return fail(bad,true) end
 R.Ready=true
 return true
end

function R.GetZone(id) if type(id)=="string" then return R.ByID[id] end end
-- Зона по id или порядковому номеру списка (для консоли): "rad_3" или "3".
function R.FindZone(ref)
 if type(ref)=="string" and R.ByID[ref] then return R.ByID[ref] end
 local n=tonumber(ref)
 if n and n%1==0 and R.Zones[n] then return R.Zones[n] end
end
function R.IndexOf(id) for i,z in ipairs(R.Zones) do if z.id==id then return i end end end

local function blocked()
 if R.Ready then return end
 return "Редактирование зон заблокировано: "..(R.LoadError or "файл зон не загружен")
end
-- Применение нового списка: запись на диск, затем замена в памяти. При ошибке записи ничего не меняется.
local function commit(zones,nextID,action,id)
 local err=blocked();if err then return false,err end
 if not save(zones,nextID) then return false,"Ошибка записи файла зон (проверьте место на диске и права на data/)" end
 R.Zones=zones;R.NextID=nextID;reindex();R.Revision=R.Revision+1
 hook.Run("STALKER_RadZonesChanged",action,id)
 return true
end

--[[ API для других аддонов и «Коменданта».
 AddZone(data) → id | nil, "причина". data: name, pos (Vector или {x,y,z}), radius, rate, falloff, enabled.
 UpdateZone(id, fields) → true | false, "причина". Поля как у AddZone (pos — перемещение).
 RemoveZone(id) → true | false, "причина". ]]
function R.AddZone(data)
 local err=blocked();if err then return nil,err end
 if type(data)~="table" then return nil,"Нет данных зоны" end
 if #R.Zones>=R.Config.ZonesLimit then return nil,"Достигнут лимит зон на карте ("..R.Config.ZonesLimit..")" end
 local f,e=R.CleanFields(data,false);if not f then return nil,e end
 f.pos=R.CleanPos(data.pos);if not f.pos then return nil,"Некорректная позиция зоны" end
 local n=math.max(1,R.NextID or 1)
 while R.ByID["rad_"..n] do n=n+1 end
 f.id="rad_"..n
 if f.name=="" then f.name="Зона "..n end
 local zones=table.Copy(R.Zones);zones[#zones+1]=f
 local ok,why=commit(zones,n+1,"add",f.id);if not ok then return nil,why end
 return f.id
end
function R.UpdateZone(id,fields)
 local err=blocked();if err then return false,err end
 local i=R.GetZone(id) and R.IndexOf(id);if not i then return false,"Зона не найдена" end
 if type(fields)~="table" then return false,"Нет изменений" end
 local f,e=R.CleanFields(fields,true);if not f then return false,e end
 if fields.pos~=nil then f.pos=R.CleanPos(fields.pos);if not f.pos then return false,"Некорректная позиция зоны" end end
 -- Пустое имя при правке оставляет прежнее.
 if f.name=="" then f.name=nil end
 local zones=table.Copy(R.Zones)
 for k,v in pairs(f) do zones[i][k]=v end
 return commit(zones,R.NextID,"update",id)
end
function R.RemoveZone(id)
 local err=blocked();if err then return false,err end
 local i=R.GetZone(id) and R.IndexOf(id);if not i then return false,"Зона не найдена" end
 local zones=table.Copy(R.Zones);table.remove(zones,i)
 return commit(zones,R.NextID,"remove",id)
end

-- Точка установки для администратора: по прицелу (до 4096 units) или под ногами.
function R.PlacementPos(p,placement)
 if not IsValid(p) then return nil,"Нужен игрок" end
 if placement=="feet" then return p:GetPos() end
 local tr=p:GetEyeTrace()
 if not tr or not tr.Hit or tr.HitSky then return nil,"Прицел не указывает на поверхность" end
 if p:GetPos():DistToSqr(tr.HitPos)>4096^2 then return nil,"Точка прицела дальше 4096 units" end
 return tr.HitPos
end

-- Перемещение администратора к зоне: свободное место в центре или рядом (точка возврата — для «Коменданта»).
function R.TeleportTo(p,id)
 local z=R.GetZone(id);if not z then return false,"Зона не найдена" end
 if not IsValid(p) or not p:Alive() then return false,"Нужно быть живым" end
 local center=Vector(z.pos.x,z.pos.y,z.pos.z)
 local A=STALKER_ADMIN
 local pos=A and A.SafePosition and A.SafePosition(p,center)
 if not pos then
  for _,off in ipairs({Vector(0,0,0),Vector(64,0,0),Vector(-64,0,0),Vector(0,64,0),Vector(0,-64,0),Vector(128,128,0),Vector(-128,-128,0)}) do
   local at=center+off
   local tr=util.TraceHull({start=at+Vector(0,0,72),endpos=at-Vector(0,0,96),mins=Vector(-16,-16,0),maxs=Vector(16,16,72),filter=p,mask=MASK_PLAYERSOLID})
   if not tr.StartSolid and not tr.AllSolid and util.IsInWorld(at) then pos=(tr.Hit and tr.HitPos or at)+Vector(0,0,2);break end
  end
 end
 if not pos then return false,"Нет свободного места у зоны" end
 p.StaReturn={pos=p:GetPos(),map=game.GetMap()}
 if p:InVehicle() then p:ExitVehicle() end
 p:SetPos(pos);p:SetLocalVelocity(Vector(0,0,0))
 return true
end

-- Строка списка для консоли.
function R.Describe(z,i)
 return string.format("%s. [%s] %s — %.0f %.0f %.0f, радиус %d, %.2f ед./с%s%s",tostring(i or R.IndexOf(z.id) or "?"),z.id,z.name,z.pos.x,z.pos.y,z.pos.z,z.radius,z.rate,
  z.falloff and ", спад к краю" or "",z.enabled and "" or ", ВЫКЛЮЧЕНА")
end

--[[ Консоль. Право — radiation через STALKER_CORE.CanAdmin (без ядра — суперадмин). ]]
local function allowed(p)
 if not IsValid(p) then return true end
 if C and C.CanAdmin then return C.CanAdmin(p,"radiation") end
 return p:IsSuperAdmin()
end
local function reply(p,msg,console)
 if IsValid(p) then if console then p:PrintMessage(HUD_PRINTCONSOLE,msg) else p:ChatPrint(msg) end else print("[Radiation] "..msg) end
end
local function audit(p,action,target,detail,ok)
 local A=STALKER_ADMIN
 if A and A.Audit then pcall(A.Audit,p,"radiation_"..action,target or "",detail or "",ok and "success" or "failed") end
end
R.Audit=audit
-- stalker_rad_add <радиус> <ед./с> [спад 0|1] [имя…] — зона по прицелу.
concommand.Add("stalker_rad_add",function(p,_,args)
 if not IsValid(p) then reply(p,"Зона ставится по прицелу игрока; из консоли сервера используйте STALKER_RAD.AddZone");return end
 if not allowed(p) then return end
 local pos,err=R.PlacementPos(p,"aim");if not pos then reply(p,err);return end
 local falloff=args[3];if falloff~=nil then falloff=falloff~="0" end
 local id,e=R.AddZone({pos=pos,radius=tonumber(args[1]) or 300,rate=tonumber(args[2]) or 2,falloff=falloff,name=table.concat(args," ",4)})
 audit(p,"add",id or "",e or "",id~=nil)
 reply(p,id and ("Радиационная зона добавлена: "..R.Describe(R.ByID[id])) or ("Зона не добавлена: "..tostring(e)))
end)
-- stalker_rad_remove <id|номер>
concommand.Add("stalker_rad_remove",function(p,_,args)
 if not allowed(p) then return end
 local z=R.FindZone(args[1]);if not z then reply(p,"Зона не найдена: укажите id или номер из stalker_rad_list");return end
 local ok,err=R.RemoveZone(z.id)
 audit(p,"remove",z.id,err or z.name,ok)
 reply(p,ok and ("Зона удалена: "..z.id.." «"..z.name.."»") or ("Зона не удалена: "..tostring(err)))
end)
concommand.Add("stalker_rad_list",function(p)
 if not allowed(p) then return end
 reply(p,string.format("Радиационные зоны %s: %d / %d%s",game.GetMap(),#R.Zones,R.Config.ZonesLimit,R.Ready and "" or (" — "..tostring(R.LoadError))),true)
 for i,z in ipairs(R.Zones) do reply(p,R.Describe(z,i),true) end
end)
-- Перечитать файл после ручного исправления.
concommand.Add("stalker_rad_reload",function(p)
 if not allowed(p) then return end
 local ok=R.Load()
 hook.Run("STALKER_RadZonesChanged","reload")
 reply(p,ok and ("Файл зон перечитан: "..#R.Zones.." зон") or ("Файл зон с ошибкой: "..tostring(R.LoadError)))
end)

R.Load()
