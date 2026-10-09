local N=STALKER_NPC
N.Stocks={};N.Blocked={}
function N.Log(event,data)
    local message="[STNPC] "..event.." "..util.TableToJSON(data or {})
    ServerLog(message.."\n")
    if N.Config.Debug then print(message) end
end
function N.Query(q) local result=sql.Query(q);if result==false then N.Log("sql_error",{error=sql.LastError()}) end;return result end
N.DatabaseReady=true
for _,q in ipairs({
 "CREATE TABLE IF NOT EXISTS stnpc_stock (id TEXT PRIMARY KEY,payload TEXT NOT NULL)",
 "CREATE TABLE IF NOT EXISTS stnpc_wallet (id TEXT PRIMARY KEY,balance INTEGER NOT NULL)",
 "CREATE TABLE IF NOT EXISTS stnpc_journal (id TEXT PRIMARY KEY,steamid TEXT NOT NULL,payload TEXT NOT NULL,status TEXT NOT NULL)"
}) do if N.Query(q)==false then N.DatabaseReady=false end end
function N.GetStock(id)
    if N.Stocks[id] then return N.Stocks[id] end
    local rows=N.Query("SELECT payload FROM stnpc_stock WHERE id="..sql.SQLStr(id));if rows==false then return nil end
    local S=STALKER_INV;local inv
    if rows and rows[1] then
        local raw=util.JSONToTable(rows[1].payload);inv=S.ValidateSaved(raw)
        if not inv then return nil end;inv.revision=tonumber(raw.revision) or 0
    else
        inv=S.EmptyInventory()
        for _,v in ipairs(N.Config.Traders[id].stock) do local nextInv=S.Insert(inv,v[1],v[2]);if not nextInv then return nil end;inv=nextInv end
        if N.Query("INSERT INTO stnpc_stock VALUES("..sql.SQLStr(id)..","..sql.SQLStr(util.TableToJSON(inv))..")")==false then return nil end
    end
    N.Stocks[id]=inv;return inv
end
function N.Balance(ply)
    local id=ply:SteamID64()
    if N.Config.Economy=="darkrp" then
        if not ply.getDarkRPVar or not ply.addMoney then return nil end
        local value=ply:getDarkRPVar("money");return type(value)=="number" and value or nil
    end
    local rows=N.Query("SELECT balance FROM stnpc_wallet WHERE id="..sql.SQLStr(id));if rows==false then return nil end
    if rows and rows[1] then local value=tonumber(rows[1].balance);if value then ply:SetNW2Int("stnpc_dummy_balance",value) end;return value end
    if N.Query("INSERT INTO stnpc_wallet VALUES("..sql.SQLStr(id)..","..N.Config.DummyStart..")")==false then return nil end
    ply:SetNW2Int("stnpc_dummy_balance",N.Config.DummyStart);return N.Config.DummyStart
end
function N.IsBlocked(ply)
    if N.Blocked[ply:SteamID64()] then return true end
    local rows=N.Query("SELECT id FROM stnpc_journal WHERE steamid="..sql.SQLStr(ply:SteamID64()).." AND status='pending'")
    return rows==false or (rows and #rows>0) or false
end
-- Восстановление расставленных NPC. Склад привязан к profile ID, общий для его копий.
file.CreateDir("stalker_npc")
function N.SpawnTrader(id,pos,ang)
    if not N.Config.Traders[id] then return end
    local e=ents.Create("stalker_npc_trader");if not IsValid(e) then return end
    e:SetTraderID(id);e:SetPos(pos);e:SetAngles(ang);e:Spawn();return e
end
function N.RestoreNPCs()
    local raw=file.Read("stalker_npc/"..game.GetMap()..".json","DATA");if not raw then return end
    local list=util.JSONToTable(raw);if not istable(list) then return end
    for _,v in ipairs(list) do if N.Config.Traders[v.id] and istable(v.pos) and istable(v.ang) then
        N.SpawnTrader(v.id,Vector(v.pos[1],v.pos[2],v.pos[3]),Angle(v.ang[1],v.ang[2],v.ang[3]))
    end end
end
hook.Add("InitPostEntity","STNPC.Restore",N.RestoreNPCs)
hook.Add("PostCleanupMap","STNPC.Restore",N.RestoreNPCs)
concommand.Add("stnpc_spawn",function(ply,_,args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local tr=ply:GetEyeTrace();if tr.HitPos:DistToSqr(ply:GetPos())>600*600 then return end
    N.SpawnTrader(args[1] or "sidor",tr.HitPos,Angle(0,ply:EyeAngles().y+180,0))
end)
function N.SaveNPCs()
 local list={};for _,e in ipairs(ents.FindByClass("stalker_npc_trader")) do
  if e~=N.ExcludeSavedEntity then local p,a=e:GetPos(),e:GetAngles();list[#list+1]={id=e:GetTraderID(),pos={p.x,p.y,p.z},ang={a.p,a.y,a.r}} end
 end
 local path="stalker_npc/"..game.GetMap()..".json";local data=util.TableToJSON(list,true)
 if not data then return false end
 file.Write(path..".pending.json",data);if file.Read(path..".pending.json","DATA")~=data then return false end
 local old=file.Read(path,"DATA");if old then file.Write(path..".backup.json",old) end
 file.Write(path,data);if file.Read(path,"DATA")~=data then return false end
 file.Delete(path..".pending.json");N.Log("placements_saved",{map=game.GetMap(),count=#list});return true
end
concommand.Add("stnpc_save",function(ply)
 if IsValid(ply) and not ply:IsSuperAdmin() then return end
 local ok=N.SaveNPCs();if IsValid(ply) then ply:ChatPrint(ok and "Торговцы сохранены" or "Ошибка сохранения торговцев") end
end)
-- Только после ручной сверки DarkRP-кошелька с журналом. Никакой автоматической повторной выплаты.
concommand.Add("stnpc_resolve",function(ply,_,args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local id=args[1];if not id or args[2]~="verified" then print("stnpc_resolve <transaction_id> verified");return end
    local rows=N.Query("SELECT steamid,payload FROM stnpc_journal WHERE id="..sql.SQLStr(id).." AND status='pending'")
    if rows and rows[1] then
        if N.Query("UPDATE stnpc_journal SET status='reviewed' WHERE id="..sql.SQLStr(id))~=false then N.Blocked[rows[1].steamid]=nil end
        N.Log("manual_resolution",{id=id,payload=rows[1].payload})
    end
end)

-- Optional one-time restock for servers that already have saved trader warehouses.
concommand.Add("stalker_survival_stock",function(p,_,args)
 if IsValid(p) and not p:IsSuperAdmin() then return end
 local id=args[1] or "sidor";if not N.Config.Traders[id] or not N.DatabaseReady then return end
 local S=STALKER_INV;local stock=N.GetStock(id);if not stock then return end
 local nextStock=S.Insert(stock,"antirad",10);if nextStock then nextStock=S.Insert(nextStock,"hazmat",2) end
 if not nextStock then return end
 nextStock.revision=(stock.revision or 0)+1
 if N.Query("REPLACE INTO stnpc_stock VALUES("..sql.SQLStr(id)..","..sql.SQLStr(util.TableToJSON(nextStock))..")")==false then return end
 N.Stocks[id]=nextStock;N.Log("survival_restock",{profile=id})
 if IsValid(p) then p:ChatPrint("На склад добавлено: 10 антирадов и 2 защитных костюма") end
end)
