local S=STALKER_INV
local OPS={create=0,put=1,take=2,delete=3,move=4,takeall=5}
local UNITS_TO_M=0.01905
function S.StashAct(op,id,index,target)
    if (S.PendingUntil or 0)>RealTime() then return end
    S.PendingUntil=RealTime()+1
    net.Start("stalker_stash.action");net.WriteUInt(OPS[op],3);net.WriteUInt(S.Inventory.revision or 0,32)
    net.WriteString(id or "");net.WriteUInt(index or 0,6);net.WriteUInt(target or 0,6);net.SendToServer()
end
local function stashPos(stash) return Vector(stash.pos.x,stash.pos.y,stash.pos.z) end
function S.GetStash(id) return S.Inventory.stashes and S.Inventory.stashes[id or ""] end
-- Стабильная нумерация: UID начинается со времени создания.
function S.SortedStashes()
    local list={}
    for id,stash in pairs(S.Inventory.stashes or {}) do list[#list+1]={id=id,stash=stash} end
    table.sort(list,function(a,b) return a.id<b.id end)
    return list
end
function S.StashNumber(id)
    for i,v in ipairs(S.SortedStashes()) do if v.id==id then return i end end
    return 0
end
local function stashDistance(stash)
    local ply=LocalPlayer();if not IsValid(ply) or stash.map~=game.GetMap() then return end
    return ply:GetPos():Distance(stashPos(stash))
end

-- Окно тайника: открывается справа от рюкзака, предметы переносятся перетаскиванием.
local W={}
function W:Init()
    self:SetSize(S.Px(S.StashWidth),S.Px(600));self:MakePopup();self:SetKeyboardInputEnabled(false)
    self:SetAlpha(0);self:AlphaTo(255,.18,0);self.Slots={}
    S.Button(self,"×",250,22,34,34,function() self:Remove() end)
    self.Body=vgui.Create("DPanel",self);self.Body:SetPos(S.Px(22),S.Px(124));self.Body:SetSize(S.Px(256),S.Px(388))
    self.Body.Paint=function(_,w,h)
        local stash=self:GetStash()
        S.Text("ТАЙНИК / "..(stash and table.Count(stash.items) or 0).." ИЗ "..S.Config.StashSlots,"SI.Title",0,0,S.C.muted)
        S.Text("Перетащите предмет из рюкзака","SI.Small",0,S.Px(352),S.C.muted)
        S.Text("2× ЛКМ / ПКМ — забрать в рюкзак","SI.Small",0,S.Px(370),S.C.muted)
    end
    -- Отпускание на фоне тайника — положить в первую свободную ячейку (со стакованием).
    S.DropAreas[self]=function(src)
        if src.Zone=="grid" then S.StashAct("put",self.StashID,src.Index,0)
        elseif src.Zone~="stash" then S.Notify("Сначала переместите предмет в рюкзак") end
    end
    self.TakeAll=S.Button(self,"Забрать всё",16,524,268,56,function() S.StashAct("takeall",self.StashID) end)
end
function W:Setup(id)
    self.StashID=id
    for i=1,S.Config.StashSlots do
        local slot=S.MakeSlot(self.Body,"stash",i,((i-1)%4)*64,28+math.floor((i-1)/4)*64,62);slot.StashID=id;self.Slots[i]=slot
    end
end
function W:GetStash() return S.GetStash(self.StashID) end
function W:Paint(w,h)
    local c=S.C;STALKER_STYLE.Frame("stalker_inv",w,h)
    S.PaintPanel(S.Px(16),S.Px(16),S.Px(268),S.Px(54),false,true)
    local stash=self:GetStash()
    S.Text(S.FitText("ЛИЧНЫЙ ТАЙНИК #"..S.StashNumber(self.StashID),"SI.Title",S.Px(218)),"SI.Title",S.Px(28),S.Px(22),c.accent)
    S.Text("ДОСТУП: ТОЛЬКО ВЛАДЕЛЕЦ","SI.Small",S.Px(28),S.Px(51),c.muted)
    local dist=stash and stashDistance(stash) or 0
    local ratio=1-math.Clamp(dist/S.Config.StashRange,0,1)
    S.PaintPanel(S.Px(16),S.Px(80),S.Px(268),S.Px(32))
    S.Text("ДИСТАНЦИЯ","SI.Small",S.Px(24),S.Px(85),c.muted)
    S.Text(string.format("%.1f м",dist*UNITS_TO_M),"SI.Small",S.Px(276),S.Px(85),ratio<.2 and c.danger or c.text,TEXT_ALIGN_RIGHT)
    STALKER_STYLE.Bar(S.Px(24),S.Px(100),S.Px(252),S.Px(5),ratio,ratio<.2 and c.danger or c.ok)
end
function W:Think()
    local ply=LocalPlayer();local stash=self:GetStash()
    if not IsValid(S.Frame) or not IsValid(ply) or not ply:Alive() then self:Remove();return end
    if not stash then self:Remove();return end
    local dist=stashDistance(stash)
    if not dist or dist>S.Config.StashRange+24 then S.Notify("Вы отошли от тайника");self:Remove();return end
    self.TakeAll:SetEnabled(next(stash.items)~=nil)
end
function W:OnRemove()
    S.DropAreas[self]=nil;S.HideTooltip()
    if S.Drag and IsValid(S.Drag.source) and S.Drag.source.Zone=="stash" then S.CancelDrag() end
    if S.StashFrame==self then S.StashFrame=nil end
end
vgui.Register("STALKERStash",W,"EditablePanel")
function S.OpenStash(id)
    if not S.GetStash(id) then return end
    S.Close();S.Open(id)
end
net.Receive("stalker_stash.open",function()
    local id=net.ReadString();if IsValid(S.Manager) then S.Manager:Remove() end
    -- Синхронизация отправлена сервером перед этим сообщением.
    S.OpenStash(id)
end)

-- Менеджер тайников: список, создание, удаление и открытие ближайшего.
local M={}
function M:Init()
    self:SetSize(S.Px(560),S.Px(440));self:Center();self:MakePopup();self:SetKeyboardInputEnabled(false)
    self:SetAlpha(0);self:AlphaTo(255,.18,0)
    S.Button(self,"×",510,22,34,34,function() self:Remove() end)
    self.Create=S.Button(self,"Создать тайник под прицелом",16,80,528,40,function() S.StashAct("create") end)
    self.List=vgui.Create("DScrollPanel",self);self.List:SetPos(S.Px(16),S.Px(132));self.List:SetSize(S.Px(528),S.Px(250))
    STALKER_STYLE.Scroll(self.List)
    self:Rebuild()
end
function M:Paint(w,h)
    local c=S.C;STALKER_STYLE.Frame("stalker_inv",w,h)
    S.PaintPanel(S.Px(16),S.Px(16),S.Px(528),S.Px(54),false,true)
    S.Text("ЛИЧНЫЕ ТАЙНИКИ","SI.Title",S.Px(28),S.Px(22),c.accent)
    S.Text(string.format("%d ИЗ %d / %d ЯЧЕЕК / ДОСТУП ТОЛЬКО ВЛАДЕЛЬЦУ",table.Count(S.Inventory.stashes or {}),S.Config.MaxStashes,S.Config.StashSlots),"SI.Small",S.Px(28),S.Px(51),c.muted)
    if not next(S.Inventory.stashes or {}) then S.Text("Тайников нет. Наведите прицел на пол рядом и нажмите «Создать».","SI.Body",S.Px(24),S.Px(148),c.muted) end
    S.Text("Подойдите к тайнику и нажмите E, чтобы открыть его. Удалить можно только пустой тайник.","SI.Small",S.Px(24),S.Px(400),c.muted)
end
function M:Rebuild()
    self.List:Clear();self.Rows={}
    for i,v in ipairs(S.SortedStashes()) do
        local id,stash=v.id,v.stash
        local row=vgui.Create("DPanel",self.List);row:Dock(TOP);row:SetTall(S.Px(58));row:DockMargin(0,0,S.Px(10),S.Px(6))
        row.Paint=function(_,w,h)
            local current=S.GetStash(id);if not current then return end
            local dist=stashDistance(current)
            S.PaintPanel(0,0,w,h,dist and dist<=S.Config.StashRange)
            S.Text("ТАЙНИК #"..i,"SI.Mono",S.Px(12),S.Px(8),S.C.accent)
            S.Text(table.Count(current.items).." / "..S.Config.StashSlots.." ячеек","SI.Small",S.Px(12),S.Px(34),S.C.text)
            local status=not dist and ("Другая карта: "..current.map) or (dist<=S.Config.StashRange and "Рядом" or string.format("%.0f м",dist*UNITS_TO_M))
            S.Text(S.FitText(status,"SI.Small",S.Px(170)),"SI.Small",S.Px(130),S.Px(34),dist and dist<=S.Config.StashRange and S.C.ok or S.C.muted)
        end
        row.Open=S.Button(row,"Открыть",300,10,104,38,function() S.OpenStash(id);if IsValid(self) then self:Remove() end end)
        row.Delete=S.Button(row,"Удалить",410,10,104,38,function()
            Derma_Query("Удалить пустой тайник #"..i.."?","Личный тайник","Удалить",function() S.StashAct("delete",id) end,"Отмена")
        end)
        row.Think=function()
            local current=S.GetStash(id);if not current then return end
            local dist=stashDistance(current);local near=dist~=nil and dist<=S.Config.StashRange
            row.Open:SetEnabled(near);row.Delete:SetEnabled(near and next(current.items)==nil)
        end
    end
    self.Create:SetEnabled(table.Count(S.Inventory.stashes or {})<S.Config.MaxStashes)
end
function M:Think()
    local ply=LocalPlayer()
    if gui.IsGameUIVisible() or not IsValid(ply) or not ply:Alive() or S.IsUnconscious(ply) then self:Remove() end
end
function M:OnRemove() if S.Manager==self then S.Manager=nil end end
vgui.Register("STALKERStashManager",M,"EditablePanel")
function S.OpenStashManager()
    if IsValid(S.Manager) then S.Manager:Remove() end
    local ply=LocalPlayer();if not IsValid(ply) or not ply:Alive() or S.IsUnconscious(ply) then return end
    S.Scale=S.ComputeScale(980,620);S.CreateFonts()
    S.Manager=vgui.Create("STALKERStashManager");S.RequestSync()
end
concommand.Add("stalker_stash",function() S.OpenStashManager() end)
hook.Add("STALKER_INV_Updated","STALKER.StashUI",function()
    if IsValid(S.Manager) then S.Manager:Rebuild() end
end)

-- Метки своих тайников в мире и подсказка «E» при наведении.
surface.CreateFont("SI.Hint",{font="Tahoma",size=15,weight=700,extended=true})
surface.CreateFont("SI.HintSmall",{font="Tahoma",size=12,weight=500,extended=true})
hook.Add("HUDPaint","STALKER.StashMarkers",function()
    local ply=LocalPlayer();if not IsValid(ply) or not ply:Alive() or IsValid(S.Frame) or IsValid(S.Manager) then return end
    local looked=S.FindStashInView(ply)
    for _,ent in ipairs(ents.FindByClass("stalker_stash")) do
        if ent:GetStashOwner()==ply then
            local dist=ply:GetPos():Distance(ent:GetPos())
            if dist<600 then
                local screen=(ent:GetPos()+Vector(0,0,ent:OBBMaxs().z+10)):ToScreen()
                if screen.visible then
                    if ent==looked then
                        draw.SimpleTextOutlined("E — открыть тайник","SI.Hint",screen.x,screen.y,S.C.accent,TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,Color(0,0,0,200))
                        draw.SimpleTextOutlined(ent:GetItemCount().." / "..S.Config.StashSlots.." ячеек","SI.HintSmall",screen.x,screen.y+2,S.C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,Color(0,0,0,200))
                    else
                        local alpha=math.Clamp(255*(1-dist/600),40,200)
                        draw.SimpleTextOutlined("ТАЙНИК","SI.HintSmall",screen.x,screen.y,ColorAlpha(S.C.accent,alpha),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,Color(0,0,0,alpha*.8))
                    end
                end
            end
        end
    end
end)
