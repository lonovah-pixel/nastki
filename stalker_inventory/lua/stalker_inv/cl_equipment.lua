local S=STALKER_INV
function S.BuildEquipment(parent)
 local panel=vgui.Create("DPanel",parent);panel:SetPos(S.Px(16),S.Px(124));panel:SetSize(S.Px(180),S.Px(388))
 panel.Paint=function(_,w,h)
  S.Text("ЭКИПИРОВКА","SI.Title",0,0,S.C.muted)
  S.PaintPanel(0,S.Px(215),S.Px(180),S.Px(173))
  local item=S.Inventory.equipment.armor
  S.Text("КОСТЮМ","SI.Small",S.Px(89),S.Px(230),S.C.muted)
  S.Text(item and (item.durability.."%") or "—","SI.Mono",S.Px(89),S.Px(249),S.C.accent)
  STALKER_STYLE.Bar(S.Px(89),S.Px(274),S.Px(80),S.Px(4),item and item.durability/100 or 0,S.C.ok)
  S.Text("ЛКМ: выбрать","SI.Small",S.Px(89),S.Px(300),S.C.muted)
  S.Text("2×: действие","SI.Small",S.Px(89),S.Px(321),S.C.muted)
  S.Text("ПКМ: меню","SI.Small",S.Px(89),S.Px(342),S.C.muted)
 end
 for i,e in ipairs(S.Config.Equipment) do S.MakeSlot(panel,"equipment",e.id,((i-1)%3)*61,28+math.floor((i-1)/3)*61,58,e.title) end
 local model=vgui.Create("DModelPanel",panel);model:SetPos(S.Px(2),S.Px(219));model:SetSize(S.Px(82),S.Px(162))
 local ply=LocalPlayer();if IsValid(ply) then model:SetModel(ply:GetModel());if IsValid(model.Entity) then model.Entity:SetSkin(ply:GetSkin());for _,group in ipairs(ply:GetBodyGroups()) do model.Entity:SetBodygroup(group.id,ply:GetBodygroup(group.id)) end end end
 model:SetFOV(30);model:SetCamPos(Vector(130,0,45));model:SetLookAt(Vector(0,0,38));model:SetAmbientLight(Color(69,71,52));model:SetDirectionalLight(BOX_FRONT,Color(156,159,128));model.LayoutEntity=function() end
 model:SetMouseInputEnabled(false);model:SetKeyboardInputEnabled(false)
 return panel
end
