ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Сбитый груз"
ENT.Spawnable=false
function ENT:SetupDataTables()
 self:NetworkVar("Bool",0,"Opened")
 self:NetworkVar("Int",0,"ItemCount")
 self:NetworkVar("Float",0,"Expires")
end
