if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
ST_EMISSION=ST_EMISSION or {}
local shared={"sh_config.lua"}
for _,f in ipairs(shared) do if SERVER then AddCSLuaFile("stalker_emissions/"..f) end include("stalker_emissions/"..f) end
if SERVER then
 resource.AddFile("materials/stalker_emissions/metal.png");resource.AddFile("materials/stalker_emissions/panel.png")
 AddCSLuaFile("stalker_emissions/cl_effects.lua");AddCSLuaFile("stalker_emissions/cl_menu.lua")
 for _,path in pairs(ST_EMISSION.Config.Sounds) do if file.Exists("sound/"..path,"GAME") then resource.AddFile("sound/"..path) end end
 include("stalker_emissions/sv_system.lua")
else include("stalker_emissions/cl_effects.lua");include("stalker_emissions/cl_menu.lua") end
