if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- STALKER Crafting: крафт из деталей и трофеев разделки, верстаки, походные костры и готовка.
-- Инвентарь, разделка, события и Зона загружаются позже (порядок autorun по имени), поэтому предметы,
-- цены и рецепты подключаются по их хукам готовности, а доступность рецептов проверяется во время игры.
STALKER_CRAFT=STALKER_CRAFT or {}
local shared={"sh_config.lua","sh_recipes.lua","sh_items.lua"}
local client={"cl_ui.lua","cl_craft.lua","cl_admin.lua"}
local server={"sv_items.lua","sv_world.lua","sv_craft.lua","sv_net.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_craft/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_craft/"..f) end
end
if not STALKER_CORE or not STALKER_SETTINGS or not STALKER_MARKERS then
 ErrorNoHalt("[STALKER Crafting] Требуется STALKER Core: аддон не загружен\n");return
end
for _,f in ipairs(shared) do include("stalker_craft/"..f) end
if SERVER then
 for _,f in ipairs(server) do include("stalker_craft/"..f) end
 local files=file.Find("materials/stalker_craft/items/*.png","GAME")
 for _,name in ipairs(files or {}) do resource.AddFile("materials/stalker_craft/items/"..name) end
else
 for _,f in ipairs(client) do include("stalker_craft/"..f) end
end
hook.Run("STALKER_CRAFT_Ready",STALKER_CRAFT)
