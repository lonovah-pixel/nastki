local N=STALKER_NPC
local function readJSON()
    local n=net.ReadUInt(16);if n>60000 then return end
    return util.JSONToTable(net.ReadData(n) or "")
end
function N.Send(name,write)
    if not N.State then return end
    net.Start("stnpc."..name);net.WriteUInt(N.State.session,32);if write then write() end;net.SendToServer()
end
function N.CloseUI(send)
    if send and N.State then N.Send("close") end
    if IsValid(N.Window) then N.Window:Remove() end
    if IsValid(N.Modal) then N.Modal:Remove() end
    N.Window=nil;N.State=nil;N.Cart={};N.Waiting=nil
end
local function cartArray() local result={};for _,v in SortedPairs(N.Cart or {}) do result[#result+1]=v end;return result end
function N.Quantity(side,index,item)
    if N.Waiting then return end
    if IsValid(N.Modal) then N.Modal:Remove() end
    local f=vgui.Create("DFrame");N.Modal=f;f:SetTitle(N.L("quantity"));f:SetSize(N.P(420),N.P(190));f:Center();f:MakePopup()
    f.Paint=function(_,w,h) STALKER_STYLE.Frame("stalker_npc",w,h) end
    local slider=vgui.Create("DNumSlider",f);slider.Label:SetTextColor(N.Colors.text);slider.TextArea:SetTextColor(N.Colors.text);slider:SetPos(N.P(16),N.P(42));slider:SetSize(N.P(388),N.P(40));slider:SetText(N.L("quantity"));slider:SetMin(1);slider:SetMax(item.count);slider:SetDecimals(0);slider:SetValue(1)
    N.Button(f,N.L("confirm"),16,112,188,42,function()
        local key=side..":"..index
        if not N.Cart[key] and #cartArray()>=N.Config.MaxLines then return end
        N.Cart[key]={side=side,index=index,count=math.Clamp(math.Round(slider:GetValue()),1,item.count),uid=item.uid,id=item.id}
        f:Remove();N.Render()
    end)
    N.Button(f,N.L("cancel"),216,112,188,42,function() f:Remove() end)
end
function N.Render()
    if not IsValid(N.Window) or not N.State then return end
    local f=N.Window;local s=N.State;local profile=N.Config.Traders[s.profile]
    if not profile then return end
    if IsValid(f.Body) then f.Body:Remove() end
    f.Body=vgui.Create("DPanel",f);f.Body:SetPos(N.P(16),N.P(150));f.Body:SetSize(N.P(1088),N.P(472));f.Body.Paint=nil
    local body=f.Body;local tab=N.Tab or "dialog"
    for k,b in pairs(f.Tabs) do b.Active=k==tab end
    if tab=="dialog" or tab=="info" then
        local left=N.Panel(body,0,0,260,472)
        local model=vgui.Create("DModelPanel",left);model:SetPos(N.P(8),N.P(8));model:SetSize(N.P(244),N.P(318));model:SetModel(profile.model)
        model:SetAmbientLight(Color(61,64,47));model:SetDirectionalLight(BOX_FRONT,Color(175,174,136));model:SetFOV(32);model:SetCamPos(Vector(65,0,61));model:SetLookAt(Vector(0,0,59));model.LayoutEntity=function() end
        N.Label(left,N.Text(profile.name),16,332,228,36,"STNPC.Title",N.Colors.accent)
        N.Label(left,N.Text(profile.role),16,375,228,30,"STNPC.Small",N.Colors.muted)
        local context=s.context or {}
        local faction=context.faction and STFW and STFW.Name(context.faction) or "СВОБОДНАЯ ТОРГОВЛЯ"
        N.Label(left,faction,16,408,228,24,"STNPC.Small",N.Colors.accent)
        N.Label(left,context.relation and STFW and (STFW.L(context.relation).." / REP "..(context.rep or 0)) or "КПК / СВЯЗЬ УСТАНОВЛЕНА",16,440,228,24,"STNPC.Small",context.relation=="war" and N.Colors.red or N.Colors.green)
        local right=N.Panel(body,276,0,812,472)
        N.Label(right,N.Text(profile.name).." / "..N.Text(profile.role),24,12,764,32,"STNPC.Small",N.Colors.accent)
        local transcript=N.Scroll(right,24,52,764,172)
        local speech=vgui.Create("DLabel",transcript);speech:Dock(TOP);speech:SetFont("STNPC.Body");speech:SetTextColor(N.Colors.text);speech:SetText(tab=="dialog" and N.Text(s.text) or N.Text(profile.info));speech:SetWrap(true);speech:SetAutoStretchVertical(true)
        local list=N.Scroll(right,24,238,764,214)
        if tab=="dialog" then
            for order,choice in ipairs(s.choices) do
                local b=vgui.Create("STNPCButton",list);b.Caption=string.format("%02d  /  ",order)..N.Text(choice.text);b:SetTall(N.P(54));b:Dock(TOP);b:DockMargin(0,0,0,N.P(10))
                b.DoClick=function() if N.Waiting then return end;N.Waiting=RealTime();N.Send("choice",function() net.WriteUInt(s.nodeRevision,32);net.WriteUInt(choice.index,8) end) end
            end
        else
            N.Label(right,N.L("balance")..": "..s.balance.." ₽\n"..N.L("condition")..": 25–100% цены\n".."КОШЕЛЁК DARKRP / РАСЧЁТ ПОСЛЕ ПОДТВЕРЖДЕНИЯ",24,260,764,130)
        end
    elseif tab=="inventory" then
        N.Label(body,N.L("you"),0,0,500,34,"STNPC.Title")
        N.Label(body,string.format("%.2f / %d kg",STALKER_INV.Weight(s.inventory),STALKER_INV.Config.MaxWeight),760,0,300,34,"STNPC.Small",N.Colors.accent)
        local grid=N.Panel(body,0,46,1088,362);N.ItemGrid(grid,s.inventory,nil,1088,362,profile)
        N.Button(body,N.L("inspect"),0,424,400,44,function() N.CloseUI(true);STALKER_INV.Open() end)
    else
        N.Label(body,N.L("you"),0,0,336,34,"STNPC.Title")
        N.Label(body,N.L("npc"),352,0,336,34,"STNPC.Title")
        for _,desc in ipairs({{side="sell",x=0,inv=s.inventory},{side="buy",x=352,inv=s.stock}}) do
            local panel=N.Panel(body,desc.x,44,336,428)
            N.ItemGrid(panel,desc.inv,desc.side,336,428,profile)
        end
        local summary=N.Panel(body,704,0,384,472)
        N.Label(summary,N.L("cart"),16,12,352,36,"STNPC.Title",N.Colors.accent)
        local list=N.Scroll(summary,16,62,352,250)
        local total=0
        for key,l in SortedPairs(N.Cart or {}) do
            local source=l.side=="buy" and s.stock or s.inventory;local item=source.grid[tostring(l.index)] or source.grid[l.index]
            if item then
                local price=N.DisplayPrice(profile,item,l.side) or 0;total=total+(l.side=="buy" and 1 or -1)*price*l.count
                local row=vgui.Create("STNPCButton",list);row.Caption=(l.side=="buy" and "+ " or "− ")..STALKER_INV.Items[item.id].name.." ×"..l.count
                row:SetTall(N.P(44));row:Dock(TOP);row:DockMargin(0,0,0,N.P(6));row:SetTooltip(N.L("remove"));row.DoClick=function() N.Cart[key]=nil;N.Render() end
            end
        end
        N.Label(summary,N.L("net"),16,318,352,28,"STNPC.Small",N.Colors.muted)
        N.Label(summary,total.." ₽",16,346,352,34,"STNPC.Title",N.Colors.accent)
        N.Button(summary,N.L("clear"),16,412,100,42,function() N.Cart={};N.Render() end)
        local q=N.Button(summary,N.L("quote"),126,412,242,42,function()
            local lines=cartArray();if #lines==0 or N.Waiting then return end;N.Waiting=RealTime()
            N.Send("quote",function()
                net.WriteUInt(s.inventory.revision,32);net.WriteUInt(s.stock.revision,32);net.WriteUInt(#lines,8)
                for _,l in ipairs(lines) do net.WriteBool(l.side=="buy");net.WriteUInt(l.index,6);net.WriteUInt(l.count,10);net.WriteString(l.uid) end
            end)
        end);q:SetEnabled(#cartArray()>0 and s.canTrade~=false)
        N.Button(summary,"Обновить наличие и цены",16,377,352,27,function() N.Send("refresh") end)
    end
end
function N.OpenUI()
    STALKER_INV.Close()
    N.Scale=math.min(ScrW()/1180,ScrH()/740,2);N.Fonts()
    local f=vgui.Create("DFrame");N.Window=f;f:SetTitle("");f:ShowCloseButton(false);f:SetSize(N.P(1120),N.P(700));f:Center();f:MakePopup();f:SetDraggable(false)
    f.Paint=function(_,w,h)
        STALKER_STYLE.Frame("stalker_npc",w,h)
        if not N.State then return end
        local p=N.Config.Traders[N.State.profile]
        draw.SimpleText("STALKER / "..N.Text(p.name),"STNPC.Title",N.P(24),N.P(24),N.Colors.text)
        draw.SimpleText(N.L("balance")..": "..N.State.balance.." ₽","STNPC.Small",N.P(1040),N.P(34),N.Colors.accent,TEXT_ALIGN_RIGHT)
        draw.SimpleText("КПК / ЛОКАЛЬНАЯ СВЯЗЬ","STNPC.Small",N.P(24),N.P(64),N.Colors.green)
        local msg=N.State.message and N.L(N.State.message) or "PDA / CONNECTED"
        draw.SimpleText(STALKER_INV.FitText(msg,"STNPC.Body",N.P(1070)),"STNPC.Body",N.P(24),N.P(654),N.State.message=="success" and N.Colors.green or N.Colors.muted)
    end
    f.Tabs={};for i,key in ipairs({"dialog","trade","inventory","info"}) do
        f.Tabs[key]=N.Button(f,N.L(key),16+(i-1)*274,98,266,36,function() if key=="trade" then N.Send("refresh") else N.Tab=key;N.Render() end end)
    end
    N.Button(f,"×",1062,22,40,36,function() N.CloseUI(true) end)
    f.OnClose=function() N.CloseUI(true) end
    f:SetAlpha(0);f:AlphaTo(255,.18,0);surface.PlaySound(N.Config.SoundOpen)
    f.Think=function()
        if N.Waiting and RealTime()-N.Waiting>8 then N.Waiting=nil;N.Send("refresh") end
        if gui.IsGameUIVisible() or not LocalPlayer():Alive() then N.CloseUI(true) end
    end
end
net.Receive("stnpc.state",function()
    local s=readJSON();if not s or not N.Ready() or not N.Config.Traders[s.profile] then return end
    -- JSON-ключи индексов нормализует API существующего Inventory.
    local inv=STALKER_INV.ValidateSaved(s.inventory);local stock=STALKER_INV.ValidateSaved(s.stock)
    if not inv or not stock then return end
    inv.revision=s.inventory.revision;stock.revision=s.stock.revision;s.inventory=inv;s.stock=stock
    if IsValid(N.Modal) then N.Modal:Remove() end
    local previous=N.State
    N.State=s;N.Waiting=nil
    if not previous or previous.session~=s.session or s.message=="success" then N.Cart={}
    else
        local kept={}
        for _,line in pairs(N.Cart or {}) do
            local source=line.side=="buy" and s.stock or s.inventory
            for index,item in pairs(source.grid) do
                if item.uid==line.uid and N.DisplayPrice(N.Config.Traders[s.profile],item,line.side) then
                    line.index=index;line.count=math.min(line.count,item.count);kept[line.side..":"..index]=line;break
                end
            end
        end
        N.Cart=kept
    end
    N.Tab=s.tab or N.Tab or "dialog"
    if not IsValid(N.Window) then N.OpenUI() end
    if s.message=="success" then surface.PlaySound(N.Config.SoundTrade) end
    N.Render()
end)
net.Receive("stnpc.offer",function()
    local q=readJSON();if not q or not N.State or q.session~=N.State.session then return end;N.Waiting=nil
    if IsValid(N.Modal) then N.Modal:Remove() end
    local f=vgui.Create("DFrame");N.Modal=f;f:SetTitle(N.L("confirm"));f:SetSize(N.P(460),N.P(300));f:Center();f:MakePopup()
    f.Paint=function(_,w,h) STALKER_STYLE.Frame("stalker_npc",w,h) end
    N.Label(f,N.L("net")..": "..q.total.." ₽\n"..N.L("balance")..": "..q.balance.." ₽\n"..N.L("weight")..": "..string.format("%.2f kg",q.weight),20,52,420,126)
    local endAt=RealTime()+q.seconds
    local accept=N.Button(f,N.L("confirm"),20,216,204,46,function() if N.Waiting then return end;N.Waiting=RealTime();N.Send("confirm",function() net.WriteUInt(q.id,32) end);f:Remove() end)
    N.Button(f,N.L("cancel"),236,216,204,46,function() f:Remove() end)
    f.Think=function() if RealTime()>endAt then accept:SetEnabled(false);accept.Caption=N.L("expired") end end
end)
net.Receive("stnpc.close",function() N.CloseUI(false) end)
hook.Add("OnScreenSizeChanged","STNPC.Resize",function() N.CloseUI(true) end)
-- Адаптер отображения тестового кошелька в существующем Inventory, без второго кошелька.
hook.Add("STALKER_INV_GetBalance","STNPC.DummyBalance",function(ply)
    if N.Config.Economy=="dummy" then local value=ply:GetNW2Int("stnpc_dummy_balance",-1);if value>=0 then return value end end
end)

function N.DisplayPrice(profile,item,side)
    local prices=N.State and N.State.pricing
    if prices and prices[side] then return prices[side][item.uid] end
    return N.Price(profile,item,side)
end
