include("shared.lua")
-- Огонь, искры, дым и мерцающий свет — частицы и спрайты из базового GMod. Цвета огня — из STALKER_CRAFT.Config.FX.
local matGlow=Material("sprites/light_glow02_add")
local matHeat=Material("sprites/heatwave")
local matFire,matSmoke,matSpark="effects/fire_cloud1","particles/smokey","effects/spark"
local ROCKS=8
local function fx() local cfg=STALKER_CRAFT and STALKER_CRAFT.Config and STALKER_CRAFT.Config.FX or {};return cfg.fire or {255,150,60},cfg.ember or {255,96,40},cfg.smoke or {92,90,86} end

function ENT:Initialize()
 self:SetRenderBounds(Vector(-40,-40,-4),Vector(40,40,110))
 self.Loop=self:StartLoopingSound("ambient/fire/fire_small_loop1.wav")
end
function ENT:Draw()
 if self:GetStyle()=="barrel" then self:DrawModel();return end
 -- Кольцо из камней: одна модель рисуется несколько раз со смещением вокруг огня.
 local base=self:GetPos();local yaw=self:GetAngles().y
 for i=1,ROCKS do
  local a=math.rad(yaw+i*360/ROCKS)
  self:SetRenderOrigin(base+Vector(math.cos(a)*15,math.sin(a)*15,0))
  self:SetRenderAngles(Angle(0,yaw+i*47,0))
  self:SetupBones();self:DrawModel()
 end
 self:SetRenderOrigin();self:SetRenderAngles();self:SetupBones()
end
function ENT:DrawTranslucent()
 if not self:IsLit() then return end
 local fire=fx()
 local top=self:GetPos()+Vector(0,0,self:FireHeight()+10)
 local flicker=.85+.15*math.sin(CurTime()*17+self:EntIndex())
 render.SetMaterial(matGlow)
 render.DrawSprite(top,90*flicker,70*flicker,Color(fire[1],fire[2],fire[3],150))
 render.SetMaterial(matHeat)
 render.DrawSprite(top+Vector(0,0,18),36,48,color_white)
end
function ENT:Think()
 if not self:IsLit() or self:IsDormant() then return end
 local now=CurTime()
 local fire,ember,smoke=fx()
 local top=self:GetPos()+Vector(0,0,self:FireHeight())
 local d=DynamicLight(self:EntIndex())
 if d then
  d.Pos=top+Vector(0,0,20);d.r=fire[1];d.g=fire[2];d.b=fire[3]
  d.Brightness=1.6+math.Rand(0,.6);d.Decay=800;d.Size=230+math.random(0,50);d.DieTime=now+.2
 end
 if (self.NextFX or 0)>now then return end
 self.NextFX=now+.07
 local lp=LocalPlayer();if IsValid(lp) and lp:GetPos():DistToSqr(self:GetPos())>3000*3000 then return end
 if not self.Emitter then self.Emitter=ParticleEmitter(self:GetPos()) end
 local em=self.Emitter;if not em then return end
 for _=1,2 do
  local f=em:Add(matFire,top+Vector(math.Rand(-7,7),math.Rand(-7,7),math.Rand(0,4)))
  if f then
   f:SetVelocity(Vector(math.Rand(-6,6),math.Rand(-6,6),math.Rand(30,60)));f:SetDieTime(math.Rand(.45,.85))
   f:SetStartAlpha(230);f:SetEndAlpha(0);f:SetStartSize(math.Rand(10,16));f:SetEndSize(2)
   f:SetRoll(math.Rand(0,360));f:SetRollDelta(math.Rand(-2,2));f:SetColor(fire[1],fire[2],fire[3])
  end
 end
 if math.random()<.35 then
  local s=em:Add(matSpark,top+Vector(math.Rand(-5,5),math.Rand(-5,5),4))
  if s then
   s:SetVelocity(Vector(math.Rand(-25,25),math.Rand(-25,25),math.Rand(70,130)));s:SetDieTime(math.Rand(.8,1.6))
   s:SetStartAlpha(255);s:SetEndAlpha(0);s:SetStartSize(1.5);s:SetEndSize(0);s:SetColor(ember[1],ember[2],ember[3])
   s:SetGravity(Vector(0,0,-40));s:SetAirResistance(30)
  end
 end
 self.SmokeTick=(self.SmokeTick or 0)+1
 if self.SmokeTick%3==0 then
  local p=em:Add(matSmoke,top+Vector(math.Rand(-4,4),math.Rand(-4,4),28))
  if p then
   p:SetVelocity(Vector(math.Rand(-8,8),math.Rand(-8,8),math.Rand(30,55)));p:SetDieTime(math.Rand(3,5))
   p:SetStartAlpha(70);p:SetEndAlpha(0);p:SetStartSize(math.Rand(8,12));p:SetEndSize(math.Rand(40,60))
   p:SetRoll(math.Rand(0,360));p:SetRollDelta(math.Rand(-.4,.4));p:SetColor(smoke[1],smoke[2],smoke[3])
   p:SetGravity(Vector(0,0,6));p:SetAirResistance(25)
  end
 end
end
function ENT:OnRemove()
 if self.Emitter then self.Emitter:Finish();self.Emitter=nil end
 if self.Loop then self:StopLoopingSound(self.Loop);self.Loop=nil end
end
