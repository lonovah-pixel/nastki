-- Дозиметр: HUD, счётчик Гейгера и эффекты экрана. Доза, фон и защита приходят сетевыми переменными.
-- Цвета — из STALKER_THEME (меняются вместе с темой интерфейса).
local R=STALKER_RAD

-- Палитра на случай, если ядро сборки не загружено: HUD не должен пропасть вместе с ним.
local fallback={ok=Color(124,190,96),warn=Color(232,196,72),danger=Color(220,74,58),text=Color(226,226,214),muted=Color(136,144,138),
 panel=Color(25,28,28,230),line=Color(58,64,62),track=Color(10,12,12,240)}
local function col(token)
 local T=STALKER_THEME;local c=T and T.C and T.C[token]
 return c or fallback[token] or fallback.text
end
R.ThemeColor=col
-- Старое поле R.Colors.<токен> теперь отдаёт цвета темы.
R.Colors=setmetatable({},{__index=function(_,k) return col(k) end})
local function px(n) local T=STALKER_THEME;return T and T.Px and T.Px(n) or math.Round(n) end

-- Любой HUD берёт показания отсюда.
function R.GetDose(p) p=p or LocalPlayer();return IsValid(p) and p:GetNW2Float("stalker_dose",0) or 0 end
function R.GetRate(p) p=p or LocalPlayer();return IsValid(p) and p:GetNW2Float("stalker_rad_rate",0) or 0 end
function R.GetProtection(p) p=p or LocalPlayer();return IsValid(p) and p:GetNW2Float("stalker_rad_prot",0) or 0 end
function R.Color(dose)
 if dose>=R.Config.DamageThreshold then return col("danger") end
 return dose>=1 and col("warn") or col("ok")
end
-- Другой HUD (группировки) рисует радиацию сам и отмечает кадр, чтобы не было дублей.
function R.MarkExternalHUD() R.ExternalFrame=FrameNumber() end

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

-- Текст нижней строки дозиметра: фон и доля, которую снимает защита снаряжения.
function R.HUDLine(rate,protection)
 if rate<=0 then return "ФОН В НОРМЕ","muted" end
 local text=string.format("ФОН +%.2f/с",rate)
 if protection>0 then text=text..string.format(" · ЗАЩИТА %d%%",math.Round(protection*100)) end
 return text,"danger"
end

function R.DrawHUD()
 local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
 if (R.ExternalFrame or 0)>=FrameNumber()-2 then return end
 if STALKER_INV and IsValid(STALKER_INV.Frame) then return end
 local U=STALKER_STYLE
 local dose,rate,protection=R.GetDose(p),R.GetRate(p),R.GetProtection(p)
 local danger=dose>=R.Config.DamageThreshold
 local w,h=px(240),px(56);local x,y=px(24),ScrH()-px(150)-h
 local c=R.Color(dose)
 if U and U.Panel then U.Panel("stalker_rad",x,y,w,h,danger)
 else surface.SetDrawColor(col("panel"));surface.DrawRect(x,y,w,h);surface.SetDrawColor(col("line"));surface.DrawOutlinedRect(x,y,w,h,1) end
 draw.SimpleText("☢ РАДИАЦИЯ","STALKER.Head",x+px(10),y+px(7),c)
 draw.SimpleText(string.format("%.1f / 100",dose),"STALKER.Head",x+w-px(10),y+px(7),col("text"),TEXT_ALIGN_RIGHT)
 local bx,by,bw,bh=x+px(10),y+px(30),w-px(20),px(6)
 if U and U.Bar then U.Bar(bx,by,bw,bh,dose/100,c)
 else surface.SetDrawColor(col("track"));surface.DrawRect(bx,by,bw,bh);surface.SetDrawColor(c);surface.DrawRect(bx+1,by+1,(bw-2)*math.Clamp(dose/100,0,1),bh-2) end
 -- Отметка порога лучевой болезни.
 surface.SetDrawColor(col("danger"));surface.DrawRect(bx+bw*math.Clamp(R.Config.DamageThreshold/100,0,1),by-px(2),1,bh+px(4))
 local line,token=R.HUDLine(rate,protection)
 draw.SimpleText(line,"STALKER.Mono",bx,y+h-px(15),col(token))
end
hook.Add("HUDPaint","STALKER.RadiationHUD",function() R.DrawHUD() end)

-- Высокая доза: лёгкое обесцвечивание и пульсирующая виньетка.
hook.Add("RenderScreenspaceEffects","STALKER.RadiationFX",function()
 local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
 local dose=R.GetDose(p);if dose<R.Config.DamageThreshold then return end
 local k=math.Clamp((dose-R.Config.DamageThreshold)/math.max(1,100-R.Config.DamageThreshold),0,1)*(.75+.25*math.sin(CurTime()*3))
 DrawColorModify({["$pp_colour_addr"]=0,["$pp_colour_addg"]=.02*k,["$pp_colour_addb"]=0,["$pp_colour_brightness"]=-.03*k,["$pp_colour_contrast"]=1+.1*k,["$pp_colour_colour"]=1-.4*k,["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0})
end)
