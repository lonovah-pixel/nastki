# STALKER Inventory — актуальный код

## lua/autorun/stalker_inv_init.lua

```lua
-- STALKER Inventory: общий загрузчик. Порядок include важен.
STALKER_INV = STALKER_INV or {}
local shared = {"sh_config.lua", "sh_items.lua", "sh_core.lua", "sh_net.lua"}
local clients = {"cl_style.lua", "cl_theme.lua", "cl_tooltip.lua", "cl_dragdrop.lua", "cl_slots.lua",
    "cl_equipment.lua", "cl_quickbar.lua", "cl_pda.lua", "cl_menu.lua"}
if SERVER then
    for _, f in ipairs(shared) do AddCSLuaFile("stalker_inv/" .. f) end
    for _, f in ipairs(clients) do AddCSLuaFile("stalker_inv/" .. f) end
    resource.AddFile("materials/stalker_inv/noise.png")
end
for _, f in ipairs(shared) do include("stalker_inv/" .. f) end
if SERVER then
    include("stalker_inv/sv_items.lua")
    include("stalker_inv/sv_persistence.lua")
    include("stalker_inv/sv_inventory.lua")
else
    for _, f in ipairs(clients) do include("stalker_inv/" .. f) end
end
hook.Run("STALKER_INV_Ready", STALKER_INV)

if SERVER then
 local function sendMaterials(dir)
  local files,dirs=file.Find(dir.."/*","GAME")
  for _,name in ipairs(files or {}) do if name:sub(-4)==".png" then resource.AddFile(dir.."/"..name) end end
  for _,name in ipairs(dirs or {}) do sendMaterials(dir.."/"..name) end
 end
 sendMaterials("materials/stalker_inv")
end

```

## lua/entities/stalker_inv_drop/cl_init.lua

```lua
include("shared.lua")
function ENT:Draw() self:DrawModel() end
hook.Add("HUDPaint","STALKER_INV.PickupHint",function()
    local ply=LocalPlayer();if not IsValid(ply) then return end
    local tr=ply:GetEyeTrace();local ent=tr.Entity
    if IsValid(ent) and ent:GetClass()=="stalker_inv_drop" and tr.HitPos:DistToSqr(ply:EyePos())<150*150 then
        draw.SimpleText("E — "..ent:GetItemTitle(),"DermaDefaultBold",ScrW()/2,ScrH()/2+30,Color(217,207,176),TEXT_ALIGN_CENTER)
    end
end)

```

## lua/entities/stalker_inv_drop/init.lua

```lua
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
function ENT:Initialize()
    local d=self.Item and STALKER_INV.Items[self.Item.id]
    if not d then self:Remove();return end
    local model=util.IsValidModel(d.model) and d.model or "models/props_junk/cardboard_box004a.mdl"
    self:SetModel(model);self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS);self:SetUseType(SIMPLE_USE)
    local phys=self:GetPhysicsObject();if IsValid(phys) then phys:Wake() end
    -- Предметы не сохраняются в мире после рестарта; время жизни — 15 минут.
    timer.Simple(900,function() if IsValid(self) then self:Remove() end end)
end
function ENT:Use(activator) STALKER_INV.Pickup(activator,self) end
-- Запрет копирования через duplicator / toolgun / physgun.
function ENT:OnDuplicated() self.Item=nil;self:Remove() end
function ENT:CanTool() return false end
function ENT:PhysgunPickup() return false end

```

## lua/entities/stalker_inv_drop/shared.lua

```lua
ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Предмет STALKER"
ENT.Spawnable=false
function ENT:SetupDataTables() self:NetworkVar("String",0,"ItemTitle") end

```

## lua/stalker_inv/cl_dragdrop.lua

```lua
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

```

## lua/stalker_inv/cl_equipment.lua

```lua
local S=STALKER_INV
function S.BuildEquipment(parent)
 local panel=vgui.Create("DPanel",parent);panel:SetPos(S.Px(16),S.Px(124));panel:SetSize(S.Px(180),S.Px(388))
 panel.Paint=function(_,w,h)
  S.Text("ЭКИПИРОВКА","SI.Title",0,0,S.C.muted)
  S.PaintPanel(0,S.Px(215),S.Px(180),S.Px(173))
  local item=S.Inventory.equipment.armor
  S.Text("КОСТЮМ","SI.Small",S.Px(89),S.Px(230),S.C.muted)
  S.Text(item and (item.durability.."%") or "—","SI.Mono",S.Px(89),S.Px(249),S.C.accent)
  STALKER_STYLE.Bar(S.Px(89),S.Px(274),S.Px(80),S.Px(4),item and item.durability/100 or 0,S.C.ok)
  S.Text("ЛКМ: выбрать","SI.Small",S.Px(89),S.Px(300),S.C.muted)
  S.Text("2×: действие","SI.Small",S.Px(89),S.Px(321),S.C.muted)
  S.Text("ПКМ: меню","SI.Small",S.Px(89),S.Px(342),S.C.muted)
 end
 for i,e in ipairs(S.Config.Equipment) do S.MakeSlot(panel,"equipment",e.id,((i-1)%3)*61,28+math.floor((i-1)/3)*61,58,e.title) end
 local model=vgui.Create("DModelPanel",panel);model:SetPos(S.Px(2),S.Px(219));model:SetSize(S.Px(82),S.Px(162))
 local ply=LocalPlayer();if IsValid(ply) then model:SetModel(ply:GetModel());if IsValid(model.Entity) then model.Entity:SetSkin(ply:GetSkin());for _,group in ipairs(ply:GetBodyGroups()) do model.Entity:SetBodygroup(group.id,ply:GetBodygroup(group.id)) end end end
 model:SetFOV(30);model:SetCamPos(Vector(130,0,45));model:SetLookAt(Vector(0,0,38));model:SetAmbientLight(Color(69,71,52));model:SetDirectionalLight(BOX_FRONT,Color(156,159,128));model.LayoutEntity=function() end
 model:SetMouseInputEnabled(false);model:SetKeyboardInputEnabled(false)
 return panel
end

```

## lua/stalker_inv/cl_menu.lua

```lua
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

```

## lua/stalker_inv/cl_pda.lua

```lua
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

```

## lua/stalker_inv/cl_quickbar.lua

```lua
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

```

## lua/stalker_inv/cl_slots.lua

