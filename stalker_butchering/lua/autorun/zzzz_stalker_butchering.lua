if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
STALKER_BUTCHERING=STALKER_BUTCHERING or {}
local path='stalker_butchering/'
for _,name in ipairs({'sh_config.lua','sh_core.lua','sh_items.lua'}) do
 if SERVER then AddCSLuaFile(path..name) end
 include(path..name)
end
if SERVER then
 AddCSLuaFile(path..'cl_ui.lua')
 for _,name in ipairs({'sv_store.lua','sv_adapter.lua','sv_corpses.lua','sv_session.lua'}) do include(path..name) end
else include(path..'cl_ui.lua') end
