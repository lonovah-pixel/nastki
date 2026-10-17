include("shared.lua")
-- Мигающий огонь маячка: цвет метки маячков из ядра, у маячка группировки — цвет группировки.
local matGlow=Material("sprites/light_glow02_add")
function ENT:Initialize() self:SetRenderBounds(Vector(-24,-24,-4),Vector(24,24,56)) end
function ENT:LightColor()
 local fid=self:GetFactionID()
 if fid~="" and STALKER_CORE and STALKER_CORE.FactionColor then return STALKER_CORE.FactionColor(fid) end
 local kind=STALKER_MARKERS and STALKER_MARKERS.Kinds and STALKER_MARKERS.Kinds.beacon
 return kind and kind.color or STALKER_THEME.C.info
end
function ENT:Draw() self:DrawModel() end
function ENT:DrawTranslucent()
 local c=self:LightColor();local on=self:Blink()
 local size=on and 46 or 12
 render.SetMaterial(matGlow)
 render.DrawSprite(self:GetPos()+Vector(0,0,15),size,size,Color(c.r,c.g,c.b,on and 255 or 110))
end
function ENT:Think()
 if not self:Blink() or self:IsDormant() then return end
 local c=self:LightColor()
 local d=DynamicLight(self:EntIndex())
 if d then d.Pos=self:GetPos()+Vector(0,0,18);d.r=c.r;d.g=c.g;d.b=c.b;d.Brightness=1;d.Decay=900;d.Size=150;d.DieTime=CurTime()+.1 end
end
