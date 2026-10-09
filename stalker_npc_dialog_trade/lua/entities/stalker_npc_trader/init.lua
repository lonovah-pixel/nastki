AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
function ENT:Initialize()
    if self:GetTraderID()=="" then self:SetTraderID("sidor") end
    local p=STALKER_NPC.Config.Traders[self:GetTraderID()];if not p then self:Remove();return end
    self:SetModel(p.model);self:SetMoveType(MOVETYPE_NONE);self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-16,-16,0),Vector(16,16,72));self:SetUseType(SIMPLE_USE)
    local seq=self:LookupSequence("idle_all_01");if seq>=0 then self:ResetSequence(seq) end
end
function ENT:Use(ply) if IsValid(ply) and ply:IsPlayer() then STALKER_NPC.Open(ply,self) end end
function ENT:OnTakeDamage() return 0 end
function ENT:CanTool() return false end
function ENT:PhysgunPickup(ply) return ply:IsSuperAdmin() end
