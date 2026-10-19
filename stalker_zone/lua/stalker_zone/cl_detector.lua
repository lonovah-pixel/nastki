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

-- Оформление — тема STALKER_THEME (цвета, шрифты и масштаб ядра).
local function px(n) local T=STALKER_THEME;return T and T.Px and T.Px(n) or math.Round(n) end
local function col(token) local T=STALKER_THEME;return T and T.C and T.C[token] or color_white end

local function menuOpen()
 return (STALKER_INV and IsValid(STALKER_INV.Frame)) or (STALKER_NPC and IsValid(STALKER_NPC.Window))
  or (STALKER_PDA and STALKER_PDA.IsOpen and STALKER_PDA.IsOpen())
end

hook.Add("HUDPaint","STALKER_ZONE.Detector",function()
 local d=Z.LocalDetector;local lp=LocalPlayer();local U=STALKER_STYLE
 if not d or not hudCvar:GetBool() or not IsValid(lp) or not lp:Alive() or menuOpen() or not U or not U.Panel then return end
 if not nearest or not IsValid(nearest.ent) then return end
 local w,h=px(240),px(68);local x,y=ScrW()/2-w/2,ScrH()-h-px(30)
 local strength=1-math.Clamp(nearest.dist/math.max(1,d.range),0,1)
 U.Panel("",x,y,w,h,strength>.75)
 U.Text("ДЕТЕКТОР "..(names[Z.LocalDetectorID] or ""),"STALKER.Head",x+px(10),y+px(6),"accent")
 U.Text(#signals>1 and ("СИГНАЛОВ: "..#signals) or "СИГНАЛ","STALKER.Mono",x+w-px(10),y+px(9),"muted",TEXT_ALIGN_RIGHT)
 local bx,by,bw,bh=x+px(10),y+px(31),w-px(20)-(d.mode~="signal" and px(36) or 0),px(8)
 U.Bar(bx,by,bw,bh,strength,col(strength>.85 and "ok" or strength>.5 and "accent2" or "accent"))
 local word=strength>.85 and "АРТЕФАКТ РЯДОМ" or strength>.5 and "СИЛЬНЫЙ" or strength>.2 and "СРЕДНИЙ" or "СЛАБЫЙ"
 U.Text(word..(d.mode=="exact" and string.format("  %.0f м",nearest.dist*.019) or ""),"STALKER.Mono",bx,y+px(46),strength>.85 and "ok" or "text")
 if d.mode=="arrow" or d.mode=="exact" then
  -- Стрелка: угол на артефакт относительно направления взгляда.
  local dir=nearest.ent:GetPos()-lp:GetPos()
  local yaw=math.rad(math.NormalizeAngle(dir:Angle().y-lp:EyeAngles().y))
  local cx,cy,r=x+w-px(24),y+px(39),px(13)
  local tip={x=cx-math.sin(yaw)*r,y=cy-math.cos(yaw)*r}
  local left={x=cx-math.sin(yaw+2.5)*r*.7,y=cy-math.cos(yaw+2.5)*r*.7}
  local right={x=cx-math.sin(yaw-2.5)*r*.7,y=cy-math.cos(yaw-2.5)*r*.7}
  draw.NoTexture();surface.SetDrawColor(col("accent"))
  surface.DrawPoly({tip,right,left})
 end
 if d.mode=="exact" then
  local ok=col("ok")
  for _,row in ipairs(signals) do
   if IsValid(row.ent) then
    local s=(row.ent:GetPos()+Vector(0,0,14)):ToScreen()
    if s.visible then
     surface.SetDrawColor(ok);surface.DrawOutlinedRect(s.x-px(6),s.y-px(6),px(12),px(12),1)
     draw.SimpleText(string.format("%.0f м",row.dist*.019),"STALKER.Mono",s.x,s.y+px(8),ok,TEXT_ALIGN_CENTER)
    end
   end
  end
 end
end)
