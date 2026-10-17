-- Наводки на чужие тайники (клиент): список из КПК, окно чужого тайника, подсказка «удерживайте E»,
-- вкладка «Тайники» в КПК (stalker_pda).
local S=STALKER_INV
S.Intel=S.Intel or {}
-- Чтение сжатого JSON (формат STALKER_CORE.Send); без ядра — тот же формат вручную.
local function read(len)
    local C=STALKER_CORE
    if C and C.Read then return C.Read(len) end
    local size=net.ReadUInt(16);if size<1 or size>63000 then return end
    local raw=util.Decompress(net.ReadData(size) or "");local t=raw and util.JSONToTable(raw)
    if type(t)=="table" then return t end
end
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<=S.MaxCoord end
local function validPos(p) return type(p)=="table" and finite(p.x) and finite(p.y) and finite(p.z) end

net.Receive("stalker_stash.intel",function(len)
    local data=read(len);if not data or type(data.list)~="table" then return end
    local list={}
    for _,x in ipairs(data.list) do
        if type(x)=="table" and type(x.id)=="string" and validPos(x.pos) then
            list[#list+1]={id=x.id,owner=tostring(x.owner or "?"),map=tostring(x.map or ""),pos=x.pos,
                expiresAt=CurTime()+(tonumber(x.left) or 0),opened=x.opened==true}
        end
    end
    S.Intel=list
    hook.Run("STALKER_INV_IntelUpdated",list)
end)
-- Забрать предмет из ячейки (0 — всё). Проверки — на сервере.
function S.LootAct(intelID,index)
    if type(intelID)~="string" or (S.LootPending or 0)>RealTime() then return end
    S.LootPending=RealTime()+.25
    net.Start("stalker_stash.loot");net.WriteString(intelID);net.WriteUInt(math.Clamp(tonumber(index) or 0,0,63),6);net.SendToServer()
end
net.Receive("stalker_stash.foreign",function(len)
    local data=read(len);if not data then return end
    S.LootPending=0
    if data.message then notification.AddLegacy(tostring(data.message),NOTIFY_GENERIC,4) end
    if data.close or type(data.intel)~="string" then
        S.Foreign=nil
        if IsValid(S.StashFrame) and S.StashFrame.Foreign then S.StashFrame:Remove() end
        return
    end
    local items={}
    for _,row in ipairs(type(data.items)=="table" and data.items or {}) do
        local slot=tonumber(type(row)=="table" and row.slot)
        local item=type(row)=="table" and row.item
        if slot and slot>=1 and slot<=S.StashMaxSlots and type(item)=="table" and S.Items[item.id] then
            item.count=tonumber(item.count) or 1;item.durability=tonumber(item.durability) or 100;items[slot]=item
        end
    end
    local foreign={intel=data.intel,owner=tostring(data.owner or "?"),slots=tonumber(data.slots) or 12,items=items,pos=validPos(data.pos) and data.pos or nil}
    local open=S.Foreign and S.Foreign.intel==data.intel and IsValid(S.StashFrame) and S.StashFrame.Foreign
    if open then S.Foreign=foreign
    else
        -- Новое окно: прежние окна закрываются раньше, чем запоминается тайник (их OnRemove сбрасывает S.Foreign).
        if IsValid(S.Manager) then S.Manager:Remove() end
        S.Close();S.Foreign=foreign;S.Open(foreign)
    end
    hook.Run("STALKER_INV_ForeignUpdated",S.Foreign)
end)

-- Ближайшее место из наводок на этой карте (для подсказки и сводки).
function S.NearestIntelLocal(range)
    local ply=LocalPlayer();if not IsValid(ply) then return end
    local best,bestD
    for _,x in ipairs(S.Intel or {}) do
        if x.map==game.GetMap() and x.expiresAt>CurTime() then
            local d=ply:GetPos():Distance(Vector(x.pos.x,x.pos.y,x.pos.z))
            if d<=range and (not bestD or d<bestD) then best,bestD=x,d end
        end
    end
    return best,bestD
end
function S.IntelLeftText(x)
    local left=math.max(0,math.floor((x.expiresAt or 0)-CurTime()));local h=math.floor(left/3600);local m=math.floor(left%3600/60)
    if h>0 then return h.." ч "..m.." мин" end
    return math.max(1,m).." мин"