```lua
local S=STALKER_INV
local PANEL={}
function PANEL:Init()
    self:SetMouseInputEnabled(true);self:SetCursor("hand");self.HoverAlpha=0;S.Slots[self]=true
end
function PANEL:Setup(zone,index,label) self.Zone=zone;self.Index=index;self.Label=label end
function PANEL:GetItem()
    local item=S.GetAt(S.Inventory,self.Zone,self.Index)
    if item and S.ActiveTab=="Артефакты" and self.Zone=="grid" and S.Items[item.id].category~="artifact" then return end
    return item
end
function PANEL:Paint(w,h)
    local item=self:GetItem();local active=self:IsHovered() or (item and S.SelectedUID==item.uid)
    self.HoverAlpha=Lerp(math.min(1,FrameTime()*14),self.HoverAlpha,active and 1 or 0)
    S.PaintPanel(0,0,w,h,active)
    if self.Zone=="equipment" and tostring(self.Index):find("artifact",1,true) then
        surface.SetDrawColor(74,122,58,22);surface.DrawRect(1,1,w-2,h-2)
    end
    surface.SetDrawColor(200,169,81,20*self.HoverAlpha);surface.DrawRect(1,1,w-2,h-2)
    S.DrawBrassFrame(0,0,w,h,active)
    if item then
        S.DrawItemIcon(item,S.Px(6),S.Px(8),w-S.Px(12),h-S.Px(18))
        if item.count>1 then S.Text("x"..item.count,"SI.Small",w-S.Px(4),S.Px(3),S.C.text,TEXT_ALIGN_RIGHT) end
        surface.SetDrawColor(S.C.background);surface.DrawRect(S.Px(5),h-S.Px(7),w-S.Px(10),S.Px(3))
        surface.SetDrawColor(item.durability<25 and S.C.danger or S.C.ok)
        surface.DrawRect(S.Px(5),h-S.Px(7),(w-S.Px(10))*item.durability/100,S.Px(3))
    elseif self.Label then
        local lines=S.Wrap(self.Label,"SI.Small",w-S.Px(8))
        for i=1,math.min(3,#lines) do S.Text(lines[i],"SI.Small",w/2,h/2+S.Px((i-(math.min(3,#lines)+1)/2)*12),S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end
    end
    if self.Zone=="quickbar" then S.Text(tostring(self.Index),"SI.Small",S.Px(3),S.Px(2),S.C.accent) end
    S.DrawNoise(0,0,w,h)
end
function PANEL:OnCursorEntered() self.HoverStart=RealTime() end
function PANEL:OnCursorExited() self.HoverStart=nil;S.HideTooltip() end
function PANEL:Think()
    if self.HoverStart and RealTime()-self.HoverStart>.45 then S.ShowTooltip(self);self.HoverStart=nil end
end
function PANEL:OnMousePressed(code)
    local item=self:GetItem()
    if not item then return end
    S.SelectedUID=item.uid;if IsValid(S.Frame) then S.Frame:RefreshDetail() end
    if code==MOUSE_RIGHT then
        S.CancelDrag();S.HideTooltip()
        local m=DermaMenu()
        m:AddOption("Использовать / экипировать",function() S.SendAction("use",self.Zone,self.Index) end)
        m:AddOption("Выбросить стак",function() S.SendAction("drop",self.Zone,self.Index) end)
        if S.Items[item.id].salvage then m:AddOption("Разобрать",function() S.ConfirmDisassemble(self.Zone,self.Index) end) end
        if self.Zone=="quickbar" then m:AddOption("Убрать из быстрого доступа",function() S.SendAction("unbind",self.Zone,self.Index) end) end
        m:Open();return
    end
    if code~=MOUSE_LEFT then return end
    if self.LastClick and RealTime()-self.LastClick<.28 then
        self.LastClick=nil;S.CancelDrag();S.SendAction("use",self.Zone,self.Index)
    else self.LastClick=RealTime();S.BeginDrag(self) end
end
function PANEL:OnMouseReleased(code) if code==MOUSE_LEFT then S.EndDrag() end end
function PANEL:OnRemove() S.Slots[self]=nil end
vgui.Register("DSLot",PANEL,"DPanel")
local EQUIP={}
function EQUIP:Init() self.IsEquipment=true end
vgui.Register("DEquipmentSlot",EQUIP,"DSLot")
function S.MakeSlot(parent,zone,index,x,y,size,label)
    local p=vgui.Create(zone=="equipment" and "DEquipmentSlot" or "DSLot",parent)
    p:Setup(zone,index,label);p:SetPos(S.Px(x),S.Px(y));p:SetSize(S.Px(size),S.Px(size));return p
end
function S.ConfirmDisassemble(zone,index)
    local item=S.GetAt(S.Inventory,zone,index);if not item then return end
    local uid=item.uid
    Derma_Query("Разобрать «"..S.Items[item.id].name.."»? Предмет будет израсходован.","Разбор предмета",
        "Разобрать",function() local current=S.GetAt(S.Inventory,zone,index);if current and current.uid==uid then S.SendAction("disassemble",zone,index) end end,"Отмена")
end

```

## lua/stalker_inv/cl_style.lua

```lua
-- Общий стиль КПК. Материалы каждого аддона загружаются независимо.
STALKER_STYLE=STALKER_STYLE or {}
local U=STALKER_STYLE
U.Materials=U.Materials or {}
function U.Texture(path,x,y,w,h,alpha)
 local mat=U.Materials[path];if not mat then mat=Material(path,"smooth");U.Materials[path]=mat end
 if mat:IsError() then return end
 surface.SetMaterial(mat);surface.SetDrawColor(255,255,255,alpha or 255);surface.DrawTexturedRect(x,y,w,h)
end
function U.Panel(prefix,x,y,w,h,active,metal)
 surface.SetDrawColor(25,27,22,255);surface.DrawRect(x,y,w,h)
 U.Texture(prefix.."/"..(metal and "metal" or "panel")..".png",x,y,w,h,255)
 surface.SetDrawColor(active and Color(191,174,116) or Color(91,91,71));surface.DrawOutlinedRect(x,y,w,h,1)
 surface.SetDrawColor(8,10,8,220);surface.DrawOutlinedRect(x+2,y+2,w-4,h-4,1)
 surface.SetDrawColor(144,139,107,75);surface.DrawLine(x+3,y+3,x+w-4,y+3)
end
function U.Frame(prefix,w,h)
 U.Panel(prefix,0,0,w,h,true,true)
 U.Panel(prefix,10,10,w-20,h-20,false,false)
 U.Texture(prefix.."/vignette.png",0,0,w,h,175)
 for _,x in ipairs({6,w-7}) do for _,y in ipairs({6,h-7}) do
  surface.SetDrawColor(15,17,13);surface.DrawRect(x-2,y-2,5,5);surface.SetDrawColor(121,113,83);surface.DrawLine(x-1,y,x+1,y)
 end end
end
function U.Bar(x,y,w,h,ratio,col)
 ratio=math.Clamp(ratio or 0,0,1);surface.SetDrawColor(9,12,8,240);surface.DrawRect(x,y,w,h)
 surface.SetDrawColor(col);surface.DrawRect(x+1,y+1,(w-2)*ratio,h-2)
 surface.SetDrawColor(164,175,128,60);surface.DrawLine(x+1,y+1,x+1+(w-2)*ratio,y+1)
end
function U.Entry(e,prefix)
 e:SetFont("DermaDefault");e:SetTextColor(Color(217,207,176));e:SetCursorColor(Color(217,207,176));e:SetHighlightColor(Color(96,101,68))
 e.Paint=function(self,w,h) U.Panel(prefix,0,0,w,h,self:HasFocus());self:DrawTextEntryText(Color(217,207,176),Color(95,105,71),Color(217,207,176)) end
end
function U.Combo(c,prefix,font)
 c:SetTextColor(Color(217,207,176,0));c:SetFont(font or "DermaDefault")
 c.Paint=function(self,w,h) U.Panel(prefix,0,0,w,h,self:IsHovered());draw.SimpleText(self:GetValue(),font or "DermaDefault",8,h/2,Color(217,207,176),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
 if IsValid(c.DropButton) then c.DropButton.Paint=function(_,w,h) draw.SimpleText("▾",font or "DermaDefault",w/2,h/2,Color(177,168,132),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end end
end
function U.Scroll(scroll)
 local bar=scroll:GetVBar();bar:SetWide(8);bar:SetHideButtons(true)
 bar.Paint=function(_,w,h) surface.SetDrawColor(13,17,11);surface.DrawRect(0,0,w,h) end
 bar.btnGrip.Paint=function(_,w,h) surface.SetDrawColor(111,119,82);surface.DrawRect(1,0,w-2,h);surface.SetDrawColor(161,165,119);surface.DrawLine(2,2,w-3,2) end
end

```

