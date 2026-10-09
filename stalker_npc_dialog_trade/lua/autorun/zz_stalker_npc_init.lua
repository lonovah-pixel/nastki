if SERVER and STALKER_WIPE and STALKER_WIPE.Blocked then return end
-- Зависимость загружается первой, а проверка API не подменяет отсутствующий Inventory.
STALKER_NPC=STALKER_NPC or {}
local N=STALKER_NPC
local shared={"sh_config.lua","sh_locale.lua","sh_trade.lua"}
local client={"cl_ui.lua"}
if SERVER then
    for _,f in ipairs(shared) do AddCSLuaFile("stalker_npc/"..f) end
    for _,f in ipairs(client) do AddCSLuaFile("stalker_npc/"..f) end
    AddCSLuaFile("stalker_npc/cl_style.lua")
    AddCSLuaFile("vgui/stalker_npc_widgets.lua")
end
for _,f in ipairs(shared) do include("stalker_npc/"..f) end
function N.Ready()
    local S=STALKER_INV
    return S and S.Items and S.ValidateSaved and S.FindUID and S.Weight and S.NewItem
        and (CLIENT or (S.CaptureEquipment and S.ApplyEquipment and S.Sync and S.SaveInventory))
end
if SERVER then
    include("stalker_npc/sv_store.lua")
    include("stalker_npc/sv_trade.lua")
    include("stalker_npc/sv_sessions.lua")
else
    include("stalker_npc/cl_style.lua")
    include("vgui/stalker_npc_widgets.lua")
    include("stalker_npc/cl_ui.lua")
end

if SERVER then
 local function sendMaterials(dir)
  local files,dirs=file.Find(dir.."/*","GAME")
  for _,name in ipairs(files or {}) do if name:sub(-4)==".png" then resource.AddFile(dir.."/"..name) end end
  for _,name in ipairs(dirs or {}) do sendMaterials(dir.."/"..name) end
 end
 sendMaterials("materials/stalker_npc")
end
