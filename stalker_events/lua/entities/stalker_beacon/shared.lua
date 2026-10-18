ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Маячок"
ENT.Spawnable=false
ENT.RenderGroup=RENDERGROUP_BOTH
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"Label")
 self:NetworkVar("String",1,"OwnerName")
 self:NetworkVar("String",2,"FactionID")
 self:NetworkVar("String",3,"OwnerSID")
 self:NetworkVar("Float",0,"Expires")
end
-- Проблесковый огонь: короткая вспышка раз в 1.2 с, у соседних маячков — со сдвигом.
function ENT:Blink() return (CurTime()+self:EntIndex()*.37)%1.2<.25 end