end
-- Подсказка у места тайника: удерживайте E, чтобы обыскать.
hook.Add("HUDPaint","STALKER_INV.IntelHint",function()
    local ply=LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or IsValid(S.Frame) or IsValid(S.Manager) or #(S.Intel or {})==0 then return end
    local x=S.NearestIntelLocal(S.Config.StashUseRange+40);if not x then return end
    local T=STALKER_THEME;local font=T and "STALKER.Head" or "SI.Hint"
    draw.SimpleTextOutlined("Удерживайте E — обыскать тайник «"..x.owner.."»",font,ScrW()/2,ScrH()*.62,S.C.warn,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,S.Alpha(S.C.shadow,200))
end)

-- Вкладка «Тайники» в КПК: свои тайники и полученные наводки.
local function buildPDATab(parent)
    local U=STALKER_STYLE;local T=STALKER_THEME
    local px=T and T.Px or S.Px
    local top=vgui.Create("DPanel",parent);top:Dock(TOP);top:SetTall(px(40));top.Paint=function() end
    local manage=U.Button(top,"Управление тайниками",function() S.OpenStashManager() end,"accent")
    manage:Dock(RIGHT);manage:SetWide(px(220))
    local scroll=vgui.Create("DScrollPanel",parent);scroll:Dock(FILL);scroll:DockMargin(0,px(6),0,0);U.Scroll(scroll)
    local list=vgui.Create("DPanel",scroll);list:Dock(TOP);list:SetTall(px(400))
    -- Высота списка — по числу строк, чтобы прокрутка работала при многих наводках.
    list.Think=function(self)
        local rows=math.max(1,table.Count(S.Inventory.stashes or {}))+math.max(1,#(S.Intel or {}))
        local tall=px(110)+rows*px(38);if self:GetTall()~=tall then self:SetTall(tall) end
    end
    list.Paint=function(_,w,h)
        local ply=LocalPlayer();if not IsValid(ply) then return end
        local C=T and T.C or S.C;local y=0
        U.Text("ЛИЧНЫЕ ТАЙНИКИ","STALKER.Head",0,y,"accent");y=y+px(24)
        local own=S.SortedStashes()
        if #own==0 then U.Text("Тайников нет. Создать: TAB → «Тайники» или команда !stash.","STALKER.Small",0,y,"muted");y=y+px(22) end
        for i,v in ipairs(own) do
            local dist=S.StashDistance(v.stash)
            U.Panel("",0,y,w,px(34))
            U.Text("Тайник #"..i,"STALKER.Body",px(10),y+px(8),"text")
            U.Text(table.Count(v.stash.items).." / "..S.StashSlotsOf(v.stash).." ячеек","STALKER.Small",w*.35,y+px(10),"muted")
            U.Text(dist and string.format("%.0f м",dist*.01905) or ("карта "..v.stash.map),"STALKER.Small",w-px(10),y+px(10),dist and "ok" or "muted",TEXT_ALIGN_RIGHT)
            y=y+px(38)
        end
        y=y+px(10);U.Text("НАВОДКИ НА ЧУЖИЕ ТАЙНИКИ","STALKER.Head",0,y,"accent");y=y+px(24)
        local intel=S.Intel or {}
        if #intel==0 then U.Text("Наводок нет. Координаты тайника иногда находятся у убитого сталкера.","STALKER.Small",0,y,"muted");y=y+px(22) end
        for _,x in ipairs(intel) do
            local here=x.map==game.GetMap()
            local dist=here and ply:GetPos():Distance(Vector(x.pos.x,x.pos.y,x.pos.z))
            U.Panel("",0,y,w,px(34),here and dist<=S.Config.StashUseRange+40)
            U.Text("Тайник «"..x.owner.."»","STALKER.Body",px(10),y+px(8),x.opened and "muted" or "warn")
            U.Text("осталось "..S.IntelLeftText(x),"STALKER.Small",w*.45,y+px(10),"muted")
            U.Text(dist and string.format("%.0f м",dist*.01905) or ("карта "..x.map),"STALKER.Small",w-px(10),y+px(10),dist and "ok" or "muted",TEXT_ALIGN_RIGHT)
            y=y+px(38)
        end
        y=y+px(8)
        U.Text("Метки наводок видны только вам. У места удерживайте E, чтобы обыскать тайник: забрать можно всё, положить — ничего.","STALKER.Small",0,y,"muted")
    end
end
S.BuildPDATab=buildPDATab
if STALKER_CORE and STALKER_CORE.RegisterPDATab then
    STALKER_CORE.RegisterPDATab("stashes",{title="Тайники",order=60,build=buildPDATab,
        badge=function() local n=0;for _,x in ipairs(S.Intel or {}) do if not x.opened then n=n+1 end end;return n>0 and n or nil end})
end
