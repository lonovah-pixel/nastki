local S=STALKER_INV
local PANEL={}
function PANEL:Init() self:SetMouseInputEnabled(false);self:SetKeyboardInputEnabled(false) end
function PANEL:SetItem(item)
    self.Item=item;local d=S.Items[item.id];self.Lines=S.Wrap(d.description,"SI.Body",S.Px(250))
    self:SetSize(S.Px(274),S.Px(78+#self.Lines*17+table.Count(d.stats)*18))
end
function PANEL:Paint(w,h)
    if not self.Item then return end
    local d=S.Items[self.Item.id]
    S.PaintPanel(0,0,w,h,true);S.DrawBrassFrame(0,0,w,h,true)
    S.Text(S.FitText(d.name,"SI.Title",w-S.Px(24)),"SI.Title",S.Px(12),S.Px(8),S.C.accent)
    S.Text(string.format("%.2f kg × %d  |  %d%%",d.weight,self.Item.count,self.Item.durability),"SI.Small",S.Px(12),S.Px(37))
    local y=S.Px(59)
    for _,line in ipairs(self.Lines) do S.Text(line,"SI.Body",S.Px(12),y);y=y+S.Px(17) end
    for key,value in SortedPairs(d.stats) do S.Text((S.StatNames[key] or key)..": "..value,"SI.Small",S.Px(12),y,S.C.muted);y=y+S.Px(18) end
end
vgui.Register("STALKERTooltip",PANEL,"DPanel")
function S.HideTooltip() if IsValid(S.Tooltip) then S.Tooltip:Remove() end;S.Tooltip=nil end
function S.ShowTooltip(slot)
    if S.Drag or not IsValid(S.Frame) then return end
    local item=slot:GetItem();if not item then return end
    S.HideTooltip();local p=vgui.Create("STALKERTooltip",S.Frame);p:SetItem(item);p:SetZPos(10000)
    p:SetDrawOnTop(true);local x,y=S.Frame:ScreenToLocal(gui.MouseX()+16,gui.MouseY()+16)
    p:SetPos(math.Clamp(x,0,math.max(0,S.Frame:GetWide()-p:GetWide())),math.Clamp(y,0,math.max(0,S.Frame:GetTall()-p:GetTall())))
    S.Tooltip=p
end
