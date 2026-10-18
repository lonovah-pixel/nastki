local S=STALKER_INV
-- Вкладка «Сводка» инвентаря: главное о персонаже, тайниках, наводках, заданиях и новостях.
-- Полный КПК (карта, сообщения, задания) открывается кнопкой — его реализует аддон stalker_pda (F4).
local function money(ply)
    local value=hook.Run("STALKER_INV_GetBalance",ply)
    if value==nil and ply.getDarkRPVar then value=ply:getDarkRPVar("money") end
    return value and (string.Comma(tonumber(value) or 0).." ₽") or "—"
end
local function meters(units) return string.format("%.0f м",units*.01905) end
-- Строки левой колонки: {подпись, значение, цвет}.
function S.SummaryRows(ply)
    local rows={}
    local C=STALKER_CORE
    local faction=C and C.Faction and C.Faction(ply)
    rows[#rows+1]={"Позывной",ply:Nick()}
    rows[#rows+1]={"Группировка",faction and C.FactionName(faction) or "Вольный сталкер"}
    rows[#rows+1]={"Сектор",game.GetMap()}
    local weight=S.Weight(S.Inventory)
    rows[#rows+1]={"Груз",string.format("%.1f / %d кг",weight,S.Config.MaxWeight)..(weight>S.Config.MaxWeight and " — перегруз" or ""),weight>S.Config.MaxWeight and S.C.danger or nil}
    rows[#rows+1]={"Счёт",money(ply)}
    local dose=S.RadiationDose(ply)
    rows[#rows+1]={"Доза радиации",string.format("%.1f",dose),S.RadiationColor(dose)}
    local own,near=0,nil
    for _,stash in pairs(S.Inventory.stashes or {}) do
        own=own+1
        if stash.map==game.GetMap() then local d=ply:GetPos():Distance(Vector(stash.pos.x,stash.pos.y,stash.pos.z));if not near or d<near then near=d end end
    end
    rows[#rows+1]={"Тайники",own.." из "..S.Config.MaxStashes..(near and (" · ближайший "..meters(near)) or "")}
    local intel=S.Intel or {}
    local best,bestD
    for _,x in ipairs(intel) do
        if x.map==game.GetMap() then local d=ply:GetPos():Distance(Vector(x.pos.x,x.pos.y,x.pos.z));if not bestD or d<bestD then best,bestD=x,d end end
    end
    rows[#rows+1]={"Наводки",#intel==0 and "нет" or (#intel..(best and (" · «"..best.owner.."» "..meters(bestD)) or "")),#intel>0 and S.C.accent or nil}
    return rows
end
function S.BuildPDA(parent)
    local p=vgui.Create("DPanel",parent);p:SetPos(S.Px(208),S.Px(124));p:SetSize(S.Px(512),S.Px(388));p:SetVisible(false)
    local C=STALKER_CORE
    local open=S.Button(p,"Открыть КПК (F4)",312,8,184,32,function() S.Close();if C and C.OpenPDA then C.OpenPDA() end end)
    open.Think=function(self) self:SetEnabled(C~=nil and C.PDAOpen~=nil) end
    p.OpenButton=open
    p.Paint=function(_,w,h)
        S.PaintPanel(0,0,w,h);S.DrawBrassFrame(0,0,w,h)
        S.Text("КПК / СВОДКА","SI.Title",S.Px(16),S.Px(12),S.C.accent)
        local ply=LocalPlayer();if not IsValid(ply) then return end
        local y=S.Px(52);local col=S.Px(236)
        for _,row in ipairs(S.SummaryRows(ply)) do
            S.Text(row[1],"SI.Small",S.Px(16),y,S.C.muted)
            S.Text(S.FitText(row[2],"SI.Body",col-S.Px(16)),"SI.Body",S.Px(16),y+S.Px(11),row[3] or S.C.text)
            y=y+S.Px(29)
        end
        -- Правая колонка: активные задания (stalker_quests) и последние новости КПК.
        local x=S.Px(264);local rw=w-x-S.Px(16);y=S.Px(52)
        S.Text("ЗАДАНИЯ","SI.Small",x,y,S.C.muted);y=y+S.Px(16)
        local quests=STALKER_QUESTS and STALKER_QUESTS.ActiveSummary and STALKER_QUESTS.ActiveSummary() or {}
        if type(quests)~="table" or #quests==0 then S.Text("Активных заданий нет","SI.Small",x,y,S.C.muted);y=y+S.Px(18)
        else
            for i=1,math.min(3,#quests) do
                local q=quests[i]
                S.Text(S.FitText(tostring(q.title or "Задание"),"SI.Body",rw-S.Px(50)),"SI.Body",x,y,S.C.text)
                if q.goal then S.Text((q.progress or 0).."/"..q.goal,"SI.Small",x+rw,y+S.Px(2),S.C.accent,TEXT_ALIGN_RIGHT)
                    STALKER_STYLE.Bar(x,y+S.Px(18),rw,S.Px(3),(tonumber(q.progress) or 0)/math.max(1,tonumber(q.goal) or 1),S.C.accent) end
                y=y+S.Px(26)
            end
        end
        y=y+S.Px(8);S.Text("НОВОСТИ","SI.Small",x,y,S.C.muted);y=y+S.Px(16)
        local feed=C and C.NewsFeed or {}
        if #feed==0 then S.Text("Лента пуста","SI.Small",x,y,S.C.muted) end
        for i=1,math.min(3,#feed) do
            local lines=S.Wrap(tostring(feed[i].text or ""),"SI.Small",rw)
            for j=1,math.min(2,#lines) do S.Text(S.FitText(lines[j],"SI.Small",rw),"SI.Small",x,y,i==1 and S.C.text or S.C.muted);y=y+S.Px(13) end
            y=y+S.Px(4)
        end
        if not (C and C.PDAOpen) then S.Text("Полный КПК недоступен на этом сервере","SI.Small",w-S.Px(16),S.Px(44),S.C.muted,TEXT_ALIGN_RIGHT) end
        -- Совместимость: аддоны дорисовывают свои строки снизу (например, «кто в сети» из stalker_zone).
        hook.Run("STALKER_INV_DrawPDA",p,w,h)
    end
    return p
end
