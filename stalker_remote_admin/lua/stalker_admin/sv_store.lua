local A=STALKER_ADMIN
function A.Query(q)
 local r=sql.Query(q)
 if r==false then ErrorNoHalt("[STALKER ADMIN] SQLite: "..tostring(sql.LastError()).."\n") end
 return r
end
A.Ready=true
for _,query in ipairs({
 "CREATE TABLE IF NOT EXISTS sta_seen (sid TEXT PRIMARY KEY, rank INTEGER NOT NULL)",
 "CREATE TABLE IF NOT EXISTS sta_roles (sid TEXT PRIMARY KEY, role TEXT NOT NULL)",
 "CREATE TABLE IF NOT EXISTS sta_bans (sid TEXT PRIMARY KEY, name TEXT, reason TEXT, actor TEXT, expires INTEGER, created INTEGER, rank INTEGER)",
 "CREATE TABLE IF NOT EXISTS sta_sanctions (sid TEXT, kind TEXT, expires INTEGER, PRIMARY KEY(sid,kind))",
 "CREATE TABLE IF NOT EXISTS sta_audit (id INTEGER PRIMARY KEY AUTOINCREMENT, time INTEGER, actor TEXT, action TEXT, target TEXT, detail TEXT, status TEXT)",
 -- Служебные отметки (одноразовые миграции в ULib) и допуск автора бана ULib (нужен для разбана по рангу).
 "CREATE TABLE IF NOT EXISTS sta_meta (key TEXT PRIMARY KEY, value TEXT)",
 "CREATE TABLE IF NOT EXISTS sta_banmeta (sid TEXT PRIMARY KEY, rank INTEGER, actor TEXT)"
}) do if A.Query(query)==false then A.Ready=false end end
A.Roles={}
local rows=A.Query("SELECT sid,role FROM sta_roles")
if rows==false then A.Ready=false else for _,row in ipairs(rows or {}) do A.Roles[row.sid]=row.role end end
A.SeenRanks={}
local seen=A.Query("SELECT sid,rank FROM sta_seen")
if seen==false then A.Ready=false else for _,row in ipairs(seen or {}) do A.SeenRanks[row.sid]=tonumber(row.rank) or 0 end end
function A.Actor(p) return IsValid(p) and p:SteamID64() or "CONSOLE" end
function A.GetMeta(key) local v=sql.QueryValue("SELECT value FROM sta_meta WHERE key="..sql.SQLStr(key));return v end
function A.SetMeta(key,value) return A.Query("REPLACE INTO sta_meta VALUES("..sql.SQLStr(key)..","..sql.SQLStr(tostring(value))..")")~=false end

local function ulxLog(p,action,target,detail,status)
 if status=="attempt" or type(ulx)~="table" or type(ulx.logString)~="function" then return end
 local who=IsValid(p) and (p:Nick().."("..p:SteamID64()..")") or "Консоль"
 local text=string.format("[Комендант] %s: %s → %s (%s)%s",who,tostring(action),tostring(target~="" and target or "сервер"),status=="success" and "выполнено" or "отклонено",
  (detail and detail~="" and status~="success") and (" — "..tostring(detail):sub(1,200)) or "")
 pcall(ulx.logString,text)
end
function A.Audit(p,action,target,detail,status)
 if not A.Ready then return false end
 local ok=A.Query("INSERT INTO sta_audit(time,actor,action,target,detail,status) VALUES("..os.time()..","..sql.SQLStr(A.Actor(p))..","..sql.SQLStr(action)..","..sql.SQLStr(target or "")..","..sql.SQLStr(tostring(detail or ""))..","..sql.SQLStr(status or "attempt")..")")~=false
 -- Журнал ULX дублирует итог действия: так персонал видит всё в одном месте (data/ulx_logs).
 if ok then ulxLog(p,action,target or "",detail,status or "attempt") end
 return ok
end

