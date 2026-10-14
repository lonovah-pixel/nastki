ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="STALKER — Флаг территории"
ENT.Spawnable=false
ENT.RenderGroup=RENDERGROUP_BOTH
ENT.FlagHeight=150
-- Состояние точки для отрисовки: владелец, «вооружившая» точку группировка, прогресс и оспаривание.
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"PointID")
 self:NetworkVar("String",1,"OwnerID")
 self:NetworkVar("String",2,"ArmedID")
 self:NetworkVar("String",3,"PointName")
 self:NetworkVar("Float",0,"Progress")
 self:NetworkVar("Bool",0,"Contested")
end
