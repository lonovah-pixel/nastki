
local F=STFW
local U=STALKER_STYLE
local hud=CreateClientConVar("stfw_hud","1",true,false)
local abilitiesHud=CreateClientConVar("stfw_abilities_hud","1",true,false,"Полоса способностей командования: 1 — показывать, 0 — скрыть")
local notices,radar={},{};local nearby=false
local scale=1
local function fonts()
 scale=math.Clamp(ScrH()/900,.85,1.8)
 surface.CreateFont("STFW.Hud",{font="Tahoma",size=math.Round(14*scale),weight=600,extended=true})
 surface.CreateFont("STFW.HudSmall",{font="Consolas",size=math.Round(11*scale),weight=500,extended=true})
 surface.CreateFont("STFW.HudTitle",{font="Trebuchet MS",size=math.Round(18*scale),weight=700,extended=true})
end
fonts();hook.Add("OnScreenSizeChanged","STFW.HudFonts",fonts)
local function px(n) return math.Round(n*scale) end
-- fit зовут из HUDPaint каждый кадр: utf8.sub GMod — O(n²) на вызов, а перебор длин с конца — O(n³), десятки мс
-- на длинное имя точки. U.Fit ядра режет за один проход по символам и O(log n) измерений.
local function fit(text,font,width)
 if U and U.Fit then return U.Fit(text,font,width) end
 surface.SetFont(font);if surface.GetTextSize(text)<=width then return text end
 local len=utf8.len(text) or 0
 for i=len,1,-1 do local s=utf8.sub(text,1,i).."…";if surface.GetTextSize(s)<=width then return s end end
 return ""
end
function F.Emblem(id,x,y,size)
 local cfg=F.Factions[id];local path=cfg and cfg.emblem~="" and cfg.emblem or "stalker_factions/emblems/"..tostring(id)..".png"
 U.Texture(path,x,y,size,size)
