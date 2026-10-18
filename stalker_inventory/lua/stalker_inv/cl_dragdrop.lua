local S=STALKER_INV
S.Slots={}
-- Панели, принимающие предмет при отпускании мимо конкретной ячейки (фон рюкзака / тайника).
S.DropAreas=S.DropAreas or {}
function S.Notify(message)
    notification.AddLegacy(message,NOTIFY_ERROR,3);surface.PlaySound("buttons/button10.wav")
end
function S.CancelDrag()
    if S.Drag and IsValid(S.Drag.source) then S.Drag.source:MouseCapture(false);S.Drag.source:SetCursor("hand") end
    S.Drag=nil
end
function S.BeginDrag(slot)
    local item=slot:GetItem();if not item then return end
    S.HideTooltip();S.Drag={source=slot,item=table.Copy(item),x=gui.MouseX(),y=gui.MouseY(),active=false}
    slot:MouseCapture(true);slot:SetCursor("hand")
end
local function inside(panel,mx,my)
    if not IsValid(panel) or not panel:IsVisible() then return false end
    local x,y=panel:LocalToScreen(0,0)
    return mx>=x and my>=y and mx<x+panel:GetWide() and my<y+panel:GetTall()
end
-- Перенос между рюкзаком, экипировкой, хотбаром и окном тайника.
function S.HandleDrop(src,dst)
    if src==dst then return end
    -- Чужой тайник по наводке: только забирать в рюкзак.
    if dst.Zone=="foreign" then if src.Zone~="foreign" then S.Notify("В чужой тайник ничего положить нельзя") end;return end
    if src.Zone=="foreign" then
        if dst.Zone=="grid" then S.LootAct(src.IntelID,src.Index) else S.Notify("Из чужого тайника предмет можно забрать только в рюкзак") end
        return
    end
    local fromStash,toStash=src.Zone=="stash",dst.Zone=="stash"
    if not fromStash and not toStash then S.SendAction("move",src.Zone,src.Index,dst.Zone,dst.Index);return end
    if fromStash and toStash then
        if src.StashID==dst.StashID then S.StashAct("move",src.StashID,src.Index,dst.Index) end
        return
    end
    if fromStash then
        if dst.Zone=="grid" then S.StashAct("take",src.StashID,src.Index,dst.Index)
        else S.Notify("Из тайника предмет можно переложить только в рюкзак") end
        return
    end
    if src.Zone=="grid" then S.StashAct("put",dst.StashID,src.Index,dst.Index)
    else S.Notify("Сначала переместите предмет в рюкзак") end
end
function S.EndDrag()
    local d=S.Drag;if not d then return end
    if d.active and IsValid(d.source) then
        local mx,my=gui.MousePos();local target
        -- MouseCapture удерживает hovered panel на источнике: цель ищем по геометрии.
        for panel in pairs(S.Slots) do
            if panel.TargetEnabled~=false and inside(panel,mx,my) then target=panel;break end
        end
        if target then S.HandleDrop(d.source,target)
        else
            for area,fn in pairs(S.DropAreas) do
                if inside(area,mx,my) then fn(d.source);break end
            end
        end
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
    S.SetColor(S.C.background,215);surface.DrawRect(x,y,size,size);S.DrawBrassFrame(x,y,size,size,true)
    S.DrawItemIcon(d.item,x,y,size,size)
    if d.item.count>1 then S.Text("x"..d.item.count,"SI.Small",x+size-S.Px(4),y+S.Px(3),S.C.text,TEXT_ALIGN_RIGHT) end
end)
