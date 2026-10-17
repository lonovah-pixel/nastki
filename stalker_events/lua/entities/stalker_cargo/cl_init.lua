include("shared.lua")
-- Дым и огонь над упавшим ящиком: частицы из базовых материалов GMod и мерцающий свет.
local matSmoke,matFire="particles/smokey","effects/fire_cloud1"
function ENT:Draw() self:DrawModel() end
function ENT:Think()
 local now=CurTime()
 if (self.NextFX or 0)>now or self:IsDormant() then return end
 self.NextFX=now+.12
 local lp=LocalPlayer();if IsValid(lp) and lp:GetPos():DistToSqr(self:GetPos())>4000*4000 then return end
 local cfg=STALKER_EVENTS and STALKER_EVENTS.Config and STALKER_EVENTS.Config.FX or {}
 local smoke,fire=cfg.smoke or {90,88,82},cfg.fire or {255,150,60}
 if not self.Emitter then self.Emitter=ParticleEmitter(self:GetPos()) end
 local em=self.Emitter;if not em then return end
 local top=self:WorldSpaceCenter()+Vector(0,0,16)
 local p=em:Add(matSmoke,top+VectorRand()*6)
 if p then
  p:SetVelocity(Vector(math.Rand(-12,12),math.Rand(-12,12),math.Rand(50,90)));p:SetDieTime(math.Rand(4,6))
  p:SetStartAlpha(150);p:SetEndAlpha(0);p:SetStartSize(math.Rand(12,20));p:SetEndSize(math.Rand(60,90))
  p:SetRoll(math.Rand(0,360));p:SetRollDelta(math.Rand(-.4,.4));p:SetColor(smoke[1],smoke[2],smoke[3])
  p:SetGravity(Vector(0,0,8));p:SetAirResistance(20)
 end
 -- Пока ящик не вскрыт, он ещё горит.
 if not self:GetOpened() then
  local f=em:Add(matFire,top+VectorRand()*8)
  if f then
   f:SetVelocity(Vector(0,0,math.Rand(20,40)));f:SetDieTime(math.Rand(.4,.8));f:SetStartAlpha(220);f:SetEndAlpha(0)
   f:SetStartSize(math.Rand(8,14));f:SetEndSize(2);f:SetRoll(math.Rand(0,360));f:SetColor(fire[1],fire[2],fire[3])
  end
  local d=DynamicLight(self:EntIndex())
  if d then d.Pos=top;d.r=fire[1];d.g=fire[2];d.b=fire[3];d.Brightness=2;d.Decay=600;d.Size=170+math.random(0,40);d.DieTime=now+.3 end
 end
end
function ENT:OnRemove() if self.Emitter then self.Emitter:Finish();self.Emitter=nil end end
