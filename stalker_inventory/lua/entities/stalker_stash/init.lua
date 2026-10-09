AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
-- Визуальная точка тайника. Содержимое хранится в профиле владельца, сущность пересоздаётся при входе.
function ENT:Initialize()
    local model=STALKER_INV.Config.StashModel
    self:SetModel(util.IsValidModel(model) and model or "models/props_junk/cardboard_box004a.mdl")
    self:SetMoveType(MOVETYPE_NONE);self:SetSolid(SOLID_NONE);self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetPos(self:GetPos()+Vector(0,0,-self:OBBMins().z))
    self:SetAngles(Angle(0,tonumber(util.CRC(self:GetStashID())) % 360,0))
    self:DrawShadow(true)
end
function ENT:UpdateTransmitState() return TRANSMIT_PVS end
function ENT:OnDuplicated() self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup() return false end
