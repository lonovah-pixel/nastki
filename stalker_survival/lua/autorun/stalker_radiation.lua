if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
if SERVER then AddCSLuaFile() end
STALKER_RAD=STALKER_RAD or {}
local R=STALKER_RAD
R.Config={Decay=0.04,DamageThreshold=30,MaxDamage=8,Antirad=40,ZonesLimit=128}
-- zones: сохранённые сферические источники; доза 0..100, интенсивность — доза/сек.
if SERVER then
 local path="stalker_radiation/"..game.GetMap()..".json"
 file.CreateDir("stalker_radiation")
 local raw=file.Read(path,"DATA")
 R.Zones=raw and util.JSONToTable(raw) or {}
 R.Ready=type(R.Zones)=="table"
 if not R.Ready then R.Zones={};ErrorNoHalt("[Radiation] Corrupt zone file; editing blocked\n") end
 local function save(zones)
  local payload=util.TableToJSON(zones);if not payload then return false end
  file.Write(path..".pending.json",payload)
  if file.Read(path..".pending.json","DATA")~=payload then return false end
  file.Write(path,payload);if file.Read(path,"DATA")~=payload then return false end
  file.Delete(path..".pending.json");R.Zones=zones;return true
 end
 concommand.Add("stalker_rad_add",function(p,_,args)
  if not IsValid(p) or not p:IsSuperAdmin() or not R.Ready then return end
  local radius,rate=tonumber(args[1]) or 300,tonumber(args[2]) or 2
  if radius~=radius or rate~=rate or radius<32 or radius>5000 or rate<=0 or rate>100 or #R.Zones>=R.Config.ZonesLimit then return end
  local tr=p:GetEyeTrace();if not tr.Hit or tr.HitSky or p:GetPos():DistToSqr(tr.HitPos)>4096^2 then return end
  local zones=table.Copy(R.Zones);zones[#zones+1]={pos={x=tr.HitPos.x,y=tr.HitPos.y,z=tr.HitPos.z},radius=radius,rate=rate}
  p:ChatPrint(save(zones) and ("Радиационная зона добавлена: #"..#zones) or "Ошибка сохранения зоны")
 end)
 concommand.Add("stalker_rad_remove",function(p,_,args)
  if IsValid(p) and not p:IsSuperAdmin() then return end
  local id=tonumber(args[1]);if not R.Ready or not id or id%1~=0 or not R.Zones[id] then return end
  local zones=table.Copy(R.Zones);table.remove(zones,id);print(save(zones) and "[Radiation] Zone removed" or "[Radiation] Save failed")
 end)
 concommand.Add("stalker_rad_list",function(p)
  if IsValid(p) and not p:IsSuperAdmin() then return end
  for id,z in ipairs(R.Zones) do local msg=id..": "..util.TableToJSON(z);if IsValid(p) then p:PrintMessage(HUD_PRINTCONSOLE,msg) else print(msg) end end
 end)
 function R.Step(dose,rate,protection)
  return math.Clamp(dose+(rate>0 and rate*(1-math.Clamp(protection,0,0.95)) or -R.Config.Decay),0,100)
 end
 timer.Create("STALKER.Radiation",1,0,function()
  local S=STALKER_INV;if not S then return end
  for _,p in ipairs(player.GetHumans()) do local inv=p.StalkerInventory
   if p:Alive() and inv and not p.StalkerLoadError then
    local rate,protection=0,0
    for _,zone in ipairs(R.Zones) do
     if type(zone)=="table" and type(zone.pos)=="table" and tonumber(zone.radius) and tonumber(zone.rate) then
      local pos=Vector(tonumber(zone.pos.x) or 0,tonumber(zone.pos.y) or 0,tonumber(zone.pos.z) or 0)
      if p:GetPos():DistToSqr(pos)<=zone.radius^2 then rate=rate+zone.rate end
     end
    end
    if STFW and STFW.World then for _,point in pairs(STFW.World.points) do
     local pos=Vector(point.pos.x,point.pos.y,point.pos.z);local here=p:GetPos()
     if math.abs(here.z-pos.z)<=(point.height or 128) and ((here.x-pos.x)^2+(here.y-pos.y)^2)<=(point.radius or 100)^2 then rate=rate+(point.radiation or 0)/10 end
    end end
    for _,item in pairs(inv.equipment) do local def=S.Items[item.id]
     if def and item.durability>0 then rate=rate+(def.stats.radiation or 0);protection=protection+(def.stats.radiationProtection or 0) end
    end
    inv.dose=R.Step(inv.dose or 0,rate,protection)
    p:SetNW2Float("stalker_dose",inv.dose);p:SetNW2Float("stalker_rad_rate",rate)
    if inv.dose>=R.Config.DamageThreshold then
     local dmg=DamageInfo();dmg:SetDamageType(DMG_RADIATION);dmg:SetDamage(math.min(R.Config.MaxDamage,1+(inv.dose-R.Config.DamageThreshold)/10));dmg:SetAttacker(game.GetWorld());dmg:SetInflictor(game.GetWorld());p:TakeDamageInfo(dmg)
    end
   end
  end
 end)
 hook.Add("PlayerDeath","STALKER.RadiationDeath",function(p)
  if p.StalkerInventory then p.StalkerInventory.dose=0;p:SetNW2Float("stalker_dose",0);p:SetNW2Float("stalker_rad_rate",0);STALKER_INV.SaveInventory(p) end
 end)
else
 local nextClick=0
 hook.Add("HUDPaint","STALKER.RadiationHUD",function()
  local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
  local dose,rate=p:GetNW2Float("stalker_dose",0),p:GetNW2Float("stalker_rad_rate",0)
  if dose>0 or rate>0 then
   draw.SimpleText(string.format("РАДИАЦИЯ: %.1f / 100   ФОН: %.2f",dose,rate),"DermaDefaultBold",ScrW()/2,55,Color(245,180,60),TEXT_ALIGN_CENTER)
   if rate>0 and CurTime()>nextClick then surface.PlaySound("player/geiger1.wav");nextClick=CurTime()+math.Clamp(1/rate,0.15,2) end
  end
 end)
end
