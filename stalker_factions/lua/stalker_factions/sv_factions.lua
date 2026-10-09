local F=STFW
function F.Notify(p,key,extra)
 net.Start("stfw.notice");net.WriteString(F.L(key)..(extra and (": "..extra) or ""));if IsValid(p) then net.Send(p) else net.Broadcast() end
end
function F.Authority(p,id) return IsValid(p) and (p:IsSuperAdmin() or (F.Load(p) and F.Load(p).joined and F.Load(p).faction==id and F.World.leaders[id]==p:SteamID64())) end
-- Одинаковые условия для предпросмотра у NPC и окончательного решения сервера.
function F.CanJoin(p,id,prospectiveTeam)
 local d=F.Load(p);local f=F.Factions[id]
 if not d then return false,"profile_unavailable" end
 if not f or not f.playable then return false,"invalid_faction" end
 if d.joined and d.faction==id then return false,"already_joined" end
 local remaining=math.max(0,F.Config.JoinCooldown-(os.time()-(d.joinedAt or 0)))
 if remaining>0 and (d.joined or (d.joinedAt or 0)>0) then return false,"cooldown",remaining end
 if (d.rep[id] or 0)<(f.minRep or F.Config.JoinMinRep) then return false,"low_reputation" end
 if F.Config.DarkRP.Enabled and F.Config.DarkRP.Mode=="jobs" and F.JobFaction(prospectiveTeam or p:Team())~=id then return false,"job_mismatch" end
 if F.Admission then local allowed,reason=F.Admission(p,id);return allowed,reason end
 return true
end
function F.SetFaction(p,id,force)
 local d=F.Load(p);local f=F.Factions[id]
 if not d then return false,"profile_unavailable" end
 if not f or not f.playable then return false,"invalid_faction" end
 if not force then local ok,err=F.CanJoin(p,id);if not ok then return false,err end end
 local fee=0
 if not force and F.Admission then local ok,err,price=F.Admission(p,id);if not ok then return false,err end;fee=price or 0 end
 if fee>0 then p:addMoney(-fee) end
 d=table.Copy(d);local w=table.Copy(F.World)
 if d.admissions then d.admissions[id]=nil end
 if w.leaders[d.faction]==p:SteamID64() then w.leaders[d.faction]=nil end
 d.faction=id;d.joined=true;d.joinedAt=os.time()
 if not F.Commit(w,{[p:SteamID64()]=d},"membership "..p:SteamID64().." -> "..id) then if fee>0 then p:addMoney(fee) end;return false,"storage" end
 hook.Run("STFW_FactionChanged",p,id);F.Notify(p,"joined",F.Name(id));return true
end
function F.AddReputation(p,id,amount,reason)
 if not F.Factions[id] or not F.Int(amount,-1000,1000) then return false end
 local d=F.Load(p);if not d then return false end;d=table.Copy(d);d.rep[id]=math.Clamp((d.rep[id] or 0)+amount,-2000,2000)
 if not F.Commit(table.Copy(F.World),{[p:SteamID64()]=d},"rep "..p:SteamID64().." "..id.." "..amount.." "..tostring(reason)) then return false end
 F.Notify(p,"updated",F.Name(id).." "..(amount>=0 and "+" or "")..amount);return true
end
function F.SetNPCFaction(ent,id) if not IsValid(ent) or not F.Factions[id] then return false end;ent:SetNW2String("stfw_faction",id);return true end
local function npcKey(ent)
 if not IsValid(ent) then return end
 if ent.StfwID then return "recruiter:"..ent.StfwID end
 if ent:GetClass()=="stalker_npc_trader" then return "trader:"..ent:GetTraderID() end
end
function F.GetNPCReputation(ent,id)
 local key=npcKey(ent);if key then return ((F.World.npcRep or {})[key] or {})[id] or 0 end
 return IsValid(ent) and ent:GetNW2Int("stfw_rep_"..id,0) or 0
end
function F.SetNPCReputation(ent,id,n)
 if not IsValid(ent) or not F.Factions[id] or not F.Int(n,-2000,2000) then return false end
 local key=npcKey(ent)
 if key then local w=table.Copy(F.World);w.npcRep=w.npcRep or {};w.npcRep[key]=w.npcRep[key] or {};w.npcRep[key][id]=n
  if not F.Commit(w,{},"npc reputation "..key) then return false end
 end
 ent:SetNW2Int("stfw_rep_"..id,n);return true
end
hook.Add("PlayerInitialSpawn","STFW.Load",function(p) timer.Simple(2,function() if IsValid(p) and F.Load(p) then F.Save();p:SetNW2String("stfw_faction",F.Load(p).faction);p:SetNW2Bool("stfw_joined",F.Load(p).joined==true);F.SendState(p) end end) end)
hook.Add("PlayerSpawn","STFW.Protection",function(p)
 p.StfwProtected=CurTime()+F.Config.SpawnProtection
 -- Отдельный модуль ищет свободное место после штатного возрождения DarkRP.
 if F.QueueBaseSpawn then F.QueueBaseSpawn(p) end
end)
hook.Add("EntityTakeDamage","STFW.SpawnProtection",function(ent,dmg)
 if ent:IsPlayer() and (ent.StfwProtected or 0)>CurTime() and dmg:GetAttacker():IsPlayer() then dmg:SetDamage(0);return true end
 local attacker=dmg:GetAttacker();if attacker:IsPlayer() and dmg:GetDamage()>0 then attacker.StfwProtected=0 end
end)
hook.Add("OnNPCKilled","STFW.Mutants",function(npc,attacker)
 local fid=F.Config.MutantClasses[npc:GetClass()]
 if fid and IsValid(attacker) and attacker:IsPlayer() then local d=F.Load(attacker);if d and d.joined then F.AddReputation(attacker,d.faction,1,"mutant") end end
end)

function F.Expel(p)
 local old=F.Load(p);if not old then return false end
 local d=table.Copy(old);local w=table.Copy(F.World)
 if w.leaders[d.faction]==p:SteamID64() then w.leaders[d.faction]=nil end
 d.joined=false;d.faction="loner";d.joinedAt=os.time()
 return F.Commit(w,{[p:SteamID64()]=d},"expelled "..p:SteamID64())
end

function F.IsLeader(p)
 local d=IsValid(p) and F.Load(p)
 return d and d.joined and F.World.leaders[d.faction]==p:SteamID64() or false
end
function F.LeaderAction(p,a)
 if a.op=="approve" or a.op=="revoke" then return F.GrantAdmission(p,a.sid,a.op=="revoke") end
 if not F.IsLeader(p) or a.op~="expel" then return false,"unauthorized" end
 local d=F.Load(p);local target
 for _,other in ipairs(player.GetHumans()) do if other:SteamID64()==a.sid then target=other;break end end
 if not IsValid(target) or target==p then return false,"denied" end
 local member=F.Load(target)
 if not member or not member.joined or member.faction~=d.faction then return false,"unauthorized" end
 return F.Expel(target)
end
