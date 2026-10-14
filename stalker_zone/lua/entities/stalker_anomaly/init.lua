AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Аномалия невидима как модель: клиент рисует только эффекты. Коллизии нет.
function ENT:Initialize()
 if not self:Config() then self:SetKind("electro") end
 self:SetModel("models/props_junk/PopCan01a.mdl");self:SetNoDraw(false);self:DrawShadow(false)
 self:SetSolid(SOLID_NONE);self:SetMoveType(MOVETYPE_NONE);self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
 self.Ready=0;self.NextTick=0
end
function ENT:UpdateTransmitState() return TRANSMIT_PVS end

local function victim(e)
 if e:IsPlayer() then
  return e:Alive() and e:GetMoveType()~=MOVETYPE_NOCLIP and e:GetObserverMode()==OBS_MODE_NONE and not e.StemHidden and not e:HasGodMode()
 end
 if e:IsNPC() or (e.IsNextBot and e:IsNextBot()) then return e:Health()>0 end
 return false
end
local function physicsProp(e)
 if e:GetClass()~="prop_physics" then return end
 local phys=e:GetPhysicsObject();return IsValid(phys) and phys:IsMotionEnabled() and phys
end
function ENT:Hurt(e,amount,force)
 local cfg=self:Config();local dmg=DamageInfo()
 dmg:SetDamage(amount*(STALKER_ZONE.Config.AnomalyDamageScale or 1));dmg:SetDamageType(cfg.dmgType);dmg:SetAttacker(game.GetWorld());dmg:SetInflictor(self)
 dmg:SetDamagePosition(e:WorldSpaceCenter());if force then dmg:SetDamageForce(force) end
 -- Очки брони HL2 поглощают 80% любого урона: аномалия бьёт в обход них (см. sv_gear.lua),
 -- а защищают характеристики костюма и артефактов.
 if e:IsPlayer() then STALKER_ZONE.AnomalyVictim=e end
 e:TakeDamageInfo(dmg)
 STALKER_ZONE.AnomalyVictim=nil
end
function ENT:Fire(sound)
 local cfg=self:Config();self:SetTriggered(CurTime())
 if sound~=false and cfg.sounds then self:EmitSound(cfg.sounds[math.random(#cfg.sounds)],85,math.random(92,108)) end
end
local function effect(name,pos,scale,magnitude)
 local ed=EffectData();ed:SetOrigin(pos);ed:SetNormal(Vector(0,0,1));ed:SetScale(scale or 1);ed:SetMagnitude(magnitude or 1);ed:SetRadius(scale or 1)
 util.Effect(name,ed,true,true)
end
-- Вытолкнуть вверх и от центра: игроку — скорость, NPC и пропам — импульс.
local function launch(e,dir,force)
 if e:IsPlayer() then e:SetVelocity(dir*force)
 elseif e:IsNPC() then e:SetVelocity(dir*force)
 else local phys=physicsProp(e);if phys then phys:ApplyForceCenter(dir*force*phys:GetMass()) end end
end

-- Ошибка в одном тике не должна останавливать аномалию и засорять консоль.
function ENT:Think()
 local ok,err=pcall(self.Tick,self)
 if not ok then
  STALKER_ZONE.AnomalyVictim=nil
  if (self.NextError or 0)<CurTime() then self.NextError=CurTime()+30;ErrorNoHalt("[STALKER Zone] Аномалия "..tostring(self:GetKind())..": "..tostring(err).."\n") end
 end
 self:NextThink(CurTime()+(self.Sleep and .3 or .1))
 return true
end
function ENT:Tick()
 local cfg=self:Config();if not cfg then return end
 local now=CurTime();self.Sleep=false
 local pos=self:GetPos();local center=pos+Vector(0,0,24)
 local reach=cfg.pull or cfg.radius
 local inside,near={},{}
 for _,e in ipairs(ents.FindInSphere(center,reach+40)) do
  if e~=self and (victim(e) or ((self:GetKind()=="springboard" or self:GetKind()=="vortex") and physicsProp(e))) then
   local d=e:WorldSpaceCenter():Distance(center)
   if d<=cfg.radius then inside[#inside+1]=e elseif d<=reach then near[#near+1]=e end
  end
 end
 -- Пустая округа: проверяем реже, чтобы десятки аномалий не грузили сервер.
 if #inside==0 and #near==0 then self.Sleep=true;return end
 local kind=self:GetKind()
 if kind=="electro" then
  if #inside>0 and now>=self.Ready then
   self.Ready=now+cfg.cooldown;self:Fire()
   effect("cball_explode",center,1);effect("Sparks",center,2,3)
   for _,e in ipairs(inside) do if victim(e) then self:Hurt(e,cfg.damage) end end
  end
 elseif kind=="burner" or kind=="acid" then
  if #inside>0 and now>=self.NextTick then
   self.NextTick=now+cfg.interval
   if now-self:GetTriggered()>1.2 then self:Fire() else self:SetTriggered(now) end
   for _,e in ipairs(inside) do if victim(e) then self:Hurt(e,cfg.damage) end end
  end
 elseif kind=="springboard" then
  if #inside>0 and now>=self.Ready then
   self.Ready=now+cfg.cooldown;self:Fire();effect("ThumperDust",pos,cfg.radius)
   for _,e in ipairs(inside) do
    local dir=(e:WorldSpaceCenter()-center);dir.z=0;dir=dir:GetNormalized()*.55+Vector(0,0,1)
    launch(e,dir:GetNormalized(),cfg.force)
    if victim(e) then self:Hurt(e,cfg.damage,dir*cfg.force*40) end
   end
  end
 elseif kind=="vortex" then
  -- Внешнее кольцо затягивает, ядро разрывает и отбрасывает.
  for _,e in ipairs(near) do
   local dir=center-e:WorldSpaceCenter();local d=dir:Length();dir:Normalize()
   local k=1-math.Clamp((d-cfg.radius)/(cfg.pull-cfg.radius),0,1)
   if e:IsPlayer() then e:SetVelocity(dir*cfg.pullForce*k)
   else local phys=physicsProp(e);if phys then phys:ApplyForceCenter(dir*cfg.pullForce*k*phys:GetMass()*.5) end end
  end
  if #inside>0 and now>=self.Ready then
   self.Ready=now+cfg.cooldown;self:Fire();effect("cball_explode",center,2);effect("ThumperDust",pos,cfg.pull)
   for _,e in ipairs(inside) do
    local dir=(e:WorldSpaceCenter()-center);dir.z=0;dir=(dir:GetNormalized()+Vector(0,0,.8)):GetNormalized()
    launch(e,dir,600)
    if victim(e) then self:Hurt(e,cfg.damage,dir*30000) end
   end
  end
 end
end
