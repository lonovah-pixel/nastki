if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- STALKER Social: знакомства («Незнакомец», пока не представились), меню взаимодействия (G), нашивки на рукаве,
-- жесты и позы (H), вкладки КПК «Контакты» и «Нашивки». Группировки, инвентарь и КПК загружаются позже
-- (порядок autorun по имени) — их API вызывается только во время игры и только если он есть.
STALKER_SOCIAL=STALKER_SOCIAL or {}
local shared={"sh_config.lua","sh_anim.lua"}
local client={"cl_patches.lua","cl_names.lua","cl_interact.lua","cl_emotes.lua","cl_pda.lua"}
local server={"sv_store.lua","sv_patches.lua","sv_interact.lua"}
if SERVER then
 for _,f in ipairs(shared) do AddCSLuaFile("stalker_social/"..f) end
 for _,f in ipairs(client) do AddCSLuaFile("stalker_social/"..f) end
 local files=file.Find("materials/stalker_social/patches/*.png","GAME")
 for _,name in ipairs(files or {}) do resource.AddFile("materials/stalker_social/patches/"..name) end
end
if not STALKER_CORE or not STALKER_SETTINGS then
 ErrorNoHalt("[STALKER Social] Требуется STALKER Core: аддон не загружен\n");return
end
for _,f in ipairs(shared) do include("stalker_social/"..f) end
if SERVER then
 for _,f in ipairs(server) do include("stalker_social/"..f) end
else
 for _,f in ipairs(client) do include("stalker_social/"..f) end
end
hook.Run("STALKER_SOCIAL_Ready",STALKER_SOCIAL)