## lua/stalker_inv/cl_theme.lua

```lua
local S=STALKER_INV
S.C=S.Config.Colors
S.Scale=1
function S.Px(v) return math.Round(v*S.Scale) end
function S.CreateFonts()
    local mono=S.CVFont:GetString();local heading=S.CVHeading:GetString()
    surface.CreateFont("SI.Small",{font=mono,size=S.Px(11),weight=400,extended=true})
    surface.CreateFont("SI.Body",{font="Tahoma",size=S.Px(14),weight=400,extended=true})
    surface.CreateFont("SI.Mono",{font=mono,size=S.Px(15),weight=500,extended=true})
    surface.CreateFont("SI.Title",{font=heading,size=S.Px(22),weight=500,extended=true})
end
S.CreateFonts()
S.PaintPanel=function(x,y,w,h,active,metal) STALKER_STYLE.Panel("stalker_inv",x,y,w,h,active,metal) end
S.Noise=Material("stalker_inv/noise.png","noclamp smooth")
S.Gradient=Material("vgui/gradient-d")
function S.DrawRoundedBoxEx(r,x,y,w,h,c,tl,tr,bl,br) draw.RoundedBoxEx(r,x,y,w,h,c,tl,tr,bl,br) end
function S.DrawNoise(x,y,w,h)
    if S.Noise:IsError() then return end
    surface.SetMaterial(S.Noise);surface.SetDrawColor(255,255,255,13)
    surface.DrawTexturedRectUV(x,y,w,h,0,0,w/128,h/128)
end
function S.DrawBrassFrame(x,y,w,h,active)
    surface.SetDrawColor(active and S.C.accent or S.C.brass);surface.DrawOutlinedRect(x,y,w,h,1)
    surface.SetMaterial(S.Gradient);surface.SetDrawColor(200,169,81,active and 28 or 12)
    surface.DrawTexturedRect(x+1,y+1,w-2,h-2)
    surface.SetDrawColor(0,0,0,90);surface.DrawOutlinedRect(x+2,y+2,w-4,h-4,1)
end
function S.DrawVignette(w,h)
    for i=0,S.Px(14) do
        surface.SetDrawColor(0,0,0,math.max(0,25-i));surface.DrawOutlinedRect(i,i,w-i*2,h-i*2,1)
    end
    surface.SetDrawColor(107,93,63,50)
    for i=1,20 do local x=(i*97)%math.max(1,w-40);surface.DrawLine(x,3,x+10+i%19,3) end
end
function S.Text(text,font,x,y,col,ax,ay) draw.SimpleText(text,font,x,y,col or S.C.text,ax or 0,ay or 0) end
function S.FitText(text,font,width)
    surface.SetFont(font)
    if surface.GetTextSize(text)<=width then return text end
    local chars=utf8.len(text) or #text
    for n=chars,1,-1 do local s=utf8.sub(text,1,n).."…";if surface.GetTextSize(s)<=width then return s end end
    return "…"
end
function S.Wrap(text,font,width)
    surface.SetFont(font);local lines={};local line=""
    for word in tostring(text):gmatch("%S+") do
        local nextLine=line=="" and word or line.." "..word
        if surface.GetTextSize(nextLine)>width and line~="" then lines[#lines+1]=line;line=word else line=nextLine end
    end
    if line~="" then lines[#lines+1]=line end
    return lines
end
local icons={}
function S.DrawItemIcon(item,x,y,w,h)
    if not item then return end
    local d=S.Items[item.id];if not d then return end
    if d.icon~="" then
        icons[d.icon]=icons[d.icon] or Material(d.icon,"smooth")
        if not icons[d.icon]:IsError() then surface.SetMaterial(icons[d.icon]);surface.SetDrawColor(255,255,255);local mat=icons[d.icon];local ratio=mat:Width()/math.max(1,mat:Height());local iw=math.min(w,h*ratio);local ih=iw/ratio;surface.DrawTexturedRect(x+(w-iw)/2,y+(h-ih)/2,iw,ih);return end
    end
    S.Text("?","SI.Title",x+w/2,y+h/2,S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
function S.Button(parent,text,x,y,w,h,fn)
    local b=vgui.Create("DButton",parent);b:SetText("");b:SetPos(S.Px(x),S.Px(y));b:SetSize(S.Px(w),S.Px(h))
    b.Paint=function(self,bw,bh)
        S.PaintPanel(0,0,bw,bh,self:IsHovered());S.DrawBrassFrame(0,0,bw,bh,self:IsHovered())
        S.Text(text,"SI.Body",bw/2,bh/2,self:IsEnabled() and S.C.text or S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end
    b.DoClick=fn;return b
end
local TAB={}
function TAB:Init() self:SetText("");self.Label="" end
function TAB:Paint(w,h)
    S.PaintPanel(0,0,w,h,self.Active or self:IsHovered());S.DrawBrassFrame(0,0,w,h,self.Active or self:IsHovered())
    S.Text(self.Label,"SI.Body",w/2,h/2,self.Active and S.C.accent or S.C.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
vgui.Register("DToggleTab",TAB,"DButton")

```

## lua/stalker_inv/cl_tooltip.lua

```lua
local S=STALKER_INV
local PANEL={}
function PANEL:Init() self:SetMouseInputEnabled(false);self:SetKeyboardInputEnabled(false) end
function PANEL:SetItem(item)
    self.Item=item;local d=S.Items[item.id];self.Lines=S.Wrap(d.description,"SI.Body",S.Px(250))
    self:SetSize(S.Px(274),S.Px(78+#self.Lines*17+table.Count(d.stats)*18))
end
function PANEL:Paint(w,h)
    if not self.Item then return end
    local d=S.Items[self.Item.id]
    S.PaintPanel(0,0,w,h,true);S.DrawBrassFrame(0,0,w,h,true)
    S.Text(S.FitText(d.name,"SI.Title",w-S.Px(24)),"SI.Title",S.Px(12),S.Px(8),S.C.accent)
    S.Text(string.format("%.2f kg × %d  |  %d%%",d.weight,self.Item.count,self.Item.durability),"SI.Small",S.Px(12),S.Px(37))
    local y=S.Px(59)
    for _,line in ipairs(self.Lines) do S.Text(line,"SI.Body",S.Px(12),y);y=y+S.Px(17) end
    for key,value in SortedPairs(d.stats) do S.Text((S.StatNames[key] or key)..": "..value,"SI.Small",S.Px(12),y,S.C.muted);y=y+S.Px(18) end
end
vgui.Register("STALKERTooltip",PANEL,"DPanel")
function S.HideTooltip() if IsValid(S.Tooltip) then S.Tooltip:Remove() end;S.Tooltip=nil end
function S.ShowTooltip(slot)
    if S.Drag or not IsValid(S.Frame) then return end
    local item=slot:GetItem();if not item then return end
    S.HideTooltip();local p=vgui.Create("STALKERTooltip",S.Frame);p:SetItem(item);p:SetZPos(10000)
    p:SetDrawOnTop(true);local x,y=S.Frame:ScreenToLocal(gui.MouseX()+16,gui.MouseY()+16)
    p:SetPos(math.Clamp(x,0,math.max(0,S.Frame:GetWide()-p:GetWide())),math.Clamp(y,0,math.max(0,S.Frame:GetTall()-p:GetTall())))
    S.Tooltip=p
end

```

