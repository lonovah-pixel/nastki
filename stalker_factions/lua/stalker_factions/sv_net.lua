local F=STFW
for _,n in ipairs({"state","request","action","notice","recruit"}) do util.AddNetworkString("stfw."..n) end
local function rate(p)
 local now=CurTime();p.StfwBucket=p.StfwBucket or {n=6,t=now};local b=p.StfwBucket;b.n=math.min(6,b.n+(now-b.t)*2);b.t=now
 if b.n<1 then return false end;b.n=b.n-1;return true
end
function F.SendState(p,reply)
 local d=F.Load(p);if not d then return end
 local top={};for sid,v in pairs(F.Profiles) do if v.faction==d.faction and v.joined then top[#top+1]={name=v.name or sid,xp=v.xp,captures=v.captures} end end
 table.sort(top,function(a,b) return a.xp>b.xp end);while #top>10 do table.remove(top) end
 local members={};local traders={};local candidates={}
 if F.IsLeader(p) then for _,other in ipairs(player.GetHumans()) do local profile=F.Load(other);if profile and (not profile.joined or profile.faction~=d.faction) then candidates[#candidates+1]={sid=other:SteamID64(),name=other:Nick()} end end end
 if p:IsSuperAdmin() or F.IsLeader(p) then
  for _,member in ipairs(player.GetHumans()) do local profile=F.Load(member)
   if profile and (p:IsSuperAdmin() or profile.joined and profile.faction==d.faction) then
    members[#members+1]={sid=member:SteamID64(),name=member:Nick(),faction=profile.faction,joined=profile.joined}
   end
  end
 end
 if p:IsSuperAdmin() then for _,ent in ipairs(ents.FindByClass("stalker_npc_trader")) do traders[#traders+1]={entity=ent:EntIndex(),profile=ent:GetTraderID()} end end
 local state={candidates=candidates,progression=F.World.progression or {},leader=F.IsLeader(p),members=members,traders=traders,reply=reply,revision=F.World.controlRevision or 0,points=F.World.points,relations=F.World.relations,leaders=F.World.leaders,
 proposals=F.World.proposals,history=F.World.history,me=d,top=top,admin=p:IsSuperAdmin(),serverTime=os.time()}
 local raw=util.TableToJSON(state);local data=raw and util.Compress(raw);if not data or #data>60000 then return end
 net.Start("stfw.state");net.WriteUInt(#data,16);net.WriteData(data,#data);net.Send(p)
end
local function trace(p)
 local tr=p:GetEyeTrace();if not tr.Hit or tr.HitSky or tr.HitNormal.z<0.5 or not util.IsInWorld(tr.HitPos) or p:GetPos():DistToSqr(tr.HitPos)>4096^2 then return end
 return tr.HitPos+tr.HitNormal*4
end
function F.Editor(p,a)
 if not p:IsSuperAdmin() then return false,"unauthorized" end
 local w=table.Copy(F.World)
 if a.op=="member" or a.op=="expel" or a.op=="rep" then
  local target;for _,v in ipairs(player.GetHumans()) do if v:SteamID64()==a.sid then target=v end end
  if not target then return false,"denied" end
  if a.op=="member" then return F.SetFaction(target,a.faction,true) end
  if a.op=="expel" then return F.Expel(target) end
  return F.AddReputation(target,a.faction,a.amount,"admin "..p:SteamID64())
 elseif a.op=="leader" then
  if not F.Factions[a.faction] or type(a.sid)~="string" or (#a.sid~=17 and a.sid~="") or (a.sid~="" and not a.sid:match("^%d+$")) then return false,"denied" end
  if a.sid~="" then
   local member=F.Profiles[a.sid]
   if not member or not member.joined or member.faction~=a.faction then return false,"leader_member" end
  end
  w.leaders[a.faction]=a.sid~="" and a.sid or nil
 elseif a.op=="recruiter" then
  if not F.Factions[a.faction] or not F.Factions[a.faction].playable or table.Count(w.recruiters)>=32 then return false,"denied" end
  local pos=trace(p);if not pos then return false,"denied" end
  local id=tostring(os.time()).."_"..math.random(10000,99999)
  w.recruiters[id]={faction=a.faction,pos={x=pos.x,y=pos.y,z=pos.z},yaw=p:EyeAngles().y+180}
 elseif a.op=="remove_recruiter" then
  local e=p:GetEyeTrace().Entity;if not IsValid(e) or e:GetClass()~="stalker_recruiter" or not e.StfwID then return false,"denied" end
  w.recruiters[e.StfwID]=nil
 else
  local point=w.points[a.id or ""]
  if a.op=="create" then
   if table.Count(w.points)>=F.Config.MaxPoints then return false,"denied" end
   local fields,err=F.PointFields(a);if not fields then return false,err end
   if a.owner~="" and (not F.Factions[a.owner] or not F.Factions[a.owner].playable) then return false,"point_owner" end
   local pos
   if a.placement=="feet" then pos=p:GetPos();if not util.IsInWorld(pos) then return false,"point_position" end else pos=trace(p) end
   if not pos then return false,"point_position" end
   local id=tostring(os.time()).."_"..math.random(10000,99999)
   point=fields;point.id=id;point.pos={x=pos.x,y=pos.y,z=pos.z};point.owner=a.owner;point.progress=0;w.points[id]=point;a.createdID=id
  elseif not point then return false,"denied"
  elseif a.op=="delete" then w.points[a.id]=nil
  elseif a.op=="move" then local pos=trace(p);if not pos then return false,"denied" end;point.pos={x=pos.x,y=pos.y,z=pos.z};point.progress=0;point.attacker=nil
  elseif a.op=="capture" then
   if a.faction~="" and (not F.Factions[a.faction] or not F.Factions[a.faction].playable) then return false,"denied" end
   point.owner=a.faction;point.progress=0;point.attacker=nil
  elseif a.op=="edit" then
   local fields,err=F.PointFields(a);if not fields then return false,err end
   if a.owner~=nil then
    if a.owner~="" and (not F.Factions[a.owner] or not F.Factions[a.owner].playable) then return false,"point_owner" end
    if point.owner~=a.owner then point.owner=a.owner;point.progress=0;point.attacker=nil end
   end
   for key,value in pairs(fields) do point[key]=value end
  else return false,"denied" end
 end
 if not F.Commit(w,{},"editor "..p:SteamID64().." "..a.op) then return false,"storage" end
 if a.op=="recruiter" or a.op=="remove_recruiter" then F.RestoreRecruiters() end
 return true,nil,a.createdID or a.id
end
function F.TraderEditor(p,a)
 if not p:IsSuperAdmin() then return false,"unauthorized" end
 local N=STALKER_NPC;if not N or not N.SpawnTrader or not N.SaveNPCs then return false,"denied" end
 if a.op=="spawn" then
  if type(a.profile)~="string" or not N.Config.Traders[a.profile] or #ents.FindByClass("stalker_npc_trader")>=64 then return false,"denied" end
  local pos=trace(p);if not pos then return false,"point_position" end
  local ent=N.SpawnTrader(a.profile,pos,Angle(0,p:EyeAngles().y+180,0));if not IsValid(ent) then return false,"denied" end
  if not N.SaveNPCs() then ent:Remove();return false,"storage" end
 elseif a.op=="save" then if not N.SaveNPCs() then return false,"storage" end
 elseif a.op=="remove" then
  local ent=p:GetEyeTrace().Entity
  if not IsValid(ent) or ent:GetClass()~="stalker_npc_trader" or p:GetPos():DistToSqr(ent:GetPos())>4096^2 then return false,"denied" end
  local id,pos,ang=ent:GetTraderID(),ent:GetPos(),ent:GetAngles();ent:Remove()
  -- GetAll может видеть помеченную на удаление сущность до конца тика; исключаем её явно в SaveNPCs.
  N.ExcludeSavedEntity=ent
  local saved=N.SaveNPCs();N.ExcludeSavedEntity=nil
  if not saved then N.SpawnTrader(id,pos,ang);return false,"storage" end
 else return false,"denied" end
 return true
end
net.Receive("stfw.request",function(len,p) if len==0 and rate(p) then F.SendState(p) end end)
net.Receive("stfw.action",function(len,p)
 if len>8192 or len<16 or not rate(p) or not F.Load(p) then return end
 local size=net.ReadUInt(16);if size<2 or size>1000 or len~=16+size*8 then return end
 local a=util.JSONToTable(net.ReadData(size));if type(a)~="table" then return end
 if not F.Int(a.requestID,1,2147483646) then return end
 if a.revision~=(F.World.controlRevision or 0) then F.Notify(p,"stale");F.SendState(p,{id=a.requestID,ok=false,error="stale"});return end
 local ok,err,pointID
 if a.kind=="diplomacy" then ok,err=F.Diplomacy(p,a) elseif a.kind=="editor" then ok,err,pointID=F.Editor(p,a) elseif a.kind=="upgrade" then ok,err=F.BuyUpgrade(p,a) elseif a.kind=="leader" then ok,err=F.LeaderAction(p,a) elseif a.kind=="trader" then ok,err=F.TraderEditor(p,a) else return end
 if F.DebugLog then F.DebugLog(p:SteamID64().." "..tostring(a.kind).."/"..tostring(a.op).." = "..tostring(ok).." "..tostring(err)) end
 F.Notify(p,ok and "saved" or (err or "denied"));F.SendState(p,{id=a.requestID,ok=ok==true,error=err,pointID=pointID})
end)
function F.SendRecruit(p,ent)
 local ok,reason,seconds=F.CanJoin(p,ent:GetFactionID())
 p.StfwRecruit={ent=ent,expires=CurTime()+60}
 net.Start("stfw.recruit");net.WriteEntity(ent);net.WriteBool(ok==true);net.WriteString(reason or "");net.WriteUInt(math.min(4294967295,seconds or 0),32);net.Send(p)
end
net.Receive("stfw.recruit",function(len,p)
 if len~=17 or not rate(p) then return end
 local ent=Entity(net.ReadUInt(16));local accept=net.ReadBool()
 if not accept or not IsValid(ent) or ent:GetClass()~="stalker_recruiter" or not p:Alive() or p:GetPos():DistToSqr(ent:GetPos())>F.Config.RecruitDistance^2 then return end
 local tr=util.TraceLine({start=p:EyePos(),endpos=ent:WorldSpaceCenter(),filter=p});if tr.Hit and tr.Entity~=ent then return end
 if not p.StfwRecruit or p.StfwRecruit.ent~=ent or p.StfwRecruit.expires<CurTime() then return end;p.StfwRecruit=nil
 local ok,err=F.SetFaction(p,ent:GetFactionID());if not ok then F.Notify(p,err);if F.SendRecruit then F.SendRecruit(p,ent) end end;F.SendState(p)
end)
timer.Create("STFW.Sync",3,0,function() for _,p in ipairs(player.GetHumans()) do F.SendState(p) end end)
-- Чат-команды используют те же проверки, что редактор и переговоры.
hook.Add("PlayerSay","STFW.Chat",function(p,text)
 local a=string.Explode(" ",text);local cmd=string.lower(a[1] or "")
 if cmd=="!leader" then p:ConCommand("stfw_leader");return "" end
 if cmd=="!fadmin" then if p:IsSuperAdmin() then p:ConCommand("stfw_admin") end;return "" end
 if cmd=="!faction" or cmd=="!factioninfo" then p:ConCommand("stfw_menu");return "" end
 if not ({["!kickfaction"]=true,["!setfaction"]=true,["!rep"]=true,["!war"]=true,["!capture"]=true})[cmd] then return end
 if not p:IsSuperAdmin() then F.Notify(p,"unauthorized");return "" end
 local ok,err
 if cmd=="!war" then ok,err=F.Diplomacy(p,{from=a[2],to=a[3],op=a[4]=="stop" and "stop" or "war"})
 elseif cmd=="!capture" then ok,err=F.Editor(p,{op="capture",id=a[2],faction=a[3] or ""})
 else
  local target;for _,v in ipairs(player.GetHumans()) do if v:SteamID64()==a[2] then target=v end end
  if target then if cmd=="!kickfaction" then ok=F.Expel(target) elseif cmd=="!setfaction" then ok,err=F.SetFaction(target,a[3],true) else ok=F.AddReputation(target,a[3],tonumber(a[4]),"admin "..p:SteamID64()) end end
 end
 F.Notify(p,ok and "saved" or (err or "denied"));return ""
end)
