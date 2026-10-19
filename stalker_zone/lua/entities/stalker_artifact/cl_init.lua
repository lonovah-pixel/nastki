include("shared.lua")
local matGlow=Material("sprites/light_glow02_add")
-- Без детектора артефакт не виден. С детектором проявляется на дистанции ArtifactVisibleRange.
function ENT:Visibility()
 local Z=STALKER_ZONE;local lp=LocalPlayer()
 if not IsValid(lp) or not Z.LocalDetector then return 0 end
 local d=lp:GetPos():Distance(self:GetPos());local range=math.max(1,tonumber(Z.Config.ArtifactVisibleRange) or 260)
 if d>range then return 0 end
 return math.Clamp((range-d)/(range*.35),0,1)
end
function ENT:Initialize() self:SetRenderBounds(Vector(-32,-32,-8),Vector(32,32,64));self.Seed=math.Rand(0,10) end
function ENT:Draw() end
function ENT:DrawTranslucent()
 local alpha=self:Visibility();if alpha<=0 then return end
 local info=self:Info();local c=info and info.color or color_white
 local t=CurTime()+(self.Seed or 0);local bob=Vector(0,0,10+math.sin(t*1.7)*3)
 self:SetRenderOrigin(self:GetNetworkOrigin()+bob);self:SetRenderAngles(Angle(0,(t*25)%360,0));self:SetupBones()
 render.SetBlend(alpha);render.SetColorModulation(c.r/255,c.g/255,c.b/255)
 self:DrawModel()
 render.SetColorModulation(1,1,1);render.SetBlend(1)
 self:SetRenderOrigin(nil);self:SetRenderAngles(nil)
 local s=36+math.sin(t*3)*8
 render.SetMaterial(matGlow);render.DrawSprite(self:GetPos()+bob+Vector(0,0,4),s,s,Color(c.r,c.g,c.b,180*alpha))
end
