-- Мост «Комендант» ↔ ULib/ULX/CAMI. ULib грузится позже аддонов сборки (autorun ulib_init.lua идёт после
-- stalker_*), поэтому всё здесь вызывается лениво: при загрузке, на Initialize и из модуля ULX
-- (lua/ulx/modules/sh/stalker_admin.lua). Повторные вызовы безопасны.
local A=STALKER_ADMIN

-- ULib с серверной частью UCL: тогда уровни = группы ULX, права = доступы "stalker_<право>", баны = ULib.bans.
function A.UsesULib()
 if type(ULib)~="table" or type(ULib.ucl)~="table" or type(ULib.ucl.query)~="function" or type(ULib.ucl.groups)~="table" then return false end
 if SERVER and (type(ULib.ucl.addUser)~="function" or type(ULib.ucl.users)~="table") then return false end
 return true
end
function A.UsesULibBans() return SERVER and A.UsesULib() and type(ULib.bans)=="table" and type(ULib.addBan)=="function" and type(ULib.unban)=="function" end
function A.UsesULX() return type(ulx)=="table" and type(ulx.command)=="function" end

-- Перевод SteamID64 → STEAM_0:X:Y. В LuaJIT числа 7656119… теряют точность, поэтому считаем по хвосту строки.
function A.SteamID(sid)
 if not A.SID(sid) then return end
 if util.SteamIDFrom64 then local id=util.SteamIDFrom64(sid);if type(id)=="string" and id:match("^STEAM_%d:%d:%d+$") then return id end end
 local account=tonumber(sid:sub(8))-7960265728
 if account<0 then return end
 return "STEAM_0:"..(account%2)..":"..math.floor(account/2)
end
function A.SteamID64(steamid)
 if type(steamid)~="string" then return end
 if util.SteamIDTo64 then local id=util.SteamIDTo64(steamid);if A.SID(id) then return id end end
 local y,z=steamid:match("^STEAM_%d:(%d):(%d+)$");if not y then return end
 local tail=tonumber(z)*2+tonumber(y)+7960265728
 if tail>9999999999 then return end
 return "7656119"..string.format("%010d",tail)
end

-- Уровень «Коменданта» для группы ULX: ищем по цепочке наследования (например, «headadmin» ← superadmin).
function A.GroupRole(group)
 local G=A.Config.GroupRoles
 local groups=A.UsesULib() and ULib.ucl.groups or nil
 local seen={}
 while type(group)=="string" and group~="" and not seen[group] do
  seen[group]=true
  local role=G[group];if role and A.Config.Roles[role] then return role end
  if not groups or not groups[group] then break end
  group=groups[group].inherit_from
 end
 return "user"
end
-- Группа ULX для уровня: обратное отображение GroupRoles; «Владелец» — superadmin.
function A.RoleGroup(role)
 if role=="owner" then role="superadmin" end
 if role=="user" then return "user" end
 local best
 for group,r in SortedPairs(A.Config.GroupRoles) do if r==role and (not best or group==role) then best=group end end
 return best
end

-- Регистрация прав. CAMI понимает только user/admin/superadmin, поэтому операторам и модераторам
-- доступ выдаём напрямую через ULib (до CAMI: ULib не добавляет уже зарегистрированный доступ повторно,
-- так владелец может перенастроить права в XGUI, и рестарт их не вернёт).
local function camiMin(permission)
 local r=A.Config.Roles[A.MinRole(permission)]
 return r and r.rank>=90 and "superadmin" or "admin"
end
function A.EnsureGroup(group,depth)
 if not SERVER or not A.UsesULib() or type(ULib.ucl.addGroup)~="function" then return false end
 if ULib.ucl.groups[group] then return true end
 if (depth or 0)>6 then return false end
 local parent=A.Config.GroupParents[group] or "user"
 if parent~="user" and not A.EnsureGroup(parent,(depth or 0)+1) then parent="user" end
 return (pcall(ULib.ucl.addGroup,group,nil,parent)) and ULib.ucl.groups[group]~=nil
end
-- Группа уже получает доступ через предка по наследованию (например, admin ← operator)?
local function inherited(group,set)
 local groups=ULib.ucl.groups;local seen={}
 local parent=groups[group] and groups[group].inherit_from
 while type(parent)=="string" and parent~="" and not seen[parent] do
  if set[parent] then return true end
  seen[parent]=true;parent=groups[parent] and groups[parent].inherit_from
 end
 return false
end
local function ulibRegister()
 if not SERVER or not A.UsesULib() or type(ULib.ucl.registerAccess)~="function" then return end
 for _,row in ipairs(A.Permissions) do
  local id=row[1];local set={}
  for group,role in SortedPairs(A.Config.GroupRoles) do
   local r=A.Config.Roles[role]
   if r and (r.permissions.all==true or r.permissions[id]==true) and A.EnsureGroup(group) then set[group]=true end
  end
  -- Доступ получают только нижние группы цепочек: остальные наследуют, и право снимается в XGUI в одном месте.
  local groups={};for group in SortedPairs(set) do if not inherited(group,set) then groups[#groups+1]=group end end
  pcall(ULib.ucl.registerAccess,"stalker_"..id,groups,"Комендант: "..row[2],"STALKER")
 end
end
function A.RegisterPrivileges()
 ulibRegister()
 if type(CAMI)=="table" and type(CAMI.RegisterPrivilege)=="function" then
  for _,row in ipairs(A.Permissions) do
   local name="stalker_"..row[1];local min=camiMin(row[1])
   local known=type(CAMI.GetPrivilege)=="function" and CAMI.GetPrivilege(name)
   if not known or known.MinAccess~=min then pcall(CAMI.RegisterPrivilege,{Name=name,MinAccess=min,Description="Комендант: "..row[2]}) end
  end
 end
 -- CAMI-мост ULib меняет описание и категорию на «CAMI» — возвращаем свои (группы при этом не трогаются).
 ulibRegister()
 A.PrivilegesRegistered=true
end
A.RegisterPrivileges()
hook.Add("Initialize","STALKER.AdminPrivileges",function() A.RegisterPrivileges() end)
