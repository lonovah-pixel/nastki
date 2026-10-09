local S=STALKER_INV
local PANEL={}
function PANEL:Init()
    self:SetMouseInputEnabled(true);self:SetCursor("hand");self.HoverAlpha=0;S.Slots[self]=true
end
function PANEL:Setup(zone,index,label) self.Zone=zone;self.Index=index;self.Label=label end
function PANEL:GetItem()
    local item=S.GetAt(S.Inventory,self.Zone,self.Index)
    if item and S.ActiveTab=="Артефакты" and self.Zone=="grid" and S.Items[item.id].category~="artifact" then return end
    return item
end
function PANEL:Paint(w,h)
    local item=self:GetItem();local active=self:IsHovered() or (item and S.SelectedUID==item.uid)
    self.HoverAlpha=Lerp(math.min(1,FrameTime()*14),self.HoverAlpha,active and 1 or 0)
    S.PaintPanel(0,0,w,h,active)
    if self.Zone=="equipment" and tostring(self.Index):find("artifact",1,true) then
        surface.SetDrawColor(74,122,58,22);surface.DrawRect(1,1,w-2,h-2)
    end
    surface.SetDrawColor(200,169,81,20*self.HoverAlpha);surface.DrawRect(1,1,w-2,h-2)
    S.DrawBrassFrame(0,0,w,h,active)
    if item then
        S.DrawItemIcon(item,S.Px(6),S.Px(8),w-S.Px(12),h-S.Px(18))
        if item.count>1 then S.Text("x"..item.count,"SI.Small",w-S.Px(4),S.Px(3),S.C.text,TEXT_ALIGN_RIGHT) end
        surface.SetDrawColor(S.C.background);surface.DrawRect(S.Px(5),h-S.Px(7),w-S.Px(10),S.Px(3))
        surface.SetDrawColor(item.durability<25 and S.C.danger or S.C.ok)
        surface.DrawRect(S.Px(5),h-S.Px(7),(w-S.Px(10))*item.durability/100,S.Px(3))
    elseif self.Label then
        local lines=S.Wrap(self.Label,"SI.Small",w-S.Px(8))
        for i=1,math.min(3,#lines) do S.Text(lines[i],"SI.Small",w/2,h/2+S.Px((i-(math.min(3,#lines)+1)/2)*12),S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end
    end
    if self.Zone=="quickbar" then S.Text(tostring(self.Index),"SI.Small",S.Px(3),S.Px(2),S.C.accent) end
    S.DrawNoise(0,0,w,h)
end
function PANEL:OnCursorEntered() self.HoverStart=RealTime() end
function PANEL:OnCursorExited() self.HoverStart=nil;S.HideTooltip() end
function PANEL:Think()
    if self.HoverStart and RealTime()-self.HoverStart>.45 then S.ShowTooltip(self);self.HoverStart=nil end
end
function PANEL:OnMousePressed(code)
    local item=self:GetItem()
    if not item then return end
    S.SelectedUID=item.uid;if IsValid(S.Frame) then S.Frame:RefreshDetail() end
    if code==MOUSE_RIGHT then
        S.CancelDrag();S.HideTooltip()
        local m=DermaMenu()
        m:AddOption("Использовать / экипировать",function() S.SendAction("use",self.Zone,self.Index) end)
        m:AddOption("Выбросить стак",function() S.SendAction("drop",self.Zone,self.Index) end)
        if S.Items[item.id].salvage then m:AddOption("Разобрать",function() S.ConfirmDisassemble(self.Zone,self.Index) end) end
        if self.Zone=="quickbar" then m:AddOption("Убрать из быстрого доступа",function() S.SendAction("unbind",self.Zone,self.Index) end) end
        m:Open();return
    end
    if code~=MOUSE_LEFT then return end
    if self.LastClick and RealTime()-self.LastClick<.28 then
        self.LastClick=nil;S.CancelDrag();S.SendAction("use",self.Zone,self.Index)
    else self.LastClick=RealTime();S.BeginDrag(self) end
end
function PANEL:OnMouseReleased(code) if code==MOUSE_LEFT then S.EndDrag() end end
function PANEL:OnRemove() S.Slots[self]=nil end
vgui.Register("DSLot",PANEL,"DPanel")
local EQUIP={}
function EQUIP:Init() self.IsEquipment=true end
vgui.Register("DEquipmentSlot",EQUIP,"DSLot")
function S.MakeSlot(parent,zone,index,x,y,size,label)
    local p=vgui.Create(zone=="equipment" and "DEquipmentSlot" or "DSLot",parent)
    p:Setup(zone,index,label);p:SetPos(S.Px(x),S.Px(y));p:SetSize(S.Px(size),S.Px(size));return p
end
function S.ConfirmDisassemble(zone,index)
    local item=S.GetAt(S.Inventory,zone,index);if not item then return end
    local uid=item.uid
    Derma_Query("Разобрать «"..S.Items[item.id].name.."»? Предмет будет израсходован.","Разбор предмета",
        "Разобрать",function() local current=S.GetAt(S.Inventory,zone,index);if current and current.uid==uid then S.SendAction("disassemble",zone,index) end end,"Отмена")
end
