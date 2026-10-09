local F=STFW
-- Проверяем пол и полный стоячий hull. Если база занята, сохраняем штатный spawn.
function F.FindBasePosition(p,point)
 if point.contested or (point.progress or 0)>0 then return end
 local center=Vector(point.pos.x,point.pos.y,point.pos.z)
 local radius=math.min(point.radius-24,192)
 local offsets={Vector(0,0,0)}
 for _,r in ipairs({radius*.5,radius}) do
  for i=0,7 do offsets[#offsets+1]=Vector(math.cos(i*math.pi/4)*r,math.sin(i*math.pi/4)*r,0) end
 end
 for _,offset in ipairs(offsets) do
  local start=center+offset+Vector(0,0,48)
  local floor=util.TraceLine({start=start,endpos=center+offset-Vector(0,0,math.min(point.height,256)),filter=p,mask=MASK_PLAYERSOLID})
  local living=IsValid(floor.Entity) and (floor.Entity:IsPlayer() or floor.Entity:IsNPC())
  if floor.Hit and not floor.StartSolid and not floor.HitSky and not living and floor.HitNormal.z>=.65 then
   local pos=floor.HitPos+Vector(0,0,2)
   local tr=util.TraceHull({start=pos,endpos=pos,mins=Vector(-16,-16,0),maxs=Vector(16,16,72),filter=p,mask=MASK_PLAYERSOLID})
   if not tr.Hit and not tr.StartSolid and util.IsInWorld(pos) and math.abs(pos.z-center.z)<=point.height then return pos end
  end
 end
end
function F.QueueBaseSpawn(p)
 p.StfwSpawnSerial=(p.StfwSpawnSerial or 0)+1;local serial=p.StfwSpawnSerial
 if not F.Config.EnableBaseSpawn then return end
 timer.Simple(.1,function()
  if not IsValid(p) or not p:Alive() or serial~=p.StfwSpawnSerial or not F.Config.EnableBaseSpawn then return end
  if p.isArrested and p:isArrested() then return end
  local d=F.Load(p);if not d or not d.joined or hook.Run("STFW_CanBaseSpawn",p,d.faction)==false then return end
  if F.Config.DarkRP.Mode=="jobs" and F.JobFaction(p:Team())~=d.faction then return end
  local points={};for id,point in pairs(F.World.points) do
   if point.base and point.owner==d.faction then points[#points+1]={id=id,point=point} end
  end
  table.sort(points,function(a,b) return a.id<b.id end)
  for _,entry in ipairs(points) do
   local pos=F.FindBasePosition(p,entry.point)
   if pos then
    p:SetPos(pos);p.StfwProtected=CurTime()+F.Config.SpawnProtection
    local armor=F.UpgradeLevel(F.World,d.faction,"infirmary")*5
    if p:Armor()<armor then p:SetArmor(armor) end
    return
   end
  end
  if #points>0 then F.Notify(p,"base_blocked") end
 end)
end
