ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="STALKER — Квестодатель"
ENT.Category="STALKER"
ENT.Spawnable=false
-- Анимация стойки проигрывается без отдельного Think на клиенте.
ENT.AutomaticFrameAdvance=true
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"Profile")
 self:NetworkVar("String",1,"QuestName")
 self:NetworkVar("String",2,"NpcID")
end
