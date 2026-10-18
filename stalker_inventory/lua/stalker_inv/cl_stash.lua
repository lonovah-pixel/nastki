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
-- Расстояние до тайника на этой карте (у чужого тайника по наводке карты в данных нет — он всегда здесь).
local function stashDistance(stash)
    local ply=LocalPlayer();if not IsValid(ply) or not stash.pos or (stash.map and stash.map~=game.GetMap()) then return end
    return ply:GetPos():Distance(stashPos(stash))
end
S.StashDistance=stashDistance

-- Окно тайника: открывается справа от рюкзака, предметы переносятся перетаскиванием.
-- Режим Foreign — чужой тайник по наводке: только забирать (по предмету и «Забрать всё»).
local W={}
function W:Init()
    self:SetSize(S.Px(S.StashWidth),S.Px(600));self:MakePopup();self:SetKeyboardInputEnabled(false)
    self:SetAlpha(0);self:AlphaTo(255,.18,0);self.Slots={}
    S.Button(self,"×",250,22,34,34,function() self:Remove() end)
    self.Body=vgui.Create("DPanel",self);self.Body:SetPos(S.Px(22),S.Px(124));self.Body:SetSize(S.Px(256),S.Px(388))
    self.Body.Paint=function(_,w,h)
        local stash=self:GetStash();local count=stash and table.Count(stash.items) or 0
        S.Text((self.Foreign and "ЧУЖОЙ ТАЙНИК / " or "ТАЙНИК / ")..count.." ИЗ "..(self.SlotCount or 0),"SI.Title",0,0,S.C.muted)
        if self.Foreign then
            S.Text("Только забрать: перетащите в рюкзак","SI.Small",0,S.Px(352),S.C.muted)
            S.Text("2× ЛКМ / ПКМ — забрать предмет","SI.Small",0,S.Px(370),S.C.muted)
        else
            S.Text("Перетащите предмет из рюкзака","SI.Small",0,S.Px(352),S.C.muted)
            S.Text("2× ЛКМ / ПКМ — забрать в рюкзак","SI.Small",0,S.Px(370),S.C.muted)
        end
    end
    -- Отпускание на фоне тайника — положить в первую свободную ячейку (со стакованием).
    S.DropAreas[self]=function(src)
        if self.Foreign then if src.Zone~="foreign" then S.Notify("В чужой тайник ничего положить нельзя") end;return end
        if src.Zone=="grid" then S.StashAct("put",self.StashID,src.Index,0)
        elseif src.Zone~="stash" then S.Notify("Сначала переместите предмет в рюкзак") end
    end
    self.TakeAll=S.Button(self,"Забрать всё",16,524,268,56,function()
        if self.Foreign then S.LootAct(self.IntelID,0) else S.StashAct("takeall",self.StashID) end
    end)
end
-- Сетка под вместимость: до 20 ячеек — 4 колонки, больше — 6; размер ячейки подбирается под высоту.
function W:BuildSlots(zone,count,key,value)
    for _,slot in pairs(self.Slots) do if IsValid(slot) then slot:Remove() end end
    self.Slots={};self.SlotCount=count
    local cols=count>20 and 6 or 4;local rows=math.max(1,math.ceil(count/cols))
    local cell=math.min(64,math.floor(256/cols),math.floor(318/rows))
    for i=1,count do
        local slot=S.MakeSlot(self.Body,zone,i,((i-1)%cols)*cell,28+math.floor((i-1)/cols)*cell,cell-2);slot[key]=value;self.Slots[i]=slot
    end
end
function W:Setup(id)
    self.StashID=id
    self:BuildSlots("stash",S.StashSlotsOf(S.GetStash(id)),"StashID",id)
end
function W:SetupForeign(data)
    self.Foreign=true;self.IntelID=data.intel;self.Owner=data.owner
    self:BuildSlots("foreign",math.Clamp(math.floor(tonumber(data.slots) or 12),1,S.StashMaxSlots),"IntelID",data.intel)
