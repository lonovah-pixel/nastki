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
 -- Доза/фон приходят сетевыми переменными; любой HUD берёт их отсюда.
 function R.GetDose(p) p=p or LocalPlayer();return IsValid(p) and p:GetNW2Float("stalker_dose",0) or 0 end
 function R.GetRate(p) p=p or LocalPlayer();return IsValid(p) and p:GetNW2Float("stalker_rad_rate",0) or 0 end
 R.Colors={ok=Color(112,158,91),warn=Color(214,170,64),danger=Color(190,70,50),text=Color(217,207,176),muted=Color(138,143,115)}
 function R.Color(dose)
  if dose>=R.Config.DamageThreshold then return R.Colors.danger end
  return dose>=1 and R.Colors.warn or R.Colors.ok
 end
 -- Другой HUD (группировки) рисует радиацию сам и отмечает кадр, чтобы не было дублей.
 function R.MarkExternalHUD() R.ExternalFrame=FrameNumber() end
 local scale=1
 local function fonts()
  scale=math.Clamp(ScrH()/900,.85,1.8)
  surface.CreateFont("STRAD.Title",{font="Tahoma",size=math.Round(14*scale),weight=700,extended=true})
  surface.CreateFont("STRAD.Small",{font="Consolas",size=math.Round(11*scale),weight=500,extended=true})
 end
 fonts();hook.Add("OnScreenSizeChanged","STALKER.RadiationFonts",fonts)
 local function px(n) return math.Round(n*scale) end
 local nextClick=0
 local sounds={"player/geiger1.wav","player/geiger2.wav","player/geiger3.wav"}
 -- Счётчик Гейгера щёлкает независимо от отрисовки HUD (камера, скрытый HUD, открытое меню).
 hook.Add("Think","STALKER.RadiationGeiger",function()
  local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
  local rate=R.GetRate(p)
  if rate>0 and CurTime()>nextClick then
   surface.PlaySound(sounds[math.Clamp(math.ceil(rate),1,3)])
   nextClick=CurTime()+math.Clamp(1/rate,0.08,2)*math.Rand(.6,1.4)
  end
 end)
 hook.Add("HUDPaint","STALKER.RadiationHUD",function()
  local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
  if (R.ExternalFrame or 0)>=FrameNumber()-2 then return end
  if STALKER_INV and IsValid(STALKER_INV.Frame) then return end
  local dose,rate=R.GetDose(p),R.GetRate(p)
  local w,h=px(232),px(52);local x,y=px(24),ScrH()-px(150)-h
  local col=R.Color(dose)
  if STALKER_STYLE and STALKER_STYLE.Panel then STALKER_STYLE.Panel("stalker_inv",x,y,w,h,dose>=R.Config.DamageThreshold)
  else surface.SetDrawColor(25,27,22,230);surface.DrawRect(x,y,w,h);surface.SetDrawColor(91,91,71);surface.DrawOutlinedRect(x,y,w,h,1) end
  draw.SimpleText("☢ РАДИАЦИЯ","STRAD.Title",x+px(10),y+px(7),col)
  draw.SimpleText(string.format("%.1f / 100",dose),"STRAD.Title",x+w-px(10),y+px(7),R.Colors.text,TEXT_ALIGN_RIGHT)
  local bx,by,bw,bh=x+px(10),y+px(29),w-px(20),px(6)
  surface.SetDrawColor(9,12,8,240);surface.DrawRect(bx,by,bw,bh)
  surface.SetDrawColor(col);surface.DrawRect(bx+1,by+1,(bw-2)*math.Clamp(dose/100,0,1),bh-2)
  surface.SetDrawColor(R.Colors.danger);surface.DrawRect(bx+bw*R.Config.DamageThreshold/100,by-px(2),1,bh+px(4))
  draw.SimpleText(rate>0 and string.format("ФОН +%.2f/с",rate) or "ФОН В НОРМЕ","STRAD.Small",bx,y+h-px(14),rate>0 and R.Colors.danger or R.Colors.muted)
 end)
 -- Высокая доза: лёгкое обесцвечивание и пульсирующая виньетка.
 hook.Add("RenderScreenspaceEffects","STALKER.RadiationFX",function()
  local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
  local dose=R.GetDose(p);if dose<R.Config.DamageThreshold then return end
  local k=math.Clamp((dose-R.Config.DamageThreshold)/(100-R.Config.DamageThreshold),0,1)*(.75+.25*math.sin(CurTime()*3))
  DrawColorModify({["$pp_colour_addr"]=0,["$pp_colour_addg"]=.02*k,["$pp_colour_addb"]=0,["$pp_colour_brightness"]=-.03*k,["$pp_colour_contrast"]=1+.1*k,["$pp_colour_colour"]=1-.4*k,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0})
 end)
end
