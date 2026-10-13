ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Аномалия"
ENT.Spawnable=false
ENT.RenderGroup=RENDERGROUP_TRANSLUCENT
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"Kind")
 self:NetworkVar("Float",0,"Triggered")
end
function ENT:Config() return STALKER_ZONE.Anomalies[self:GetKind()] end
