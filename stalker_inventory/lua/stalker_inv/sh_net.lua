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
            -- В обмороке (выброс) инвентарь закрыт, но ALT+1–9 и подделанный пакет шли бы дальше: лечение, переодевание, выброс.
            if S.IsUnconscious(ply) then S.Sync(ply,"Вы без сознания");return end
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