## lua/stalker_inv/sh_config.lua

```lua
local S = STALKER_INV
S.Config = {
    Width = 960, Height = 600, Columns = 8, Rows = 5, Slot = 64, QuickSlot = 48,
    DarkRP = {UseHunger=true, DisableStarter=true},
    MaxWeight = 50, OverweightSpeed = 0.55, Autosave = 30,
    -- Боеприпасы SWEP остаются нативными; хотбар не подменяет выбор оружия.
    QuickModifier = KEY_LALT, AllowDisassemble = true,
    Equipment = {
        {id="helmet", title="Шлем", category="helmet"},
        {id="armor", title="Броня", category="armor"},
        {id="primary", title="Основное", category="primary"},
        {id="secondary", title="Второе", category="secondary"},
        {id="pistol", title="Пистолет", category="pistol"},
        {id="throwable", title="Гранаты", category="throwable"},
        {id="artifact1", title="Артеф. I", category="artifact"},
        {id="artifact2", title="Артеф. II", category="artifact"},
        {id="boots", title="Ботинки", category="boots"}
    },
    Colors = {background=Color(28,26,20), panel=Color(42,38,32), brass=Color(107,93,63),
        accent=Color(200,169,81), text=Color(217,207,176), muted=Color(138,127,99),
        danger=Color(162,43,31), ok=Color(74,122,58)},
    Starter = {{"medkit",3},{"bandage",5},{"water",2},{"food",2},{"ammo_pistol",15},
        {"pistol",1},{"jacket",1},{"artifact",1},{"scrap",4}},
    MapMaterials = {} -- ["gm_construct"] = "stalker_inv/maps/gm_construct.png"
}
S.Items = S.Items or {}
S.ITEMS = S.Items
S.EquipmentByID = {}
for _, e in ipairs(S.Config.Equipment) do S.EquipmentByID[e.id] = e end
if SERVER then
    S.CVBackend = CreateConVar("stalker_inv_storage", "sqlite", FCVAR_ARCHIVE, "sqlite или json")
    S.CVStarter = CreateConVar("stalker_inv_starter", "1", FCVAR_ARCHIVE, "Выдавать стартовый набор новым игрокам")
else
    S.CVKey = CreateClientConVar("stalker_inv_key", tostring(KEY_TAB), true, false, "Код клавиши открытия")
    S.CVScale = CreateClientConVar("stalker_inv_scale", "1", true, false, "Масштаб интерфейса", 0.65, 2)
    S.CVFont = CreateClientConVar("stalker_inv_font", "Consolas", true, false, "Моноширинный шрифт (или Courier New)")
    S.CVHeading = CreateClientConVar("stalker_inv_heading", "Trebuchet MS", true, false, "Заголовки (или Trebuchet MS)")
end

```

## lua/stalker_inv/sh_core.lua

```lua
local S = STALKER_INV
local function int(v, lo, hi) return type(v)=="number" and v==v and v%1==0 and v>=lo and v<=hi end
S.IsInt = int
function S.EmptyInventory()
    return {version=1, revision=0, grid={}, equipment={}, quickbar={}, hunger=100, thirst=100, radiation=0}
end
function S.ValidLocation(zone, index)
    if zone=="grid" then return int(index,1,40) end
    if zone=="quickbar" then return int(index,1,9) end
    return zone=="equipment" and S.EquipmentByID[index]~=nil
end
function S.FindUID(inv, uid)
    for _,zone in ipairs({"grid","equipment"}) do
        for k,v in pairs(inv[zone]) do if v.uid==uid then return v,zone,k end end
    end
end
function S.GetAt(inv, zone, index)
    if not inv or not S.ValidLocation(zone,index) then return end
    if zone=="quickbar" then return S.FindUID(inv, inv.quickbar[index]) end
    return inv[zone][index]
end
function S.CanPlace(item, zone, index)
    if not item then return true end
    if zone=="grid" then return true end
    local d=S.Items[item.id]
    return zone=="equipment" and d and S.EquipmentByID[index].category==d.category and item.count==1
end
function S.Weight(inv)
    local n=0
    for _,zone in ipairs({"grid","equipment"}) do
        for _,item in pairs(inv[zone]) do local d=S.Items[item.id]; if d then n=n+d.weight*item.count end end
    end
    return n
end
function S.CleanQuickbar(inv)
    for k,uid in pairs(inv.quickbar) do if not S.FindUID(inv,uid) then inv.quickbar[k]=nil end end
end
function S.UID() return tostring(os.time()).."_"..tostring(math.random(100000,999999)).."_"..tostring(SysTime()):gsub("%.","") end
function S.NewItem(id,count,durability)
    local d=S.Items[id]
    return {id=id,uid=S.UID(),count=count or 1,durability=durability or d.durability,
        clip1=d.clip1 or 0,clip2=d.clip2 or 0,armor=d.stats.armor or 0}
end
-- Добавление в копию: при нехватке места исходный инвентарь не меняется.
function S.Insert(inv,id,count,durability)
    local d=S.Items[id]
    if not d or not int(count,1,999) then return false,"Неизвестный предмет или количество" end
    local copy=table.Copy(inv)
    durability=durability or d.durability
    if d.stackable then
        for i=1,40 do local v=copy.grid[i]
            if v and v.id==id and v.durability==durability then
                local take=math.min(count,d.max_stack-v.count);v.count=v.count+take;count=count-take
                if count==0 then return copy end
            end
        end
    end
    for i=1,40 do
        if not copy.grid[i] then
            local take=math.min(count,d.max_stack);copy.grid[i]=S.NewItem(id,take,durability);count=count-take
            if count==0 then return copy end
        end
    end
    return false,"Рюкзак заполнен"
end
-- Перестановка, объединение стаков и назначение ссылок хотбара.
function S.Move(inv, from, fi, to, ti)
    if not S.ValidLocation(from,fi) or not S.ValidLocation(to,ti) then return false,"Некорректная ячейка" end
    if from==to and fi==ti then return false,"Та же ячейка" end
    local a=S.GetAt(inv,from,fi)
    if not a then return false,"Ячейка пуста" end
    if to=="quickbar" then
        if from=="quickbar" then inv.quickbar[fi],inv.quickbar[ti]=inv.quickbar[ti],inv.quickbar[fi]
        else inv.quickbar[ti]=a.uid end
        return true
    end
    if from=="quickbar" then return false,"Хотбар хранит только ссылки" end
    local b=inv[to][ti]
    if not S.CanPlace(a,to,ti) or not S.CanPlace(b,from,fi) then return false,"Снаряжение не подходит к слоту" end
    if a and b and to=="grid" and a.id==b.id and a.durability==b.durability and S.Items[a.id].stackable then
        local n=math.min(a.count,S.Items[a.id].max_stack-b.count)
        if n<=0 then return false,"Стак заполнен" end
        b.count=b.count+n;a.count=a.count-n
        if a.count==0 then
            inv[from][fi]=nil
            for k,uid in pairs(inv.quickbar) do if uid==a.uid then inv.quickbar[k]=b.uid end end
        end
    else inv[from][fi],inv[to][ti]=b,a end
    S.CleanQuickbar(inv)
    return true
end
-- JSON рассматривается как недоверенное/устаревшее состояние. Ошибки не затирают файл.
function S.ValidateSaved(raw)
    if type(raw)~="table" or raw.version~=1 then return nil,"Неизвестная версия" end
    local out=S.EmptyInventory();local seen={}
    for _,zone in ipairs({"grid","equipment"}) do
        if type(raw[zone])~="table" then return nil,"Повреждённая секция "..zone end
        for key,v in pairs(raw[zone]) do
            local k=zone=="grid" and tonumber(key) or key
            if not S.ValidLocation(zone,k) or type(v)~="table" or not S.Items[v.id]
                or type(v.uid)~="string" or #v.uid>96 or #v.uid<1 or seen[v.uid]
                or not int(v.count,1,S.Items[v.id].max_stack) or not S.CanPlace(v,zone,k)
                or not int(v.durability,0,100) then return nil,"Недопустимый предмет: "..tostring(type(v)=="table" and v.id or key) end
            local d=S.Items[v.id]
            local n={id=v.id,uid=v.uid,count=v.count,durability=v.durability,
                clip1=math.Clamp(tonumber(v.clip1) or 0,-1,999),clip2=math.Clamp(tonumber(v.clip2) or 0,-1,999),
                armor=math.Clamp(tonumber(v.armor) or d.stats.armor or 0,0,d.stats.armor or 0)}
            out[zone][k]=n;seen[v.uid]=true
        end
    end
    if type(raw.quickbar)=="table" then for k,uid in pairs(raw.quickbar) do
        k=tonumber(k);if int(k,1,9) and seen[uid] then out.quickbar[k]=uid end
    end end
    for _,k in ipairs({"hunger","thirst"}) do out[k]=math.Clamp(tonumber(raw[k]) or 100,0,100) end
    return out
end
local meta=FindMetaTable("Player")
function meta:GetInventory()
    if SERVER then return self.StalkerInventory end
    if self==LocalPlayer() then return S.Inventory end
end

```

