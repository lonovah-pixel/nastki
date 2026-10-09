local F=STFW
function F.AccrueSupply(w)
 local online={};for _,p in ipairs(player.GetHumans()) do local d=F.Load(p)
  if d and d.joined and p:Alive() then online[d.faction]=true end
 end
 local income={}
 for _,pt in pairs(w.points) do
  if online[pt.owner] and not pt.contested and (pt.progress or 0)==0 then income[pt.owner]=(income[pt.owner] or 0)+F.Config.SupplyPerTerritory end
 end
 local changed=false;w.progression=w.progression or {}
 for id,amount in pairs(income) do
  local d=w.progression[id] or {credits=0,levels={}};w.progression[id]=d
  local nextValue=math.min(F.Config.SupplyLimit,(d.credits or 0)+amount)
  if nextValue~=(d.credits or 0) then d.credits=nextValue;changed=true end
 end
 return changed
end
function F.BuyUpgrade(p,a)
 if not F.IsLeader(p) then return false,"unauthorized" end
 local cfg=F.Upgrades[a.upgrade];if not cfg then return false,"denied" end
 local id=F.Load(p).faction;local level=F.UpgradeLevel(F.World,id,a.upgrade)
 if a.level~=level then return false,"stale" end
 local price=cfg.costs[level+1];if not price then return false,"upgrade_max" end
 local w=table.Copy(F.World);w.progression=w.progression or {}
 local d=w.progression[id] or {credits=0,levels={}};w.progression[id]=d
 if (d.credits or 0)<price then return false,"supply_low" end
 d.credits=d.credits-price;d.levels=d.levels or {};d.levels[a.upgrade]=level+1
 if not F.Commit(w,{},"upgrade "..p:SteamID64().." "..id.." "..a.upgrade) then return false,"storage" end
 return true
end