--[[ Баны: при ULib — ULib.bans (видны в XGUI, проверяются ULib), иначе собственная таблица sta_bans. ]]
local function banRank(sid)
 local r=sql.QueryValue("SELECT rank FROM sta_banmeta WHERE sid="..sql.SQLStr(sid))
 -- Бан, выданный напрямую в ULX: по умолчанию «ulx ban» доступна администраторам.
 return tonumber(r) or 60
end
-- Активный бан в едином виде {sid,name,reason,actor,expires,created,rank}; false — хранилище недоступно.
function A.GetBan(sid)
 if not A.Ready then return false end
 if A.UsesULibBans() then
  local steamid=A.SteamID(sid);local b=steamid and ULib.bans[steamid]
  if type(b)~="table" then return nil end
  local expires=tonumber(b.unban) or 0
  if expires~=0 and expires<=os.time() then return nil end
  return {sid=sid,name=b.name or sid,reason=b.reason or "Без причины",actor=b.admin or "",expires=expires,created=tonumber(b.time) or 0,rank=banRank(sid)}
 end
 local rows=A.Query("SELECT * FROM sta_bans WHERE sid="..sql.SQLStr(sid))
 if rows==false then return false end
 local ban=rows and rows[1]
 if ban and (tonumber(ban.expires)==0 or tonumber(ban.expires)>os.time()) then return ban end
end
function A.StoreBan(p,sid,name,reason,minutes)
 if A.UsesULibBans() then
  local steamid=A.SteamID(sid);if not steamid then return false,"Неверный SteamID64" end
  local ok,err=pcall(ULib.addBan,steamid,minutes,reason,name,IsValid(p) and p or "Комендант (консоль)")
  if not ok then ErrorNoHalt("[STALKER ADMIN] ULib.addBan: "..tostring(err).."\n");return false,"Ошибка записи бана ULib" end
  A.Query("REPLACE INTO sta_banmeta VALUES("..sql.SQLStr(sid)..","..A.Rank(p)..","..sql.SQLStr(A.Actor(p))..")")
  return true
 end
 local expires=minutes==0 and 0 or os.time()+minutes*60
 if A.Query("REPLACE INTO sta_bans VALUES("..sql.SQLStr(sid)..","..sql.SQLStr(name)..","..sql.SQLStr(reason)..","..sql.SQLStr(A.Actor(p))..","..expires..","..os.time()..","..A.Rank(p)..")")==false then return false,"Ошибка записи бана" end
 return true
end
function A.RemoveBan(p,sid)
 if A.UsesULibBans() then
  local steamid=A.SteamID(sid);if not steamid then return false end
  local ok,err=pcall(ULib.unban,steamid,IsValid(p) and p or nil)
  if not ok then ErrorNoHalt("[STALKER ADMIN] ULib.unban: "..tostring(err).."\n");return false end
  A.Query("DELETE FROM sta_banmeta WHERE sid="..sql.SQLStr(sid))
  -- Старая запись «Коменданта» не должна воскреснуть, если ULib когда-нибудь удалят.
  A.Query("DELETE FROM sta_bans WHERE sid="..sql.SQLStr(sid))
  return true
 end
 return A.Query("DELETE FROM sta_bans WHERE sid="..sql.SQLStr(sid))~=false
end
-- Одноразовый перенос активных банов sta_bans в ULib (отметка в sta_meta). ULib.addBan сам выкинет онлайн-цель.
function A.MigrateBans()
 if not A.Ready or not A.UsesULibBans() or A.GetMeta("bans_migrated") then return 0 end
 local rows=A.Query("SELECT * FROM sta_bans WHERE expires=0 OR expires>"..os.time())
 if rows==false then return 0 end
 local moved=0
 for _,ban in ipairs(rows or {}) do
  local steamid=A.SteamID(ban.sid)
  if steamid and not ULib.bans[steamid] then
   local expires=tonumber(ban.expires) or 0
   local minutes=expires==0 and 0 or math.max(1,math.ceil((expires-os.time())/60))
   if pcall(ULib.addBan,steamid,minutes,ban.reason,ban.name,"Комендант ("..tostring(ban.actor)..")") then
    moved=moved+1
    A.Query("REPLACE INTO sta_banmeta VALUES("..sql.SQLStr(ban.sid)..","..(tonumber(ban.rank) or 100)..","..sql.SQLStr(ban.actor or "")..")")
   end
  end
 end
 A.SetMeta("bans_migrated",os.time())
 if moved>0 then print("[STALKER ADMIN] Перенесено банов в ULib: "..moved) end
 return moved
