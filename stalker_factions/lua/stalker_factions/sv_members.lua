-- Командование составом: приглашения, звания, исключение, запрет вступления. Все решения — на сервере.
local F=STFW
for _,n in ipairs({"invite","cmd"}) do util.AddNetworkString("stfw."..n) end
F.Invites=F.Invites or {}

local function online(sid)
 for _,p in ipairs(player.GetHumans()) do if p:SteamID64()==sid then return p end end
end
F.OnlineBySID=online
local function rankOf(sid,id)
 local d=F.Profiles[sid]
 if not d or not d.joined or d.faction~=id then return end
 if F.World.leaders[id]==sid then return 100 end
 return d.frank or 1
end

--[[ Приглашение: лидер или офицер зовёт игрока; у цели всплывает окно на InviteSeconds.
 Принятие — вступление без взноса (лимит состава и запрет лидера всё равно проверяются). ]]
function F.Invite(leader,target)
 if not IsValid(leader) or not IsValid(target) or not target:IsPlayer() then return false,"denied" end
 if not F.CanCommand(leader) then return false,"unauthorized" end
 if target==leader or target:IsBot() then return false,"denied" end
 local id=F.Load(leader).faction
 local ok,err=F.CanJoin(target,id,nil,{invite=true});if not ok then return false,err end
 local sid=target:SteamID64();local old=F.Invites[sid]
 if old and old.expires>CurTime() and old.faction==id then return false,"invite_pending" end
 local token=tostring(math.random(100000,999999))..tostring(math.floor(CurTime()*10)%100000)
 F.Invites[sid]={faction=id,from=leader:SteamID64(),fromName=leader:Nick(),expires=CurTime()+F.Config.InviteSeconds,token=token}
 F.SendJSON("stfw.invite",target,{faction=id,from=leader:Nick(),seconds=F.Config.InviteSeconds,token=token,members=F.MemberCount(id),cap=F.MemberCap(id)})
 F.Toast(target,"Приглашение в «"..F.Name(id).."» от "..leader:Nick(),"info")
 return true
end
-- Ответ на приглашение. Пригласивший должен сохранить полномочия к моменту ответа.
function F.AnswerInvite(p,token,accept)
 local sid=p:SteamID64();local inv=F.Invites[sid]
 if not inv or inv.token~=token then return false,"invite_invalid" end
 F.Invites[sid]=nil
 local from=online(inv.from)
 if inv.expires<CurTime() then return false,"invite_expired" end
 if not accept then if IsValid(from) then F.Toast(from,p:Nick().." отклонил приглашение","warn") end;return true end
 local r=rankOf(inv.from,inv.faction)
 if not r or (r<100 and r<F.OfficerRank) then return false,"invite_invalid" end
 local ok,err=F.SetFaction(p,inv.faction,{invite=true})
 if ok and IsValid(from) then F.Toast(from,p:Nick().." принял приглашение","ok") end
 return ok,err
end

-- Звания: повышает и понижает только лидер, в том числе профили не в сети.
function F.SetRank(actor,sid,delta)
 if not F.IsLeader(actor) then return false,"unauthorized" end
 if not F.ValidSID(sid) or (delta~=1 and delta~=-1) then return false,"denied" end
 local id=F.Load(actor).faction;local d=F.Profiles[sid]
 if not d or not d.joined or d.faction~=id then return false,"not_member" end
 if F.World.leaders[id]==sid then return false,"target_leader" end
 local nextRank=(d.frank or 1)+delta
 if nextRank<1 or nextRank>#F.FactionRanks then return false,"rank_limit" end
 d=table.Copy(d);d.frank=nextRank
 if not F.Commit(table.Copy(F.World),{[sid]=d},"rank "..id.." "..sid.." "..nextRank) then return false,"storage" end
 local p=online(sid);if IsValid(p) then F.Toast(p,(delta>0 and "Повышение: " or "Понижение: ")..F.FRankName(nextRank),delta>0 and "ok" or "warn") end
 return true,nil,F.FRankName(nextRank)
end
-- Исключение: лидер — любого члена, офицеры и выше — только младших по званию.
function F.KickMember(actor,sid)
 if not F.CanCommand(actor) or not F.ValidSID(sid) then return false,"unauthorized" end
 local id=F.Load(actor).faction
 if sid==actor:SteamID64() then return false,"denied" end
 local target=rankOf(sid,id);if not target then return false,"not_member" end
 local mine=rankOf(actor:SteamID64(),id)
 if target>=mine then return false,"unauthorized" end
 return F.ExpelSID(sid,"kick by "..actor:SteamID64())
end

--[[ Запрет вступления: один на лидера, оплачивается из кошелька лидера, действует до смены лидера.
 Запрещённого члена группировки сразу исключаем. ]]