end
function W:GetStash()
    if self.Foreign then local f=S.Foreign;return f and f.intel==self.IntelID and f or nil end
    return S.GetStash(self.StashID)
end
function W:Paint(w,h)
    local c=S.C;STALKER_STYLE.Frame("stalker_inv",w,h)
    S.PaintPanel(S.Px(16),S.Px(16),S.Px(268),S.Px(54),false,true)
    local stash=self:GetStash()
    if self.Foreign then
        S.Text(S.FitText("ТАЙНИК: "..tostring(self.Owner or "?"),"SI.Title",S.Px(218)),"SI.Title",S.Px(28),S.Px(22),c.warn)
        S.Text("ПО НАВОДКЕ / ТОЛЬКО ЗАБРАТЬ","SI.Small",S.Px(28),S.Px(51),c.muted)
    else
        S.Text(S.FitText("ЛИЧНЫЙ ТАЙНИК #"..S.StashNumber(self.StashID),"SI.Title",S.Px(218)),"SI.Title",S.Px(28),S.Px(22),c.accent)
        S.Text("ДОСТУП: ТОЛЬКО ВЛАДЕЛЕЦ","SI.Small",S.Px(28),S.Px(51),c.muted)
    end
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
    if not self.Foreign and S.StashSlotsOf(stash)~=self.SlotCount then self:Setup(self.StashID) end
    self.TakeAll:SetEnabled(next(stash.items)~=nil)
end
function W:OnRemove()
    S.DropAreas[self]=nil;S.HideTooltip()
    if S.Drag and IsValid(S.Drag.source) and (S.Drag.source.Zone=="stash" or S.Drag.source.Zone=="foreign") then S.CancelDrag() end
    if S.StashFrame==self then S.StashFrame=nil end
    if self.Foreign and S.Foreign and S.Foreign.intel==self.IntelID then S.Foreign=nil end
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
    S.Text(string.format("%d ИЗ %d / НОВЫЙ ТАЙНИК: %d ЯЧЕЕК / ДОСТУП ТОЛЬКО ВЛАДЕЛЬЦУ",table.Count(S.Inventory.stashes or {}),S.Config.MaxStashes,S.Config.StashSlots),"SI.Small",S.Px(28),S.Px(51),c.muted)
    if not next(S.Inventory.stashes or {}) then S.Text("Тайников нет. Наведите прицел на пол рядом и нажмите «Создать».","SI.Body",S.Px(24),S.Px(148),c.muted) end
    S.Text(S.FitText("Подойдите к тайнику и нажмите E, чтобы открыть его. Удалить можно только пустой тайник.","SI.Small",S.Px(512)),"SI.Small",S.Px(24),S.Px(400),c.muted)
    S.Text(S.FitText("Убийца может узнать координаты одного из ваших тайников: не храните всё в одном месте.","SI.Small",S.Px(512)),"SI.Small",S.Px(24),S.Px(416),c.warn)
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
            S.Text(table.Count(current.items).." / "..S.StashSlotsOf(current).." ячеек","SI.Small",S.Px(12),S.Px(34),S.C.text)
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

-- Метки своих тайников в мире и подсказка «E» при наведении. Обводка текста — цвет тени темы.
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
                        local slots=ent.GetSlots and ent:GetSlots() or 0;if slots<=0 then slots=S.Config.LegacyStashSlots end
                        draw.SimpleTextOutlined("E — открыть тайник","SI.Hint",screen.x,screen.y,S.C.accent,TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,S.Alpha(S.C.shadow,200))
                        draw.SimpleTextOutlined(ent:GetItemCount().." / "..slots.." ячеек","SI.HintSmall",screen.x,screen.y+2,S.C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,S.Alpha(S.C.shadow,200))
                    else
                        local alpha=math.Clamp(255*(1-dist/600),40,200)
                        draw.SimpleTextOutlined("ТАЙНИК","SI.HintSmall",screen.x,screen.y,S.Alpha(S.C.accent,alpha),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM,1,S.Alpha(S.C.shadow,alpha*.8))
                    end
                end
            end
        end
    end
end)
