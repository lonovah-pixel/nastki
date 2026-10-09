local N=STALKER_NPC
-- Мост к проверенному формату Inventory v1: единая SQLite-транзакция вместо двух GiveItem.
-- JSON записывается исключительно ПОСЛЕ COMMIT: rollback не должен оставить новую резервную копию.
function N.CommitTrade(ply,session,quote)
    local S=STALKER_INV;local id=ply:SteamID64();local profile=N.Config.Traders[session.profile]
    if N.Busy then return false,"stale" end
    if N.IsBlocked(ply) then return false,"locked" end
    if not quote or quote.expires<CurTime() then return false,"expired" end
    local stock=N.GetStock(session.profile);local inv=ply:GetInventory()
    if not stock or not inv or inv.revision~=quote.invRevision or stock.revision~=quote.stockRevision then return false,"stale" end
    local balance=N.Balance(ply);if not balance then return false,"economy" end
    S.CaptureEquipment(ply)
    local result,err=N.BuildTrade(inv,stock,profile,quote.lines,balance,ply);if not result then return false,err end
    if result.total~=quote.total then return false,"stale" end
    if hook.Run("STNPC_CanTrade",ply,session.entity,quote.lines,result.total)==false then return false,"invalid" end
    N.Busy=true;ply.StnpcTrading=true
    local txid=S.UID();local dark=N.Config.Economy=="darkrp";local begun=false;local moneyTouched=false
    local expectedRevision=inv.revision
    local ok,reason=pcall(function()
        if dark then
            local journal=util.TableToJSON({before=balance,delta=-result.total,profile=session.profile,time=os.time(),lines=quote.lines})
            if N.Query("INSERT INTO stnpc_journal VALUES("..sql.SQLStr(txid)..","..sql.SQLStr(id)..","..sql.SQLStr(journal)..",'pending')")==false then error("storage") end
        end
        if N.Query("BEGIN IMMEDIATE")==false then error("storage") end;begun=true
        if dark and result.total~=0 then
            moneyTouched=true;ply:addMoney(-result.total)
            if N.Balance(ply)~=balance-result.total then error("economy") end
        end
        -- Сторонний money-hook мог изменить инвентарь; такой снимок нельзя перезаписывать.
        if ply:GetInventory().revision~=expectedRevision then error("stale") end
        result.inventory.revision=(expectedRevision+1)%4294967296
        result.stock.revision=(stock.revision+1)%4294967296
        S.SaveStamp=math.max((S.SaveStamp or 0)+1,os.time()*1000)
        local saved=table.Copy(result.inventory);saved.savedAt=S.SaveStamp
        local queries={
            "REPLACE INTO stalker_inventory VALUES("..sql.SQLStr(id)..","..sql.SQLStr(util.TableToJSON(saved))..")",
            "REPLACE INTO stnpc_stock VALUES("..sql.SQLStr(session.profile)..","..sql.SQLStr(util.TableToJSON(result.stock))..")"
        }
        if dark then queries[#queries+1]="UPDATE stnpc_journal SET status='committed' WHERE id="..sql.SQLStr(txid)
        else queries[#queries+1]="REPLACE INTO stnpc_wallet VALUES("..sql.SQLStr(id)..","..result.balance..")" end
        for _,q in ipairs(queries) do if N.Query(q)==false then error("storage") end end
        if N.Query("COMMIT")==false then error("storage") end;begun=false
    end)
    if not ok then
        if begun then N.Query("ROLLBACK") end
        if dark then
            local restored=not moneyTouched
            if moneyTouched then
                local current=N.Balance(ply)
                if current==balance then restored=true
                elseif current==balance-result.total then local called=pcall(ply.addMoney,ply,result.total);restored=called and N.Balance(ply)==balance end
            end
            if restored then N.Query("UPDATE stnpc_journal SET status='aborted' WHERE id="..sql.SQLStr(txid))
            else N.Blocked[id]=true end
        end
        N.Busy=false;ply.StnpcTrading=nil
        N.Log("trade_failed",{id=txid,steamid=id,error=tostring(reason)})
        return false,"storage"
    end
    -- Публикуем состояние только после успешного COMMIT; экипировка не входит в продажи.
    ply.StalkerInventory=result.inventory;N.Stocks[session.profile]=result.stock
    ply:SetNW2Float("stalker_inv_weight",result.weight)
    local saved,saveErr=pcall(S.SaveInventory,ply)
    if not saved or not saveErr then N.Log("postcommit_backup_error",{id=txid}) end
    if not dark then ply:SetNW2Int("stnpc_dummy_balance",result.balance) end
    N.Busy=false;ply.StnpcTrading=nil
    local synced,syncError=pcall(S.Sync,ply)
    if not synced then N.Log("postcommit_sync_error",{id=txid,error=tostring(syncError)}) end
    N.Log("trade",{id=txid,steamid=id,profile=session.profile,total=result.total,lines=quote.lines,economy=N.Config.Economy})
    return true
end
hook.Add("STALKER_INV_CanAction","STNPC.TransactionLock",function(ply) if ply.StnpcTrading then return false end end)
