ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Артефакт"
ENT.Spawnable=false
ENT.RenderGroup=RENDERGROUP_TRANSLUCENT
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"ArtifactID")
end
function ENT:Info() return STALKER_ZONE.Artifacts[self:GetArtifactID()] end
