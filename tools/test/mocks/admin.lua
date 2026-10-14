-- Мок ULib / ULX / CAMI для «Коменданта» (сценарий 31_admin). Повторяет поведение реальных функций из
-- ulib/ и ulx/ этого репозитория в той части, которой пользуется сборка: группы и наследование UCL,
-- ucl.query/registerAccess/addUser/removeUser, баны ULib.addBan/unban/bans, ULib.kick, мост CAMI→ULib,
-- ulx.command/logString/fancyLogAdmin. Выполняется до загрузки аддонов в обоих realm.
local M=TEST.M
local function has(t,v) for _,x in ipairs(t or {}) do if x==v then return true end end;return false end

-- util.SteamIDFrom64/SteamIDTo64 (есть в GMod; в моке ядра их нет). Считаем по хвосту строки: точности double не хватает.
if not util.SteamIDFrom64 then
 function util.SteamIDFrom64(sid)
  sid=tostring(sid or "");if not sid:match("^7656119%d%d%d%d%d%d%d%d%d%d$") then return "STEAM_0:0:0" end
  local account=tonumber(sid:sub(8))-7960265728;if account<0 then return "STEAM_0:0:0" end
  return "STEAM_0:"..(account%2)..":"..math.floor(account/2)
 end
end
if not util.SteamIDTo64 then
 function util.SteamIDTo64(id)
  local y,z=tostring(id or ""):match("^STEAM_%d:(%d):(%d+)$");if not y then return "0" end
  return "7656119"..string.format("%010d",tonumber(z)*2+tonumber(y)+7960265728)
 end
end
if not player.GetBySteamID then
 function player.GetBySteamID(id) for _,p in ipairs(player.GetAll()) do if util.SteamIDFrom64(p:SteamID64())==id then return p end end;return false end
