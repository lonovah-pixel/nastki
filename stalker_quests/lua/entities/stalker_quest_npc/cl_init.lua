include("shared.lua")
function ENT:Draw()
 self:DrawModel()
 if STALKER_QUESTS and STALKER_QUESTS.DrawNPC then STALKER_QUESTS.DrawNPC(self) end
end
