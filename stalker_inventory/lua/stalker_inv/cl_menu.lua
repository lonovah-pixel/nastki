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
        S.Text("Перетащите предмет в ячейку или быстрый слот","SI.Small",0,S.Px(370),S.C.muted)
    end
    self.GridSlots={}
    for i=1,40 do self.GridSlots[i]=S.MakeSlot(self.Grid,"grid",i,((i-1)%8)*64,28+math.floor((i-1)/8)*68,64) end
    self.PDA=S.BuildPDA(self);self.Tabs={}
    for i,label in ipairs({"Рюкзак","Артефакты","Карта","PDA"}) do
        local tab=vgui.Create("DToggleTab",self);tab.Label=label;tab:SetPos(S.Px(512+(i-1)*110),S.Px(82));tab:SetSize(S.Px(106),S.Px(30));tab.Active=i==1
        tab.DoClick=function() self:SetTab(label) end;self.Tabs[#self.Tabs+1]=tab
    end
    S.Button(self,"Тайники",760,22,124,34,function() S.Close();RunConsoleCommand("stalker_stash") end)
    S.Button(self,"×",898,22,34,34,function() S.Close() end)
    self.Detail=vgui.Create("DPanel",self);self.Detail:SetPos(S.Px(732),S.Px(124));self.Detail:SetSize(S.Px(212),S.Px(388))
    self.Detail.Paint=function(_,w,h) self:PaintDetail(w,h) end
    local function selected(action)
        local item,zone,index=S.FindUID(S.Inventory,S.SelectedUID);if item then
            if action=="disassemble" then S.ConfirmDisassemble(zone,index) else S.SendAction(action,zone,index) end
        end
    end
    self.Use=S.Button(self.Detail,"Использовать",12,274,188,28,function() selected("use") end)
    self.Drop=S.Button(self.Detail,"Выбросить",12,310,188,28,function() selected("drop") end)
    self.Disassemble=S.Button(self.Detail,"Разобрать",12,346,188,28,function() selected("disassemble") end)
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
function PANEL:PaintDetail(w,h)
    S.PaintPanel(0,0,w,h)
    local item=S.FindUID(S.Inventory,S.SelectedUID)
    if not item then S.Text("Выберите предмет","SI.Body",S.Px(12),S.Px(24),S.C.muted);return end
    local d=S.Items[item.id]
    surface.SetDrawColor(S.C.background);surface.DrawRect(S.Px(12),S.Px(12),S.Px(188),S.Px(86))
    S.DrawItemIcon(item,S.Px(32),S.Px(12),S.Px(148),S.Px(86))
    S.Text(S.FitText(d.name,"SI.Title",S.Px(188)),"SI.Title",S.Px(12),S.Px(108),S.C.accent)
    S.Text(string.format("%s / %.2f kg",(S.CategoryNames[d.category] or d.category),d.weight),"SI.Small",S.Px(12),S.Px(137),S.C.muted)
    local lines=S.Wrap(d.description,"SI.Body",S.Px(188))
    for i=1,math.min(2,#lines) do S.Text(S.FitText(lines[i],"SI.Body",S.Px(188)),"SI.Body",S.Px(12),S.Px(158+(i-1)*17)) end
    local y=201;local n=0
    for key,val in SortedPairs(d.stats) do
        if n>=2 then break end
        S.Text(S.StatNames[key] or key,"SI.Small",S.Px(12),S.Px(y),S.C.muted)
        S.Text(tostring(val),"SI.Small",S.Px(200),S.Px(y),S.C.text,TEXT_ALIGN_RIGHT);y=y+18;n=n+1
    end
    S.Text("Износ / кол-во","SI.Small",S.Px(12),S.Px(244),S.C.muted)
    S.Text(item.durability.."% / "..item.count,"SI.Small",S.Px(200),S.Px(244),S.C.text,TEXT_ALIGN_RIGHT)
end
function PANEL:Paint(w,h)
    local c=S.C;STALKER_STYLE.Frame("stalker_inv",w,h)
    S.PaintPanel(S.Px(16),S.Px(16),S.Px(928),S.Px(54),false,true)
    local ply=LocalPlayer();if not IsValid(ply) then return end
    S.Text(S.FitText(ply:Nick(),"SI.Title",S.Px(280)),"SI.Title",S.Px(28),S.Px(22))
    S.Text((STFW and STFW.State and STFW.Name(STFW.State.me.faction) or "ВОЛЬНЫЙ СТАЛКЕР").." / КПК","SI.Small",S.Px(28),S.Px(51),c.muted)
    local weight=S.Weight(S.Inventory);local col=weight>S.Config.MaxWeight and c.danger or c.accent
    S.Text(string.format("%.1f / %d kg",weight,S.Config.MaxWeight),"SI.Mono",S.Px(330),S.Px(23),col)
    surface.SetDrawColor(c.background);surface.DrawRect(S.Px(330),S.Px(48),S.Px(260),S.Px(4))
    surface.SetDrawColor(col);surface.DrawRect(S.Px(330),S.Px(48),S.Px(260)*math.min(1,weight/S.Config.MaxWeight),S.Px(4))
    local money=hook.Run("STALKER_INV_GetBalance",ply)
    if money==nil and ply.getDarkRPVar then money=ply:getDarkRPVar("money") end
    S.Text(money and (string.Comma(tonumber(money) or 0).." ₽") or "— ₽","SI.Mono",S.Px(878),S.Px(24),c.text,TEXT_ALIGN_RIGHT)
    S.Text("ЛИЧНЫЙ СЧЁТ","SI.Small",S.Px(878),S.Px(50),c.muted,TEXT_ALIGN_RIGHT)
    local rad=S.Inventory.radiation or 0;local radcol=rad>.5 and c.danger or c.ok
    draw.RoundedBox(2,S.Px(16),S.Px(84),S.Px(78),S.Px(24),Color(radcol.r,radcol.g,radcol.b,35))
    S.Text(string.format("☢ %.2f",rad),"SI.Small",S.Px(20),S.Px(90),radcol)
    S.Text("СЫТОСТЬ","SI.Small",S.Px(102),S.Px(87),c.muted);S.Text("ВОДА","SI.Small",S.Px(288),S.Px(87),c.muted)
    surface.SetDrawColor(c.panel);surface.DrawRect(S.Px(174),S.Px(91),S.Px(96),S.Px(4));surface.DrawRect(S.Px(338),S.Px(91),S.Px(96),S.Px(4))
    surface.SetDrawColor(c.ok);surface.DrawRect(S.Px(174),S.Px(91),S.Px(96)*((S.Config.DarkRP.UseHunger and ply.getDarkRPVar and ply:getDarkRPVar("Energy")) or S.Inventory.hunger)/100,S.Px(4))
    surface.SetDrawColor(c.accent);surface.DrawRect(S.Px(338),S.Px(91),S.Px(96)*S.Inventory.thirst/100,S.Px(4))
end
function PANEL:Think()
    if self.Animation:Active() then self.Animation:Run() end
    if S.Looking and not input.IsMouseDown(MOUSE_RIGHT) then
        S.Looking=false;self:SetMouseInputEnabled(true);gui.EnableScreenClicker(true)
    end
    if gui.IsGameUIVisible() or (IsValid(LocalPlayer()) and not LocalPlayer():Alive()) then S.Close() end
end
function PANEL:OnMousePressed(code)
    if code==MOUSE_RIGHT then S.HideTooltip();S.Looking=true;self:SetMouseInputEnabled(false);gui.EnableScreenClicker(false) end
end
function PANEL:OnRemove()
    S.CancelDrag();S.HideTooltip();S.Looking=false;gui.EnableScreenClicker(false)
end
vgui.Register("STALKERInventory",PANEL,"EditablePanel")
function S.Close() if IsValid(S.Frame) then S.Frame:Remove() end;S.Frame=nil end
function S.Open()
    if IsValid(S.Frame) then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then return end
    S.Scale=math.Clamp(math.min(ScrW()/1280,ScrH()/720)*S.CVScale:GetFloat(),.5,math.min(ScrW()/980,ScrH()/620))
    S.CreateFonts();S.Frame=vgui.Create("STALKERInventory");S.RequestSync()
end
function S.Toggle() if IsValid(S.Frame) then S.Close() else S.Open() end end
concommand.Add("stalker_inv",S.Toggle)
concommand.Add("+stalker_inv",S.Open)
concommand.Add("-stalker_inv",S.Close)
hook.Add("OnScreenSizeChanged","STALKER_INV.Resize",function() if IsValid(S.Frame) then S.Close();S.Open() end end)
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
