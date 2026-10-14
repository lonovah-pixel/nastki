local F=STFW
function F.RestoreRecruiters()
 for _,e in ipairs(ents.FindByClass("stalker_recruiter")) do e:Remove() end
 for id,r in pairs(F.World.recruiters) do if F.Factions[r.faction] and F.Factions[r.faction].playable then
  local e=ents.Create("stalker_recruiter");if IsValid(e) then e:SetFactionID(r.faction);e:SetPos(Vector(r.pos.x,r.pos.y,r.pos.z));e:SetAngles(Angle(0,r.yaw,0));e.StfwID=id;e:Spawn() end
 end end
end
hook.Add("InitPostEntity","STFW.Recruiters",F.RestoreRecruiters)
hook.Add("PostCleanupMap","STFW.Recruiters",F.RestoreRecruiters)
hook.Add("PhysgunPickup","STFW.RecruiterLock",function(_,e) if e:GetClass()=="stalker_recruiter" then return false end end)
hook.Add("CanTool","STFW.RecruiterLock",function(_,tr) if IsValid(tr.Entity) and tr.Entity:GetClass()=="stalker_recruiter" then return false end end)
hook.Add("OnPlayerChangedTeam","STFW.DarkRP",function(p,_,teamID)
 if not F.Config.DarkRP.Enabled or F.Config.DarkRP.Mode~="jobs" then return end
 local d=F.Load(p);if not d then return end
 local target=F.JobFaction(teamID)
 if target then if not d.joined or d.faction~=target then F.SetFaction(p,target) end
 elseif d.joined then F.Expel(p) end
end)
hook.Add("PlayerInitialSpawn","STFW.DarkRPInitial",function(p)
 timer.Simple(3,function()
  if not IsValid(p) or not F.Config.DarkRP.Enabled or F.Config.DarkRP.Mode~="jobs" then return end
  local target=F.JobFaction(p:Team());local d=F.Load(p)
  if not d then return end
  if target then
   if not d.joined or d.faction~=target then F.SetFaction(p,target) end
  elseif d.joined then F.Expel(p) end
 end)
end)
-- Новые точки расширения приложенной версии NPC; инвентарь и кошелёк не дублируются.
hook.Add("STNPC_CanTrade","STFW.Trade",function(p,ent)
 local profile=STALKER_NPC and STALKER_NPC.Config.Traders[ent:GetTraderID()]
 local id=(profile and profile.Faction) or F.Config.TraderFactions[ent:GetTraderID()];local d=F.Load(p)
 if id and d and d.joined and F.Relation(d.faction,id)=="war" then return false end
end)
hook.Add("STNPC_PriceMultiplier","STFW.Economy",function(profile,_,side,p)
 if not IsValid(p) then return end
 local id=profile.Faction
 if not id and STALKER_NPC then for key,v in pairs(STALKER_NPC.Config.Traders) do if v==profile then id=F.Config.TraderFactions[key];break end end end
 local d=F.Load(p);if not id or not d then return end
 local factor=F.PriceFactor(d.faction,id,F.World,d.rep[id]);return side=="buy" and factor or (2-factor)
end)

hook.Add("OnEntityCreated","STFW.TagNPC",function(ent)
 timer.Simple(0,function() if not IsValid(ent) then return end
  local faction=F.Config.MutantClasses[ent:GetClass()]
  if ent:GetClass()=="stalker_npc_trader" then faction=F.Config.TraderFactions[ent:GetTraderID()] end
  if ent:GetClass()=="stalker_recruiter" then faction=ent:GetFactionID() end
  if faction then F.SetNPCFaction(ent,faction) end
 end)
end)
hook.Add("STNPC_DialogueText","STFW.Dialogue",function(profile,p,text)
 local faction=profile.Faction
 if not faction and STALKER_NPC then for id,v in pairs(STALKER_NPC.Config.Traders) do if v==profile then faction=F.Config.TraderFactions[id];break end end end
 local d=F.Load(p);if not faction or not d then return end
 local relation,points=F.Relation(d.faction,faction)
 return F.Text(text).."\n\n["..F.Name(faction).." / "..F.L(relation).." / "..points.."]"
end)

-- Check prospective job before DarkRP switches it; fee is charged only by SetFaction.
hook.Add("playerCanChangeTeam","STFW.AdmissionJob",function(p,teamID,force)
 if not F.Config.DarkRP.Enabled then return end
 -- Режим recruiter: вступление только у вербовщика или по приглашению; профессию группировки выбрать в меню профессий нельзя.
 if F.Config.DarkRP.Mode~="jobs" then
  local job=RPExtraTeams and RPExtraTeams[teamID]
  if not force and job and job.stalkerFaction and not F.IsMember(p,job.stalkerFaction) then return false,"Вступление в группировку — только у её вербовщика или по приглашению лидера." end
  return
 end
 local id=F.JobFaction(teamID);if not id then return end
 local d=F.Load(p);if d and d.joined and d.faction==id then return end
 local ok,reason=F.CanJoin(p,id,teamID);if not ok then return false,F.L(reason) end
end)