end
net.Receive("stfw.notice",function()
 notices[#notices+1]={text=net.ReadString(),time=CurTime()};if #notices>4 then table.remove(notices,1) end
 surface.PlaySound("buttons/button17.wav")
end)
timer.Create("STFW.Radar",.25,0,function()
 radar={};nearby=false;local p=LocalPlayer();if not IsValid(p) or not F.State then return end
 for _,other in ipairs(player.GetAll()) do
  if other~=p and not other:IsDormant() and other:Alive() and other:GetNW2Bool("stfw_joined") and p:GetPos():DistToSqr(other:GetPos())<F.Config.RadarRange^2 then
   local rel=F.Relation(F.State.me.faction,other:GetNW2String("stfw_faction","loner"),F.State)
   local tr=util.TraceLine({start=p:EyePos(),endpos=other:EyePos(),filter={p,other},mask=MASK_VISIBLE})
   if rel=="allied" or not tr.Hit then radar[#radar+1]={entity=other,relation=rel};if rel=="war" or rel=="enemy" then nearby=true end end
  end
 end
end)
local function menuOpen()
 return (IsValid(F.Frame) and F.Frame:IsVisible()) or IsValid(F.CommandFrame) or (STALKER_INV and IsValid(STALKER_INV.Frame)) or (STALKER_NPC and IsValid(STALKER_NPC.Window))
end
hook.Add("HUDShouldDraw","STFW.Vitals",function(name)
 if hud:GetBool() and F.State and not menuOpen() then
  if name=="CHudHealth" or name=="CHudBattery" then return false end
  local gun=IsValid(LocalPlayer()) and LocalPlayer():GetActiveWeapon()
  if IsValid(gun) and gun:Clip1()>=0 and (name=="CHudAmmo" or name=="CHudSecondaryAmmo") then return false end
 end
end)
hook.Add("HUDPaint","STFW.HUD",function()
 if not hud:GetBool() or not F.State or menuOpen() then return end
 local p=LocalPlayer();if not IsValid(p) then return end
 local state=F.State;local me=state.me;local _,rank=F.Rank(me.xp)
 local inv=STALKER_INV and STALKER_INV.Inventory
 -- Мини-радар: вращение по направлению взгляда, стены скрывают врагов.
 local rx,ry,rs=px(22),px(26),px(174)
 F.Box(rx,ry,rs,rs);U.Texture("stalker_factions/radar.png",rx+px(5),ry+px(5),rs-px(10),rs-px(10))
 local cx,cy=rx+rs/2,ry+rs/2
 local function mark(pos,color,size)
  local vec=pos-p:GetPos();local angle=math.rad(p:EyeAngles().y)
  local forward=vec.x*math.cos(angle)+vec.y*math.sin(angle);local right=vec.x*math.sin(angle)-vec.y*math.cos(angle)
  local factor=(rs/2-px(13))/F.Config.RadarRange
  local mx,my=math.Clamp(right*factor,-rs/2+px(12),rs/2-px(12)),math.Clamp(-forward*factor,-rs/2+px(12),rs/2-px(12))
  surface.SetDrawColor(color);surface.DrawRect(cx+mx-size/2,cy+my-size/2,size,size)
 end
 for _,pt in pairs(state.points) do local rel=pt.owner~="" and F.Relation(me.faction,pt.owner,state) or "neutral";mark(Vector(pt.pos.x,pt.pos.y,pt.pos.z),rel=="allied" and F.C.green or F.C.accent,px(4)) end
 for _,m in ipairs(radar) do if IsValid(m.entity) then mark(m.entity:GetPos(),m.relation=="allied" and F.C.green or F.C.red,px(5)) end end
 draw.SimpleText("▲","STFW.HudTitle",cx,cy,F.C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 draw.SimpleText(string.format("%03d°",math.floor(p:EyeAngles().y%360)),"STFW.HudSmall",rx+rs-px(7),ry+px(8),F.C.accent,TEXT_ALIGN_RIGHT)
 F.Box(rx,ry+rs+px(5),rs,px(49));F.Emblem(me.faction,rx+px(5),ry+rs+px(9),px(39))
 draw.SimpleText(fit(F.Name(me.faction),"STFW.Hud",rs-px(51)),"STFW.Hud",rx+px(49),ry+rs+px(13),F.C.text)
 draw.SimpleText(F.Config.Language=="ru" and rank[2] or rank[3],"STFW.HudSmall",rx+px(49),ry+rs+px(32),F.C.muted)
 -- Компактные жизненные показатели справа снизу, как на старом КПК.
 local width,height=px(302),px(153);local vx,vy=ScrW()-width-px(24),ScrH()-height-px(28)
 F.Box(vx,vy,width,height);draw.SimpleText("СТАТУС / "..(me.joined and "ONLINE" or "FREE"),"STFW.HudSmall",vx+px(12),vy+px(10),F.C.muted)
 for i,v in ipairs({{F.L("health"),p:Health(),math.max(1,p:GetMaxHealth()),F.C.green},{F.L("armor"),p:Armor(),100,F.C.accent}}) do
  local y=vy+px(30+(i-1)*26);draw.SimpleText(v[1],"STFW.HudSmall",vx+px(12),y,F.C.text)
  U.Bar(vx+px(99),y+px(3),px(151),px(8),v[2]/v[3],v[4]);draw.SimpleText(tostring(math.max(0,v[2])),"STFW.HudSmall",vx+width-px(10),y,F.C.text,TEXT_ALIGN_RIGHT)
 end
 -- Радиация: накопленная доза и текущий фон из системы радиации (а не сумма артефактов).
 local dose,rate=p:GetNW2Float("stalker_dose",0),p:GetNW2Float("stalker_rad_rate",0)
 local R=STALKER_RAD;local danger=R and R.Config and R.Config.DamageThreshold or 30
 local radcol=R and R.Color and R.Color(dose) or (dose>=danger and F.C.red or F.C.muted)
 draw.SimpleText(string.format("☢ %.1f",dose),"STFW.Hud",vx+px(12),vy+px(87),radcol)
 draw.SimpleText(rate>0 and string.format("+%.2f/с",rate) or "фон 0","STFW.HudSmall",vx+px(74),vy+px(89),rate>0 and F.C.red or F.C.muted)
 U.Bar(vx+px(140),vy+px(92),px(70),px(6),dose/100,radcol)
 draw.SimpleText(string.format("REP %+d",me.rep[me.faction] or 0),"STFW.Hud",vx+width-px(10),vy+px(87),F.C.muted,TEXT_ALIGN_RIGHT)
 if R and R.MarkExternalHUD then R.MarkExternalHUD() end
 if inv then
  U.Bar(vx+px(12),vy+px(116),px(87),px(4),(inv.hunger or 100)/100,F.C.green)
  U.Bar(vx+px(109),vy+px(116),px(87),px(4),(inv.thirst or 100)/100,F.C.info)
  draw.SimpleText(string.format("%.1f kg",STALKER_INV.Weight(inv)),"STFW.HudSmall",vx+width-px(10),vy+px(108),F.C.accent,TEXT_ALIGN_RIGHT)
 end
 draw.SimpleText("F6  /  КПК ГРУППИРОВКИ","STFW.HudSmall",vx+px(12),vy+height-px(17),F.C.muted)
 local gun=p:GetActiveWeapon()
 if IsValid(gun) and gun:Clip1()>=0 then
  local ax,ay=vx-px(115),vy+px(71);F.Box(ax,ay,px(104),px(82))
  draw.SimpleText("БОЕЗАПАС","STFW.HudSmall",ax+px(9),ay+px(8),F.C.muted)
  draw.SimpleText(string.format("%02d",math.max(0,gun:Clip1())),"STFW.HudTitle",ax+px(9),ay+px(29),gun:Clip1()==0 and F.C.red or F.C.accent)
  draw.SimpleText("/ "..p:GetAmmoCount(gun:GetPrimaryAmmoType()),"STFW.HudSmall",ax+px(46),ay+px(34),F.C.text)
  local secondary=gun:GetSecondaryAmmoType();if secondary>=0 then draw.SimpleText("Ⅱ "..p:GetAmmoCount(secondary),"STFW.HudSmall",ax+px(9),ay+px(62),F.C.muted) end
 end
 local zone
 for _,pt in SortedPairs(state.points) do local dx,dy=p:GetPos().x-pt.pos.x,p:GetPos().y-pt.pos.y
  if dx*dx+dy*dy<pt.radius^2 and math.abs(p:GetPos().z-pt.pos.z)<pt.height then zone=pt;break end
 end
 if zone then
  local zw=px(370);local zx,zy=ScrW()/2-zw/2,px(26)
  F.Box(zx,zy,zw,px(94));draw.SimpleText(fit(zone.name,"STFW.HudTitle",zw-px(22)),"STFW.HudTitle",ScrW()/2,zy+px(9),F.C.accent,TEXT_ALIGN_CENTER)
  draw.SimpleText("☢ "..zone.radiation.." / "..F.L("anomaly").." "..zone.anomaly.." / "..F.Name(zone.owner),"STFW.HudSmall",ScrW()/2,zy+px(34),F.C.muted,TEXT_ALIGN_CENTER)
  local status=F.TerritoryStatus(zone,me.faction,me.joined,state)
  draw.SimpleText(fit(F.L(status),"STFW.HudSmall",zw-px(24)),"STFW.HudSmall",zx+px(12),zy+px(71),status=="territory_threat" and F.C.red or F.C.text)
  local armed=zone.armed and F.Factions[zone.armed]
  U.Bar(zx+px(12),zy+px(55),zw-px(24),px(4),zone.progress or 0,zone.contested and F.C.red or (armed and Color(armed.color[1],armed.color[2],armed.color[3])) or F.C.green)
  if zone.armed then draw.SimpleText("ЗАХВАТ: "..F.Name(zone.armed),"STFW.HudSmall",zx+zw-px(12),zy+px(71),F.C.red,TEXT_ALIGN_RIGHT) end
 end
 if nearby then draw.SimpleText(F.Config.Language=="ru" and "ВРАГ РЯДОМ" or "ENEMY NEARBY","STFW.Hud",rx,ry+rs+px(66),F.C.red) end
 for i=#notices,1,-1 do if CurTime()-notices[i].time>7 then table.remove(notices,i) end end
 for i,n in ipairs(notices) do
  local nw=px(355);local nx,ny=ScrW()-nw-px(24),px(110)+(i-1)*px(68)
  F.Box(nx,ny,nw,px(60),true);draw.SimpleText("КПК / СООБЩЕНИЕ","STFW.HudSmall",nx+px(10),ny+px(8),F.C.accent)
  local lines=STALKER_INV and STALKER_INV.Wrap(n.text,"STFW.Hud",nw-px(20)) or {fit(n.text,"STFW.Hud",nw-px(20))}
  for j=1,math.min(2,#lines) do draw.SimpleText(lines[j],"STFW.Hud",nx+px(10),ny+px(24+(j-1)*16),F.C.text) end
 end
end)
-- Полоса способностей командования (лидер и офицеры): перезарядка по снимку сервера.
hook.Add("HUDPaint","STFW.Abilities",function()
 if not hud:GetBool() or not abilitiesHud:GetBool() or menuOpen() then return end
 local p=LocalPlayer();if not IsValid(p) or not p:Alive() then return end
 local warcry=p:GetNW2Float("stfw_warcry",0)-CurTime()
 if warcry>0 then draw.SimpleText(string.format("БОЕВОЙ КЛИЧ: −%d%% урона · %d с",math.floor((F.Abilities.warcry.reduction or .2)*100),math.ceil(warcry)),"STFW.Hud",ScrW()/2,ScrH()-px(150),F.C.green,TEXT_ALIGN_CENTER) end
 local cmd=F.State and F.State.command;if not cmd then return end
 local list=F.AbilityOrder;local size,gap=px(64),px(6)
 local total=#list*size+(#list-1)*gap;local x0,y=ScrW()/2-total/2,ScrH()-size-px(70)
 local elapsed=CurTime()-(F.StateAt or CurTime())
 for i,id in ipairs(list) do
  local a=F.Abilities[id];local x=x0+(i-1)*(size+gap)
  local allowed=cmd.role=="leader" or a.minRank~="leader"
  local left=math.max(0,((cmd.cooldowns or {})[id] or 0)-elapsed)
  local ready=allowed and left<=0 and (cmd.credits or 0)>=a.cost
  F.Box(x,y,size,size,ready)
  draw.SimpleText(fit(a.name,"STFW.HudSmall",size-px(6)),"STFW.HudSmall",x+size/2,y+px(6),allowed and F.C.text or F.C.muted,TEXT_ALIGN_CENTER)
  if left>0 then
   U.Bar(x+px(4),y+size-px(10),size-px(8),px(4),1-left/math.max(1,a.cooldown),F.C.warn)
   draw.SimpleText(left>=60 and (math.ceil(left/60).." мин") or (math.ceil(left).." с"),"STFW.Hud",x+size/2,y+size/2,F.C.warn,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  else
   draw.SimpleText(tostring(a.cost),"STFW.Hud",x+size/2,y+size/2,ready and F.C.accent or F.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  end
 end
 draw.SimpleText("Снабжение: "..(cmd.credits or 0).."  ·  stfw_ability <id>","STFW.HudSmall",ScrW()/2,y-px(16),F.C.muted,TEXT_ALIGN_CENTER)
end)
-- В редакторе видны границы реальных серверных зон, без изменения правил захвата.
hook.Add("PostDrawTranslucentRenderables","STFW.ZonePreview",function()
 if (not IsValid(F.Frame) and not F.Placement) or (not F.Placement and F.Tab~="admin") or not F.State or not F.State.admin then return end
 for _,p in pairs(F.State.points) do
  local pos=Vector(p.pos.x,p.pos.y,p.pos.z)
  for i=0,31 do local a,b=i*math.pi/16,(i+1)*math.pi/16
   local first=Vector(math.cos(a)*p.radius,math.sin(a)*p.radius,0);local second=Vector(math.cos(b)*p.radius,math.sin(b)*p.radius,0)
   for _,z in ipairs({-p.height,p.height}) do render.DrawLine(pos+first+Vector(0,0,z),pos+second+Vector(0,0,z),F.C.accent,true) end
   if i%4==0 then render.DrawLine(pos+first-Vector(0,0,p.height),pos+first+Vector(0,0,p.height),F.C.accent,true) end
  end
 end
end)
