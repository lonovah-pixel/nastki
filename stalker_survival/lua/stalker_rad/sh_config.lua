-- Радиация: параметры, проверка полей зоны и формула фона. Общий файл: сервер считает дозу,
-- клиент (панель администратора) — предпросмотр той же формулой, чтобы цифры совпадали.
local R=STALKER_RAD
R.Config=R.Config or {}
local cfg=R.Config
-- Decay — вывод дозы в секунду вне фона; DamageThreshold — доза, с которой идёт урон;
-- MaxDamage — потолок урона в секунду; MaxProtection — предел суммарной защиты снаряжения;
-- FactionFactor — доза/с на единицу «радиации» территории группировки (0–100); ZonesLimit — зон на карте.
local defaults={Decay=0.04,DamageThreshold=30,MaxDamage=8,MaxProtection=0.95,Antirad=40,ZonesLimit=128,FactionFactor=0.1}
for k,v in pairs(defaults) do if cfg[k]==nil then cfg[k]=v end end

-- Границы полей зоны. Имя — в байтах UTF-8 (кириллица занимает два байта на букву).
R.Limits={radiusMin=32,radiusMax=5000,rateMin=0.01,rateMax=100,nameBytes=64,coord=16777216}
R.IDPattern="^[%w_]+$"

local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
R.Finite=finite

-- Позиция из Vector или таблицы {x,y,z}; координаты округляются до 0.1, чтобы файл не менялся при перечитывании.
-- В GMod type(Vector) — "Vector" (includes/util.lua: isvector), а не "userdata": без этой ветки зону по прицелу не создать.
function R.CleanPos(p)
 local t=type(p)
 if t~="table" and t~="Vector" and t~="userdata" then return end
 local x,y,z=tonumber(p.x),tonumber(p.y),tonumber(p.z)
 local L=R.Limits.coord
 if not finite(x) or not finite(y) or not finite(z) or math.abs(x)>L or math.abs(y)>L or math.abs(z)>L then return end
 return {x=math.Round(x,1),y=math.Round(y,1),z=math.Round(z,1)}
end

--[[ Проверка полей зоны (создание и правка). partial — правка: отсутствующие поля не меняются.
 Возвращает чистую таблицу {name,radius,rate,falloff,enabled} или nil, "причина" (текст для администратора). ]]
function R.CleanFields(a,partial)
 if type(a)~="table" then return nil,"Нет данных зоны" end
 local L=R.Limits;local out={}
 if a.name~=nil or not partial then
  local name=a.name
  if name==nil then name="" end
  if type(name)~="string" then return nil,"Имя зоны должно быть строкой" end
  name=string.Trim(name)
  if #name>L.nameBytes or name:find("[%c]") or (utf8 and utf8.len and not utf8.len(name)) then
   return nil,"Имя зоны: до 32 букв, без служебных символов"
  end
  out.name=name
 end
 if a.radius~=nil or not partial then
  local v=tonumber(a.radius)
  if not finite(v) or v<L.radiusMin or v>L.radiusMax then return nil,"Радиус: от "..L.radiusMin.." до "..L.radiusMax end
  out.radius=math.Round(v)
 end
 if a.rate~=nil or not partial then
  local v=tonumber(a.rate)
  if not finite(v) or v<L.rateMin or v>L.rateMax then return nil,"Интенсивность: от "..L.rateMin.." до "..L.rateMax.." ед./с" end
  out.rate=math.Clamp(math.Round(v,2),L.rateMin,L.rateMax)
 end
 for _,key in ipairs({"falloff","enabled"}) do
  local v=a[key]
  if v~=nil and type(v)~="boolean" then return nil,"Поле "..key.." должно быть да/нет" end
  if v~=nil then out[key]=v elseif not partial then out[key]=true end
 end
 return out
end

--[[ Фон зоны в точке pos (Vector или {x,y,z}), доза/с. Зона — шар: внутри без спада фон равен rate,
 со спадом линейно падает от rate в центре до нуля на границе. ]]
function R.ZoneRate(zone,pos)
 if type(zone)~="table" or zone.enabled==false or type(zone.pos)~="table" then return 0 end
 local r,rate=tonumber(zone.radius),tonumber(zone.rate)
 if not r or not rate or r<=0 then return 0 end
 local dx,dy,dz=pos.x-(tonumber(zone.pos.x) or 0),pos.y-(tonumber(zone.pos.y) or 0),pos.z-(tonumber(zone.pos.z) or 0)
 local d2=dx*dx+dy*dy+dz*dz
 if d2>r*r then return 0 end
 if zone.falloff==false then return rate end
 return rate*(1-math.sqrt(d2)/r)
end
-- Суммарный фон списка зон в точке.
function R.RateAt(pos,zones)
 local rate=0
 for _,z in ipairs(zones or R.Zones or {}) do rate=rate+R.ZoneRate(z,pos) end
 return rate
end

-- Шаг дозы за секунду: фон снижается защитой, без фона доза медленно выводится. Доза 0..100.
function R.Step(dose,rate,protection)
 local cap=math.Clamp(tonumber(cfg.MaxProtection) or .95,0,1)
 return math.Clamp(dose+(rate>0 and rate*(1-math.Clamp(protection or 0,0,cap)) or -cfg.Decay),0,100)
end

--[[ Настройки в общей админ-панели. Порог дозы и лимит зон нужны клиенту (HUD, панель зон) — shared. ]]
local S=STALKER_SETTINGS
if S and S.Bind then
 local CAT="Радиация"
 local function bind(id,key,def) def.category=CAT;def.type=def.type or "number";return S.Bind("radiation."..id,cfg,key,def) end
 bind("decay","Decay",{label="Естественный вывод дозы, ед./с",description="На сколько снижается доза каждую секунду, пока игрок вне радиационного фона.",min=0,max=5,step=0.01,decimals=2,order=1})
 bind("damage_threshold","DamageThreshold",{label="Порог лучевой болезни, ед. дозы",description="С этой дозы облучение наносит урон; отметка на шкале дозиметра.",min=1,max=100,realm="shared",order=2})
 bind("max_damage","MaxDamage",{label="Предел урона от облучения, в секунду",description="Урон растёт на 1 за каждые 10 ед. дозы сверх порога, но не выше предела. 0 — облучение не ранит.",min=0,max=100,step=0.5,decimals=1,order=3})
 bind("max_protection","MaxProtection",{label="Предел защиты снаряжения",description="Какую долю фона может поглотить снаряжение при любой сумме защиты (0.95 — 95 %).",min=0,max=1,step=0.01,decimals=2,order=4})
 bind("faction_factor","FactionFactor",{label="Коэффициент радиации территорий группировок",description="Фон на точке группировки = уровень радиации точки (0–100) × коэффициент, ед./с.",min=0,max=2,step=0.01,decimals=2,order=5})
 bind("zones_limit","ZonesLimit",{label="Лимит радиационных зон на карте",description="Новые зоны сверх лимита не создаются; существующие не удаляются.",min=1,max=512,realm="shared",order=6})
end
