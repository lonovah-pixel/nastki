-- STALKER Core загружается раньше остальных аддонов сборки (после 000_stalker_wipe).
if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
STALKER_CORE=STALKER_CORE or {}
local shared={"sh_core.lua","sh_settings.lua","sh_markers.lua","sh_hold.lua","sh_register.lua"}
local client={"cl_theme.lua","cl_markers.lua","cl_feed.lua","cl_pda.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_core/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_core/"..f) end
end
for _,f in ipairs(shared) do include("stalker_core/"..f) end
if SERVER then include("stalker_core/sv_feed.lua") else for _,f in ipairs(client) do include("stalker_core/"..f) end end
hook.Run("STALKER_CoreReady",STALKER_CORE)
