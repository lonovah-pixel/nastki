local F=STFW
function F.Int(n,a,b) return type(n)=="number" and n==math.floor(n) and n>=a and n<=b end
function F.Pair(a,b) if a>b then a,b=b,a end return a..":"..b end
function F.Name(id) local f=F.Factions[id];return f and F.Text(f.name) or tostring(id or "—") end
function F.Text(v) if type(v)=="table" then return v[F.Config.Language] or v.en or v.ru or "" end return tostring(v or "") end
function F.Relation(a,b,world)
 if a==b then return "allied",100 end
 local r=(world or F.World or F.State or {}).relations or {};r=r[F.Pair(a,b)] or {}
 local n=r.points or 0;return r.war and "war" or (n>=50 and "allied" or (n<=-50 and "enemy" or "neutral")),n
end
function F.Rank(xp) local k=1;for i,r in ipairs(F.Ranks) do if xp>=r[1] then k=i end end return k,F.Ranks[k] end
function F.NewProfile() return {faction="loner",joined=false,xp=0,rep={},joinedAt=0,kills=0,captures=0} end
-- Множитель скорости захвата: улучшение «Тактика захвата» и способность «Мобилизация» (только сервер знает баффы).
function F.CaptureRate(world,id)
 local rate=1+(F.UpgradeLevel and F.UpgradeLevel(world,id,"logistics") or 0)*.1
 if F.BuffActive and F.BuffActive(id,"mobilize") then rate=rate*(1+((F.Abilities.mobilize or {}).bonus or .5)) end
 return rate
end
-- Чистый шаг захвата. Присутствие двух разных группировок блокирует прогресс.
-- Прогресс идёт только у группировки, «вооружившей» точку действием на флаге (point.armed).
function F.CaptureStep(point,counts,dt,world)
 local attacker,n;local groups=0
 for id,count in pairs(counts) do if count>0 then groups=groups+1;attacker=id;n=count end end
 if groups>1 then point.contested=true;return end
 point.contested=false
 local function decay() point.progress=math.max(0,(point.progress or 0)-dt/F.Config.CaptureSeconds);if point.progress==0 then point.attacker=nil end end
 -- Никого нет: вооружённая точка ждёт атакующих до конца окна (его считает таймер захвата), иначе прогресс спадает.
 if not attacker then if not point.armed then decay() end;return end
 if attacker==point.owner or attacker~=point.armed then decay();return end
 if point.owner~="" and F.Relation(attacker,point.owner,world)~="war" then point.progress=0;point.attacker=nil;point.armed=nil;return end
 if point.attacker~=attacker then point.attacker=attacker;point.progress=0 end
 point.progress=math.min(1,(point.progress or 0)+dt*math.min(n,F.Config.MaxContributors)*F.CaptureRate(world,attacker)/F.Config.CaptureSeconds)
 if point.progress>=1 then local old=point.owner;point.owner=attacker;point.attacker=nil;point.progress=0;point.armed=nil;return attacker,old end
end
function F.PriceFactor(faction,trader,world,rep)
 local owned,total=0,0
 for _,p in pairs(world.points or {}) do total=total+1;if p.owner==trader then owned=owned+1 end end
 local _,score=F.Relation(faction,trader,world)
 return math.Clamp(1-(faction==trader and (F.UpgradeLevel and F.UpgradeLevel(world,faction,"supply") or 0)*.02 or 0)-score*.001-(rep or 0)*.00005-(total>0 and owned/total*.15 or 0),.65,1.4)
end

-- Режим recruiter сохраняет вступление у NPC независимо от профессии.
-- В режиме jobs используйте поле stalkerFaction у RPExtraTeams или таблицу Teams.
function F.JobFaction(teamID)
 local job=RPExtraTeams and RPExtraTeams[teamID]
 if job and F.Factions[job.stalkerFaction] and F.Factions[job.stalkerFaction].playable then return job.stalkerFaction end
 for key,id in pairs(F.Config.DarkRP.Teams) do
  if (type(key)=="number" and key==teamID or type(key)=="string" and _G[key]==teamID) and F.Factions[id] and F.Factions[id].playable then return id end
 end
