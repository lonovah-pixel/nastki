-- Реестр настроек: аддоны регистрируют свои параметры, админ-панель показывает и меняет их без правки Lua.
-- Значения переопределений хранятся в SQLite (stalker_settings) и применяются при регистрации.
local C=STALKER_CORE
STALKER_SETTINGS=STALKER_SETTINGS or {Defs={},Order={},Values={},Stored={}}
local S=STALKER_SETTINGS
C.Settings=S

local function decimals(def) return def.decimals or ((def.step and def.step<1) and 2 or 0) end

-- Приводит значение к типу настройки; nil — значение недопустимо.
function S.Validate(def,v)
 local kind=def.type
 if kind=="bool" then if type(v)=="boolean" then return v end;return nil end
 if kind=="number" then
  v=tonumber(v);if not v or v~=v or v==math.huge or v==-math.huge then return nil end
  if def.min then v=math.max(def.min,v) end
  if def.max then v=math.min(def.max,v) end
  local m=10^decimals(def);return math.floor(v*m+.5)/m
 end
 if kind=="string" then if type(v)=="string" and #v<=(def.maxLength or 200) and not v:find("[%c]") then return v end;return nil end
 if kind=="choice" then for _,c in ipairs(def.choices or {}) do if c[1]==v then return v end end;return nil end
 return nil
end

function S.Apply(id,v)
 local def=S.Defs[id];if not def then return false end
 local value=S.Validate(def,v);if value==nil then return false end
 S.Values[id]=value
 if def.set then local ok,err=pcall(def.set,value);if not ok then ErrorNoHalt("[STALKER Settings] "..id..": "..tostring(err).."\n") end end
 if def.onChange then pcall(def.onChange,value) end
 return true
end

--[[ def:
 category   — раздел в панели («Аномалии», «Выживание»…)
 label      — подпись; description — подсказка
 type       — number | bool | string | choice
 min,max,step,decimals — для number; choices={{значение,"подпись"},…} — для choice
 default    — значение по умолчанию (иначе берётся текущее из get)
 get,set    — чтение и применение (обычно поле таблицы конфигурации)
 realm      — server (только сервер) или shared (значение отправляется клиентам)
 order      — порядок внутри раздела ]]
