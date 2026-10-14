include("shared.lua")
-- Аномалия видна по искажению воздуха, искрам, пламени или испарениям. Модель не рисуется.
local matHeat=Material("sprites/heatwave")
local matGlow=Material("sprites/light_glow02_add")
local matFire=Material("effects/fire_cloud1")
local matArc=Material("trails/electric")
local effectsCvar=CreateClientConVar("stz_anomaly_fx","1",true,false,"Эффекты аномалий (0 — только искажение)")

function ENT:Initialize()
 local cfg=self:Config();local r=cfg and (cfg.pull or cfg.radius) or 128
 self:SetRenderBounds(Vector(-r,-r,-16),Vector(r,r,r*1.6))
 self.NextParticle=0;self.Seed=math.Rand(0,100)
end
-- Тип аномалии может прийти по сети позже Initialize: звук и границы отрисовки догоняют его.
function ENT:EnsureSetup(cfg)
 if self.SetupKind==self:GetKind() then return end
 self.SetupKind=self:GetKind()
 local r=cfg.pull or cfg.radius
 self:SetRenderBounds(Vector(-r,-r,-16),Vector(r,r,r*1.6))
 if self.Loop then self:StopLoopingSound(self.Loop);self.Loop=nil end
 if cfg.idle then self.Loop=self:StartLoopingSound(cfg.idle) end
end
function ENT:OnRemove()
 if self.Loop then self:StopLoopingSound(self.Loop) end
 if IsValid(self.Emitter) then self.Emitter:Finish() end
end
function ENT:Draw() end

local function emitter(self)
 if not IsValid(self.Emitter) then self.Emitter=ParticleEmitter(self:GetPos(),false) end
 return self.Emitter
end
local function puff(em,mat,pos,vel,life,size,endSize,color,alpha,gravity)
 local p=em:Add(mat,pos);if not p then return end
 p:SetVelocity(vel);p:SetDieTime(life);p:SetStartAlpha(alpha or 200);p:SetEndAlpha(0)
 p:SetStartSize(size);p:SetEndSize(endSize or 0);p:SetRoll(math.Rand(0,360));p:SetRollDelta(math.Rand(-1,1))
 p:SetColor(color.r,color.g,color.b);if gravity then p:SetGravity(gravity) end
 return p
end

function ENT:Think()
 local cfg=self:Config();local lp=LocalPlayer()
 if not cfg or not IsValid(lp) then return end
 self:EnsureSetup(cfg)
 if not effectsCvar:GetBool() then return end
 local pos=self:GetPos();local dist=lp:GetPos():DistToSqr(pos)
 if dist>2500^2 or CurTime()<self.NextParticle then return end
 local active=CurTime()-self:GetTriggered()<.6
 self.NextParticle=CurTime()+(active and .03 or .15)
 local em=emitter(self);if not IsValid(em) then return end
 em:SetPos(pos)
 local kind=self:GetKind();local c=cfg.color;local r=cfg.radius
 if kind=="electro" then
  local n=active and 6 or (math.random()<.25 and 1 or 0)
  for _=1,n do puff(em,"effects/spark",pos+Vector(0,0,30)+VectorRand()*r*.35,VectorRand()*(active and 260 or 60),.35,6,0,c,255,Vector(0,0,-300)) end
  if active then
   local light=DynamicLight(self:EntIndex());if light then light.pos=pos+Vector(0,0,40);light.r=c.r;light.g=c.g;light.b=c.b;light.brightness=4;light.decay=900;light.size=r*3;light.dietime=CurTime()+.2 end
  end
 elseif kind=="burner" then
  if active then
   for _=1,3 do puff(em,"effects/fire_cloud1",pos+VectorRand()*12+Vector(0,0,6),Vector(math.Rand(-15,15),math.Rand(-15,15),math.Rand(180,320)),.7,26,4,Color(255,220,180),230) end
   local light=DynamicLight(self:EntIndex());if light then light.pos=pos+Vector(0,0,60);light.r=255;light.g=140;light.b=50;light.brightness=3;light.decay=600;light.size=260;light.dietime=CurTime()+.25 end
  elseif math.random()<.3 then puff(em,"effects/spark",pos+VectorRand()*20+Vector(0,0,4),Vector(0,0,math.Rand(30,70)),1.2,3,0,c,180) end
 elseif kind=="springboard" then
  local a=math.Rand(0,math.pi*2);local d=math.Rand(r*.2,r)
  puff(em,"particles/smokey",pos+Vector(math.cos(a)*d,math.sin(a)*d,6),Vector(-math.sin(a)*40,math.cos(a)*40,8),1.4,10,22,c,active and 120 or 25)
 elseif kind=="vortex" then
  for _=1,active and 8 or 2 do
   local a=math.Rand(0,math.pi*2);local d=math.Rand(r,cfg.pull)
   local from=pos+Vector(math.cos(a)*d,math.sin(a)*d,math.Rand(4,60))
   local to=(pos+Vector(0,0,30)-from):GetNormalized()
   puff(em,"particles/smokey",from,to*math.Rand(80,180)+Vector(-math.sin(a)*90,math.cos(a)*90,0),1,6,2,c,active and 160 or 45)
  end
 elseif kind=="acid" then
  local a=math.Rand(0,math.pi*2);local d=math.Rand(0,r)
  puff(em,"particles/smokey",pos+Vector(math.cos(a)*d,math.sin(a)*d,4),Vector(0,0,math.Rand(4,16)),2.5,18,48,c,active and 110 or 45)
  if math.random()<.35 then puff(em,"sprites/light_glow02_add",pos+Vector(math.cos(a)*d*.6,math.sin(a)*d*.6,2),Vector(0,0,math.Rand(10,25)),.8,5,0,c,200) end
 end
