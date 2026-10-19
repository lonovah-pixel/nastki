AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
-- Квестодатель: человек HL2, стоит на месте, разговор — клавиша E. Расстановка — data/stalker_quests/<карта>.json.
local idle={"idle_all_01","LineIdle01","idle_subtle","Idle_Relaxed_01","idle01"}
function ENT:Initialize()
 local Q=STALKER_QUESTS
 local prof=Q and Q.Profiles and Q.Profiles[self:GetProfile()]
 local model=prof and prof.model
 -- Модели нет на сервере (другой контент) — резервная модель вербовщика.
 if not model or not util.IsValidModel(model) then model=Q and Q.FallbackModel or "models/Humans/Group01/male_07.mdl" end
 if not util.IsValidModel(model) then model="models/Humans/Group01/male_07.mdl" end
 self:SetModel(model)
 self:SetMoveType(MOVETYPE_NONE);self:SetSolid(SOLID_BBOX)
 self:SetCollisionBounds(Vector(-16,-16,0),Vector(16,16,72));self:SetUseType(SIMPLE_USE)
 for _,name in ipairs(idle) do
  local seq=self:LookupSequence(name)
  if seq and seq>=0 then self:ResetSequence(seq);break end
 end
end
function ENT:Think() self:NextThink(CurTime()+.1);return true end
function ENT:Use(ply)
 if IsValid(ply) and ply:IsPlayer() and STALKER_QUESTS and STALKER_QUESTS.OpenDialog then STALKER_QUESTS.OpenDialog(ply,self) end
end
function ENT:OnTakeDamage() return 0 end
function ENT:CanTool() return false end
-- Место хранится в файле карты: двигать физганом нельзя, переставляют из панели «Задания».
function ENT:PhysgunPickup() return false end
