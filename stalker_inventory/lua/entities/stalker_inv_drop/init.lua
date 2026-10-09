AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
function ENT:Initialize()
    local d=self.Item and STALKER_INV.Items[self.Item.id]
    if not d then self:Remove();return end
    local model=util.IsValidModel(d.model) and d.model or "models/props_junk/cardboard_box004a.mdl"
    self:SetModel(model);self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS);self:SetUseType(SIMPLE_USE)
    local phys=self:GetPhysicsObject();if IsValid(phys) then phys:Wake() end
    -- Предметы не сохраняются в мире после рестарта; время жизни — 15 минут.
    timer.Simple(900,function() if IsValid(self) then self:Remove() end end)
end
function ENT:Use(activator) STALKER_INV.Pickup(activator,self) end
-- Запрет копирования через duplicator / toolgun / physgun.
function ENT:OnDuplicated() self.Item=nil;self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup() return false end
