-- Отрисовка меток: значки и расстояние на экране, стрелки у края для важных целей, флажки в мире.
local C=STALKER_CORE
local M=STALKER_MARKERS
local T=STALKER_THEME
local hudCvar=CreateClientConVar("stalker_markers","1",true,false,"Метки на экране: 1 — показывать, 0 — скрыть")
local matGlow=Material("sprites/light_glow02_add")
local matFlag=Material("vgui/white")

local function enabled() return hudCvar:GetBool() and C.Config.MarkersHUD~=false end
local function meters(d) return d<1000 and string.format("%.0f м",d*.01905) or string.format("%.1f км",d*.01905/1000) end

local function diamond(x,y,size,col)
 draw.NoTexture();surface.SetDrawColor(col)
 surface.DrawPoly({{x=x,y=y-size},{x=x+size,y=y},{x=x,y=y+size},{x=x-size,y=y}})
end
local function arrow(x,y,angle,size,col)
 local function rot(dx,dy) return {x=x+dx*math.cos(angle)-dy*math.sin(angle),y=y+dx*math.sin(angle)+dy*math.cos(angle)} end
 draw.NoTexture();surface.SetDrawColor(col)
 surface.DrawPoly({rot(size,0),rot(-size*.7,size*.6),rot(-size*.7,-size*.6)})
end

hook.Add("HUDPaint","STALKER_Markers.HUD",function()
 local ply=LocalPlayer();if not IsValid(ply) or not enabled() then return end
 local eye=ply:EyePos();local px=T.Px
 local cx,cy=ScrW()/2,ScrH()/2
 for _,m in ipairs(M.All()) do
  if m.hud~=false then
   local dist=eye:Distance(m.pos)
   if dist<=(m.range or 4000) then
    local s=(m.pos+Vector(0,0,m.world and 96 or 24)):ToScreen()
    local col=m.color or T.C.accent
    local onScreen=s.visible and s.x>0 and s.x<ScrW() and s.y>0 and s.y<ScrH()
    if onScreen then
     local size=px(dist<1500 and 7 or 5)
     diamond(s.x,s.y,size+1,Color(0,0,0,180));diamond(s.x,s.y,size,col)
     if dist<6000 or m.edge then
      draw.SimpleTextOutlined(m.label or "","STALKER.Small",s.x,s.y-size-px(4),col,TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,Color(0,0,0,200))
      draw.SimpleTextOutlined(meters(dist),"STALKER.Mono",s.x,s.y+size+px(2),T.C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,Color(0,0,0,200))
     end
    elseif m.edge then
     -- Направление на цель относительно взгляда: стрелка по краю эллипса вокруг центра экрана.
     local dir=m.pos-eye
     local yaw=math.rad(math.NormalizeAngle(dir:Angle().y-ply:EyeAngles().y))
     local ang=-yaw-math.pi/2
     local rx,ry=ScrW()*.42,ScrH()*.40
     local ax,ay=cx+math.cos(ang)*rx,cy+math.sin(ang)*ry
     arrow(ax,ay,ang,px(10),col)
     draw.SimpleTextOutlined((m.label or "").." · "..meters(dist),"STALKER.Small",ax,ay+px(14),col,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,Color(0,0,0,200))
    end
   end
  end
 end
end)

-- Флажки в мире: древко и полотнище цвета метки, у полотнища — значок (эмблема), если задан icon.
local icons={}
local function icon(path)
 if not path or path=="" then return end
 local mat=icons[path];if mat==nil then mat=Material(path,"smooth");if mat:IsError() then mat=false end;icons[path]=mat end
 return mat or nil
end
hook.Add("PostDrawTranslucentRenderables","STALKER_Markers.World",function(depth,sky)
 if sky or depth or not enabled() then return end
 local ply=LocalPlayer();if not IsValid(ply) then return end
 local eye=EyePos()
 for _,m in ipairs(M.All()) do
  if m.world then
   local d=eye:DistToSqr(m.pos)
   if d<3500^2 then
    local col=m.color or T.C.accent
    local base=m.pos;local top=base+Vector(0,0,110)
    render.SetColorMaterial()
    render.DrawBeam(base,top,2.5,0,1,Color(60,60,60,255))
    -- Полотнище смотрит на камеру по горизонтали и слегка колышется.
    local toEye=(eye-top);toEye.z=0;toEye:Normalize()
    local wave=math.sin(CurTime()*3+m.pos.x*.01)*.12
    local normal=Vector(toEye.x*math.cos(wave)-toEye.y*math.sin(wave),toEye.x*math.sin(wave)+toEye.y*math.cos(wave),0)
    local right=Vector(-normal.y,normal.x,0)
    local center=top-Vector(0,0,16)+right*22
    render.SetMaterial(matFlag)
    render.DrawQuadEasy(center,normal,44,30,Color(col.r,col.g,col.b,235),180)
    local mat=icon(m.icon)
    if mat then render.SetMaterial(mat);render.DrawQuadEasy(center+normal*.6,normal,24,24,color_white,180) end
    render.SetMaterial(matGlow);render.DrawSprite(top+Vector(0,0,4),16,16,Color(col.r,col.g,col.b,200))
   end
  end
 end
end)
