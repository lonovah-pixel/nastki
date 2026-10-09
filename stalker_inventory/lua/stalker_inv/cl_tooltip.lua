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
-- Подсказка — отдельная панель поверх всех окон: работает и для рюкзака, и для окна тайника.
function S.ShowTooltip(slot)
    if S.Drag or not IsValid(S.Frame) then return end
    local item=slot:GetItem();if not item then return end
    S.HideTooltip();local p=vgui.Create("STALKERTooltip");p:SetItem(item);p:SetDrawOnTop(true)
    local x,y=gui.MouseX()+16,gui.MouseY()+16
    if x+p:GetWide()>ScrW() then x=gui.MouseX()-16-p:GetWide() end
    if y+p:GetTall()>ScrH() then y=ScrH()-p:GetTall() end
    p:SetPos(math.max(0,x),math.max(0,y))
    S.Tooltip=p
end