end

function ENT:DrawTranslucent()
 local cfg=self:Config();if not cfg then return end
 local pos=self:GetPos();local t=CurTime()+self.Seed;local kind=self:GetKind();local c=cfg.color
 local since=CurTime()-self:GetTriggered();local pulse=since<.6 and (1-since/.6) or 0
 -- Искажение воздуха выдаёт аномалию внимательному сталкеру.
 render.UpdateRefractTexture();render.SetMaterial(matHeat)
 local size=(kind=="vortex" and 90 or 54)+math.sin(t*2)*6+pulse*40
 render.DrawSprite(pos+Vector(0,0,kind=="vortex" and 36 or 28),size,size*1.3,Color(255,255,255,255))
 if kind=="electro" then
  render.SetMaterial(matGlow);render.DrawSprite(pos+Vector(0,0,30),40+pulse*140,40+pulse*140,Color(c.r,c.g,c.b,60+pulse*190))
  if pulse>0 or math.sin(t*7)>.97 then
   render.SetMaterial(matArc)
   for _=1,pulse>0 and 4 or 1 do
    local a=pos+Vector(0,0,30)+VectorRand()*12;local b=pos+VectorRand()*cfg.radius*.8;b.z=pos.z+math.Rand(0,50)
    render.DrawBeam(a,b,math.Rand(4,10),0,1,Color(c.r,c.g,c.b,220))
   end
  end
 elseif kind=="burner" then
  render.SetMaterial(matGlow);render.DrawSprite(pos+Vector(0,0,6),70+pulse*160,40+pulse*60,Color(255,120,40,30+pulse*170))
  if pulse>0 then
   render.SetMaterial(matFire)
   local scroll=(t*-4)%100
   render.StartBeam(3)
   render.AddBeam(pos,40,scroll,Color(255,200,120,230))
   render.AddBeam(pos+Vector(0,0,80*pulse+40),34,scroll+1,Color(255,160,80,200))
   render.AddBeam(pos+Vector(0,0,180*pulse+60),18,scroll+3,Color(255,120,60,0))
   render.EndBeam()
  end
 elseif kind=="vortex" then
  render.SetMaterial(matGlow);render.DrawSprite(pos+Vector(0,0,36),30+pulse*200,30+pulse*200,Color(c.r,c.g,c.b,40+pulse*200))
 elseif kind=="acid" then
  render.SetMaterial(matGlow);render.DrawSprite(pos+Vector(0,0,4),cfg.radius*2,cfg.radius*.6,Color(c.r,c.g,c.b,22+pulse*60))
 end
end
