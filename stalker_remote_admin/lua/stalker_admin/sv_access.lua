local A=STALKER_ADMIN
function A.Role(p)
 if not IsValid(p) then return "owner" end
 local sid=p:SteamID64()
 if A.Config.Owners[sid] then return "owner" end
 local role=A.Roles[sid]
 if role and A.Config.Roles[role] then return role end
 local mapped=A.Config.GroupRoles[p:GetUserGroup()]
 return A.Config.Roles[mapped or ""] and mapped or "user"
end
function A.Rank(p) return A.Config.Roles[A.Role(p)].rank end
function A.Has(p,permission)
 if not A.Ready then return false end
 local grants=A.Config.Roles[A.Role(p)].permissions
 return grants.all==true or grants[permission]==true
end
function A.OfflineRank(sid)
 if A.Config.Owners[sid] then return 100 end
 for _,p in ipairs(player.GetHumans()) do if p:SteamID64()==sid then return A.Rank(p) end end
 local role=A.Config.Roles[A.Roles[sid] or "user"]
 return math.max(role and role.rank or 0,A.SeenRanks[sid] or 0)
end
function A.CanTarget(p,target,command)
 if not IsValid(target) or not target:IsPlayer() or target:IsBot() then return false,"Цель недоступна" end
 if not IsValid(p) then return true end
 if p==target then return command.selfOK==true, "Эта команда недоступна для себя" end
 if A.Rank(p)<=A.Rank(target) then return false,"У цели равный или более высокий допуск" end
 return true
end
function A.SetRole(actor,sid,role)
 if not A.SID(sid) or not A.Config.Roles[role] or not A.Has(actor,"roles") then return false,"Недопустимый допуск" end
 if IsValid(actor) and (sid==actor:SteamID64() or A.Config.Roles[role].rank>=A.Rank(actor) or A.OfflineRank(sid)>=A.Rank(actor)) then return false,"Нельзя изменить этот допуск" end
 if A.Config.Owners[sid] then return false,"Владелец закреплён в sh_config.lua" end
 if not A.Audit(actor,"role",sid,role,"attempt") then return false,"Ошибка журнала" end
 if A.Query("REPLACE INTO sta_roles VALUES("..sql.SQLStr(sid)..","..sql.SQLStr(role)..")")==false then return false,"Ошибка записи" end
 A.Roles[sid]=role;A.SeenRanks[sid]=A.Config.Roles[role].rank
 A.Query("REPLACE INTO sta_seen VALUES("..sql.SQLStr(sid)..","..A.SeenRanks[sid]..")")
 A.Audit(actor,"role",sid,role,"success");return true
end
concommand.Add("sta_setrole",function(p,_,args)
 if IsValid(p) then p:ChatPrint("Эта команда доступна только в серверной консоли. Используйте панель допусков.");return end
 local ok,err=A.SetRole(p,args[1],args[2]);print(ok and "[STA] Допуск сохранён" or ("[STA] "..tostring(err)))
end)

function A.RememberRank(p)
 if not A.Ready or p:IsBot() then return end
 local sid,rank=p:SteamID64(),A.Rank(p)
 if A.SeenRanks[sid]~=rank and A.Query("REPLACE INTO sta_seen VALUES("..sql.SQLStr(sid)..","..rank..")")~=false then A.SeenRanks[sid]=rank end
end
hook.Add("PlayerInitialSpawn","STALKER.AdminRememberRank",function(p)
 timer.Simple(2,function() if IsValid(p) then A.RememberRank(p) end end)
end)
hook.Add("PlayerDisconnected","STALKER.AdminRememberRank",A.RememberRank)
