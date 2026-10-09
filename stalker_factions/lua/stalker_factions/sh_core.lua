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
-- Чистый шаг захвата: присутствие двух разных группировок блокирует прогресс.
function F.CaptureStep(point,counts,dt,world)
 local attacker,n;local groups=0
 for id,count in pairs(counts) do if count>0 then groups=groups+1;attacker=id;n=count end end
 if groups>1 then point.contested=true;return end
 point.contested=false
 if not attacker or attacker==point.owner then point.progress=math.max(0,(point.progress or 0)-dt/F.Config.CaptureSeconds);if point.progress==0 then point.attacker=nil end;return end
 if point.owner~="" and F.Relation(attacker,point.owner,world)~="war" then point.progress=0;point.attacker=nil;return end
 if point.attacker~=attacker then point.attacker=attacker;point.progress=0 end
 point.progress=math.min(1,(point.progress or 0)+dt*math.min(n,F.Config.MaxContributors)*(1+(F.UpgradeLevel and F.UpgradeLevel(world,attacker,"logistics") or 0)*.1)/F.Config.CaptureSeconds)
 if point.progress>=1 then local old=point.owner;point.owner=attacker;point.attacker=nil;point.progress=0;return attacker,old end
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
