ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Рюкзак погибшего"
ENT.Spawnable=false
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"OwnerName")
 self:NetworkVar("Int",0,"ItemCount")
 -- SteamID64 владельца: клиент показывает имя глазами зрителя (знакомства STALKER_SOCIAL).
 self:NetworkVar("String",1,"OwnerSID")
 -- В сумке лежат записи КПК погибшего (наводка на тайник).
 self:NetworkVar("Bool",0,"HasIntel")
end
