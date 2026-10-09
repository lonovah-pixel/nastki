ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Личный тайник"
ENT.Spawnable=false
function ENT:SetupDataTables()
    self:NetworkVar("Entity",0,"StashOwner")
    self:NetworkVar("String",0,"StashID")
    self:NetworkVar("Int",0,"ItemCount")
end
