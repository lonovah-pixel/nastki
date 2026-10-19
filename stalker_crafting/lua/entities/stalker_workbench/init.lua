AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Верстак: стол из HL2, при урезанном контенте — запасные модели. Не двигается и не ломается: место хранит администратор.
local MODELS={"models/props_wasteland/controlroom_desk001b.mdl","models/props_c17/FurnitureTable001a.mdl","models/props_junk/wood_crate001a.mdl"}
function ENT:Initialize()
 local model=MODELS[#MODELS]
 for _,m in ipairs(MODELS) do if util.IsValidModel(m) then model=m;break end end
 self:SetModel(model)
 -- Дно модели — на земле, какой бы ни была её точка отсчёта.
 local mins=self:OBBMins();if mins.z<0 then self:SetPos(self:GetPos()-Vector(0,0,mins.z)) end
 self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS);self:SetSolid(SOLID_VPHYSICS)
 self:SetUseType(SIMPLE_USE)
 local phys=self:GetPhysicsObject();if IsValid(phys) then phys:EnableMotion(false) end
end
function ENT:Use(p) if STALKER_CRAFT and STALKER_CRAFT.UseStation then STALKER_CRAFT.UseStation(p,self,"craft") end end
function ENT:OnTakeDamage() return 0 end
function ENT:OnDuplicated() self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup() return false end
function ENT:GravGunPickupAllowed() return false end
