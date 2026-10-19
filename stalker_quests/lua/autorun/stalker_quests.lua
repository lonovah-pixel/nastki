if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- STALKER Quests: квестодатели (Бармен, Профессор, Охотник, Связной), случайные задания из шаблонов, трекер и
-- направляющая линия к цели (GUIDE LINE), обучающая цепочка «Путь новичка», вкладка КПК «Задания».
-- Группировки, Зона, торговцы и разделка загружаются позже (порядок autorun по имени файла), поэтому всё,
-- что от них зависит, проверяется во время игры или подключается по их хукам готовности.
STALKER_QUESTS=STALKER_QUESTS or {}
local shared={"sh_config.lua","sh_items.lua"}
local client={"cl_quests.lua","cl_dialog.lua","cl_admin.lua"}
local server={"sv_world.lua","sv_data.lua","sv_quests.lua","sv_tutorial.lua","sv_net.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_quests/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_quests/"..f) end
 resource.AddFile("materials/stalker_quests/items/quest_package.png")
end
if not STALKER_CORE or not STALKER_SETTINGS or not STALKER_MARKERS then
 ErrorNoHalt("[STALKER Quests] Требуется STALKER Core: аддон не загружен\n");return
end
for _,f in ipairs(shared) do include("stalker_quests/"..f) end
if SERVER then
 for _,f in ipairs(server) do include("stalker_quests/"..f) end
else
 for _,f in ipairs(client) do include("stalker_quests/"..f) end
end
hook.Run("STALKER_QUESTS_Ready",STALKER_QUESTS)
