if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- STALKER Zone: загружается после инвентаря, торговли, группировок и разделки (порядок autorun по имени файла).
STALKER_ZONE=STALKER_ZONE or {}
local shared={"sh_config.lua","sh_items.lua","sh_gear.lua","sh_link.lua"}
local client={"cl_detector.lua","cl_editor.lua","cl_help.lua"}
local server={"sv_items.lua","sv_gear.lua","sv_survival.lua","sv_traders.lua","sv_world.lua","sv_mutants.lua","sv_editor.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_zone/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_zone/"..f) end
end
if not STALKER_INV or not STALKER_INV.RegisterItem then
 ErrorNoHalt("[STALKER Zone] Требуется STALKER Inventory: аддон не загружен\n");return
end
for _,f in ipairs(shared) do include("stalker_zone/"..f) end
if SERVER then
 for _,f in ipairs(server) do include("stalker_zone/"..f) end
 local files=file.Find("materials/stalker_zone/items/*.png","GAME")
 for _,name in ipairs(files or {}) do resource.AddFile("materials/stalker_zone/items/"..name) end
else
 for _,f in ipairs(client) do include("stalker_zone/"..f) end
end
hook.Run("STALKER_ZONE_Ready",STALKER_ZONE)
