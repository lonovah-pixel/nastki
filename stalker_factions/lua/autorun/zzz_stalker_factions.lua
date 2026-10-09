if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
STFW=STFW or {}
local shared={"sh_config.lua","sh_core.lua","sh_locale.lua","sh_point.lua","sh_progression.lua","sh_traders.lua"}
local client={"cl_style.lua","cl_theme.lua","cl_management.lua","cl_ui.lua","cl_hud.lua"}
for _,f in ipairs(shared) do if SERVER then AddCSLuaFile("stalker_factions/"..f) end include("stalker_factions/"..f) end
if SERVER then
 resource.AddFile("materials/stalker_factions/noise.png")
 for _,f in ipairs(client) do AddCSLuaFile("stalker_factions/"..f) end
 for _,f in ipairs({"sv_store.lua","sv_factions.lua","sv_admission.lua","sv_progression.lua","sv_spawn.lua","sv_war.lua","sv_net.lua","sv_integration.lua"}) do include("stalker_factions/"..f) end
else for _,f in ipairs(client) do include("stalker_factions/"..f) end end

if SERVER then
 local function sendMaterials(dir)
  local files,dirs=file.Find(dir.."/*","GAME")
  for _,name in ipairs(files or {}) do if name:sub(-4)==".png" then resource.AddFile(dir.."/"..name) end end
  for _,name in ipairs(dirs or {}) do sendMaterials(dir.."/"..name) end
 end
 sendMaterials("materials/stalker_factions")
end
