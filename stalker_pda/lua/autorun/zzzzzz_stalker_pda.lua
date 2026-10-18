if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- STALKER PDA: окно КПК (F4). Грузится последним, но соседние аддоны читает только при открытии вкладок,
-- поэтому работает и без них. Обязательно только ядро (тема, сеть, метки, новости).
STALKER_PDA=STALKER_PDA or {}
local shared={"sh_config.lua"}
local client={"cl_core.lua","cl_catalog.lua","cl_summary.lua","cl_map.lua","cl_encyclopedia.lua","cl_messages.lua","cl_guide.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_pda/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_pda/"..f) end
end
if not STALKER_CORE or not STALKER_CORE.Send or not STALKER_SETTINGS then
 ErrorNoHalt("[STALKER PDA] Требуется STALKER Core: аддон не загружен\n");return
end
for _,f in ipairs(shared) do include("stalker_pda/"..f) end
if SERVER then include("stalker_pda/sv_messages.lua") else for _,f in ipairs(client) do include("stalker_pda/"..f) end end
hook.Run("STALKER_PDA_Ready",STALKER_PDA)
