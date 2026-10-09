local F=STFW
function F.Diplomacy(p,a)
 local from,to=a.from,a.to
 if not F.Factions[from] or not F.Factions[to] or from==to or not F.Factions[from].playable or not F.Factions[to].playable then return false,"denied" end
 if not F.Authority(p,from) then return false,"unauthorized" end
 local w=table.Copy(F.World);local key=F.Pair(from,to);local r=w.relations[key] or {points=0,revision=0,war=false};w.relations[key]=r
 if a.op=="propose" then
  if not F.Int(a.points,-100,100) or type(a.peace)~="boolean" then return false,"denied" end
  if not w.leaders[to] and not p:IsSuperAdmin() then return false,"offline" end
  w.proposals[key]={from=from,to=to,points=a.points,peace=a.peace,token=tostring(os.time()).."_"..math.random(1,2147483646),revision=r.revision,expires=os.time()+F.Config.ProposalTTL,author=p:SteamID64()}
 elseif a.op=="accept" or a.op=="reject" then
  local proposal=w.proposals[key]
  if not proposal or type(a.token)~="string" or a.token~=proposal.token or proposal.to~=from or proposal.from~=to or proposal.expires<os.time() or proposal.revision~=r.revision then return false,"stale" end
  if a.op=="accept" then
   r.points=proposal.points;r.revision=r.revision+1
   if proposal.peace then r.war=false;r.truce=os.time()+F.Config.TruceSeconds;r.scores=nil end
  end
  w.proposals[key]=nil
 elseif a.op=="war" then
  if r.war or (r.truce or 0)>os.time() then return false,"denied" end
  r.war=true;r.points=math.min(-50,r.points);r.scores={[from]=0,[to]=0};r.started=os.time();r.revision=r.revision+1;w.proposals[key]=nil
 elseif a.op=="adjust" and p:IsSuperAdmin() then
  if not F.Int(a.points,-100,100) then return false,"denied" end
  r.points=math.Clamp(r.points+a.points,-100,100);r.revision=r.revision+1;w.proposals[key]=nil
 elseif a.op=="stop" and p:IsSuperAdmin() then r.war=false;r.scores=nil;r.truce=os.time()+F.Config.TruceSeconds;r.revision=r.revision+1;w.proposals[key]=nil
 else return false,"denied" end
 if not F.Commit(w,{},"diplomacy "..p:SteamID64().." "..a.op.." "..key) then return false,"storage" end
 F.Notify(nil,a.op=="propose" and "proposal" or "updated",F.Name(from).." / "..F.Name(to));return true
end
function F.Score(w,a,b,n)
 if not a or not b or a=="" or b=="" or a==b then return end
 local r=w.relations[F.Pair(a,b)];if not r or not r.war then return end
 r.scores=r.scores or {};r.scores[a]=(r.scores[a] or 0)+n
 if r.scores[a]>=F.Config.VictoryScore then
  w.victorySerial=(w.victorySerial or 0)+1
  w.history[#w.history+1]={winner=a,loser=b,time=os.time()};if #w.history>30 then table.remove(w.history,1) end
  r.war=false;r.points=-50;r.truce=os.time()+F.Config.TruceSeconds;r.revision=r.revision+1;w.proposals[F.Pair(a,b)]=nil
 end
end
function F.Eligible(p,point)
 if ST_EMISSION and ST_EMISSION.IsUnconscious and ST_EMISSION.IsUnconscious(p) then return end
 if not p:Alive() or p:IsBot() or p:GetMoveType()==MOVETYPE_NOCLIP or p:GetObserverMode()~=OBS_MODE_NONE or p:InVehicle() or (p.StfwProtected or 0)>CurTime() then return end
 local d=F.Load(p);if not d or not d.joined then return end
 local pos=p:GetPos();local dx,dy=pos.x-point.pos.x,pos.y-point.pos.y
 if dx*dx+dy*dy<=point.radius^2 and math.abs(pos.z-point.pos.z)<=point.height then return d.faction end
end
local last=CurTime();local control=0
 timer.Create("STFW.Capture",1,0,function()
 if not F.DatabaseReady then return end
 local now=CurTime();local dt=math.Clamp(now-last,0,2);last=now;control=control+dt
 local w=table.Copy(F.World);local profiles={};local changed=false;local messages={}
 for id,point in pairs(w.points) do
  local counts,participants={},{}
  for _,p in ipairs(player.GetHumans()) do local f=F.Eligible(p,point);if f then counts[f]=(counts[f] or 0)+1;participants[#participants+1]=p end end
  local oldProgress,oldAttacker,oldContest=point.progress,point.attacker,point.contested
  local owner,old=F.CaptureStep(point,counts,dt,w)
  if oldProgress~=point.progress or oldAttacker~=point.attacker or oldContest~=point.contested then changed=true end
  if owner then
   changed=true;F.Score(w,owner,old,F.Config.CaptureScore);messages[#messages+1]=point.name.." / "..F.Name(owner)
   for _,p in ipairs(participants) do local sid=p:SteamID64();local d=profiles[sid] or table.Copy(F.Load(p));if d.faction==owner then
    d.xp=d.xp+25;d.captures=d.captures+1;d.rep[owner]=math.Clamp((d.rep[owner] or 0)+10,-2000,2000);profiles[sid]=d
   end end
  end
 end
 if control>=60 then
  control=0
  if F.AccrueSupply and F.AccrueSupply(w) then changed=true end
  for key,r in pairs(w.relations) do if r.war then
   local a,b=key:match("^([^:]+):([^:]+)$");local online={}
   for _,p in ipairs(player.GetHumans()) do local d=F.Load(p);if d and d.joined then online[d.faction]=true end end
   if online[a] and online[b] then for _,pt in pairs(w.points) do if pt.owner==a then F.Score(w,a,b,F.Config.ControlScore);changed=true elseif pt.owner==b then F.Score(w,b,a,F.Config.ControlScore);changed=true end end end
  end end
 end
 for key,proposal in pairs(w.proposals) do if proposal.expires<os.time() then w.proposals[key]=nil;changed=true end end
 if changed and F.Commit(w,profiles) then
  for _,msg in ipairs(messages) do F.Notify(nil,"captured",msg) end
 end
end)
local kills={}
hook.Add("PlayerDeath","STFW.Kill",function(victim,_,attacker)
 if not IsValid(attacker) or not attacker:IsPlayer() or attacker==victim or (victim.StfwProtected or 0)>CurTime() then return end
 local a,b=F.Load(attacker),F.Load(victim);if not a or not b or not a.joined or not b.joined then return end
 local key=attacker:SteamID64()..":"..victim:SteamID64();if (kills[key] or 0)>CurTime() then return end;kills[key]=CurTime()+120
 local relation=F.Relation(a.faction,b.faction)
 if relation=="war" then
  local w=table.Copy(F.World);a=table.Copy(a);a.xp=a.xp+5;a.kills=a.kills+1;F.Score(w,a.faction,b.faction,F.Config.KillScore);F.Commit(w,{[attacker:SteamID64()]=a},"war kill "..key)
 else F.AddReputation(attacker,b.faction,relation=="allied" and -10 or -5,"player kill") end
end)
