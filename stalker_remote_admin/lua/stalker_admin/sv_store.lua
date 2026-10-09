local A=STALKER_ADMIN
function A.Query(q)
 local r=sql.Query(q)
 if r==false then ErrorNoHalt("[STALKER ADMIN] SQLite: "..sql.LastError().."\n") end
 return r
end
A.Ready=true
for _,query in ipairs({
 "CREATE TABLE IF NOT EXISTS sta_seen (sid TEXT PRIMARY KEY, rank INTEGER NOT NULL)",
 "CREATE TABLE IF NOT EXISTS sta_roles (sid TEXT PRIMARY KEY, role TEXT NOT NULL)",
 "CREATE TABLE IF NOT EXISTS sta_bans (sid TEXT PRIMARY KEY, name TEXT, reason TEXT, actor TEXT, expires INTEGER, created INTEGER, rank INTEGER)",
 "CREATE TABLE IF NOT EXISTS sta_sanctions (sid TEXT, kind TEXT, expires INTEGER, PRIMARY KEY(sid,kind))",
 "CREATE TABLE IF NOT EXISTS sta_audit (id INTEGER PRIMARY KEY AUTOINCREMENT, time INTEGER, actor TEXT, action TEXT, target TEXT, detail TEXT, status TEXT)"
}) do if A.Query(query)==false then A.Ready=false end end
A.Roles={}
local rows=A.Query("SELECT sid,role FROM sta_roles")
if rows==false then A.Ready=false else for _,row in ipairs(rows or {}) do A.Roles[row.sid]=row.role end end
A.SeenRanks={}
local seen=A.Query("SELECT sid,rank FROM sta_seen")
if seen==false then A.Ready=false else for _,row in ipairs(seen or {}) do A.SeenRanks[row.sid]=tonumber(row.rank) or 0 end end
function A.Actor(p) return IsValid(p) and p:SteamID64() or "CONSOLE" end
function A.Audit(p,action,target,detail,status)
 if not A.Ready then return false end
 return A.Query("INSERT INTO sta_audit(time,actor,action,target,detail,status) VALUES("..os.time()..","..sql.SQLStr(A.Actor(p))..","..sql.SQLStr(action)..","..sql.SQLStr(target or "")..","..sql.SQLStr(tostring(detail or ""))..","..sql.SQLStr(status or "attempt")..")")~=false
end
function A.GetBan(sid)
 if not A.Ready then return false end
 local rows=A.Query("SELECT * FROM sta_bans WHERE sid="..sql.SQLStr(sid))
 if rows==false then return false end
 local ban=rows and rows[1]
 if ban and (tonumber(ban.expires)==0 or tonumber(ban.expires)>os.time()) then return ban end
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
 local query
 if kind=="bans" then query="SELECT * FROM sta_bans WHERE expires=0 OR expires>"..os.time().." ORDER BY created DESC"
 else query="SELECT * FROM sta_audit ORDER BY id DESC" end
 return A.Query(query.." LIMIT "..size.." OFFSET "..offset)
end
hook.Add("CheckPassword","STALKER.AdminBans",function(sid)
 local ban=A.GetBan(sid)
 if ban==false then return false,"Система доступа недоступна. Сообщите владельцу сервера." end
 if ban then return false,"Блокировка: "..ban.reason.." / "..(tonumber(ban.expires)==0 and "бессрочно" or os.date("%Y-%m-%d %H:%M",tonumber(ban.expires))) end
end)
hook.Add("PlayerInitialSpawn","STALKER.AdminBanFallback",function(p)
 timer.Simple(1,function() if not IsValid(p) then return end
  local ban=A.GetBan(p:SteamID64());if ban==false or ban then p:Kick(ban and ban.reason or "Хранилище доступа недоступно") end
 end)
end)
timer.Create("STALKER.AdminLogRetention",3600,0,function()
 if A.Ready then A.Query("DELETE FROM sta_audit WHERE time<"..(os.time()-A.Config.LogDays*86400)) end
end)