end
M.kickedIDs={}
if not game.KickID then function game.KickID(id,reason) M.kickedIDs[#M.kickedIDs+1]={id=id,reason=reason} end end

--[[ CAMI (ulib/lua/ulib/shared/cami_global.lua) ]]
CAMI={Version=20150902.1,ULX_TOKEN="ULX",privileges={},usergroups={user={Name="user",Inherits="user"},admin={Name="admin",Inherits="user"},superadmin={Name="superadmin",Inherits="admin"}}}
function CAMI.RegisterPrivilege(p) CAMI.privileges[p.Name]=p;hook.Call("CAMI.OnPrivilegeRegistered",nil,p);return p end
function CAMI.UnregisterPrivilege(name) local p=CAMI.privileges[name];if not p then return false end;CAMI.privileges[name]=nil;return true end
function CAMI.GetPrivilege(name) return CAMI.privileges[name] end
function CAMI.GetPrivileges() return CAMI.privileges end
function CAMI.RegisterUsergroup(g,source) CAMI.usergroups[g.Name]=g;hook.Call("CAMI.OnUsergroupRegistered",nil,g,source);return g end
function CAMI.GetUsergroups() return CAMI.usergroups end
function CAMI.GetUsergroup(name) return CAMI.usergroups[name] end
function CAMI.SignalUserGroupChanged() end
function CAMI.SignalSteamIDUserGroupChanged() end
function CAMI.PlayerHasAccess(actor,priv,callback,target,extra)
 local answered=false
 hook.Call("CAMI.PlayerHasAccess",nil,actor,priv,function(r) answered=true;callback(r) end,target,extra)
 if not answered then callback(IsValid(actor) and actor:IsSuperAdmin()) end
end

--[[ ULib: UCL (shared/sh_ucl.lua + server/ucl.lua) ]]
ULib={ACCESS_ALL="user",ACCESS_OPERATOR="operator",ACCESS_ADMIN="admin",ACCESS_SUPERADMIN="superadmin",
 HOOK_UCLCHANGED="UCLChanged",HOOK_USER_BANNED="ULibPlayerBanned",HOOK_USER_UNBANNED="ULibPlayerUnBanned",HOOK_USER_KICKED="ULibPlayerKicked"}
local ucl={groups={user={allow={}},operator={allow={},can_target="!%admin"},admin={allow={},inherit_from="operator",can_target="!%superadmin"},superadmin={allow={},inherit_from="admin"}},
 users={},authed={},accessStrings={},accessCategories={}}
ULib.ucl=ucl
function ucl.groupInheritsFrom(group)
 if not ucl.groups[group] then return false end
 if group==ULib.ACCESS_ALL then return nil end
 local parent=ucl.groups[group].inherit_from
 if not parent or parent=="" then return ULib.ACCESS_ALL end
 return parent
end
function ucl.query(ply,access,hide)
 if SERVER and not IsValid(ply) then return true end
 if access==nil then return true end
 access=access:lower()
 local info=ucl.users[util.SteamIDFrom64(ply:SteamID64())]
 if info then
  if has(info.deny,access) then return false end
  if has(info.allow,access) then return true end
 end
 local group=ply:GetUserGroup()
 while group do
  local g=ucl.groups[group]
  if not g then return error("[ULib] Player "..ply:Nick().." has an invalid group ("..group..")") end
  if has(g.allow,access) then return true end
  group=ucl.groupInheritsFrom(group)
 end
 return nil
end
function ULib.getPlyByID(id)
 id=tostring(id):upper()
 for _,p in ipairs(player.GetAll()) do if util.SteamIDFrom64(p:SteamID64())==id or p:SteamID64()==id then return p end end
end
function ULib.findInTable(t,v) for i,x in ipairs(t) do if x==v then return i end end;return false end

-- Игроки мока: группа ULX хранится в _group (как SetUserGroup ULib), IsAdmin/IsSuperAdmin — по наследованию (как в ULib).
local function attach(p)
 local baseGroup,baseSuper,baseAdmin=p.GetUserGroup,p.IsSuperAdmin,p.IsAdmin
 p.GetUserGroup=function(self) return self._group or baseGroup(self) end
 p.SetUserGroup=function(self,g) self._group=g end
 p.CheckGroup=function(self,g)
  local cur=self:GetUserGroup();local guard=0
  while cur and guard<16 do if cur==g then return true end;cur=ucl.groupInheritsFrom(cur);guard=guard+1 end
  return g==ULib.ACCESS_ALL
 end
 p.IsSuperAdmin=function(self) if self._group then return self:CheckGroup("superadmin") end;return baseSuper(self) end
 p.IsAdmin=function(self) if self._group then return self:CheckGroup("admin") end;return baseAdmin(self) end
 -- Как ucl.probe при входе: сохранённая группа применяется к игроку.
 local info=ucl.users[util.SteamIDFrom64(p:SteamID64())]
 if info and info.group then p._group=info.group end
 return p
end
local addPlayer=M.addPlayer
M.addPlayer=function(opts) return attach(addPlayer(opts)) end

if SERVER then
 function ucl.addGroup(name,allows,inherit_from)
  allows=allows or {};inherit_from=inherit_from or "user"
  if ucl.groups[name] then return error("Group already exists, cannot add again ("..name..")",2) end
  if inherit_from==name then return error("Group cannot inherit from itself",2) end
  if not ucl.groups[inherit_from] then return error("Invalid group for inheritance ("..tostring(inherit_from)..")",2) end
  ucl.groups[name]={allow=allows,inherit_from=inherit_from}
  if not ULib.findInTable({"superadmin","admin","user"},name) then CAMI.RegisterUsergroup({Name=name,Inherits=inherit_from},CAMI.ULX_TOKEN) end
 end
 function ucl.groupAllow(name,access,revoke)
  if type(access)=="string" then access={access} end
  if not ucl.groups[name] then return error("Group does not exist for changing access ("..name..")",2) end
  local allow=ucl.groups[name].allow;local changed=false
  for _,a in ipairs(access) do
   a=a:lower();local i=ULib.findInTable(allow,a)
   if not revoke and not i then table.insert(allow,a);changed=true elseif revoke and i then table.remove(allow,i);changed=true end
  end
  return changed
 end
 function ucl.registerAccess(access,groups,comment,category)
  access=access:lower();comment=comment or ""
  if groups==nil then groups={} end
  if type(groups)=="string" then groups={groups} end
  ucl.accessCategories[access]=category
  if ucl.accessStrings[access]~=comment then
   ucl.accessStrings[access]=comment
   for _,info in pairs(ucl.groups) do if has(info.allow,access) then return end end
   for _,group in ipairs(groups) do
    if not ucl.groups[group] then ucl.addGroup(group) end
    table.insert(ucl.groups[group].allow,access)
   end
  end
 end
 function ucl.addUser(id,allows,denies,group)
  assert(type(id)=="string","ULib.ucl.addUser: id")
  id=id:upper();allows=allows or {};denies=denies or {}
  if group and not ucl.groups[group] then return error("Group does not exist for adding user to ("..group..")",2) end
  local name=ucl.users[id] and ucl.users[id].name
  ucl.users[id]={allow=allows,deny=denies,group=group,name=name}
  local ply=ULib.getPlyByID(id);if ply then ply._group=group or "user" end
 end
 function ucl.removeUser(id)
  id=id:upper()
  if not ucl.users[id] then return error("User id does not exist for removing ("..id..")",2) end
  ucl.users[id]=nil
  local ply=ULib.getPlyByID(id);if ply then ply._group="user" end
 end
 -- Мост CAMI → ULib (shared/cami_ulib.lua): привилегия CAMI становится доступом с MinAccess.
 hook.Add("CAMI.OnPrivilegeRegistered","ULXCamiPrivilegeRegistered",function(p) ucl.registerAccess(p.Name:lower(),p.MinAccess,"A privilege from CAMI","CAMI") end)
 hook.Add("CAMI.PlayerHasAccess","ULXCamiPlayerHasAccess",function(actor,priv,callback) callback(not not ucl.query(actor,priv:lower(),true));return true end)

 --[[ ULib: баны и кик (server/bans.lua, server/player.lua) ]]
 ULib.bans={}
 M.ulibKicks={}
 function ULib.kick(ply,reason,calling)
  local nick=calling and IsValid(calling) and (calling:Nick().."("..util.SteamIDFrom64(calling:SteamID64())..")")
  local text=reason and nick and ("Kicked by "..nick.." - "..reason) or nick and ("Kicked by "..nick) or (reason or "[ULX] Kicked from server")
  M.ulibKicks[#M.ulibKicks+1]={ply=ply,reason=reason,text=text}
  ply:Kick(text)
 end
 function ULib.addBan(steamid,time,reason,name,admin)
  if reason=="" then reason=nil end
  local admin_name
  if admin then
   if type(admin)=="string" then admin_name=admin elseif not IsValid(admin) then admin_name="(Console)" elseif admin:IsPlayer() then admin_name=admin:Nick().."("..util.SteamIDFrom64(admin:SteamID64())..")" end
  end
  local t={};local now=os.time()
  if ULib.bans[steamid] then t=ULib.bans[steamid];t.modified_admin=admin_name;t.modified_time=now else t.admin=admin_name end
  t.time=t.time or now
  t.unban=time>0 and (time*60+now) or 0
  t.reason=reason;t.name=name;t.steamID=steamid
  ULib.bans[steamid]=t
  local ply=player.GetBySteamID(steamid);if ply then ULib.kick(ply,"Banned: "..tostring(reason),nil) end
  game.KickID(steamid,"Banned")
  hook.Call(ULib.HOOK_USER_BANNED,nil,steamid,t)
 end
 function ULib.unban(steamid,admin)
  ULib.bans[steamid]=nil
  hook.Call(ULib.HOOK_USER_UNBANNED,nil,steamid,admin)
 end
end

--[[ ULib: сообщения ]]
M.ulibSay={}
function ULib.tsay(ply,msg) M.ulibSay[#M.ulibSay+1]={ply=ply,text=msg};if IsValid(ply) then ply:ChatPrint(msg) end end
function ULib.tsayError(ply,msg) M.ulibSay[#M.ulibSay+1]={ply=ply,text=msg,error=true};if IsValid(ply) then ply:ChatPrint(msg) end end
function ULib.tsayColor(ply,wait,...) local parts={};for _,v in ipairs({...}) do if type(v)=="string" then parts[#parts+1]=v end end;ULib.tsay(ply,table.concat(parts)) end

--[[ ULib: команды (shared/commands.lua) — маркеры типов аргументов ]]
ULib.cmds={CallingPlayerArg={name="CallingPlayerArg"},PlayerArg={name="PlayerArg"},PlayersArg={name="PlayersArg"},NumArg={name="NumArg"},StringArg={name="StringArg"},BoolArg={name="BoolArg"},
 optional="optional",round="round",takeRestOfLine="takeRestOfLine",restrictToCompletes="restrictToCompletes",allowTimeString="allowTimeString"}

--[[ ULX: команды и журнал (sh_base.lua, log.lua) ]]
ulx={cmdsByCategory={},logs={}}
local Cmd={};Cmd.__index=Cmd
function Cmd:addParam(p) self.args[#self.args+1]=p end
function Cmd:defaultAccess(access) if CLIENT then return end;ucl.registerAccess(self.cmd,access,"Grants access to the "..self.cmd.." command","Command") end
function Cmd:help(text) self.helpStr=text end
function Cmd:setOpposite(name) self.opposite=name end
function ulx.command(category,command,fn,say_cmd)
 assert(type(command)=="string","ulx.command: command")
 if SERVER then assert(type(fn)=="function","ulx.command: fn") end
 local obj=setmetatable({cmd=command,fn=fn,args={{type=ULib.cmds.CallingPlayerArg}},category=category,say_cmd=say_cmd},Cmd)
 ulx.cmdsByCategory[category]=ulx.cmdsByCategory[category] or {}
 for _,list in pairs(ulx.cmdsByCategory) do for i=#list,1,-1 do if list[i].cmd==command then table.remove(list,i) end end end
 table.insert(ulx.cmdsByCategory[category],obj)
 return obj
end
function ulx.logString(str) ulx.logs[#ulx.logs+1]=str end
function ulx.fancyLogAdmin(calling,format,...)
 local args={...};local i=0
 local text=format:gsub("#([%.%d]*%a)",function(tag)
  local spec=tag:sub(-1)
  if spec=="A" then return IsValid(calling) and calling:Nick() or "(Console)" end
  i=i+1;local v=args[i]
  if spec=="T" or spec=="P" then
   local names={};for _,p in ipairs(type(v)=="table" and v or {v}) do names[#names+1]=IsValid(p) and p:Nick() or "?" end
   return table.concat(names,", ")
  end
  return tostring(v)
 end)
 ulx.logs[#ulx.logs+1]=text
end
-- Запуск команды ULX как это делает ULib: сначала доступ к самой команде (ucl.query), потом функция.
function M.ulxRun(ply,command,...)
 local obj
 for _,list in pairs(ulx.cmdsByCategory) do for _,c in ipairs(list) do if c.cmd==command then obj=c end end end
 assert(obj,"нет команды ULX "..command)
 if IsValid(ply) and not ucl.query(ply,command) then ULib.tsayError(ply,"You don't have access to this command, "..ply:Nick().."!");return false end
 obj.fn(ply or NULL,...)
 return true
end
