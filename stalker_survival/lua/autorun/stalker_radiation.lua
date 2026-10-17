if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- Радиация: доза игроков, радиационные зоны карты и их редактор для администраторов.
-- Код разложен по stalker_rad/*: общие параметры, хранение зон, доза, сеть редактора, HUD и панель.
if SERVER then AddCSLuaFile() end
STALKER_RAD=STALKER_RAD or {}
local shared={"sh_config.lua"}
local client={"cl_hud.lua","cl_admin.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_rad/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_rad/"..f) end
end
for _,f in ipairs(shared) do include("stalker_rad/"..f) end
if SERVER then
 include("stalker_rad/sv_zones.lua")
 include("stalker_rad/sv_dose.lua")
 include("stalker_rad/sv_net.lua")
else
 for _,f in ipairs(client) do include("stalker_rad/"..f) end
end
hook.Run("STALKER_RAD_Ready",STALKER_RAD)
