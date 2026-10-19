-- Метки Зоны на карте КПК (STALKER_MARKERS): торговцы, вербовщики, поля аномалий и логова мутантов.
-- Только карта: без значков на экране (range=0), стрелок у края и флажков в мире. Обновляются после
-- правки редактора, перестройки Зоны и раз в 30 с (торговцев и вербовщиков расставляют другие аддоны).
local Z=STALKER_ZONE
Z.MarkerCache=Z.MarkerCache or {}
local PREFIX="stz."

local function mapOnly(data) data.world=false;data.edge=false;data.range=0;data.hud=false;data.map=true;return data end
local function vec(t) return Vector(t.x,t.y,t.z) end
local function factionColor(id) local C=STALKER_CORE;return id and C and C.FactionColor and C.FactionColor(id) or nil end
local function factionName(id) local C=STALKER_CORE;return C and C.FactionName and C.FactionName(id) or tostring(id) end

-- Имя торговца из профиля торговли (локализованная таблица {ru=…}) и его группировка.
local function traderInfo(id)
 local N=STALKER_NPC;local profile=N and N.Config and N.Config.Traders and N.Config.Traders[id]
 if not profile then return "Торговец" end
 local name=profile.name
 if type(name)=="table" then name=N.Text and N.Text(name,"ru") or name.ru or name.en end
 name=type(name)=="string" and name~="" and name or "Торговец"
 local faction=profile.Faction
 if not faction and STFW and STFW.Config and STFW.Config.TraderFactions then faction=STFW.Config.TraderFactions[id] end
 return name,faction
end

-- Полный набор меток Зоны: {[id]=data}.
function Z.CollectMarkers()
 local out={}
 if Z.Config.MarkTraders~=false then
  for _,e in ipairs(ents.FindByClass("stalker_npc_trader")) do
   if IsValid(e) then
    local name,faction=traderInfo(e.GetTraderID and e:GetTraderID() or "")
    local label=(faction and faction~="loner") and (name.." · "..factionName(faction)) or name
    out[PREFIX.."trader."..e:EntIndex()]=mapOnly({pos=e:GetPos(),label=label,kind="trader",color=factionColor(faction)})
   end
  end
  for _,e in ipairs(ents.FindByClass("stalker_recruiter")) do
   if IsValid(e) then
    local faction=e.GetFactionID and e:GetFactionID() or ""
    out[PREFIX.."recruiter."..e:EntIndex()]=mapOnly({pos=e:GetPos(),label="Вербовщик · "..factionName(faction),kind="recruiter",color=factionColor(faction)})
   end
  end
 end
 if Z.Config.MarkFields~=false then
  for id,f in pairs(Z.World.fields or {}) do
   if type(f)=="table" and type(f.pos)=="table" then
    out[PREFIX.."field."..id]=mapOnly({pos=vec(f.pos),label="Аномальное поле",kind="anomaly",radius=f.radius})
   end
  end
  for id,zn in pairs(Z.World.zones or {}) do
   if type(zn)=="table" and type(zn.pos)=="table" then
    out[PREFIX.."lair."..id]=mapOnly({pos=vec(zn.pos),label="Логово мутантов",kind="lair",radius=zn.radius})
   end
  end
 end
 return out
end

-- Метка ставится заново только при изменении: снимок для игроков не пересылается без причины.
local function signature(d)
 local c=d.color
 return string.format("%s|%s|%.0f|%.0f|%.0f|%s|%s",d.kind,d.label,d.pos.x,d.pos.y,d.pos.z,tostring(d.radius or ""),c and (c.r..","..c.g..","..c.b) or "")
end
function Z.UpdateMarkers()
 local MK=STALKER_MARKERS;if not MK or not MK.Set or not MK.Remove then return 0 end
 local ok,list=pcall(Z.CollectMarkers)
 if not ok then Z.ReportError("Метки Зоны",list);return 0 end
 local cache=Z.MarkerCache;local n=0
 for id,data in pairs(list) do
  local sig=signature(data)
  if cache[id]~=sig or not MK.Get(id) then MK.Set(id,data);cache[id]=sig end
  n=n+1
 end
 for id in pairs(cache) do if not list[id] then MK.Remove(id);cache[id]=nil end end
 return n
end
-- Изменение настроек меток и границ полей применяется сразу.
hook.Add("STALKER_SettingChanged","STALKER_ZONE.Markers",function(id)
 if id=="zone.map_fields" or id=="zone.map_traders" then Z.UpdateMarkers() end
end)
hook.Add("InitPostEntity","STALKER_ZONE.Markers",function() timer.Simple(7,function() Z.UpdateMarkers() end) end)
hook.Add("PostCleanupMap","STALKER_ZONE.Markers",function() timer.Simple(2,function() Z.UpdateMarkers() end) end)
timer.Create("STALKER_ZONE.Markers",30,0,function() Z.UpdateMarkers() end)