## lua/stalker_inv/sh_items.lua

```lua
local S = STALKER_INV
-- Общий реестр; исполняемые OnUse задаются только на сервере.
function S.RegisterItem(id, data)
    assert(type(id)=="string" and #id<=48 and id:match("^[%w_]+$"), "Некорректный ID предмета")
    assert(type(data)=="table" and type(data.weight)=="number" and data.weight>=0 and data.weight<10000, "Некорректный вес")
    data.name = data.name or id
    data.description = data.description or "Описание отсутствует."
    data.model = data.model or "models/props_junk/cardboard_box004a.mdl"
    data.icon = data.icon or ""
    data.category = data.category or "misc"
    data.stats = data.stats or {}
    data.max_stack = data.stackable and math.Clamp(math.floor(data.max_stack or 1),1,999) or 1
    data.durability = math.floor(math.Clamp(data.durability or 100,0,100))
    S.Items[id] = data
end
local function add(id, d) S.RegisterItem(id,d) end
add("medkit",{name="Аптечка",description="Индивидуальный набор первой помощи. Восстанавливает 35 здоровья.",model="models/items/healthkit.mdl",weight=.3,stackable=true,max_stack=10,category="medicine",stats={health=35}})
add("bandage",{name="Бинт",description="Стерильная повязка. Восстанавливает 10 здоровья.",model="models/props_lab/box01a.mdl",weight=.05,stackable=true,max_stack=20,category="medicine",stats={health=10}})
add("water",{name="Вода",description="Чистая питьевая вода. Утоляет жажду.",model="models/props_junk/garbage_plasticbottle003a.mdl",weight=.5,stackable=true,max_stack=10,category="food",stats={thirst=35}})
add("food",{name="Консервы",description="Походный рацион. Утоляет голод.",model="models/props_junk/garbage_metalcan001a.mdl",weight=.35,stackable=true,max_stack=10,category="food",stats={hunger=30}})
add("ammo_pistol",{name="Пистолетные патроны",description="Одна единица даёт 12 патронов стандартного типа Pistol.",model="models/items/boxsrounds.mdl",weight=.12,stackable=true,max_stack=60,category="ammo",ammo="Pistol",ammoCount=12,stats={rounds=12}})
add("pistol",{name="Пистолет",description="Стандартный SWEP weapon_pistol. Перенесите в слот пистолета.",model="models/weapons/w_pistol.mdl",weight=.9,category="pistol",weapon="weapon_pistol",clip1=12,stats={damage=12},salvage={scrap=3}})
add("rifle",{name="Автомат",description="Стандартный SWEP weapon_smg1. Основное оружие.",model="models/weapons/w_smg1.mdl",weight=3.2,category="primary",weapon="weapon_smg1",clip1=30,stats={damage=10},salvage={scrap=6}})
add("jacket",{name="Куртка сталкера",description="Укреплённая куртка. Запас брони сохраняется при снятии и надевании.",model="models/props_c17/SuitCase_Passenger_Physics.mdl",weight=4.5,category="armor",stats={armor=40},salvage={scrap=4}})
add("helmet",{name="Шлем",description="Защитный шлем; характеристики доступны интеграциям через хук экипировки.",weight=1.2,category="helmet",stats={protection=10},salvage={scrap=2}})
add("boots",{name="Ботинки",description="Походные ботинки. Дополнительный слот снаряжения.",weight=1.5,category="boots",stats={condition=100},salvage={scrap=2}})
add("artifact",{name="Каменный цветок",description="Артефакт. Добавляет 0.12 к радиационному индикатору, пока экипирован.",model="models/props_junk/rock001a.mdl",weight=.5,category="artifact",stats={radiation=.12},salvage={scrap=5}})
add("scrap",{name="Детали",description="Материалы, полученные при разборе снаряжения.",model="models/gibs/metal_gib4.mdl",weight=.15,stackable=true,max_stack=100,category="material"})
S.StatNames = {health="Здоровье",thirst="Вода",hunger="Сытость",rounds="Патроны",damage="Урон",armor="Броня",radiation="Радиация",protection="Защита",condition="Состояние"}

for _,id in ipairs({"medkit","bandage","water","food","ammo_pistol","pistol","rifle","jacket","helmet","boots","artifact","scrap"}) do
 if S.Items[id] and S.Items[id].icon=="" then S.Items[id].icon="stalker_inv/items/"..id..".png" end
end

S.CategoryNames={medicine="Медицина",food="Провизия",ammo="Боеприпасы",pistol="Пистолет",primary="Основное оружие",secondary="Второе оружие",armor="Костюм",helmet="Шлем",boots="Обувь",artifact="Артефакт",material="Материалы",misc="Снаряжение"}

```

