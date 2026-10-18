AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Маячок игрока: не мешает движению, не ломается, снимается владельцем (E). Срок и метку ведёт STALKER Events.
local MODELS={"models/props_lab/reciever01b.mdl","models/items/battery.mdl"}
function ENT:Initialize()
 local model=MODELS[#MODELS]
 for _,m in ipairs(MODELS) do if util.IsValidModel(m) then model=m;break end end
 self:SetModel(model)
 local mins=self:OBBMins();if mins.z<0 then self:SetPos(self:GetPos()-Vector(0,0,mins.z)) end
 self:SetMoveType(MOVETYPE_NONE);self:SetSolid(SOLID_BBOX);self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
 self:SetCollisionBounds(Vector(-8,-8,0),Vector(8,8,14));self:SetUseType(SIMPLE_USE);self:DrawShadow(false)
end
function ENT:Use(p) if STALKER_EVENTS and STALKER_EVENTS.UseBeacon then STALKER_EVENTS.UseBeacon(p,self) end end
function ENT:OnRemove() if STALKER_EVENTS and STALKER_EVENTS.BeaconRemoved then STALKER_EVENTS.BeaconRemoved(self) end end
function ENT:OnTakeDamage() return 0 end
function ENT:OnDuplicated() self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup(p) return IsValid(p) and p:IsSuperAdmin() end
