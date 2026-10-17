local A=STALKER_ADMIN
-- Владелец: SteamID64 из Owners (sh_config.lua) или назначенный командой sta_setrole … owner (sta_roles).
function A.IsOwnerSID(sid) return A.Config.Owners[sid]==true or A.Roles[sid]=="owner" end
-- Уровень игрока. С ULib — по группе ULX (наследование учитывается); без ULib — прежняя таблица sta_roles.
function A.Role(p)
 if not IsValid(p) then return "owner" end
 local sid=p:SteamID64()
 if A.IsOwnerSID(sid) then return "owner" end
 if A.UsesULib() then return A.GroupRole(p:GetUserGroup()) end
 local role=A.Roles[sid]
 if role and A.Config.Roles[role] then return role end
 return A.GroupRole(p:GetUserGroup())
end
function A.Rank(p) return A.Config.Roles[A.Role(p)].rank end
-- Право. С ULib спрашиваем доступ "stalker_<право>" — так права раздаются группам в XGUI ULX.
function A.Has(p,permission)
 if not A.Ready then return false end
 local role=A.Role(p)
 if role=="owner" then return true end
 if A.UsesULib() then
  -- query бросает ошибку для ещё не авторизованного в ULib игрока — тогда решает таблица уровней.
  local ok,result=pcall(ULib.ucl.query,p,"stalker_"..tostring(permission))
  if ok then return result==true end
 end
 local grants=A.Config.Roles[role].permissions
 return grants.all==true or grants[permission]==true
end
function A.OfflineRank(sid)
 if A.IsOwnerSID(sid) then return 100 end
 local online=player.GetBySteamID64(sid)
 if IsValid(online) then return A.Rank(online) end
 local rank=0
 if A.UsesULib() then
  local info=ULib.ucl.users[A.SteamID(sid) or ""]
  if type(info)=="table" then rank=A.Config.Roles[A.GroupRole(info.group)].rank end
 else
  local role=A.Config.Roles[A.Roles[sid] or "user"];rank=role and role.rank or 0
 end
 return math.max(rank,A.SeenRanks[sid] or 0)
end
-- Группа ULX игрока по SteamID64 (онлайн — текущая, офлайн — из users ULib).
function A.ULXGroup(sid)
 if not A.UsesULib() then return nil end
 local online=player.GetBySteamID64(sid)
 if IsValid(online) then return online:GetUserGroup() end
 local info=ULib.ucl.users[A.SteamID(sid) or ""]
 return type(info)=="table" and info.group or "user"
end
function A.CanTarget(p,target,command)
 if not IsValid(target) or not target:IsPlayer() or target:IsBot() then return false,"Цель недоступна" end
 if not IsValid(p) then return true end
 if p==target then return command.selfOK==true, "Эта команда недоступна для себя" end
 if A.Rank(p)<=A.Rank(target) then return false,"У цели равный или более высокий допуск" end
 return true
end

-- Назначение уровня в ULib: группа ULX по SteamID (работает и для офлайн-игроков), allow/deny игрока сохраняются.
local function ulibAssign(sid,role)
 local steamid=A.SteamID(sid);if not steamid then return false,"Неверный SteamID64" end
 local group=A.RoleGroup(role);if not group then return false,"Для уровня нет группы ULX (GroupRoles)" end
 if group~="user" and not A.EnsureGroup(group) then return false,"Не удалось создать группу ULX «"..group.."»" end
 local info=ULib.ucl.users[steamid]
 local allow=type(info)=="table" and info.allow or {};local deny=type(info)=="table" and info.deny or {}
 local ok,err
 if group=="user" and type(info)=="table" and #allow==0 and #deny==0 and next(allow)==nil and next(deny)==nil then
  ok,err=pcall(ULib.ucl.removeUser,steamid)
 elseif group=="user" and type(info)~="table" then ok=true
 else ok,err=pcall(ULib.ucl.addUser,steamid,allow,deny,group) end
 if not ok then ErrorNoHalt("[STALKER ADMIN] ULib: "..tostring(err).."\n");return false,"ULib отклонил изменение группы" end
 return true
