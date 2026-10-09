local S=STALKER_INV
local frame,selection
local function act(op,id,index)
 net.Start("stalker_stash.action");net.WriteUInt(op,2);net.WriteUInt(S.Inventory.revision or 0,32);net.WriteString(id or "");net.WriteUInt(index or 0,6);net.SendToServer()
end
local function rebuild()
 if not IsValid(frame) then return end
 frame.Body:Clear()
 local function button(parent,label,fn)
  local b=vgui.Create("DButton",parent);b:Dock(TOP);b:SetTall(34);b:DockMargin(0,0,0,4);b:SetText(label);b.DoClick=fn
 end
 button(frame.Body,"Создать тайник под прицелом (до 3 тайников / 20 ячеек)",function() act(0) end)
 local select=vgui.Create("DComboBox",frame.Body);select:Dock(TOP);select:SetTall(34);select:SetValue("Выберите личный тайник")
 for id,stash in pairs(S.Inventory.stashes or {}) do
  local dist=math.floor(LocalPlayer():GetPos():Distance(Vector(stash.pos.x,stash.pos.y,stash.pos.z)))
  local label=stash.map.." / "..dist.." units / "..table.Count(stash.items).." из 20"
  select:AddChoice(label,id,id==selection)
 end
 select.OnSelect=function(_,_,_,id) selection=id;rebuild() end
 local stash=(S.Inventory.stashes or {})[selection or ""];if not stash then return end
 button(frame.Body,"Удалить пустой тайник",function() act(3,selection) end)
 local left=vgui.Create("DScrollPanel",frame.Body);left:Dock(LEFT);left:SetWide(math.floor(frame:GetWide()/2)-25)
 local right=vgui.Create("DScrollPanel",frame.Body);right:Dock(FILL)
 for slot,item in SortedPairs(S.Inventory.grid) do local index=slot
  button(left,"Убрать: "..S.Items[item.id].name.." ×"..item.count,function() act(1,selection,index) end)
 end
 for slot,item in SortedPairs(stash.items) do local index=slot
  button(right,"Забрать: "..S.Items[item.id].name.." ×"..item.count,function() act(2,selection,index) end)
 end
end
concommand.Add("stalker_stash",function()
 if IsValid(frame) then frame:Remove() end
 frame=vgui.Create("DFrame");frame:SetSize(math.min(860,ScrW()-40),math.min(560,ScrH()-40));frame:Center();frame:SetTitle("Личные тайники — доступ только владельцу, в пределах 150 units");frame:MakePopup()
 frame.Body=vgui.Create("DPanel",frame);frame.Body:Dock(FILL);rebuild();S.RequestSync()
end)
hook.Add("STALKER_INV_Updated","STALKER.StashUI",rebuild)
hook.Add("HUDPaint","STALKER.StashMarkers",function()
 for _,stash in pairs(S.Inventory.stashes or {}) do if stash.map==game.GetMap() then
  local pos=Vector(stash.pos.x,stash.pos.y,stash.pos.z)
  if LocalPlayer():GetPos():DistToSqr(pos)<600^2 then local screen=(pos+Vector(0,0,12)):ToScreen()
   if screen.visible then draw.SimpleText("Личный тайник","DermaDefaultBold",screen.x,screen.y,Color(220,190,90),TEXT_ALIGN_CENTER) end
  end
 end end
end)