## lua/stalker_inv/sh_net.lua

```lua
local S=STALKER_INV
local names={"sync","request","move","use","drop","disassemble","unbind"}
local zones={[1]="grid",[2]="equipment",[3]="quickbar"}
local zoneIDs={grid=1,equipment=2,quickbar=3}
function S.WriteLocation(zone,index)
    net.WriteUInt(zoneIDs[zone] or 0,2)
    if zone=="equipment" then
        local n=0;for i,e in ipairs(S.Config.Equipment) do if e.id==index then n=i end end
        net.WriteUInt(n,6)
    else net.WriteUInt(tonumber(index) or 0,6) end
end
function S.ReadLocation()
    local zone=zones[net.ReadUInt(2)];local index=net.ReadUInt(6)
    if zone=="equipment" then index=S.Config.Equipment[index] and S.Config.Equipment[index].id end
    return zone,index
end
if SERVER then
    for _,n in ipairs(names) do util.AddNetworkString("stalker_inv."..n) end
    function S.Sync(ply,message)
        if not ply.StalkerInventory then return end
        local payload=util.TableToJSON(ply.StalkerInventory)
        if not payload or #payload>60000 then return end
        net.Start("stalker_inv.sync");net.WriteUInt(#payload,16);net.WriteData(payload,#payload)
        net.WriteString(message or "");net.Send(ply)
    end
    local function allowed(ply,cost)
        local now=CurTime();local b=ply.StalkerNet or {time=now,tokens=12}
        b.tokens=math.min(12,b.tokens+(now-b.time)*8);b.time=now;ply.StalkerNet=b
        if b.tokens<cost then return false end
        b.tokens=b.tokens-cost;return true
    end
    net.Receive("stalker_inv.request",function(_,ply)
        if allowed(ply,3) and S.LoadPlayer then S.LoadPlayer(ply);S.Sync(ply,ply.StalkerLoadError) end
    end)
    for _,action in ipairs({"move","use","drop","disassemble","unbind"}) do
        net.Receive("stalker_inv."..action,function(len,ply)
            if len<48 or len>1600 or not allowed(ply,1) or not ply:Alive() or ply.StalkerLoadError then return end
            local inv=ply.StalkerInventory;if not inv then return end
            local revision=net.ReadUInt(32);local zone,index=S.ReadLocation();local uid=net.ReadString()
            if not S.ValidLocation(zone,index) or #uid>96 then return end
            local item=S.GetAt(inv,zone,index)
            if revision~=inv.revision or not item or item.uid~=uid then S.Sync(ply,"Состояние обновилось. Повторите действие.");return end
            local to,ti
            if action=="move" then to,ti=S.ReadLocation();if not S.ValidLocation(to,ti) then return end end
            if hook.Run("STALKER_INV_CanAction",ply,action,item,zone,index,to,ti)==false then S.Sync(ply,"Действие запрещено");return end
            S.HandleAction(ply,action,zone,index,to,ti)
        end)
    end
else
    S.Inventory=S.EmptyInventory()
    function S.SendAction(action,zone,index,to,ti)
        local inv=S.Inventory;local item=S.GetAt(inv,zone,index)
        if not item or (S.PendingUntil or 0)>RealTime() then return end
        S.PendingUntil=RealTime()+1
        net.Start("stalker_inv."..action);net.WriteUInt(inv.revision or 0,32)
        S.WriteLocation(zone,index);net.WriteString(item.uid)
        if action=="move" then S.WriteLocation(to,ti) end
        net.SendToServer()
    end
    function S.RequestSync() net.Start("stalker_inv.request");net.SendToServer() end
    net.Receive("stalker_inv.sync",function()
        local size=net.ReadUInt(16);if size>60000 then return end
        local raw=util.JSONToTable(net.ReadData(size) or "");local message=net.ReadString()
        local inv=S.ValidateSaved(raw)
        if not inv then notification.AddLegacy("Неизвестные предметы: проверьте shared-реестр сервера и клиента",NOTIFY_ERROR,6);return end
        inv.revision=tonumber(raw.revision) or 0;inv.radiation=tonumber(raw.radiation) or 0
        S.Inventory=inv;S.PendingUntil=0
        if message~="" then notification.AddLegacy(message,NOTIFY_GENERIC,4) end
        hook.Run("STALKER_INV_Updated",inv)
    end)
    hook.Add("InitPostEntity","STALKER_INV.Sync",function() S.RequestSync() end)
end
-- Ограничение скорости применяется и в предсказании клиента, и на сервере.
hook.Add("SetupMove","STALKER_INV.Weight",function(ply,mv)
    if ply:GetNW2Float("stalker_inv_weight",0)>S.Config.MaxWeight then
        mv:SetMaxClientSpeed(mv:GetMaxClientSpeed()*S.Config.OverweightSpeed)
        mv:SetMaxSpeed(mv:GetMaxSpeed()*S.Config.OverweightSpeed)
    end
end)

```

## lua/stalker_inv/sv_inventory.lua