end

A.SanctionCache={}
function A.GetSanction(p,kind)
 local cached=A.SanctionCache[p:SteamID64()]
 if cached and cached[kind]~=nil then local v=cached[kind];return v==0 or v>os.time() end
 local rows=A.Query("SELECT expires FROM sta_sanctions WHERE sid="..sql.SQLStr(p:SteamID64()).." AND kind="..sql.SQLStr(kind))
 if rows==false then return true end -- a failed read must not grant a forbidden channel
 local expiry=rows and tonumber(rows[1].expires)
 A.SanctionCache[p:SteamID64()]=cached or {};A.SanctionCache[p:SteamID64()][kind]=expiry or -1
 return expiry and (expiry==0 or expiry>os.time()) or false
end
function A.SetSanction(p,kind,minutes)
 A.SanctionCache[p:SteamID64()]=nil
 local expiry=minutes==0 and 0 or os.time()+minutes*60
 return A.Query("REPLACE INTO sta_sanctions VALUES("..sql.SQLStr(p:SteamID64())..","..sql.SQLStr(kind)..","..expiry..")")~=false
end
function A.Page(kind,page)
 if not A.Int(page,1,100000) then return nil end
 local size=A.Config.MaxPageRows;local offset=(page-1)*size
 if kind=="bans" and A.UsesULibBans() then
  local list={};local now=os.time()
  for steamid,b in pairs(ULib.bans) do
   local expires=tonumber(type(b)=="table" and b.unban) or 0;local sid=A.SteamID64(steamid)
   if sid and (expires==0 or expires>now) then
    list[#list+1]={sid=sid,name=b.name or sid,reason=b.reason or "Без причины",actor=b.admin or "",expires=expires,created=tonumber(b.time) or 0}
   end
  end
  table.sort(list,function(a,b) if a.created~=b.created then return a.created>b.created end;return a.sid<b.sid end)
  local out={};for i=offset+1,math.min(#list,offset+size) do out[#out+1]=list[i] end
  return out
 end
 local query
 if kind=="bans" then query="SELECT * FROM sta_bans WHERE expires=0 OR expires>"..os.time().." ORDER BY created DESC"
 else query="SELECT * FROM sta_audit ORDER BY id DESC" end
 return A.Query(query.." LIMIT "..size.." OFFSET "..offset)
end
local function banMessage(ban)
 return "Блокировка: "..tostring(ban.reason).." / "..(tonumber(ban.expires)==0 and "бессрочно" or os.date("%Y-%m-%d %H:%M",tonumber(ban.expires)))
end
hook.Add("CheckPassword","STALKER.AdminBans",function(sid)
 local ban=A.GetBan(sid)
 if ban==false then return false,"Система доступа недоступна. Сообщите владельцу сервера." end
 if ban then return false,banMessage(ban) end
end)
hook.Add("PlayerInitialSpawn","STALKER.AdminBanFallback",function(p)
 timer.Simple(1,function() if not IsValid(p) then return end
  local ban=A.GetBan(p:SteamID64());if ban==false or ban then p:Kick(ban and banMessage(ban) or "Хранилище доступа недоступно") end
 end)
end)
timer.Create("STALKER.AdminLogRetention",3600,0,function()
 if A.Ready then A.Query("DELETE FROM sta_audit WHERE time<"..(os.time()-math.max(1,A.Config.LogDays)*86400)) end
end)
