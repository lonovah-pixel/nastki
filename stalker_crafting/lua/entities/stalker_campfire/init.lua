AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Костёр: камни вокруг огня (походный и постоянный) или бочка с огнём (постоянный). Не тушится уроном,
-- не двигается; походный гаснет по сроку (таймер STALKER_CRAFT.Fires), постоянный — только по воле администратора.
local MODELS={ring={"models/props_junk/rock001a.mdl"},barrel={"models/props_c17/oildrum001.mdl","models/props_junk/rock001a.mdl"}}
function ENT:Initialize()
 if self:GetStyle()=="" then self:SetStyle("ring") end
 local list=MODELS[self:GetStyle()] or MODELS.ring
 local model=list[#list]
 for _,m in ipairs(list) do if util.IsValidModel(m) then model=m;break end end
 self:SetModel(model)
 local mins=self:OBBMins();if mins.z<0 then self:SetPos(self:GetPos()-Vector(0,0,mins.z)) end
 if self:GetStyle()=="barrel" then
  self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS);self:SetSolid(SOLID_VPHYSICS)
  local phys=self:GetPhysicsObject();if IsValid(phys) then phys:EnableMotion(false) end
 else
  -- Низкий костёр не мешает ходить, но ловит прицел для E.
  self:SetMoveType(MOVETYPE_NONE);self:SetSolid(SOLID_BBOX);self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
  self:SetCollisionBounds(Vector(-18,-18,0),Vector(18,18,14))
 end
 self:SetUseType(SIMPLE_USE);self:DrawShadow(false)
end
function ENT:Use(p) if STALKER_CRAFT and STALKER_CRAFT.UseStation then STALKER_CRAFT.UseStation(p,self,"cook") end end
function ENT:OnTakeDamage() return 0 end
function ENT:OnDuplicated() self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup() return false end
function ENT:GravGunPickupAllowed() return false end
