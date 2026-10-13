-- Детектор артефактов: лучший детектор из рюкзака пищит, показывает сигнал, направление или метки.
local Z=STALKER_ZONE
local hudCvar=CreateClientConVar("stz_detector_hud","1",true,false,"Показывать панель детектора")
local volume=CreateClientConVar("stz_detector_volume","0.6",true,false,"Громкость писка детектора",0,1)
local names={det_echo="«ОТКЛИК»",det_bear="«МЕДВЕДЬ»",det_veles="«ВЕЛЕС»"}

local function refresh()
 Z.LocalDetector,Z.LocalDetectorID=Z.BestDetector(STALKER_INV and STALKER_INV.Inventory)
end
hook.Add("STALKER_INV_Updated","STALKER_ZONE.Detector",refresh)
timer.Create("STALKER_ZONE.DetectorRefresh",2,0,refresh)

local signals,nearest={},nil
timer.Create("STALKER_ZONE.DetectorScan",.15,0,function()
 signals,nearest={},nil
 local d=Z.LocalDetector;local lp=LocalPlayer()
 if not d or not IsValid(lp) or not lp:Alive() then return end
 local origin=lp:GetPos()
 for _,e in ipairs(ents.FindByClass("stalker_artifact")) do
  if IsValid(e) and not e:IsDormant() then
   local dist=origin:Distance(e:GetPos())
   if dist<=d.range then
    local row={ent=e,dist=dist};signals[#signals+1]=row
    if not nearest or dist<nearest.dist then nearest=row end
   end
  end
 end
end)

local nextBeep=0
hook.Add("Think","STALKER_ZONE.DetectorBeep",function()
 local d=Z.LocalDetector;if not d or not nearest or not IsValid(nearest.ent) then return end
 if CurTime()<nextBeep then return end
 local k=math.Clamp(nearest.dist/d.range,0,1)
 nextBeep=CurTime()+Lerp(k,.09,1.3)
 local lp=LocalPlayer();if IsValid(lp) then lp:EmitSound("buttons/blip1.wav",55,math.floor(150-k*60),math.Clamp(volume:GetFloat(),0,1)) end
end)

local scale=1
local function px(n) return math.Round(n*scale) end
local function fonts()
 scale=math.Clamp(ScrH()/900,.85,1.8)
 surface.CreateFont("STZ.Det",{font="Tahoma",size=px(13),weight=700,extended=true})
 surface.CreateFont("STZ.DetSmall",{font="Consolas",size=px(11),weight=500,extended=true})
end
fonts();hook.Add("OnScreenSizeChanged","STALKER_ZONE.DetectorFonts",fonts)

local function panel(x,y,w,h,active)
 if STALKER_STYLE and STALKER_STYLE.Panel then STALKER_STYLE.Panel("stalker_inv",x,y,w,h,active)
 else surface.SetDrawColor(25,27,22,230);surface.DrawRect(x,y,w,h);surface.SetDrawColor(91,91,71);surface.DrawOutlinedRect(x,y,w,h,1) end
end
local text,muted,accent,green=Color(217,207,176),Color(138,143,115),Color(200,169,81),Color(112,158,91)

local function menuOpen()
 return (STALKER_INV and IsValid(STALKER_INV.Frame)) or (STALKER_NPC and IsValid(STALKER_NPC.Window))
end

hook.Add("HUDPaint","STALKER_ZONE.Detector",function()
 local d=Z.LocalDetector;local lp=LocalPlayer()
 if not d or not hudCvar:GetBool() or not IsValid(lp) or not lp:Alive() or menuOpen() then return end
 if not nearest or not IsValid(nearest.ent) then return end
 local w,h=px(230),px(66);local x,y=ScrW()/2-w/2,ScrH()-h-px(30)
 local strength=1-math.Clamp(nearest.dist/d.range,0,1)
 panel(x,y,w,h,strength>.75)
 draw.SimpleText("ДЕТЕКТОР "..(names[Z.LocalDetectorID] or ""),"STZ.Det",x+px(10),y+px(7),accent)
 draw.SimpleText(#signals>1 and ("СИГНАЛОВ: "..#signals) or "СИГНАЛ","STZ.DetSmall",x+w-px(10),y+px(9),muted,TEXT_ALIGN_RIGHT)
 local bx,by,bw,bh=x+px(10),y+px(30),w-px(20)-(d.mode~="signal" and px(36) or 0),px(8)
 if STALKER_STYLE and STALKER_STYLE.Bar then STALKER_STYLE.Bar(bx,by,bw,bh,strength,green)
 else surface.SetDrawColor(9,12,8);surface.DrawRect(bx,by,bw,bh);surface.SetDrawColor(green);surface.DrawRect(bx,by,bw*strength,bh) end
 local word=strength>.85 and "АРТЕФАКТ РЯДОМ" or strength>.5 and "СИЛЬНЫЙ" or strength>.2 and "СРЕДНИЙ" or "СЛАБЫЙ"
 draw.SimpleText(word..(d.mode=="exact" and string.format("  %.0f м",nearest.dist*.019) or ""),"STZ.DetSmall",bx,y+px(46),text)
 if d.mode=="arrow" or d.mode=="exact" then
  -- Стрелка: угол на артефакт относительно направления взгляда.
  local dir=nearest.ent:GetPos()-lp:GetPos()
  local yaw=math.rad(math.NormalizeAngle(dir:Angle().y-lp:EyeAngles().y))
  local cx,cy,r=x+w-px(24),y+px(38),px(13)
  local tip=Vector(cx-math.sin(yaw)*r,cy-math.cos(yaw)*r,0)
  local left=Vector(cx-math.sin(yaw+2.5)*r*.7,cy-math.cos(yaw+2.5)*r*.7,0)
  local right=Vector(cx-math.sin(yaw-2.5)*r*.7,cy-math.cos(yaw-2.5)*r*.7,0)
  draw.NoTexture();surface.SetDrawColor(accent)
  surface.DrawPoly({{x=tip.x,y=tip.y},{x=right.x,y=right.y},{x=left.x,y=left.y}})
 end
 if d.mode=="exact" then
  for _,row in ipairs(signals) do
   if IsValid(row.ent) then
    local s=(row.ent:GetPos()+Vector(0,0,14)):ToScreen()
    if s.visible then
     surface.SetDrawColor(green);surface.DrawOutlinedRect(s.x-px(6),s.y-px(6),px(12),px(12),1)
     draw.SimpleText(string.format("%.0f м",row.dist*.019),"STZ.DetSmall",s.x,s.y+px(8),green,TEXT_ALIGN_CENTER)
    end
   end
  end
 end
end)
