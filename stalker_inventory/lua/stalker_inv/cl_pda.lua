local S=STALKER_INV
function S.BuildPDA(parent)
    local p=vgui.Create("DPanel",parent);p:SetPos(S.Px(208),S.Px(124));p:SetSize(S.Px(512),S.Px(388));p:SetVisible(false)
    p.Paint=function(_,w,h)
        S.PaintPanel(0,0,w,h);S.DrawBrassFrame(0,0,w,h)
        if S.ActiveTab=="Карта" then
            S.Text("КАРТА / "..game.GetMap(),"SI.Title",S.Px(16),S.Px(12),S.C.accent)
            local path=S.Config.MapMaterials[game.GetMap()]
            if path then
                p.Map=p.Map or Material(path,"smooth")
                if not p.Map:IsError() then surface.SetMaterial(p.Map);surface.SetDrawColor(255,255,255);surface.DrawTexturedRect(S.Px(16),S.Px(54),w-S.Px(32),h-S.Px(70));return end
            end
            if STFW and STFW.State and next(STFW.State.points) then
                local minx,maxx,miny,maxy=math.huge,-math.huge,math.huge,-math.huge
                for _,point in pairs(STFW.State.points) do minx=math.min(minx,point.pos.x);maxx=math.max(maxx,point.pos.x);miny=math.min(miny,point.pos.y);maxy=math.max(maxy,point.pos.y) end
                surface.SetDrawColor(99,116,71,35);for gx=S.Px(16),w-S.Px(16),S.Px(32) do surface.DrawLine(gx,S.Px(54),gx,h-S.Px(18)) end
                for _,point in pairs(STFW.State.points) do
                    local x=S.Px(48)+(point.pos.x-minx)/math.max(1,maxx-minx)*(w-S.Px(96));local y=h-S.Px(54)-(point.pos.y-miny)/math.max(1,maxy-miny)*(h-S.Px(140))
                    surface.SetDrawColor(S.C.accent);surface.DrawRect(x-S.Px(3),y-S.Px(3),S.Px(6),S.Px(6));S.Text(S.FitText(point.name,"SI.Small",S.Px(130)),"SI.Small",x,y+S.Px(8),S.C.text,TEXT_ALIGN_CENTER)
                end
                return
            end
            S.Text("Картографические данные не установлены.","SI.Body",S.Px(16),S.Px(68))
            S.Text("Текущий сектор: "..game.GetMap(),"SI.Small",S.Px(16),S.Px(102),S.C.muted)
        else
            S.Text("PDA / ЛИЧНЫЙ ЖУРНАЛ","SI.Title",S.Px(16),S.Px(12),S.C.accent)
            local lines={"Соединение установлено.","Позывной: "..LocalPlayer():Nick(),"Сектор: "..game.GetMap(),
                "Масса груза: "..string.format("%.2f kg",S.Weight(S.Inventory)),"", "TAB — инвентарь", "ALT + 1–9 — быстрый доступ", "ПКМ по фону — удерживать для обзора"}
            for i,line in ipairs(lines) do S.Text(S.FitText(line,"SI.Body",w-S.Px(32)),"SI.Body",S.Px(16),S.Px(52+i*27),S.C.text) end
            hook.Run("STALKER_INV_DrawPDA",p,w,h)
        end
    end
    return p
end
