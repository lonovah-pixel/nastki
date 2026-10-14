if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- STALKER Inventory: общий загрузчик. Порядок include важен.
STALKER_INV = STALKER_INV or {}
local shared = {"sh_config.lua", "sh_items.lua", "sh_core.lua", "sh_net.lua"}
local clients = {"cl_style.lua", "cl_theme.lua", "cl_tooltip.lua", "cl_dragdrop.lua", "cl_slots.lua",
    "cl_equipment.lua", "cl_quickbar.lua", "cl_pda.lua", "cl_menu.lua", "cl_stash.lua"}
if SERVER then
    for _, f in ipairs(shared) do AddCSLuaFile("stalker_inv/" .. f) end
    for _, f in ipairs(clients) do AddCSLuaFile("stalker_inv/" .. f) end
    resource.AddFile("materials/stalker_inv/noise.png")
end
for _, f in ipairs(shared) do include("stalker_inv/" .. f) end
if SERVER then
    include("stalker_inv/sv_items.lua")
    include("stalker_inv/sv_persistence.lua")
    include("stalker_inv/sv_inventory.lua")
    include("stalker_inv/sv_stash.lua")
    include("stalker_inv/sv_api.lua")
else
    for _, f in ipairs(clients) do include("stalker_inv/" .. f) end
end
hook.Run("STALKER_INV_Ready", STALKER_INV)

if SERVER then
 local function sendMaterials(dir)
  local files,dirs=file.Find(dir.."/*","GAME")
  for _,name in ipairs(files or {}) do if name:sub(-4)==".png" then resource.AddFile(dir.."/"..name) end end
  for _,name in ipairs(dirs or {}) do sendMaterials(dir.."/"..name) end
 end
 sendMaterials("materials/stalker_inv")
end