function F.BanJoin(leader,sid)
 if not F.IsLeader(leader) then return false,"unauthorized" end
 if not F.ValidSID(sid) or sid==leader:SteamID64() then return false,"denied" end
 local id=F.Load(leader).faction
 if F.ActiveBan(id) then return false,"ban_slot_taken" end
 local cost=math.max(0,math.floor(F.Config.LeaderBanCost))
 if cost>0 then
  if not leader.addMoney or not leader.getDarkRPVar then return false,"no_darkrp" end
  local money=leader:getDarkRPVar("money");if type(money)~="number" or money<cost then return false,"ban_money" end
 end
 local target=online(sid);local profile=F.Profiles[sid]
 local name=IsValid(target) and target:Nick() or (profile and profile.name) or sid
 local w=table.Copy(F.World);w.bans=w.bans or {}
 w.bans[id]={sid=sid,leader=leader:SteamID64(),name=name,t=os.time(),cost=cost}
 local profiles={};local expelled=false
 if profile and profile.joined and profile.faction==id then
  local d=table.Copy(profile);d.joined=false;d.faction="loner";d.joinedAt=os.time();d.frank=1;profiles[sid]=d;expelled=true
 end
 if profile and profile.admissions and profile.admissions[id] then
  local d=profiles[sid] or table.Copy(profile);d.admissions[id]=nil;profiles[sid]=d
 end
 if cost>0 then leader:addMoney(-cost) end
 if not F.Commit(w,profiles,"ban "..id.." "..sid) then if cost>0 then leader:addMoney(cost) end;return false,"storage" end
 local inv=F.Invites[sid];if inv and inv.faction==id then F.Invites[sid]=nil end
 if IsValid(target) then
  if expelled then hook.Run("STFW_FactionLeft",target,id) end
  F.Toast(target,"Лидер «"..F.Name(id).."» запретил вам вступление в группировку","danger",10)
 end
 F.AlertFaction(id,"Лидер запретил вступление: "..name,"warn",leader)
 return true
end
function F.LiftBan(leader)
 if not F.IsLeader(leader) then return false,"unauthorized" end
 local id=F.Load(leader).faction
 if not F.ActiveBan(id) then return false,"denied" end
 local w=table.Copy(F.World);w.bans[id]=nil
 if not F.Commit(w,{},"unban "..id) then return false,"storage" end
 return true
end

--[[ Команды из меню командования и КПК: op + параметры. Возвращают ok, ключ ошибки, текст успеха. ]]
local handlers={
 invite=function(p,a) local t=F.ValidSID(a.sid) and online(a.sid);if not t then return false,"member_offline" end;local ok,err=F.Invite(p,t);return ok,err,"Приглашение отправлено: "..(IsValid(t) and t:Nick() or "") end,
 kick=function(p,a) return F.KickMember(p,a.sid) end,
 rank=function(p,a) local ok,err,name=F.SetRank(p,a.sid,a.delta);return ok,err,name and ("Новое звание: "..name) end,
 approve=function(p,a) return F.GrantAdmission(p,a.sid,false) end,
 revoke=function(p,a) return F.GrantAdmission(p,a.sid,true) end,
 ban=function(p,a) return F.BanJoin(p,a.sid) end,
 unban=function(p) return F.LiftBan(p) end,
 withdraw=function(p,a) return F.TreasuryWithdraw(p,a.amount) end,
 payout=function(p,a) return F.TreasuryPayout(p,a.sid,a.amount) end,
 ability=function(p,a) return F.UseAbility(p,a.id) end,
}
function F.Command(p,a)
 local h=type(a)=="table" and type(a.op)=="string" and handlers[a.op]
 if not h then return false,"denied" end
 return h(p,a)
end
net.Receive("stfw.cmd",function(len,p)
 if not F.RateOK(p,"stfw.cmd",3,6) or not F.Load(p) then return end
 local a=F.ReadJSON(len,2000);if not a then return end
 local ok,err,info=F.Command(p,a)
 if ok then F.Toast(p,info or F.L("saved"),"ok") else F.Toast(p,F.L(err or "denied"),"warn") end
 F.SendState(p,{cmd=true,op=a.op,ok=ok==true,error=err})
end)
net.Receive("stfw.invite",function(len,p)
 if not F.RateOK(p,"stfw.invite",1,3) then return end
 local a=F.ReadJSON(len,400);if not a or type(a.token)~="string" then return end
 local ok,err=F.AnswerInvite(p,a.token,a.accept==true)
 if not ok then F.Toast(p,F.L(err or "denied"),"warn") end
 F.SendState(p)
end)
hook.Add("PlayerDisconnected","STFW.Invites",function(p) F.Invites[p:SteamID64()]=nil end)
-- Консольная команда приглашения игрока под прицелом или по SteamID64 (можно повесить на клавишу).
function F.InviteCommand(p,arg)
 if not IsValid(p) or not F.RateOK(p,"stfw.invitecmd",1,3) then return end
 local target=F.ValidSID(arg) and online(arg)
 if not target then local e=p:GetEyeTrace().Entity;if IsValid(e) and e:IsPlayer() and p:GetPos():DistToSqr(e:GetPos())<300^2 then target=e end end
 if not target then F.Toast(p,F.L("member_offline"),"warn");return end
 local ok,err=F.Invite(p,target);F.Toast(p,ok and ("Приглашение отправлено: "..target:Nick()) or F.L(err or "denied"),ok and "ok" or "warn")
end
concommand.Add("stfw_invite",function(p,_,args) F.InviteCommand(p,args[1]) end)
