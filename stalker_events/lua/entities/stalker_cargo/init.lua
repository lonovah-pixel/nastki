AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Ящик сбитого груза. Содержимое (self.Items) живёт только в памяти сервера и пропадает вместе с ящиком.
-- Армейский ящик HL2; при урезанном контенте — деревянный ящик или ящик предметов.
local MODELS={"models/items/ammocrate_smg1.mdl","models/props_junk/wood_crate001a.mdl","models/items/item_item_crate.mdl"}
function ENT:Initialize()
 local model=MODELS[#MODELS]
 for _,m in ipairs(MODELS) do if util.IsValidModel(m) then model=m;break end end
 self:SetModel(model)
 -- Дно модели — на земле, какой бы ни была её точка отсчёта.
 local mins=self:OBBMins();if mins.z<0 then self:SetPos(self:GetPos()-Vector(0,0,mins.z)) end
 self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS);self:SetSolid(SOLID_VPHYSICS)
 self:SetUseType(SIMPLE_USE)
 -- Ящик не сдвинуть и не утащить: он лежит там, где упал.
 local phys=self:GetPhysicsObject();if IsValid(phys) then phys:EnableMotion(false) end
 self.Items=self.Items or {}
 self:EmitSound("ambient/explosions/explode_4.wav",90,110)
end
function ENT:Use(p) if STALKER_EVENTS and STALKER_EVENTS.UseCargo then STALKER_EVENTS.UseCargo(p,self) end end
function ENT:OnTakeDamage() return 0 end
function ENT:OnDuplicated() self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup(p) return IsValid(p) and p:IsSuperAdmin() end
