local S=STALKER_INV
S.Slots={}
function S.CancelDrag()
    if S.Drag and IsValid(S.Drag.source) then S.Drag.source:MouseCapture(false);S.Drag.source:SetCursor("hand") end
    S.Drag=nil
end
function S.BeginDrag(slot)
    local item=slot:GetItem();if not item then return end
    S.HideTooltip();S.Drag={source=slot,item=table.Copy(item),x=gui.MouseX(),y=gui.MouseY(),active=false}
    slot:MouseCapture(true);slot:SetCursor("hand")
end
function S.EndDrag()
    local d=S.Drag;if not d then return end
    if d.active and IsValid(d.source) then
        local mx,my=gui.MousePos()
        -- MouseCapture удерживает hovered panel на источнике: цель ищем по геометрии.
        for panel in pairs(S.Slots) do if IsValid(panel) and panel:IsVisible() and panel.TargetEnabled~=false then
            local x,y=panel:LocalToScreen(0,0)
            if mx>=x and my>=y and mx<x+panel:GetWide() and my<y+panel:GetTall() then
                S.SendAction("move",d.source.Zone,d.source.Index,panel.Zone,panel.Index);break
            end
        end end
    end
    S.CancelDrag()
end
hook.Add("Think","STALKER_INV.Drag",function()
    local d=S.Drag;if not d then return end
    if not IsValid(d.source) or not IsValid(S.Frame) then S.CancelDrag();return end
    if math.abs(gui.MouseX()-d.x)+math.abs(gui.MouseY()-d.y)>S.Px(5) then d.active=true end
    if not input.IsMouseDown(MOUSE_LEFT) then S.EndDrag() end
end)
hook.Add("PostRenderVGUI","STALKER_INV.Ghost",function()
    local d=S.Drag;if not d or not d.active then return end
    local size=S.Px(56);local x,y=gui.MouseX()-size/2,gui.MouseY()-size/2
    surface.SetDrawColor(28,26,20,215);surface.DrawRect(x,y,size,size);S.DrawBrassFrame(x,y,size,size,true)
    S.DrawItemIcon(d.item,x,y,size,size)
end)
