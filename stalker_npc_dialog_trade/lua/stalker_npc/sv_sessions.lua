local N=STALKER_NPC
N.Sessions={}
for _,name in ipairs({"state","choice","quote","offer","confirm","close","refresh"}) do util.AddNetworkString("stnpc."..name) end
local function rate(ply)
    local now=CurTime();local b=ply.StnpcRate or {time=now,tokens=8};ply.StnpcRate=b
    b.tokens=math.min(8,b.tokens+(now-b.time)*4);b.time=now
    if b.tokens<1 then return false end;b.tokens=b.tokens-1;return true
end
function N.ValidSession(ply,s)
    if not s or not IsValid(ply) or not ply:Alive() or not IsValid(s.entity) or s.expires<CurTime() then return false end
    if ST_EMISSION and type(ST_EMISSION.IsUnconscious)=="function" and ST_EMISSION.IsUnconscious(ply) then return false end
    if STALKER_BUTCHERING and STALKER_BUTCHERING.Sessions and STALKER_BUTCHERING.Sessions[ply] then return false end
    if s.entity:GetClass()~="stalker_npc_trader" or s.entity:GetTraderID()~=s.profile then return false end
    if ply:GetPos():DistToSqr(s.entity:GetPos())>N.Config.Distance^2 then return false end
    local tr=util.TraceLine({start=ply:EyePos(),endpos=s.entity:WorldSpaceCenter(),filter=ply,mask=MASK_SOLID})
    return not tr.Hit or tr.Entity==s.entity
end
function N.AllowedChoice(ply,c)
    if c.requires then
        local n=0;for _,item in pairs(ply:GetInventory().grid) do if item.id==c.requires.item then n=n+item.count end end
        if n<(c.requires.count or 1) then return false end
    end
    return true
