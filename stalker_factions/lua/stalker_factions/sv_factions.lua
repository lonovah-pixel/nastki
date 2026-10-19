local F=STFW
-- Уведомление игрока (p=nil — всем). С ядром сборки — общий тост КПК, без него — старая полоса STFW.
function F.Toast(p,text,kind,seconds)
 if p~=nil and not IsValid(p) then return end
 local C=STALKER_CORE
 if C and C.Notify then return C.Notify(p,text,kind or "info",seconds) end
 net.Start("stfw.notice");net.WriteString(text);if p~=nil then net.Send(p) else net.Broadcast() end
end
function F.Notify(p,key,extra)
 local kind=({saved="ok",joined="ok",captured="info",victory="ok",proposal="info",updated="info"})[key] or "warn"
 F.Toast(p,F.L(key)..(extra and (": "..extra) or ""),kind)
end
-- Уведомить всех членов группировки в сети (кроме except).
function F.AlertFaction(id,text,kind,except)
 local list={}
 for _,p in ipairs(player.GetHumans()) do
  local d=F.Profiles[p:SteamID64()]
  if d and d.joined and d.faction==id and p~=except then list[#list+1]=p;F.Toast(p,text,kind or "info",8) end
 end
 return list
end
function F.Authority(p,id) return IsValid(p) and (F.IsAdmin(p) or (F.Load(p) and F.Load(p).joined and F.Load(p).faction==id and F.World.leaders[id]==p:SteamID64())) end

-- Состав: все вступившие профили (в том числе не в сети).
-- Подсчёт кэшируется до следующей записи мира: членство меняется только через F.Commit (ревизия растёт).
local counts={rev=-1}
function F.MemberCount(id)
 if counts.rev~=F.World.revision then
  counts={rev=F.World.revision}
  for _,d in pairs(F.Profiles) do if d.joined then counts[d.faction]=(counts[d.faction] or 0)+1 end end
 end
 return counts[id or ""] or 0
end
function F.IsFull(id) local cap=F.MemberCap(id);return cap>0 and F.MemberCount(id)>=cap end
-- Действующий запрет вступления: принадлежит текущему лидеру; смена лидера снимает его.
function F.ActiveBan(id,world)
 world=world or F.World
 local b=world.bans and world.bans[id or ""]
 if type(b)=="table" and b.leader and world.leaders[id]==b.leader then return b end
end

-- Одинаковые условия для предпросмотра у NPC и окончательного решения сервера.
-- opts.invite — вступление по приглашению лидера/офицера: без взноса и требований к репутации.
function F.CanJoin(p,id,prospectiveTeam,opts)
 opts=opts or {}
 local d=F.Load(p);local f=F.Factions[id]
 if not d then return false,"profile_unavailable" end
 if not f or not f.playable then return false,"invalid_faction" end
 if d.joined and d.faction==id then return false,"already_joined" end
 local ban=F.ActiveBan(id);if ban and ban.sid==p:SteamID64() then return false,"leader_banned" end
 if F.IsFull(id) then return false,"faction_full" end
 local remaining=math.max(0,F.Config.JoinCooldown-(os.time()-(d.joinedAt or 0)))
 if remaining>0 and (d.joined or (d.joinedAt or 0)>0) then return false,"cooldown",remaining end
 if not opts.invite and (d.rep[id] or 0)<(f.minRep or F.Config.JoinMinRep) then return false,"low_reputation" end
 if F.Config.DarkRP.Enabled and F.Config.DarkRP.Mode=="jobs" and F.JobFaction(prospectiveTeam or p:Team())~=id then return false,"job_mismatch" end
 if not opts.invite and F.Admission then local allowed,reason=F.Admission(p,id);return allowed,reason end
 return true
end
--[[ Вступление. Третий аргумент: true — принудительно (администратор), либо таблица {force, invite}.
 Любое вступление проходит здесь и вызывает хук STFW_FactionChanged(p, id) — по нему DarkRP выдаёт профессию. ]]
function F.SetFaction(p,id,opts)
 if opts==true then opts={force=true} elseif type(opts)~="table" then opts={} end
 local d=F.Load(p);local f=F.Factions[id]
 if not d then return false,"profile_unavailable" end
 if not f or not f.playable then return false,"invalid_faction" end
 if not opts.force then local ok,err=F.CanJoin(p,id,nil,opts);if not ok then return false,err end end
 local fee=0
 if not opts.force and not opts.invite and F.Admission then local ok,err,price=F.Admission(p,id);if not ok then return false,err end;fee=price or 0 end
 if fee>0 then p:addMoney(-fee) end
 d=table.Copy(d);local w=table.Copy(F.World)
 if d.admissions then d.admissions[id]=nil end
 -- Повторное включение администратором в ту же группировку (например, чтобы заново выдать профессию)
 -- не снимает лидерство и звание: должность снимается только при уходе из прежней группировки.
 if not (d.joined and d.faction==id) then
  if w.leaders[d.faction]==p:SteamID64() then w.leaders[d.faction]=nil end
  d.faction=id;d.joined=true;d.joinedAt=os.time();d.frank=1
 end
 if not F.Commit(w,{[p:SteamID64()]=d},"membership "..p:SteamID64().." -> "..id..(opts.invite and " (invite)" or "")) then if fee>0 then p:addMoney(fee) end;return false,"storage" end
 if F.Invites then F.Invites[p:SteamID64()]=nil end
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
hook.Add("PlayerInitialSpawn","STFW.Load",function(p) timer.Simple(2,function() if IsValid(p) and F.Load(p) then F.SaveProfile(p:SteamID64());F.PublishProfile(p,F.Load(p));F.SendState(p) end end) end)
-- Снимок по таймеру выше медленный клиент теряет (он ещё грузит Lua): досылаем, когда клиент реально загрузился.
hook.Add("STALKER_PlayerReady","STFW.Ready",function(p) if IsValid(p) and F.Load(p) then F.PublishProfile(p,F.Load(p));F.SendState(p) end end)
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

-- Исключение по SteamID64: работает и для профилей не в сети (их меняет лидер из меню состава).
function F.ExpelSID(sid,reason)
 local old=F.Profiles[sid];if not old or not old.joined then return false,"not_member" end
 local d=table.Copy(old);local w=table.Copy(F.World);local from=d.faction
 if w.leaders[d.faction]==sid then w.leaders[d.faction]=nil end
 d.joined=false;d.faction="loner";d.joinedAt=os.time();d.frank=1
 if not F.Commit(w,{[sid]=d},"expelled "..sid..(reason and (" "..reason) or "")) then return false,"storage" end
 local p=STALKER_CORE and STALKER_CORE.PlayerBySID and STALKER_CORE.PlayerBySID(sid)
 if not p then for _,q in ipairs(player.GetHumans()) do if q:SteamID64()==sid then p=q end end end
 if IsValid(p) then hook.Run("STFW_FactionLeft",p,from);F.Toast(p,"Вы больше не состоите в группировке «"..F.Name(from).."»","warn") end
 return true
end
function F.Expel(p)
 if not IsValid(p) or not F.Load(p) then return false end
 return F.ExpelSID(p:SteamID64())
end

function F.IsLeader(p)
 local d=IsValid(p) and F.Load(p)
 return d and d.joined and F.World.leaders[d.faction]==p:SteamID64() or false
end
-- Роль в командовании: leader, officer (звание «Офицер» и выше), member или nil (не состоит).
function F.Role(p)
 local d=IsValid(p) and F.Load(p);if not d or not d.joined then return end
 if F.World.leaders[d.faction]==p:SteamID64() then return "leader" end
 if (d.frank or 1)>=F.OfficerRank then return "officer" end
 return "member"
end
function F.CanCommand(p) local r=F.Role(p);return r=="leader" or r=="officer" end
-- Старые действия меню лидера (допуск, отзыв, исключение) — с новыми правилами званий.
function F.LeaderAction(p,a)
 if a.op=="approve" or a.op=="revoke" then return F.GrantAdmission(p,a.sid,a.op=="revoke") end
 if a.op~="expel" or not F.KickMember then return false,"unauthorized" end
 return F.KickMember(p,a.sid)
end
