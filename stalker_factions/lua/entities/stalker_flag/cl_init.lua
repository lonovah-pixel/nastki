include("shared.lua")
-- Полотнище цвета владельца с эмблемой группировки и табличка состояния точки над флагом.
local matWhite=Material("vgui/white")
local matGlow=Material("sprites/light_glow02_add")
local emblems={}
local function emblem(id)
 if not id or id=="" then return end
 local mat=emblems[id]
 if mat==nil then
  local f=STFW and STFW.Factions and STFW.Factions[id]
  local path=f and f.emblem and f.emblem~="" and f.emblem or ("stalker_factions/emblems/"..id..".png")
  mat=Material(path,"smooth");if mat:IsError() then mat=false end;emblems[id]=mat
 end
 return mat or nil
end
local function themeColor(token,fallback)
 local T=STALKER_THEME;local c=T and T.C and T.C[token]
 return c or fallback
end
local function factionColor(id)
 local f=STFW and STFW.Factions and STFW.Factions[id or ""]
 if f and f.color then return Color(f.color[1],f.color[2],f.color[3]) end
 return themeColor("muted",color_white)
end

function ENT:Draw()
 self:DrawModel()
 local pos=self:GetPos();local top=pos+Vector(0,0,self.FlagHeight)
 -- Древко рисуем сами: полотнище всегда на верхушке, какой бы ни была модель основания.
 render.SetColorMaterial()
 render.DrawBeam(pos,top+Vector(0,0,4),2.5,0,1,themeColor("line",color_white))
 local col=factionColor(self:GetOwnerID())
 if self:GetArmedID()~="" and math.floor(CurTime()*2)%2==0 then col=factionColor(self:GetArmedID()) end
 -- Полотнище из полос с бегущей волной; рисуем обе стороны.
 local yaw=math.rad((self:GetAngles().y or 0)+math.sin(CurTime()*.4+pos.x*.001)*25)
 local right=Vector(math.cos(yaw),math.sin(yaw),0);local normal=Vector(-right.y,right.x,0)
 local width,height,strips=56,34,8
 render.SetMaterial(matWhite)
 local t=CurTime()*3
 for i=0,strips-1 do
  local a,b=i/strips,(i+1)/strips
  local wa=math.sin(t+a*5)*5*a;local wb=math.sin(t+b*5)*5*b
  local p1=top+right*(width*a)+normal*wa;local p2=top+right*(width*b)+normal*wb
  local p3=p2-Vector(0,0,height);local p4=p1-Vector(0,0,height)
  local shade=.82+.18*math.sin(t+a*5)
  local c=Color(col.r*shade,col.g*shade,col.b*shade,245)
  render.DrawQuad(p1,p2,p3,p4,c);render.DrawQuad(p4,p3,p2,p1,c)
 end
 local mat=emblem(self:GetOwnerID())
 if mat then
  local mid=top+right*(width*.5)-Vector(0,0,height*.5)+normal*(math.sin(t+2.5)*2.5)
  render.SetMaterial(mat)
  render.DrawQuadEasy(mid+normal*.8,normal,24,24,color_white,180)
  render.DrawQuadEasy(mid-normal*.8,-normal,24,24,color_white,180)
 end
 render.SetMaterial(matGlow);render.DrawSprite(top+Vector(0,0,5),14,14,Color(col.r,col.g,col.b,200))
end

function ENT:DrawTranslucent()
 local eye=EyePos();local pos=self:GetPos()+Vector(0,0,self.FlagHeight+30)
 if eye:DistToSqr(pos)>700^2 then return end
 local ang=(eye-pos):Angle();ang=Angle(0,ang.y+90,90)
 local U=STALKER_STYLE;local F=STFW
 local text=themeColor("text",color_white);local muted=themeColor("muted",color_white)
 local owner=self:GetOwnerID();local armed=self:GetArmedID()
 local status
 if self:GetContested() then status="Точка оспаривается"
 elseif armed~="" then status="Захват: "..(F and F.Name(armed) or armed).." — "..math.floor(self:GetProgress()*100).."%"
 elseif owner=="" then status="Ничья точка — удерживайте E для захвата"
 else status="Удерживайте E: захват (война) или защита" end
 cam.Start3D2D(pos,ang,.12)
  if U and U.Panel then U.Panel("",-220,-60,440,120,armed~="") end
  draw.SimpleText(self:GetPointName(),"STALKER.Head",0,-44,themeColor("accent",color_white),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
  draw.SimpleText(owner~="" and (F and F.Name(owner) or owner) or "Без владельца","STALKER.Body",0,-14,factionColor(owner),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
  draw.SimpleText(status,"STALKER.Small",0,12,armed~="" and themeColor("danger",text) or muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
  if U and U.Bar and (armed~="" or self:GetProgress()>0) then U.Bar(-200,38,400,10,self:GetProgress(),factionColor(armed~="" and armed or owner)) end
 cam.End3D2D()
end