end
function A.SetRole(actor,sid,role)
 if not A.SID(sid) or not A.Config.Roles[role] or not A.Has(actor,"roles") then return false,"Недопустимый допуск" end
 if IsValid(actor) and (sid==actor:SteamID64() or A.Config.Roles[role].rank>=A.Rank(actor) or A.OfflineRank(sid)>=A.Rank(actor)) then return false,"Нельзя изменить этот допуск" end
 if A.Config.Owners[sid] then return false,"Владелец закреплён в sh_config.lua" end
 if not A.Audit(actor,"role",sid,role,"attempt") then return false,"Ошибка журнала" end
 if A.UsesULib() then
  local ok,err=ulibAssign(sid,role);if not ok then A.Audit(actor,"role",sid,err,"failed");return false,err end
  -- В sta_roles остаётся только отметка владельца; прочие уровни живут в группах ULX.
  if role=="owner" then
   if A.Query("REPLACE INTO sta_roles VALUES("..sql.SQLStr(sid)..",'owner')")==false then return false,"Ошибка записи" end
   A.Roles[sid]="owner"
  elseif A.Roles[sid] then
   if A.Query("DELETE FROM sta_roles WHERE sid="..sql.SQLStr(sid))==false then return false,"Ошибка записи" end
   A.Roles[sid]=nil
  end
 else
  if A.Query("REPLACE INTO sta_roles VALUES("..sql.SQLStr(sid)..","..sql.SQLStr(role)..")")==false then return false,"Ошибка записи" end
  A.Roles[sid]=role
 end
 A.SeenRanks[sid]=A.Config.Roles[role].rank
 A.Query("REPLACE INTO sta_seen VALUES("..sql.SQLStr(sid)..","..A.SeenRanks[sid]..")")
 A.Audit(actor,"role",sid,role,"success");return true
end
concommand.Add("sta_setrole",function(p,_,args)
 if IsValid(p) then p:ChatPrint("Эта команда доступна только в серверной консоли. Используйте панель допусков.");return end
 local ok,err=A.SetRole(p,args[1],args[2])
 print(ok and ("[STA] Допуск сохранён"..(A.UsesULib() and (", группа ULX: "..tostring(A.RoleGroup(args[2]))) or "")) or ("[STA] "..tostring(err)))
end)

-- Владелец всегда в группе superadmin (или в группе, наследующей её), чтобы ULX давал ему полный доступ.
function A.SyncOwner(p)
 if not IsValid(p) or p:IsBot() or not A.UsesULib() or not A.IsOwnerSID(p:SteamID64()) then return end
 if A.GroupRole(p:GetUserGroup())=="superadmin" then return end
 local ok=ulibAssign(p:SteamID64(),"owner")
 if ok then A.Audit(nil,"owner_sync",p:SteamID64(),"superadmin","success") end
end
-- Одноразовый перенос уровней sta_roles в группы ULX: существующие записи ULX не перезаписываются.
function A.MigrateRoles()
 if not A.Ready or not A.UsesULib() or A.GetMeta("roles_migrated") then return 0 end
 local moved=0
 for sid,role in SortedPairs(A.Roles) do
  local steamid=A.SteamID(sid)
  if steamid and A.Config.Roles[role] and role~="user" and type(ULib.ucl.users[steamid])~="table" and ulibAssign(sid,role) then moved=moved+1 end
 end
 A.SetMeta("roles_migrated",os.time())
 if moved>0 then print("[STALKER ADMIN] Перенесено уровней в группы ULX: "..moved) end
 return moved
end
hook.Add("InitPostEntity","STALKER.AdminULib",function()
 A.RegisterPrivileges()
 A.MigrateRoles();A.MigrateBans()
end)

function A.RememberRank(p)
 if not A.Ready or p:IsBot() then return end
 local sid,rank=p:SteamID64(),A.Rank(p)
 if A.SeenRanks[sid]~=rank and A.Query("REPLACE INTO sta_seen VALUES("..sql.SQLStr(sid)..","..rank..")")~=false then A.SeenRanks[sid]=rank end
end
hook.Add("PlayerInitialSpawn","STALKER.AdminRememberRank",function(p)
 -- ULib авторизует игрока чуть позже входа: синхронизация владельца и ранга — после неё.
 timer.Simple(2,function() if IsValid(p) then A.SyncOwner(p);A.RememberRank(p) end end)
end)
hook.Add("PlayerDisconnected","STALKER.AdminRememberRank",A.RememberRank)