```lua
local S=STALKER_INV
function S.CaptureEquipment(ply)
    local inv=ply.StalkerInventory;if not inv then return end
    for uid,wep in pairs(ply.StalkerWeapons or {}) do
        local item=S.FindUID(inv,uid)
        if item and IsValid(wep) then item.clip1=wep:Clip1();item.clip2=wep:Clip2() end
    end
    if ply.StalkerArmorUID then
        local item=S.FindUID(inv,ply.StalkerArmorUID)
        if item then item.armor=math.min(item.armor or 0,math.max(0,ply:Armor()-(ply.StalkerBaseArmor or 0))) end
    end
end
function S.ApplyEquipment(ply)
    local inv=ply.StalkerInventory;if not inv then return end
    ply.StalkerWeapons=ply.StalkerWeapons or {}
    local wanted={}
    for _,item in pairs(inv.equipment) do if S.Items[item.id].weapon and item.durability>0 then wanted[item.uid]=item end end
    for uid,wep in pairs(ply.StalkerWeapons) do
        if not wanted[uid] then if IsValid(wep) then wep:Remove() end;ply.StalkerWeapons[uid]=nil end
    end
    for uid,item in pairs(wanted) do
        local d=S.Items[item.id]
        if not IsValid(ply.StalkerWeapons[uid]) and not ply:HasWeapon(d.weapon) then
            local wep=ply:Give(d.weapon,true)
            if IsValid(wep) then
                wep.StalkerManaged=true;wep.StalkerOwner=ply
                wep:SetClip1(item.clip1 or 0);wep:SetClip2(item.clip2 or 0)
                ply.StalkerWeapons[uid]=wep
            end
        end
    end
    local armor=inv.equipment.armor;local uid=armor and armor.uid
    if uid~=ply.StalkerArmorUID then
        if ply.StalkerArmorUID then ply:SetArmor(math.min(ply:Armor(),ply.StalkerBaseArmor or 0)) end
        ply.StalkerArmorUID=uid;ply.StalkerBaseArmor=ply:Armor()
        if armor then ply:SetArmor(ply:Armor()+(armor.armor or 0)) end
    end
    inv.radiation=0
    for _,item in pairs(inv.equipment) do inv.radiation=inv.radiation+(S.Items[item.id].stats.radiation or 0) end
    hook.Run("STALKER_INV_EquipmentChanged",ply,inv.equipment)
end
function S.Commit(ply,inv,message)
    S.CleanQuickbar(inv);inv.revision=((ply.StalkerInventory and ply.StalkerInventory.revision or 0)+1)%4294967296
    ply.StalkerInventory=inv;ply:SetNW2Float("stalker_inv_weight",S.Weight(inv))
    S.ApplyEquipment(ply)
    if not S.SaveInventory(ply) then message="Ошибка сохранения: обратитесь к администратору" end
    S.Sync(ply,message)
end
function S.LoadPlayer(ply)
    if ply.StalkerInventory or ply.StalkerLoadError then return end
    local inv,fresh,err=S.LoadInventory(ply)
    if not inv then ply.StalkerLoadError=err;ply:ChatPrint(err);return end
    if fresh and S.CVStarter:GetBool() and not (DarkRP and S.Config.DarkRP.DisableStarter) then
        for _,v in ipairs(S.Config.Starter) do local nextInv=S.Insert(inv,v[1],v[2]);if nextInv then inv=nextInv end end
        for i=1,4 do if inv.grid[i] then inv.quickbar[i]=inv.grid[i].uid end end
    end
    ply.StalkerInventory=inv;S.Commit(ply,inv)
end
-- Серверный API: атомарное добавление всех единиц или отказ.
function S.GiveItem(ply,id,count)
    if not IsValid(ply) or not ply:IsPlayer() or ply.StalkerLoadError then return false,"Игрок не готов" end
    S.LoadPlayer(ply);if not ply.StalkerInventory then return false,"Нет инвентаря" end
    S.CaptureEquipment(ply)
    local inv,err=S.Insert(ply.StalkerInventory,id,count or 1)
    if not inv then return false,err end
    S.Commit(ply,inv);return true
end
function S.HandleAction(ply,action,zone,index,to,ti)
    S.CaptureEquipment(ply)
    local inv=table.Copy(ply.StalkerInventory)
    local item,realZone,realIndex
    if zone=="quickbar" then item,realZone,realIndex=S.GetAt(inv,zone,index)
    else item=inv[zone][index];realZone=zone;realIndex=index end
    local d=S.Items[item.id]
    local ok,err=false,"Действие недоступно"
    if action=="move" then
        -- Не выдаём второй экземпляр SWEP одного класса и не заменяем оружие другого аддона.
        if to=="equipment" and d.weapon then
            for _,other in pairs(inv.equipment) do
                if other.uid~=item.uid and S.Items[other.id].weapon==d.weapon then S.Sync(ply,"Это оружие уже экипировано");return end
            end
            local wep=ply:GetWeapon(d.weapon)
            if IsValid(wep) and not wep.StalkerManaged then S.Sync(ply,"Такое оружие уже выдано игровым режимом");return end
        end
        ok,err=S.Move(inv,zone,index,to,ti)
    elseif action=="unbind" and zone=="quickbar" then inv.quickbar[index]=nil;ok=true
    elseif action=="use" then
        if d.weapon and realZone=="equipment" then
            local w=ply.StalkerWeapons and ply.StalkerWeapons[item.uid]
            if IsValid(w) then ply:SelectWeapon(d.weapon);ok=true else err="Оружие недоступно или занято игровым режимом" end
        elseif d.OnUse then
            local success,result,reason=pcall(d.OnUse,ply,item,inv,d)
            if not success then ErrorNoHalt("[STALKER Inventory] OnUse: "..tostring(result).."\n");err="Ошибка обработчика предмета"
            elseif result then item.count=item.count-1;if item.count<=0 then inv[realZone][realIndex]=nil end;ok=true
            else err=reason or err end
        else
            for _,e in ipairs(S.Config.Equipment) do
                if e.category==d.category and not inv.equipment[e.id] then
                    if d.weapon and ply:HasWeapon(d.weapon) then err="Такое оружие уже есть у игрока";break end
                    ok,err=S.Move(inv,realZone,realIndex,"equipment",e.id);break
                end
            end
        end
    elseif action=="drop" then
        local start=ply:GetShootPos()
        local tr=util.TraceHull({start=start,endpos=start+ply:GetAimVector()*70,
            mins=Vector(-10,-10,-10),maxs=Vector(10,10,10),filter=ply,mask=MASK_SOLID})
        if tr.StartSolid then err="Недостаточно места для выброса"
        else
            local ent=ents.Create("stalker_inv_drop")
            if IsValid(ent) then
                ent.Item=table.Copy(item);ent:SetPos(tr.HitPos);ent:Spawn();ent:SetItemTitle(d.name)
                ent.PickupAfter=CurTime()+.6;ent:Activate()
                inv[realZone][realIndex]=nil;ok=true
            end
        end
    elseif action=="disassemble" and S.Config.AllowDisassemble and d.salvage then
        inv[realZone][realIndex]=nil;ok=true
        for id,n in pairs(d.salvage) do
            local nextInv,reason=S.Insert(inv,id,n*item.count)
            if not nextInv then ok=false;err=reason;break end
            inv=nextInv
        end
    end
    if ok then S.Commit(ply,inv) else S.Sync(ply,err) end
end
function S.Pickup(ply,ent)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not ent.Item or ent.Busy or
        ply:GetShootPos():DistToSqr(ent:GetPos())>150*150 or (ent.PickupAfter or 0)>CurTime() then return end
    S.LoadPlayer(ply);if not ply.StalkerInventory or ply.StalkerLoadError then return end
    if hook.Run("STALKER_INV_CanPickup",ply,ent,ent.Item)==false then return end
    S.CaptureEquipment(ply)
    local inv=table.Copy(ply.StalkerInventory);local empty
    -- Выброшенный стак сохраняет UID, износ, магазин и броню без пересоздания.
    for i=1,40 do if not inv.grid[i] then empty=i;break end end
    if not empty then ply:ChatPrint("Нужна свободная ячейка для подбора");return end
    if S.FindUID(inv,ent.Item.uid) then return end
    ent.Busy=true;inv.grid[empty]=table.Copy(ent.Item);ent.Item=nil;ent:Remove();S.Commit(ply,inv)
end
hook.Add("PlayerInitialSpawn","STALKER_INV.Load",function(ply) S.LoadPlayer(ply) end)
hook.Add("PlayerSpawn","STALKER_INV.Equip",function(ply)
    timer.Simple(0,function()
        if not IsValid(ply) then return end
        S.LoadPlayer(ply);ply.StalkerArmorUID=nil;ply.StalkerBaseArmor=nil
        S.ApplyEquipment(ply);S.Sync(ply)
    end)
end)
hook.Add("DoPlayerDeath","STALKER_INV.CaptureDeath",function(ply)
    S.CaptureEquipment(ply)
    -- Нативный дроп SWEP не должен создавать копию предмета.
    for _,w in pairs(ply.StalkerWeapons or {}) do if IsValid(w) then w:Remove() end end
    ply.StalkerWeapons={};S.SaveInventory(ply)
end)
hook.Add("PlayerDroppedWeapon","STALKER_INV.NoDuplicate",function(ply,wep)
    if IsValid(wep) and wep.StalkerManaged then S.CaptureEquipment(ply);wep:Remove() end
end)
hook.Add("PlayerCanPickupWeapon","STALKER_INV.ManagedWeapon",function(ply,wep)
    if wep.StalkerManaged then return false end
end)
hook.Add("PlayerDisconnected","STALKER_INV.Save",function(ply) S.SaveInventory(ply) end)
hook.Add("ShutDown","STALKER_INV.SaveAll",function() for _,ply in ipairs(player.GetAll()) do S.SaveInventory(ply) end end)
timer.Create("STALKER_INV.Autosave",S.Config.Autosave,0,function()
    for _,ply in ipairs(player.GetAll()) do if ply.StalkerInventory then S.SaveInventory(ply) end end
end)
-- Небольшая автономная модель потребностей. DarkRP hunger не изменяется.
timer.Create("STALKER_INV.Needs",60,0,function()
    for _,ply in ipairs(player.GetAll()) do if ply:Alive() and ply.StalkerInventory and not ply.StalkerLoadError then
        S.CaptureEquipment(ply);local inv=table.Copy(ply.StalkerInventory)
        local energy=S.Config.DarkRP.UseHunger and ply.getDarkRPVar and ply:getDarkRPVar("Energy")
        inv.hunger=type(energy)=="number" and math.Clamp(energy,0,100) or math.max(0,inv.hunger-.5);inv.thirst=math.max(0,inv.thirst-.8);S.Commit(ply,inv)
    end end
end)
concommand.Add("stalker_inv_give",function(ply,_,args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local target=IsValid(ply) and ply or nil
    if args[3] then for _,p in ipairs(player.GetAll()) do if p:SteamID64()==args[3] then target=p;break end end end
    if not IsValid(target) then print("stalker_inv_give <id> <count> <steamid64>");return end
    local ok,err=S.GiveItem(target,args[1] or "",tonumber(args[2]) or 1)
    if not ok then if IsValid(ply) then ply:ChatPrint(err) else print(err) end end
end)

```

