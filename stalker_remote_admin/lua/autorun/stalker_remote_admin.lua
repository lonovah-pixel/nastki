STALKER_ADMIN=STALKER_ADMIN or {}
local shared={"sh_config.lua","sh_commands.lua"}
local client={"cl_theme.lua","cl_panel.lua"}
for _,f in ipairs(shared) do if SERVER then AddCSLuaFile("stalker_admin/"..f) end;include("stalker_admin/"..f) end
if SERVER then
 for _,f in ipairs(client) do AddCSLuaFile("stalker_admin/"..f) end
 for _,f in ipairs({"sv_store.lua","sv_access.lua","sv_actions.lua","sv_net.lua"}) do include("stalker_admin/"..f) end
else for _,f in ipairs(client) do include("stalker_admin/"..f) end end
