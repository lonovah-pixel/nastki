ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Рюкзак погибшего"
ENT.Spawnable=false
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"OwnerName")
 self:NetworkVar("Int",0,"ItemCount")
end
