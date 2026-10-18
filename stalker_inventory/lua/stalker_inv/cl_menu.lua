local S=STALKER_INV
local PANEL={}
function PANEL:Init()
    self:SetSize(S.Px(960),S.Px(600));self:Center();self:MakePopup();self:SetKeyboardInputEnabled(false)
    self:SetAlpha(0);self.Animation=Derma_Anim("STALKER.Open",self,function(panel,anim,delta) panel:SetAlpha(255*delta) end)
    self.Animation:Start(.18)
    S.ActiveTab="Рюкзак";self.Equipment=S.BuildEquipment(self);self.Quickbar=S.BuildQuickbar(self)
    self.Grid=vgui.Create("DPanel",self);self.Grid:SetPos(S.Px(208),S.Px(124));self.Grid:SetSize(S.Px(512),S.Px(388))
    self.Grid.Paint=function(_,w,h)
        local count=table.Count(S.Inventory.grid)
        S.Text((S.ActiveTab=="Артефакты" and "АРТЕФАКТЫ" or "РЮКЗАК").." / "..count.." ИЗ 40","SI.Title",0,0,S.C.muted)
        local hint=IsValid(S.StashFrame) and (S.StashFrame.Foreign and "Перетащите предмет из чужого тайника в рюкзак" or "Перетащите предмет в тайник справа или в ячейку рюкзака")
            or "Перетащите в ячейку или быстрый слот · 2×ЛКМ — действие · ПКМ — меню"
        S.Text(S.FitText(hint,"SI.Small",w),"SI.Small",0,S.Px(370),S.C.muted)
    end
    self.GridSlots={}
    for i=1,40 do self.GridSlots[i]=S.MakeSlot(self.Grid,"grid",i,((i-1)%8)*64,28+math.floor((i-1)/8)*66,62) end
    -- Предмет из тайника, отпущенный на свободное место рюкзака, кладётся в первую свободную ячейку.
    S.DropAreas[self.Grid]=function(src)
        if src.Zone=="stash" then S.StashAct("take",src.StashID,src.Index,0)
        elseif src.Zone=="foreign" then S.LootAct(src.IntelID,src.Index) end
    end
    -- «Карта» и «PDA» заменены сводкой: полный КПК открывается кнопкой на вкладке (F4).
    self.PDA=S.BuildPDA(self);self.Tabs={}
    for i,label in ipairs({"Рюкзак","Артефакты","Сводка"}) do
        local tab=vgui.Create("DToggleTab",self);tab.Label=label;tab:SetPos(S.Px(626+(i-1)*106),S.Px(80));tab:SetSize(S.Px(102),S.Px(32));tab.Active=i==1
        tab.DoClick=function() self:SetTab(label) end;self.Tabs[#self.Tabs+1]=tab
    end
    S.Button(self,"Тайники",760,22,124,34,function() S.Close();S.OpenStashManager() end)
    S.Button(self,"×",898,22,34,34,function() S.Close() end)
    self.Detail=vgui.Create("DPanel",self);self.Detail:SetPos(S.Px(732),S.Px(124));self.Detail:SetSize(S.Px(212),S.Px(388))
    self.Detail.Paint=function(_,w,h) self:PaintDetail(w,h) end
    local function selected(action)
        local item,zone,index=S.FindUID(S.Inventory,S.SelectedUID);if item then
            if action=="disassemble" then S.ConfirmDisassemble(zone,index) else S.SendAction(action,zone,index) end
        end
    end
    -- Кнопки компактнее, чтобы в карточке поместились все характеристики брони.
    self.Use=S.Button(self.Detail,"Использовать",12,318,188,28,function() selected("use") end)
    self.Drop=S.Button(self.Detail,"Выбросить",12,352,92,28,function() selected("drop") end)
    self.Disassemble=S.Button(self.Detail,"Разобрать",108,352,92,28,function() selected("disassemble") end)
    self:RefreshDetail()
    -- Фон рисуется в Paint до дочерних слотов. Поверх предметов эффектов нет.
end
function PANEL:SetTab(label)
    S.ActiveTab=label;S.HideTooltip();S.CancelDrag()
    local grid=label=="Рюкзак" or label=="Артефакты"
    self.Grid:SetVisible(grid);self.PDA:SetVisible(not grid)
    for _,slot in ipairs(self.GridSlots) do slot.TargetEnabled=grid end
    for _,tab in ipairs(self.Tabs) do tab.Active=tab.Label==label end
end
function PANEL:RefreshDetail()
    local item=S.FindUID(S.Inventory,S.SelectedUID)
    self.Use:SetEnabled(item~=nil);self.Drop:SetEnabled(item~=nil)
    self.Disassemble:SetEnabled(item~=nil and S.Items[item.id].salvage~=nil and S.Config.AllowDisassemble)
end
-- Карточка предмета: значок, название, описание, состояние и характеристики с полосами (с учётом износа).
function PANEL:PaintDetail(w,h)
    S.PaintPanel(0,0,w,h)
    local item=S.FindUID(S.Inventory,S.SelectedUID)
    if not item or not S.Items[item.id] then S.Text("Выберите предмет","SI.Body",S.Px(12),S.Px(24),S.C.muted);return end
    local d=S.Items[item.id];local cw=S.Px(188)
    S.SetColor(S.C.track);surface.DrawRect(S.Px(12),S.Px(12),cw,S.Px(60))
    S.DrawItemIcon(item,S.Px(42),S.Px(14),S.Px(128),S.Px(56))
    if item.count>1 then S.Text("x"..item.count,"SI.Small",S.Px(196),S.Px(15),S.C.text,TEXT_ALIGN_RIGHT) end
    S.Text(S.FitText(d.name,"SI.Title",cw),"SI.Title",S.Px(12),S.Px(76),S.C.accent)
    S.Text(S.FitText(string.format("%s · %.2f кг",(S.CategoryNames[d.category] or d.category),d.weight),"SI.Small",cw),"SI.Small",S.Px(12),S.Px(101),S.C.muted)
    local lines=S.Wrap(d.description,"SI.Small",cw)
    for i=1,math.min(2,#lines) do S.Text(S.FitText(lines[i],"SI.Small",cw),"SI.Small",S.Px(12),S.Px(117+(i-1)*13),S.C.text) end
    local y=S.Px(148)
    S.DrawStatRow({label="Состояние",text=item.durability.."%",ratio=item.durability/100,token=item.durability<25 and "danger" or item.durability<50 and "warn" or "ok"},S.Px(12),y,cw)
    y=y+S.Px(18)
    local rows=S.ItemStats(item,d);local room=math.floor((S.Px(312)-y)/S.Px(18))
    if #rows>room then room=room-1 end
    for i,row in ipairs(rows) do
        if i>room then S.Text("… ещё "..(#rows-room)..": наведите на предмет","SI.Small",S.Px(12),y,S.C.muted);break end
        S.DrawStatRow(row,S.Px(12),y,cw);y=y+S.Px(18)
    end
end
function PANEL:Paint(w,h)
    local c=S.C;STALKER_STYLE.Frame("stalker_inv",w,h)
    S.PaintPanel(S.Px(16),S.Px(16),S.Px(928),S.Px(54),false,true)
    local ply=LocalPlayer();if not IsValid(ply) then return end
    S.Text(S.FitText(ply:Nick(),"SI.Title",S.Px(280)),"SI.Title",S.Px(28),S.Px(22))
    S.Text((STFW and STFW.State and STFW.Name(STFW.State.me.faction) or "ВОЛЬНЫЙ СТАЛКЕР").." / КПК","SI.Small",S.Px(28),S.Px(51),c.muted)
    local weight=S.Weight(S.Inventory);local col=weight>S.Config.MaxWeight and c.danger or c.accent
    S.Text(string.format("%.1f / %d kg",weight,S.Config.MaxWeight),"SI.Mono",S.Px(330),S.Px(23),col)
    S.SetColor(c.track);surface.DrawRect(S.Px(330),S.Px(48),S.Px(260),S.Px(4))
    surface.SetDrawColor(col);surface.DrawRect(S.Px(330),S.Px(48),S.Px(260)*math.min(1,weight/S.Config.MaxWeight),S.Px(4))
    local money=hook.Run("STALKER_INV_GetBalance",ply)
    if money==nil and ply.getDarkRPVar then money=ply:getDarkRPVar("money") end
    -- Деньги левее кнопок «Тайники» / «×», иначе текст оказывается под кнопкой.
    S.Text(money and (string.Comma(tonumber(money) or 0).." ₽") or "— ₽","SI.Mono",S.Px(744),S.Px(24),c.text,TEXT_ALIGN_RIGHT)
    S.Text("ЛИЧНЫЙ СЧЁТ","SI.Small",S.Px(744),S.Px(50),c.muted,TEXT_ALIGN_RIGHT)
    -- Радиация: накопленная доза (0–100) и текущий фон, как на сервере.
    local dose,rate=S.RadiationDose(ply),S.RadiationRate(ply);local radcol=S.RadiationColor(dose)
    S.PaintPanel(S.Px(16),S.Px(80),S.Px(180),S.Px(32),dose>=S.RadiationDanger())
    S.Text("☢","SI.Mono",S.Px(24),S.Px(87),radcol)
    S.Text(string.format("ДОЗА %.1f",dose),"SI.Small",S.Px(42),S.Px(85),radcol)
    S.Text(rate>0 and string.format("+%.2f/с",rate) or "ФОН 0","SI.Small",S.Px(188),S.Px(85),rate>0 and c.danger or c.muted,TEXT_ALIGN_RIGHT)
    STALKER_STYLE.Bar(S.Px(42),S.Px(100),S.Px(146),S.Px(5),dose/100,radcol)
    local energy=S.Config.DarkRP.UseHunger and ply.getDarkRPVar and ply:getDarkRPVar("Energy")
    local hunger=type(energy)=="number" and energy or S.Inventory.hunger or 100;local thirst=S.Inventory.thirst or 100
    for i,v in ipairs({{"СЫТОСТЬ",hunger,c.ok},{"ВОДА",thirst,c.accent}}) do
        local x=S.Px(208+(i-1)*152)
        S.Text(v[1],"SI.Small",x,S.Px(85),c.muted);S.Text(math.floor(v[2]).."%","SI.Small",x+S.Px(140),S.Px(85),c.text,TEXT_ALIGN_RIGHT)
        STALKER_STYLE.Bar(x,S.Px(100),S.Px(140),S.Px(5),v[2]/100,v[2]<20 and c.danger or v[3])
    end
end
function PANEL:Think()
    if self.Animation:Active() then self.Animation:Run() end
    if S.Looking and not input.IsMouseDown(MOUSE_RIGHT) then
        S.Looking=false;self:SetMouseInputEnabled(true);gui.EnableScreenClicker(true)
    end
    local ply=LocalPlayer()
    if gui.IsGameUIVisible() or (IsValid(ply) and (not ply:Alive() or S.IsUnconscious(ply))) then S.Close() end
end
function PANEL:OnMousePressed(code)
    if code==MOUSE_RIGHT then S.HideTooltip();S.Looking=true;self:SetMouseInputEnabled(false);gui.EnableScreenClicker(false) end
end
function PANEL:OnRemove()
    S.CancelDrag();S.HideTooltip();S.Looking=false;gui.EnableScreenClicker(false)
    S.DropAreas[self.Grid]=nil
    if IsValid(S.StashFrame) then S.StashFrame:Remove() end
end
vgui.Register("STALKERInventory",PANEL,"EditablePanel")
function S.Close()
    if IsValid(S.StashFrame) then S.StashFrame:Remove() end;S.StashFrame=nil
    if IsValid(S.Frame) then S.Frame:Remove() end;S.Frame=nil
end
-- Масштаб подбирается так, чтобы окно (или рюкзак + тайник) целиком помещалось на экране.
function S.ComputeScale(width,height)
    return math.Clamp(math.min(ScrW()/1280,ScrH()/720)*S.CVScale:GetFloat(),.5,math.min((ScrW()-20)/width,(ScrH()-20)/height))
end
S.StashWidth=300;S.StashGap=12
-- stashID (строка) открывает рядом окно своего тайника, таблица {intel=…} — чужого тайника по наводке.
-- Консольные команды передают сюда игрока — игнорируем.
function S.Open(stashID)
    if IsValid(S.Frame) then return end
    local ply=LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or S.IsUnconscious(ply) then return end
    local foreign=type(stashID)=="table" and type(stashID.intel)=="string" and stashID or nil
    local withStash=foreign~=nil or (type(stashID)=="string" and stashID~="")
    S.Scale=S.ComputeScale(withStash and 960+S.StashGap+S.StashWidth+20 or 980,620)
    S.CreateFonts();S.Frame=vgui.Create("STALKERInventory")
    if withStash then
        local stash=vgui.Create("STALKERStash")
        if foreign then stash:SetupForeign(foreign) else stash:Setup(stashID) end
        S.StashFrame=stash
        local gap=S.Px(S.StashGap);local total=S.Frame:GetWide()+gap+stash:GetWide()
        local x,y=math.floor((ScrW()-total)/2),math.floor((ScrH()-S.Frame:GetTall())/2)
        S.Frame:SetPos(x,y);stash:SetPos(x+S.Frame:GetWide()+gap,y)
    end
    S.RequestSync()
end
function S.Toggle() if IsValid(S.Frame) then S.Close() else S.Open() end end
concommand.Add("stalker_inv",S.Toggle)
concommand.Add("+stalker_inv",S.Open)
concommand.Add("-stalker_inv",S.Close)
hook.Add("OnScreenSizeChanged","STALKER_INV.Resize",function()
    if not IsValid(S.Frame) then return end
    local stash=IsValid(S.StashFrame) and (S.StashFrame.Foreign and S.Foreign or S.StashFrame.StashID)
    S.Close();S.Open(stash)
end)
hook.Add("STALKER_INV_Updated","STALKER_INV.Refresh",function()
    S.HideTooltip()
    if IsValid(S.Frame) then S.Frame:RefreshDetail() end
end)
hook.Add("StartChat","STALKER_INV.ChatStart",function() S.Chatting=true end)
hook.Add("FinishChat","STALKER_INV.ChatEnd",function() S.Chatting=false end)
local wasDown=false
hook.Add("Think","STALKER_INV.ToggleKey",function()
    local down=input.IsKeyDown(S.CVKey:GetInt())
    if down and not wasDown and not S.Chatting and not gui.IsGameUIVisible() and not gui.IsConsoleVisible()
        and not IsValid(vgui.GetKeyboardFocus()) then S.Toggle() end
    wasDown=down
end)
hook.Add("PlayerBindPress","STALKER_INV.Scoreboard",function(_,bind)
    if bind=="+showscores" and S.CVKey:GetInt()==KEY_TAB then return true end
end)
