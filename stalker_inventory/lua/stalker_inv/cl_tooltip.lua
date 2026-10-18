local S=STALKER_INV
local PANEL={}
function PANEL:Init() self:SetMouseInputEnabled(false);self:SetKeyboardInputEnabled(false) end
-- Высота считается заранее: описание переносится, характеристики — по строке с полосой.
function PANEL:SetItem(item)
    self.Item=item;local d=S.Items[item.id]
    self.Lines=S.Wrap(d.description,"SI.Body",S.Px(250))
    self.Stats=S.ItemStats(item,d)
    self:SetSize(S.Px(274),S.Px(84+#self.Lines*17+#self.Stats*20))
end
function PANEL:Paint(w,h)
    if not self.Item then return end
    local d=S.Items[self.Item.id];if not d then return end
    S.PaintPanel(0,0,w,h,true);S.DrawBrassFrame(0,0,w,h,true)
    S.Text(S.FitText(d.name,"SI.Title",w-S.Px(24)),"SI.Title",S.Px(12),S.Px(8),S.C.accent)
    S.Text(S.FitText((S.CategoryNames[d.category] or d.category).." · "..string.format("%.2f кг",d.weight)..(self.Item.count>1 and (" × "..self.Item.count) or ""),"SI.Small",w-S.Px(90)),"SI.Small",S.Px(12),S.Px(37),S.C.muted)
    S.Text("Состояние "..self.Item.durability.."%","SI.Small",w-S.Px(12),S.Px(37),S.ConditionColor(self.Item.durability),TEXT_ALIGN_RIGHT)
    S.SetColor(S.C.track);surface.DrawRect(S.Px(12),S.Px(52),w-S.Px(24),S.Px(2))
    S.SetColor(S.ConditionColor(self.Item.durability));surface.DrawRect(S.Px(12),S.Px(52),(w-S.Px(24))*self.Item.durability/100,S.Px(2))
    local y=S.Px(62)
    for _,line in ipairs(self.Lines) do S.Text(line,"SI.Body",S.Px(12),y);y=y+S.Px(17) end
    y=y+S.Px(6)
    for _,row in ipairs(self.Stats) do S.DrawStatRow(row,S.Px(12),y,w-S.Px(24));y=y+S.Px(20) end
end
vgui.Register("STALKERTooltip",PANEL,"DPanel")
function S.HideTooltip() if IsValid(S.Tooltip) then S.Tooltip:Remove() end;S.Tooltip=nil end
-- Подсказка — отдельная панель поверх всех окон: работает и для рюкзака, и для окна тайника.
function S.ShowTooltip(slot)
    if S.Drag or not IsValid(S.Frame) then return end
    local item=slot:GetItem();if not item or not S.Items[item.id] then return end
    S.HideTooltip();local p=vgui.Create("STALKERTooltip");p:SetItem(item);p:SetDrawOnTop(true)
    local x,y=gui.MouseX()+16,gui.MouseY()+16
    if x+p:GetWide()>ScrW() then x=gui.MouseX()-16-p:GetWide() end
    if y+p:GetTall()>ScrH() then y=ScrH()-p:GetTall() end
    p:SetPos(math.max(0,x),math.max(0,y))
    S.Tooltip=p
end
