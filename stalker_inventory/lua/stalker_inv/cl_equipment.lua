local S=STALKER_INV
-- Состояние надетого предмета: подпись, процент и полоса цвета состояния.
local function condition(label,item,y)
 S.Text(label,"SI.Small",S.Px(89),S.Px(y),S.C.muted)
 S.Text(item and (item.durability.."%") or "—","SI.Small",S.Px(176),S.Px(y),item and S.ConditionColor(item.durability) or S.C.muted,TEXT_ALIGN_RIGHT)
 STALKER_STYLE.Bar(S.Px(89),S.Px(y+15),S.Px(87),S.Px(4),item and item.durability/100 or 0,item and S.ConditionColor(item.durability) or S.C.muted)
end
-- Главные защиты комплекта (с учётом износа) — коротко, полная разбивка в подсказке предмета.
local SUMMARY={{"bulletResist","Пули"},{"radiationProtection","Радиация"},{"burnResist","Термо"},{"chemResist","Химия"}}
function S.BuildEquipment(parent)
 local panel=vgui.Create("DPanel",parent);panel:SetPos(S.Px(16),S.Px(124));panel:SetSize(S.Px(180),S.Px(388))
 panel.Paint=function(_,w,h)
  S.Text("ЭКИПИРОВКА","SI.Title",0,0,S.C.muted)
  S.PaintPanel(0,S.Px(215),S.Px(180),S.Px(173))
  local eq=S.Inventory.equipment
  condition("КОСТЮМ",eq.armor,222)
  condition("ШЛЕМ",eq.helmet,250)
  local gear=S.GearSummary(S.Inventory);local y=282
  local ply=LocalPlayer()
  S.Text("Броня","SI.Small",S.Px(89),S.Px(y),S.C.muted)
  S.Text(IsValid(ply) and tostring(ply:Armor()) or "0","SI.Small",S.Px(176),S.Px(y),S.C.text,TEXT_ALIGN_RIGHT);y=y+17
  for _,s in ipairs(SUMMARY) do
   local value=gear[s[1]]
   if value and value>0 and y<=366 then
    S.Text(s[2],"SI.Small",S.Px(89),S.Px(y),S.C.muted)
    S.Text((S.FormatStat(s[1],value)),"SI.Small",S.Px(176),S.Px(y),S.C.ok,TEXT_ALIGN_RIGHT);y=y+17
   end
  end
 end
 for i,e in ipairs(S.Config.Equipment) do S.MakeSlot(panel,"equipment",e.id,((i-1)%3)*61,28+math.floor((i-1)/3)*61,58,e.title) end
 local model=vgui.Create("DModelPanel",panel);model:SetPos(S.Px(2),S.Px(219));model:SetSize(S.Px(82),S.Px(162))
 local ply=LocalPlayer();if IsValid(ply) then model:SetModel(ply:GetModel());if IsValid(model.Entity) then model.Entity:SetSkin(ply:GetSkin());for _,group in ipairs(ply:GetBodyGroups()) do model.Entity:SetBodygroup(group.id,ply:GetBodygroup(group.id)) end end end
 -- Освещение модели в тонах темы: в зелёном КПК персонаж подсвечен зелёным и т.д.
 model:SetFOV(30);model:SetCamPos(Vector(130,0,45));model:SetLookAt(Vector(0,0,38));model:SetAmbientLight(S.C.panel2);model:SetDirectionalLight(BOX_FRONT,S.C.text);model.LayoutEntity=function() end
 model:SetMouseInputEnabled(false);model:SetKeyboardInputEnabled(false)
 return panel
end