end

--[[ Общие помощники STALKER Factions. Если ядра сборки нет, используются локальные реализации. ]]
function F.ValidSID(s) return type(s)=="string" and #s==17 and s:match("^%d+$")~=nil end
function F.FRankName(n) local list=F.FactionRanks;return list[math.Clamp(math.floor(tonumber(n) or 1),1,#list)] end
function F.Money(n)
 n=math.floor(tonumber(n) or 0)
 if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(n) end
 return (string.Comma and string.Comma(n) or tostring(n)).." ₽"
end
-- Членство в группировке (id=nil — в любой). Сервер смотрит профиль, клиент — сетевые переменные.
function F.IsMember(p,id)
 if not IsValid(p) or not p:IsPlayer() then return false end
 if SERVER and F.Load then
  local d=F.Load(p);if not d or not d.joined then return false end
  return id==nil or d.faction==id
 end
 if not p:GetNW2Bool("stfw_joined",false) then return false end
 return id==nil or p:GetNW2String("stfw_faction","")==id
end
-- Казна группировки: на сервере — из мира, на клиенте — из последнего снимка (видна лидеру и офицерам).
function F.Treasury(id)
 local world=SERVER and F.World or F.State
 local d=world and world.progression and world.progression[id or ""]
 return d and tonumber(d.treasury) or 0
end
-- Лимит состава: личный лимит группировки, иначе общий; 0 — без ограничения.
function F.MemberCap(id)
 local own=math.floor(tonumber(F.Config.JoinCaps[id or ""]) or 0)
 if own>0 then return own end
 return math.max(0,math.floor(tonumber(F.Config.MaxMembers) or 0))
end
function F.JoinFee(id) return math.max(0,math.floor(tonumber(F.Config.JoinFees[id or ""] or F.Config.JoinFee) or 0)) end
function F.SendJSON(name,target,tbl)
 local C=STALKER_CORE;if C and C.Send then return C.Send(name,target,tbl) end
 local raw=util.TableToJSON(tbl or {});local data=raw and util.Compress(raw);if not data or #data>63000 then return false end
 net.Start(name);net.WriteUInt(#data,16);net.WriteData(data,#data)
 if SERVER then if target then net.Send(target) else net.Broadcast() end else net.SendToServer() end
 return true
end
function F.ReadJSON(len,maxBytes)
 local C=STALKER_CORE;if C and C.Read then return C.Read(len,maxBytes) end
 local size=net.ReadUInt(16);if size<1 or size>(maxBytes or 63000) or (len and len~=16+size*8) then return end
 local raw=util.Decompress(net.ReadData(size) or "");local t=raw and #raw<=1000000 and util.JSONToTable(raw)
 if type(t)=="table" then return t end
end
function F.RateOK(p,key,perSecond,burst)
 local C=STALKER_CORE;if C and C.Rate then return C.Rate(p,key,perSecond,burst) end
 if not IsValid(p) then return true end
 p.StfwRates=p.StfwRates or {};local now=CurTime();local b=p.StfwRates[key]
 if not b then b={n=burst or 5,t=now};p.StfwRates[key]=b end
 b.n=math.min(burst or 5,b.n+(now-b.t)*(perSecond or 2));b.t=now
 if b.n<1 then return false end;b.n=b.n-1;return true
end
-- Права администрирования группировок: «Комендант»/ULX (stalker_factions) или суперадмин.
function F.IsAdmin(p)
 if not IsValid(p) then return false end
 local C=STALKER_CORE;if C and C.CanAdmin then return C.CanAdmin(p,"factions")==true end
 return p:IsSuperAdmin()
end