end
function N.SendJSON(name,ply,data)
    local text=util.TableToJSON(data);if not text or #text>60000 then return end
    net.Start("stnpc."..name);net.WriteUInt(#text,16);net.WriteData(text,#text);net.Send(ply)
end
function N.Close(ply)
    N.Sessions[ply]=nil;net.Start("stnpc.close");net.Send(ply)
end
function N.SendState(ply,message,tab)
    local s=N.Sessions[ply];if not N.ValidSession(ply,s) then N.Close(ply);return end
    local profile=N.Config.Traders[s.profile];local node=profile and profile.nodes[s.node]
    if not node then N.Close(ply);return end
    local stock=N.GetStock(s.profile)
    local balance=N.Balance(ply);if not stock or balance==nil then ply:ChatPrint(N.L(not stock and "storage" or "economy"));N.Close(ply);return end
    local choices={};for i,c in ipairs(node.choices or {}) do if N.AllowedChoice(ply,c) then choices[#choices+1]={index=i,text=c.text} end end
    s.expires=CurTime()+N.Config.SessionSeconds;s.quote=nil
    local inv=ply:GetInventory();STALKER_INV.CaptureEquipment(ply)
    local pricing={buy={},sell={}}
    for _,item in pairs(stock.grid) do pricing.buy[item.uid]=N.Price(profile,item,"buy",ply) end
    for _,item in pairs(inv.grid) do pricing.sell[item.uid]=N.Price(profile,item,"sell",ply) end
    local context={}
    if STFW and profile.Faction then
        local d=STFW.Load(ply)
        if d then local relation,points=STFW.Relation(d.faction,profile.Faction);context={faction=profile.Faction,relation=relation,points=points,rep=d.rep[profile.Faction] or 0} end
    end
    N.SendJSON("state",ply,{context=context,canTrade=hook.Run("STNPC_CanTrade",ply,s.entity)~=false,pricing=pricing,session=s.id,entity=s.entity:EntIndex(),profile=s.profile,node=s.node,nodeRevision=s.nodeRevision,
        text=hook.Run("STNPC_DialogueText",profile,ply,node.text) or node.text,choices=choices,stock=stock,inventory=inv,balance=balance,message=message,tab=tab,economy=N.Config.Economy})
end
function N.Open(ply,entity)
    if not rate(ply) or not N.Ready() then return end
    local S=STALKER_INV
    if not N.DatabaseReady or not S.DatabaseReady or S.CVBackend:GetString()~="sqlite" then ply:ChatPrint(N.L("dependency"));return end
    if ply:IsBot() or not ply:SteamID64():match("^%d+$") or ply:SteamID64()=="0" then return end
    S.LoadPlayer(ply);if not ply:GetInventory() or ply.StalkerLoadError then return end
    local id=entity:GetTraderID();local profile=N.Config.Traders[id];if not profile then return end
    local s={id=math.random(1,2147483646),entity=entity,profile=id,node=profile.root,nodeRevision=0,expires=CurTime()+N.Config.SessionSeconds}
    if not N.ValidSession(ply,s) then return end
    if N.IsBlocked(ply) then ply:ChatPrint(N.L("locked"));return end
    N.Sessions[ply]=s;N.SendState(ply,nil,"dialog")
end
local function session(ply,minBits,len)
    if len<minBits or len>16000 or not rate(ply) then return end
    local token=net.ReadUInt(32);local s=N.Sessions[ply]
    if not N.ValidSession(ply,s) then N.Close(ply);return end
    if token~=s.id then return end
    if ply.StalkerLoadError or not ply:GetInventory() then N.Close(ply);return end
    return s
end
net.Receive("stnpc.choice",function(len,ply)
    if len~=72 then return end
    local s=session(ply,72,len);if not s then return end
    local rev=net.ReadUInt(32);local index=net.ReadUInt(8)
    if rev~=s.nodeRevision then N.SendState(ply,"stale");return end
    local profile=N.Config.Traders[s.profile];local c=(profile.nodes[s.node].choices or {})[index]
    if not c or not N.AllowedChoice(ply,c) then return end
    s.nodeRevision=s.nodeRevision+1
    if c.action=="close" then N.Close(ply);return end
    if c.next and profile.nodes[c.next] then s.node=c.next end
    N.SendState(ply,nil,c.action=="trade" and "trade" or "dialog")
end)
net.Receive("stnpc.quote",function(len,ply)
    local s=session(ply,104,len);if not s then return end
    if N.IsBlocked(ply) or hook.Run("STNPC_CanTrade",ply,s.entity)==false then N.SendState(ply,"trade_denied","dialog");return end
    local invrev=net.ReadUInt(32);local stockrev=net.ReadUInt(32);local count=net.ReadUInt(8)
    if count<1 or count>N.Config.MaxLines then return end
    if len<104+count*33 then return end
    local lines={};local expected=104
    for i=1,count do
        local side=net.ReadBool() and "buy" or "sell";local index=net.ReadUInt(6);local n=net.ReadUInt(10);local uid=net.ReadString()
        if #uid<1 or #uid>96 then return end;expected=expected+17+(#uid+1)*8;lines[i]={side=side,index=index,count=n,uid=uid}
    end
    if len~=expected then return end
    local inv=ply:GetInventory();local stock=N.GetStock(s.profile)
    if not stock or inv.revision~=invrev or stock.revision~=stockrev then N.SendState(ply,"stale","trade");return end
    STALKER_INV.CaptureEquipment(ply);local balance=N.Balance(ply)
    if not balance then N.SendState(ply,"economy");return end
    local result,err=N.BuildTrade(inv,stock,N.Config.Traders[s.profile],lines,balance,ply)
    if not result then N.SendState(ply,err,"trade");return end
    s.quote={id=math.random(1,2147483646),invRevision=invrev,stockRevision=stockrev,lines=lines,total=result.total,expires=CurTime()+N.Config.QuoteSeconds}
    N.SendJSON("offer",ply,{session=s.id,id=s.quote.id,total=result.total,balance=result.balance,weight=result.weight,seconds=N.Config.QuoteSeconds})
end)
net.Receive("stnpc.confirm",function(len,ply)
    if len~=64 then return end
    local s=session(ply,64,len);if not s then return end
    local id=net.ReadUInt(32);local q=s.quote;s.quote=nil -- Одноразовое предложение, даже при отказе.
    if not q or q.id~=id then N.SendState(ply,"expired","trade");return end
    local ok,err=N.CommitTrade(ply,s,q);N.SendState(ply,ok and "success" or err,"trade")
end)
net.Receive("stnpc.refresh",function(len,ply) if len~=32 then return end;local s=session(ply,32,len);if s then N.SendState(ply,nil,"trade") end end)
net.Receive("stnpc.close",function(len,ply) if len~=32 then return end;local id=net.ReadUInt(32);local s=N.Sessions[ply];if s and s.id==id then N.Sessions[ply]=nil end end)
hook.Add("PlayerDisconnected","STNPC.Close",function(ply) N.Sessions[ply]=nil end)
timer.Create("STNPC.SessionWatch",1,0,function() for ply,s in pairs(N.Sessions) do if not IsValid(ply) then N.Sessions[ply]=nil elseif not N.ValidSession(ply,s) then N.Close(ply) end end end)