## lua/stalker_inv/sv_items.lua

```lua
local S=STALKER_INV
for _,id in ipairs({"medkit","bandage"}) do
    S.Items[id].OnUse=function(ply,item,inv,def)
        if ply:Health()>=ply:GetMaxHealth() then return false,"Здоровье уже полное" end
        ply:SetHealth(math.min(ply:GetMaxHealth(),ply:Health()+def.stats.health));return true
    end
end
for _,id in ipairs({"food","water"}) do
    S.Items[id].OnUse=function(ply,item,inv,def)
        local stat=def.stats.hunger and "hunger" or "thirst"
        if stat=="hunger" and S.Config.DarkRP.UseHunger and ply.getDarkRPVar and ply.setSelfDarkRPVar then
            local energy=ply:getDarkRPVar("Energy")
            if type(energy)=="number" then
                if energy>=100 then return false,"Сытость уже полная" end
                inv.hunger=math.min(100,energy+def.stats.hunger);ply:setSelfDarkRPVar("Energy",inv.hunger);return true
            end
        end
        if inv[stat]>=100 then return false,"Показатель уже полный" end
        inv[stat]=math.min(100,inv[stat]+def.stats[stat]);return true
    end
end
S.Items.ammo_pistol.OnUse=function(ply,item,inv,def)
    if ply:GiveAmmo(def.ammoCount,def.ammo,true)<=0 then return false,"Боезапас заполнен" end
    return true
end

```

## lua/stalker_inv/sv_persistence.lua

```lua
local S=STALKER_INV
file.CreateDir("stalker_inv")
S.DatabaseReady=sql.Query("CREATE TABLE IF NOT EXISTS stalker_inventory (steamid TEXT PRIMARY KEY, payload TEXT NOT NULL)")~=false
local function steam(ply)
    if ply:IsBot() then return end
    local id=ply:SteamID64();if id and id:match("^%d+$") and id~="0" then return id end
end
function S.LoadInventory(ply)
    local id=steam(ply);if not id then return S.EmptyInventory(),true end
    local path="stalker_inv/"..id..".json"
    local backup=file.Exists(path,"DATA") and file.Read(path,"DATA") or nil
    local primary
    local readFailed=not S.DatabaseReady and S.CVBackend:GetString()~="json"
    if S.DatabaseReady and S.CVBackend:GetString()~="json" then
        local rows=sql.Query("SELECT payload FROM stalker_inventory WHERE steamid="..sql.SQLStr(id))
        if rows==false then readFailed=true;ErrorNoHalt("[STALKER Inventory] SQLite read: "..sql.LastError().."\n")
        elseif rows and rows[1] then primary=rows[1].payload end
    end
    if not primary and not backup then
        if readFailed then return nil,false,"Хранилище недоступно; инвентарь заблокирован до восстановления" end
        return S.EmptyInventory(),true
    end
    local a=primary and util.JSONToTable(primary);local b=backup and util.JSONToTable(backup)
    local raw=a
    if b and (not a or (tonumber(b.savedAt) or 0)>(tonumber(a.savedAt) or 0)) then raw=b end
    if not raw then return nil,false,"Сохранение повреждено; выдача предметов заблокирована" end
    local inv,err=S.ValidateSaved(raw)
    if not inv then return nil,false,"Не удалось загрузить инвентарь: "..err end
    return inv,false
end
function S.SaveInventory(ply)
    if not ply.StalkerInventory or ply.StalkerLoadError then return false end
    local id=steam(ply);if not id then return true end
    if S.CaptureEquipment then S.CaptureEquipment(ply) end
    local copy=table.Copy(ply.StalkerInventory);S.SaveStamp=math.max((S.SaveStamp or 0)+1,os.time()*1000);copy.savedAt=S.SaveStamp
    local payload=util.TableToJSON(copy)
    if not payload then return false end
    local sqlOK=false
    if S.DatabaseReady and S.CVBackend:GetString()~="json" then
        sqlOK=sql.Query("REPLACE INTO stalker_inventory (steamid,payload) VALUES ("..sql.SQLStr(id)..","..sql.SQLStr(payload)..")")~=false
        if not sqlOK then ErrorNoHalt("[STALKER Inventory] SQLite write: "..sql.LastError().."\n") end
    end
    -- JSON — резервная копия, temp -> rename уменьшает риск обрыва записи.
    local path="stalker_inv/"..id..".json";local temp="stalker_inv/"..id..".pending.json"
    file.Write(temp,payload)
    local jsonOK=file.Read(temp,"DATA")==payload
    if jsonOK then
        file.Rename(temp,path)
        -- На некоторых файловых системах rename не заменяет существующий файл.
        if file.Read(path,"DATA")~=payload then file.Write(path,payload) end
        jsonOK=file.Read(path,"DATA")==payload
        if jsonOK and file.Exists(temp,"DATA") then file.Delete(temp) end
    end
    if not sqlOK and not jsonOK then ErrorNoHalt("[STALKER Inventory] Не удалось сохранить "..id.."\n") end
    return sqlOK or jsonOK
end

```

