AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Содержимое рюкзака живёт только в памяти сервера: после рестарта карты оно пропадает, как и труп.
function ENT:Initialize()
 local cfg=STALKER_ZONE.Config.DeathDrop
 self:SetModel(util.IsValidModel(cfg.Model) and cfg.Model or "models/props_junk/cardboard_box004a.mdl")
 self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS);self:SetSolid(SOLID_VPHYSICS)
 self:SetCollisionGroup(COLLISION_GROUP_WEAPON);self:SetUseType(SIMPLE_USE)
 local phys=self:GetPhysicsObject();if IsValid(phys) then phys:Wake() end
 local ent=self;timer.Simple(cfg.Lifetime,function() if IsValid(ent) then ent.Items=nil;ent:Remove() end end)
end
function ENT:Use(p) if IsValid(p) and p:IsPlayer() then STALKER_ZONE.LootBag(p,self) end end
function ENT:OnDuplicated() self.Items=nil;self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup(p) return IsValid(p) and p:IsSuperAdmin() end
