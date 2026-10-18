local S=STALKER_INV
local PANEL={}
function PANEL:Init()
    self:SetMouseInputEnabled(true);self:SetCursor("hand");self.HoverAlpha=0;S.Slots[self]=true
end
function PANEL:Setup(zone,index,label) self.Zone=zone;self.Index=index;self.Label=label end
function PANEL:GetItem()
    if self.Zone=="stash" then
        local stash=S.Inventory.stashes and S.Inventory.stashes[self.StashID]
        return stash and stash.items[self.Index]
    end
    if self.Zone=="foreign" then
        local f=S.Foreign;return f and f.intel==self.IntelID and f.items[self.Index] or nil
    end
    local item=S.GetAt(S.Inventory,self.Zone,self.Index)
    if item and S.ActiveTab=="Артефакты" and self.Zone=="grid" and S.Items[item.id].category~="artifact" then return end
    return item
end
function PANEL:Paint(w,h)
    local item=self:GetItem();local active=self:IsHovered() or (item and S.SelectedUID==item.uid)
    -- Подсветка ячейки под курсором во время перетаскивания.
    local d=S.Drag;local dropTarget=d and d.active and d.source~=self and self:IsVisible() and self.TargetEnabled~=false
    if dropTarget then
        local mx,my=gui.MousePos();local x,y=self:LocalToScreen(0,0)
        dropTarget=mx>=x and my>=y and mx<x+w and my<y+h
        active=active or dropTarget
    end
    self.HoverAlpha=Lerp(math.min(1,FrameTime()*14),self.HoverAlpha,active and 1 or 0)
    S.PaintPanel(0,0,w,h,active)
    if self.Zone=="equipment" and tostring(self.Index):find("artifact",1,true) then
        S.SetColor(S.C.ok,22);surface.DrawRect(1,1,w-2,h-2)
    end
    S.SetColor(S.C.accent,(dropTarget and 45 or 20)*self.HoverAlpha);surface.DrawRect(1,1,w-2,h-2)
    S.DrawBrassFrame(0,0,w,h,active)
    if item then
        if d and d.active and d.source==self then S.SetColor(S.C.shadow,120);surface.DrawRect(1,1,w-2,h-2) end
        S.DrawItemIcon(item,S.Px(6),S.Px(8),w-S.Px(12),h-S.Px(18))
        if item.count>1 then S.Text("x"..item.count,"SI.Small",w-S.Px(4),S.Px(3),S.C.text,TEXT_ALIGN_RIGHT) end
        S.SetColor(S.C.track);surface.DrawRect(S.Px(5),h-S.Px(7),w-S.Px(10),S.Px(3))
        S.SetColor(S.ConditionColor(item.durability))
        surface.DrawRect(S.Px(5),h-S.Px(7),(w-S.Px(10))*math.Clamp(item.durability,0,100)/100,S.Px(3))
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
local function stashOpen() return IsValid(S.StashFrame) and S.StashFrame.StashID end
function PANEL:OnMousePressed(code)
    local item=self:GetItem()
    if not item then return end
    if self.Zone~="foreign" then S.SelectedUID=item.uid;if IsValid(S.Frame) then S.Frame:RefreshDetail() end end
    if code==MOUSE_RIGHT then
        S.CancelDrag();S.HideTooltip()
        local m=DermaMenu()
        if self.Zone=="stash" then
            m:AddOption("Забрать в рюкзак",function() S.StashAct("take",self.StashID,self.Index,0) end)
            m:Open();return
        end
        if self.Zone=="foreign" then
            m:AddOption("Забрать в рюкзак",function() S.LootAct(self.IntelID,self.Index) end)
            m:Open();return
        end
        local d=S.Items[item.id]
        local equipped=select(2,S.FindUID(S.Inventory,item.uid))=="equipment"
        m:AddOption(equipped and not d.weapon and "Снять" or (equipped and "Взять в руки" or "Использовать / экипировать"),function() S.SendAction("use",self.Zone,self.Index) end)
        if self.Zone=="grid" and stashOpen() then
            m:AddOption("Положить в тайник",function() if stashOpen() then S.StashAct("put",S.StashFrame.StashID,self.Index,0) end end)
        end
        m:AddOption("Выбросить стак",function() S.SendAction("drop",self.Zone,self.Index) end)
        if d.salvage and S.Config.AllowDisassemble then m:AddOption("Разобрать",function() S.ConfirmDisassemble(self.Zone,self.Index) end) end
        if self.Zone=="quickbar" then m:AddOption("Убрать из быстрого доступа",function() S.SendAction("unbind",self.Zone,self.Index) end) end
        m:Open();return
    end
    if code~=MOUSE_LEFT then return end
    if self.LastClick and RealTime()-self.LastClick<.28 then
        self.LastClick=nil;S.CancelDrag()
        if self.Zone=="stash" then S.StashAct("take",self.StashID,self.Index,0)
        elseif self.Zone=="foreign" then S.LootAct(self.IntelID,self.Index)
        else S.SendAction("use",self.Zone,self.Index) end
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
