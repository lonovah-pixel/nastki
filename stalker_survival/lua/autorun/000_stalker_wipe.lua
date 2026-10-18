if not SERVER then return end
-- Runs before this pack's autorun loaders. No live player state can resurrect a wiped profile.
STALKER_WIPE=STALKER_WIPE or {}
local W=STALKER_WIPE
local marker="stalker_wipe/pending.json"
local tables={"stalker_inventory","stfw_profiles","stfw_world","stnpc_stock","stnpc_wallet","stnpc_journal","stb_profiles","stb_rewards","stz_ammo",
 "stalker_stash_intel","stalker_stats",
 "darkrp_jobspawn","darkrp_position","darkrp_player","playerinformation","darkrp_door","darkrp_doorjobs","darkrp_doorgroups"}
local dirs={"stalker_inv","stalker_npc","stalker_emissions","stalker_radiation","stalker_zone","stalker_events"}
file.CreateDir("stalker_wipe")
local function reply(p,msg) if IsValid(p) then p:ChatPrint(msg) else print("[STALKER WIPE] "..msg) end end
local function fail(msg)
 W.Blocked=true
 ErrorNoHalt("[STALKER WIPE] BLOCKED: "..msg..". See stalker_wipe/pending.json; stop server and restore backup or fix error.\n")
 hook.Add("CheckPassword","STALKER.WipeBlocked",function() return false,"Wipe incomplete; administrator intervention required" end)
end
local pending=file.Read(marker,"DATA")
if pending then
 local request=util.JSONToTable(pending)
 if type(request)~="table" or request.confirm~="FULL_WIPE" or type(request.backup)~="string" or not request.backup:match("^stalker_wipe/backup_%d+_%d+$") then
  fail("Invalid pending request")
 else
  local backup=request.backup
  -- A partial run is not retried automatically: the original backup must never be overwritten.
  if file.Exists(backup.."/started.txt","DATA") then fail("Previous wipe interrupted; backup: "..backup)
  else
   file.CreateDir(backup);file.Write(backup.."/started.txt","started")
   local ok=file.Read(backup.."/started.txt","DATA")=="started"
   local files={};local snapshots={}
   for _,dir in ipairs(dirs) do
    local names=file.Find(dir.."/*.json","DATA")
    for _,name in ipairs(names or {}) do files[#files+1]=dir.."/"..name end
   end
   -- Back up every affected table and every authoritative/fallback JSON file before deleting anything.
   for _,name in ipairs(tables) do
    local exists=sql.Query("SELECT name FROM sqlite_master WHERE type='table' AND name="..sql.SQLStr(name))
    if exists==false then ok=false;break end
    if exists then
     local rows=sql.Query("SELECT * FROM "..name)
     if rows==false then ok=false;break end
     snapshots[name]=rows or {}
    end
   end
   local dump=util.TableToJSON(snapshots)
   if dump then file.Write(backup.."/tables.json",dump);ok=file.Read(backup.."/tables.json","DATA")==dump and ok else ok=false end
   for _,path in ipairs(files) do
    local raw=file.Read(path,"DATA");local copy=backup.."/"..path:gsub("/","__")
    if not raw then ok=false;break end
    file.Write(copy,raw);if file.Read(copy,"DATA")~=raw then ok=false;break end
   end
   if not ok then fail("Backup failed: "..backup)
   else
    ok=sql.Query("BEGIN")==nil
    if ok then
     for _,name in ipairs(tables) do if snapshots[name] and sql.Query("DELETE FROM "..name)==false then ok=false;break end end
     if ok then ok=sql.Query("COMMIT")~=false end
     if not ok then sql.Query("ROLLBACK") end
    end
    if not ok then fail("SQL wipe failed; backup: "..backup)
    else
     for _,path in ipairs(files) do file.Delete(path);if file.Exists(path,"DATA") then ok=false end end
     if ok then
      file.Delete(marker)
      if file.Exists(marker,"DATA") then fail("Cannot remove pending marker")
      else print("[STALKER WIPE] Completed. Backup: data/"..backup) end
     else fail("JSON removal failed; backup: "..backup) end
    end
   end
  end
 end
end
local tokens={}
concommand.Add("stalker_fullwipe",function(p,_,args)
 if IsValid(p) and not p:IsSuperAdmin() then return end
 local key=IsValid(p) and p:SteamID64() or "console"
 if args[1]=="cancel" then
  if W.Blocked then reply(p,"Вайп уже начался и прерван. Требуется восстановление из резервной копии.");return end
  file.Delete(marker);tokens[key]=nil;reply(p,file.Exists(marker,"DATA") and "Не удалось отменить" or "Запланированный вайп отменён");return
 end
 if W.Blocked then reply(p,"Вайп заблокирован после ошибки. Проверьте журнал сервера.");return end
 if args[1]=="status" then reply(p,file.Exists(marker,"DATA") and "Вайп запланирован на следующий запуск карты/сервера" or "Вайп не запланирован");return end
 -- This implementation targets SQLite. Never pretend an external MySQL wallet was erased.
 if MySQLite and MySQLite.isMySQL and MySQLite.isMySQL() then reply(p,"Внешний MySQL: полный вайп не поддерживается; ничего не изменено.");return end
 if args[1]~="confirm" then
  tokens[key]={value=tostring(math.random(100000,999999)),expires=CurTime()+60}
  reply(p,"ПОЛНЫЙ ВАЙП сборки + DarkRP SQLite: деньги/имена, инвентари/тайники, группировки, точки, NPC, склады, зоны, поля аномалий и логова мутантов всех карт. Файлы аддонов, баны и сторонние базы не удаляются.")
  reply(p,"Для подтверждения за 60 сек: stalker_fullwipe confirm "..tokens[key].value.." FULL_WIPE");return
 end
 local token=tokens[key]
 if not token or token.expires<CurTime() or args[2]~=token.value or args[3]~="FULL_WIPE" then reply(p,"Неверное/просроченное подтверждение");return end
 if file.Exists(marker,"DATA") then reply(p,"Вайп уже запланирован");return end
 local request={confirm="FULL_WIPE",actor=key,backup="stalker_wipe/backup_"..os.time().."_"..token.value}
 local raw=util.TableToJSON(request);file.Write(marker,raw)
 if file.Read(marker,"DATA")~=raw then reply(p,"Ошибка записи: вайп не запланирован");return end
 tokens[key]=nil
 reply(p,"Вайп запланирован. Остановите и запустите сервер. На старте будут созданы резервные копии, затем очищены данные. Отмена: stalker_fullwipe cancel")
end)
