if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- STALKER Events: события Зоны (сбитый груз, гон мутантов, артефактный шторм, военный рейд, охота за головой),
-- маячки игроков и точки интереса администратора. Инвентарь и Зона загружаются позже (порядок autorun по имени),
-- поэтому всё, что от них зависит, подключается через их хуки готовности или во время игры.
STALKER_EVENTS=STALKER_EVENTS or {}
local shared={"sh_config.lua","sh_items.lua"}
local client={"cl_events.lua","cl_admin.lua"}
local server={"sv_core.lua","sv_world.lua","sv_npc.lua","sv_events.lua","sv_beacons.lua","sv_net.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_events/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_events/"..f) end
 resource.AddFile("materials/stalker_events/items/beacon.png")
end
if not STALKER_CORE or not STALKER_SETTINGS or not STALKER_MARKERS then
 ErrorNoHalt("[STALKER Events] Требуется STALKER Core: аддон не загружен\n");return
end
for _,f in ipairs(shared) do include("stalker_events/"..f) end
if SERVER then
 for _,f in ipairs(server) do include("stalker_events/"..f) end
else
 for _,f in ipairs(client) do include("stalker_events/"..f) end
end
hook.Run("STALKER_EVENTS_Ready",STALKER_EVENTS)