function S.Register(id,def)
 assert(type(id)=="string" and #id<=64 and id:match("^[%w_%.]+$"),"Некорректный ID настройки: "..tostring(id))
 assert(type(def)=="table","Описание настройки должно быть таблицей")
 def.id=id;def.type=def.type or "number";def.realm=def.realm or "server"
 def.category=def.category or "Прочее";def.label=def.label or id
 if def.default==nil and def.get then def.default=def.get() end
 local fresh=S.Defs[id]==nil
 S.Defs[id]=def
 if fresh then S.Order[#S.Order+1]=id end
 local stored=S.Stored[id]
 if stored~=nil then S.Apply(id,stored) end
 return def
end
-- Привязка к полю таблицы: Bind("zone.max_artifacts", Z.Config, "MaxArtifacts", {...}).
function S.Bind(id,tbl,key,def)
 def=def or {}
 def.get=function() return tbl[key] end
 def.set=function(v) tbl[key]=v end
 return S.Register(id,def)
end
function S.Get(id)
 local def=S.Defs[id];if not def then return nil end
 if def.get then return def.get() end
 local v=S.Values[id];if v==nil then return def.default end
 return v
end

local function describe(id)
 local d=S.Defs[id]
 return {id=id,category=d.category,label=d.label,description=d.description,type=d.type,min=d.min,max=d.max,step=d.step,
  decimals=decimals(d),choices=d.choices,default=d.default,value=S.Get(id),order=d.order or 100,changed=S.Stored[id]~=nil}
end

if SERVER then
 for _,n in ipairs({"sync","list","set"}) do util.AddNetworkString("stalker_settings."..n) end
 S.Ready=sql.Query("CREATE TABLE IF NOT EXISTS stalker_settings (id TEXT PRIMARY KEY, value TEXT NOT NULL)")~=false
 local rows=S.Ready and sql.Query("SELECT id,value FROM stalker_settings")
 for _,row in ipairs(type(rows)=="table" and rows or {}) do
  local data=util.JSONToTable(row.value or "")
  if type(data)=="table" and data.v~=nil then S.Stored[row.id]=data.v end
 end

 local function sharedValues()
  local out={}
  for id,def in pairs(S.Defs) do if def.realm=="shared" and S.Stored[id]~=nil then out[id]=S.Stored[id] end end
  return out
 end
 local function broadcast(id,value,reset) C.Send("stalker_settings.sync",nil,{values={[id]=value},reset=reset and {id} or nil}) end

 -- Изменение администратором (ply может быть nil — консоль/код). value=nil сбрасывает к значению по умолчанию.
 function S.Set(id,value,ply)
  local def=S.Defs[id];if not def then return false,"Неизвестная настройка" end
  if not S.Ready then return false,"Хранилище настроек недоступно" end
  local old=S.Get(id)
  if value==nil then
   if sql.Query("DELETE FROM stalker_settings WHERE id="..sql.SQLStr(id))==false then return false,"Ошибка записи" end
   S.Stored[id]=nil;S.Apply(id,def.default)
   if def.realm=="shared" then broadcast(id,def.default,true) end
   hook.Run("STALKER_SettingChanged",id,def.default,old,ply)
   return true
  end
  local v=S.Validate(def,value);if v==nil then return false,"Недопустимое значение" end
  if sql.Query("REPLACE INTO stalker_settings VALUES("..sql.SQLStr(id)..","..sql.SQLStr(util.TableToJSON({v=v}))..")")==false then return false,"Ошибка записи" end
  S.Stored[id]=v;S.Apply(id,v)
  if def.realm=="shared" then broadcast(id,v) end
  hook.Run("STALKER_SettingChanged",id,v,old,ply)
  return true
 end

 function S.List()
  local out={}
  for _,id in ipairs(S.Order) do if S.Defs[id] then out[#out+1]=describe(id) end end
  table.sort(out,function(a,b) if a.category~=b.category then return a.category<b.category end;if a.order~=b.order then return a.order<b.order end;return a.id<b.id end)
  return out
 end

 net.Receive("stalker_settings.list",function(len,ply)
  if len~=0 or not C.Rate(ply,"settings.list",1,3) or not C.CanAdmin(ply,"settings") then return end
  C.Send("stalker_settings.list",ply,{list=S.List()})
 end)
 net.Receive("stalker_settings.set",function(len,ply)
  if not C.Rate(ply,"settings.set",4,8) or not C.CanAdmin(ply,"settings") then return end
  local a=C.Read(len,4000);if not a or type(a.id)~="string" then return end
  local ok,err=S.Set(a.id,a.reset and nil or a.value,ply)
  C.Send("stalker_settings.list",ply,{list=S.List(),result={id=a.id,ok=ok==true,error=err}})
 end)
 hook.Add("PlayerInitialSpawn","STALKER_Settings.Sync",function(ply)
  timer.Simple(1,function() if IsValid(ply) then C.Send("stalker_settings.sync",ply,{values=sharedValues()}) end end)
 end)
 concommand.Add("stalker_setting",function(ply,_,args)
  if IsValid(ply) and not C.CanAdmin(ply,"settings") then return end
  local id,raw=args[1],args[2]
  local function out(text) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE,text) else print(text) end end
  if not id then for _,row in ipairs(S.List()) do out(row.id.." = "..tostring(row.value).."  ("..row.category.." / "..row.label..")") end;return end
  local def=S.Defs[id];if not def then out("Неизвестная настройка: "..id);return end
  if raw==nil then out(id.." = "..tostring(S.Get(id)));return end
  local value=raw
  if raw=="default" then value=nil elseif def.type=="bool" then value=raw=="1" or raw=="true" elseif def.type=="number" then value=tonumber(raw) end
  local ok,err=S.Set(id,value,ply);out(ok and (id.." = "..tostring(S.Get(id))) or ("Ошибка: "..tostring(err)))
 end)
else
 net.Receive("stalker_settings.sync",function(len)
  local data=C.Read(len);if not data then return end
  for _,id in ipairs(data.reset or {}) do S.Stored[id]=nil end
  for id,v in pairs(data.values or {}) do S.Stored[id]=v;if S.Defs[id] then S.Apply(id,v) end end
  hook.Run("STALKER_SettingsSynced")
 end)
 net.Receive("stalker_settings.list",function(len)
  local data=C.Read(len);if not data then return end
  S.LastList=data.list
  if S.ListCallback then local cb=S.ListCallback;S.ListCallback=nil;cb(data.list,data.result) end
  hook.Run("STALKER_SettingsList",data.list,data.result)
 end)
 function S.RequestList(cb) S.ListCallback=cb;net.Start("stalker_settings.list");net.SendToServer() end
 function S.RequestSet(id,value) C.Send("stalker_settings.set",nil,{id=id,value=value}) end
 function S.RequestReset(id) C.Send("stalker_settings.set",nil,{id=id,reset=true}) end
end
