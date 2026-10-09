ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="STALKER Trader"
ENT.Category="STALKER"
ENT.Spawnable=true
ENT.AdminOnly=true
function ENT:SetupDataTables() self:NetworkVar("String",0,"TraderID") end
