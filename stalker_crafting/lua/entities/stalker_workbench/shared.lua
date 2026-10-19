ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Верстак"
ENT.Spawnable=false
ENT.RenderGroup=RENDERGROUP_OPAQUE
-- PlaceID — ключ места в data/stalker_craft/<карта>.json (верстаки ставит только администратор).
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"PlaceID")
end
