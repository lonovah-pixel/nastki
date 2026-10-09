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
