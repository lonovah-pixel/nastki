local S=STALKER_INV
function S.BuildQuickbar(parent)
    local p=vgui.Create("DPanel",parent);p:SetPos(S.Px(16),S.Px(524));p:SetSize(S.Px(928),S.Px(56))
    p.Paint=function(_,w,h)
        S.PaintPanel(0,0,w,h)
        S.Text("БЫСТРЫЙ ДОСТУП","SI.Title",S.Px(12),S.Px(3),S.C.muted)
        S.Text("ALT + 1–9 / действие","SI.Small",S.Px(12),S.Px(33),S.C.muted)
        S.Text("ЗОНА ОТЧУЖДЕНИЯ","SI.Body",S.Px(718),S.Px(6),S.C.muted)
        S.Text("PDA / ONLINE","SI.Small",S.Px(718),S.Px(31),S.C.ok)
    end
    for i=1,9 do S.MakeSlot(p,"quickbar",i,198+(i-1)*56,4,48) end
    return p
end
local previous={}
hook.Add("Think","STALKER_INV.QuickKeys",function()
    for i=1,9 do
        local down=input.IsKeyDown(KEY_1+i-1)
        if down and not previous[i] and input.IsKeyDown(S.Config.QuickModifier) and not S.Chatting
            and not gui.IsGameUIVisible() and not gui.IsConsoleVisible() and not IsValid(vgui.GetKeyboardFocus()) then
            S.SendAction("use","quickbar",i)
        end
        previous[i]=down
    end
end)
hook.Add("PlayerBindPress","STALKER_INV.QuickSuppress",function(_,bind)
    if input.IsKeyDown(S.Config.QuickModifier) and bind:match("^slot[1-9]$") then return true end
end)
