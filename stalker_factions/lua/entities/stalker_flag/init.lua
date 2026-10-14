AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Флагшток из базового HL2; если модели нет (урезанный контент), берём заведомо существующий ящик.
local MODELS={"models/props_c17/signpole001.mdl","models/props_junk/wood_crate001a.mdl"}
function ENT:Initialize()
 local model=MODELS[#MODELS]
 for _,m in ipairs(MODELS) do if util.IsValidModel(m) then model=m;break end end
 self:SetModel(model);self:SetSolid(SOLID_BBOX);self:SetMoveType(MOVETYPE_NONE)
 self:SetCollisionBounds(Vector(-12,-12,0),Vector(12,12,self.FlagHeight));self:SetUseType(SIMPLE_USE);self:DrawShadow(false)
end
function ENT:Use(p) if STFW and STFW.FlagUse then STFW.FlagUse(p,self) end end
function ENT:OnTakeDamage() return 0 end
