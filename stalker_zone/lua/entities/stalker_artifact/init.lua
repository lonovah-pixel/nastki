AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Артефакт висит над землёй, не мешает движению и подбирается только с детектором в рюкзаке.
function ENT:Initialize()
 local info=self:Info()
 if not info then self:Remove();return end
 self:SetModel(util.IsValidModel(info.model or "") and info.model or "models/props_junk/rock001a.mdl")
 self:SetMoveType(MOVETYPE_NONE);self:SetSolid(SOLID_BBOX);self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
 self:SetCollisionBounds(Vector(-10,-10,0),Vector(10,10,24));self:SetUseType(SIMPLE_USE);self:DrawShadow(false)
 self:SetColor(info.color or color_white)
end
function ENT:Use(p) if IsValid(p) and p:IsPlayer() then STALKER_ZONE.PickupArtifact(p,self) end end
function ENT:OnDuplicated() self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup(p) return IsValid(p) and p:IsSuperAdmin() end
function ENT:OnTakeDamage() return 0 end
