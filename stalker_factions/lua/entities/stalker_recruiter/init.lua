AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
function ENT:Initialize()
 self:SetModel("models/Humans/Group01/male_07.mdl");self:SetSolid(SOLID_BBOX);self:SetMoveType(MOVETYPE_NONE)
 self:SetCollisionBounds(Vector(-16,-16,0),Vector(16,16,72));self:SetUseType(SIMPLE_USE)
 local seq=self:LookupSequence("idle_all_01");if seq>=0 then self:ResetSequence(seq) end
end
function ENT:Use(p)
 if not IsValid(p) or not p:IsPlayer() or not p:Alive() or p:GetPos():DistToSqr(self:GetPos())>STFW.Config.RecruitDistance^2 then return end
 if (p.StfwRecruitTime or 0)>CurTime() then return end;p.StfwRecruitTime=CurTime()+1
 STFW.SendRecruit(p,self)
end
function ENT:OnTakeDamage() return 0 end
